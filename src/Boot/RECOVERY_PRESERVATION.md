# AndroidSMA recovery preservation map

Date: 2026-08-31

Source of truth: `C:\dev\AndroidSMA-main\src\Boot\Recovery.ps1`

This document freezes the behavior that must survive removing application policy from `MainActivity.cs`. It is a preservation contract, not a redesign.

## The current machine

```text
Android creates Activity
        |
        v
Does private/PROFILE.PS1 exist? -- no --> green recovery :(
        |
       yes
        |
        v
obtain runspace -> publish Activity and PSScriptRoot -> invoke PROFILE.PS1
        |                                            |
        | success                                    | terminating or stream error
        v                                            v
 application owns view                    format error -> dispose runspace
                                                     -> green recovery :(

green recovery
  COPY TO CLIPBOARD -> failure + current PROFILE.PS1 if readable
  HELP              -> exact six-step help + current details
  IMPORT FILE       -> Android document picker
  RETRY              -> dispose failed app runspace -> try PROFILE.PS1 again

document result
  cancelled/wrong request -> no-op
  accepted -> validate display name
           -> stream to <name>.incoming
           -> flush to disk
           -> atomic replace/move to private/<name>
           -> PROFILE.PS1: retry immediately
           -> other file: show IMPORTED and ask for RETRY
```

## Observable behavior that is frozen

- Private root is `Activity.FilesDir.AbsolutePath`.
- Boot filename is exactly `PROFILE.PS1`; imported case variants are canonicalized to that spelling.
- `$Activity` is present in the application runspace. `MainActivity` attempts to
  inject `$PSScriptRoot`, but the profile is invoked with `AddScript(string)` as
  anonymous source; the automatic variable resolves to empty inside that source.
  This is a verified contract defect, not behavior to preserve. The corrected
  boot path must invoke a file-backed script or otherwise provide an honest
  private-root variable that cannot be shadowed by the automatic variable.
- Profile text runs in the application runspace's global scope.
- Either a thrown exception or anything in the PowerShell error stream fails boot.
- A failed application runspace is disposed before recovery is shown.
- Retry always starts from a fresh application runspace.
- Recovery background is RGB `(11, 61, 46)` with white text.
- Heading is `:(` at 64sp. Details are selectable, scrollable, 15sp text.
- The preserved failure buttons remain `COPY TO CLIPBOARD`, `HELP`, `IMPORT FILE`, and `RETRY`.
- `PRIVATE HOME` extends that surface without changing its green visual language.
- The private-home walker is rooted at `Activity.FilesDir.AbsolutePath`, cannot
  navigate above it, sorts directories before files, and exposes file metadata
  and a copyable path without requiring a desktop shell.
- Imports reject blank names, `.`, `..`, `/`, and `\`.
- Imports use a same-directory `.incoming` file, flush it to durable storage, then replace the destination.
- Importing a non-profile file leaves recovery visible and tells the operator to select retry.
- The failure report keeps source, line, column, ErrorRecord fields, UTC timestamp, pid, tid, package, device, Android/API, ABI, .NET description, and app-runspace ID.
- Failure clipboard payload includes the current profile between begin/end markers, or says it is unavailable.
- No APK rebuild is required to repair `PROFILE.PS1` or add supporting scripts.

## The correct PS1 shape

The recovery script is not a line-for-line C# port. It owns verbs and state:

```text
Receive boot event
  -> Test-Path PROFILE.PS1
  -> New-AndroidSmaApplicationRunspace
  -> Invoke-AndroidSmaProfile
  -> Show-AndroidSmaRecovery on failure

Receive document result
  -> Import-AndroidSmaDocument
  -> Restart-AndroidSmaApplication when it is PROFILE.PS1
```

The firmware owns filesystem discovery and housekeeping through the BCL types
already required by CoreCLR (`System.IO.File`, `DirectoryInfo`, and `Path`). It
does not load optional command assemblies merely to recover. The disposable
application runspace may admit command implementations separately. Direct
Android types appear only where Android is the actual capability: Activity,
Intent, ContentResolver, clipboard, dialogs, and views.

## The tiny entry artifact that remains

Android cannot create a `.ps1` as an Activity. One Android-callable type must exist in packaged IL so the platform has an entry point. It has only two jobs:

1. On `OnCreate`, ensure CoreCLR/SMA is alive and deliver a `Create` event containing the Activity to the durable boot runspace.
2. On `OnActivityResult`, deliver an `ActivityResult` event containing request code, result code, and Intent to that same boot runspace.

It must not contain profile paths, recovery text, buttons, import rules, error formatting, runspace policy, or application lifetime policy. Those belong to PS1.

The source tree does not require a C# file for this artifact. After behavior is proven, the entry type can be emitted mechanically as IL during the build or carried as a small audited bootstrap binary. That choice is downstream of the recovery proof, not permission to hide an application framework in a DLL.

## Why there are two runspaces

Today C# survives while the failed profile runspace is disposed. Once recovery lives in PS1, recovery cannot saw off the runspace branch it is sitting on. Therefore:

- a small durable boot/recovery runspace owns recovery and event admission;
- a disposable application runspace owns `PROFILE.PS1` and everything it launches.

This preserves the visible contract while making retry honest. The boot runspace is firmware-shaped; the application runspace is the replaceable userland.

## Cmdlet sanity check

The current C# uses `InitialSessionState.Create()`. That factory contains **0 commands and 0 providers** on the inspected PowerShell runtime. `CreateDefault2()` contains **234 commands and 6 providers**. That explains the gap between "SMA is loaded" and "PowerShell cmdlets work."

`CreateDefault2()` is the oracle for the first working build, not the final assembly policy. We will record which commands/providers the product wants, then construct an explicit session-state manifest and keep only the assemblies that satisfy it.

## Non-negotiable compiler and server lane

The reduced runtime is not merely able to execute canned scripts. It must always be able to:

```text
parse -> inspect/mutate symbols and AST -> bind -> emit -> RyuJIT -> execute
                                                    |
                                                    +-> serve/connect/stream
```

Accordingly, SMA's language/compiler path, the dynamic runtime, expression trees, metadata inspection, `System.Reflection.Emit` (including dynamic methods and IL generation), and the basic network/TLS/WebSocket stack are core capabilities. Roslyn and CodeDOM are not the definition of compilation and do not earn admission merely because `Add-Type` historically uses them. A direct emitter must be able to create callable IL, hand it to RyuJIT, invoke it, and expose the result through a small local server in the device proof.

## Private-home extension

The private-home view is a recovery intent built on
`Get-ChildItem -LiteralPath`. Its first admitted shape is deliberately read-only:
touch navigation, file metadata, and path copying. Mutating verbs require their
own recovery and atomicity proofs.

## Proof gates

1. Missing profile produces the same green recovery surface.
2. Syntax error reports exact source/line/column and copies the profile.
3. Runtime error reports the ErrorRecord fields and script stack.
4. Import of `PROFILE.ps1` canonicalizes the name and boots immediately.
5. Import of a support file keeps recovery visible and becomes discoverable with `Get-ChildItem`.
6. Interrupted import never replaces the last good destination.
7. Retry uses a new application-runspace ID but does not destroy the recovery runspace.
8. A repaired profile boots without rebuilding or reinstalling the APK.
9. Private-home navigation cannot escape `Activity.FilesDir.AbsolutePath`.
10. The walker opens nested directories and reports files without altering them.
