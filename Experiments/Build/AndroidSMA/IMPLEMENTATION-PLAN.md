# Recovery.ps1 to Android entry assembly

Status: implementation plan; no source-removal authority

## Mission

Make `src/Boot/Recovery.ps1` the canonical, human-maintained definition of the
AndroidSMA entry activity and recovery experience.

`Foreground.ps1` will be the separate canonical definition of the Android
foreground service that owns durable runtime liveness and integrations. The
Activity owns recovery and touch projection; the Service owns foreground
lifecycle. Neither script is permission to merge those responsibilities or
import an older application's architecture.

`Build-AndroidSMA.ps1` must validate and lower that PS1 into a persistent
managed assembly that Android can instantiate. The APK must not contain
`Recovery.ps1` as source, an embedded script string, generated C#, Roslyn, or a
retained project file. The current recovery screen must retain its look and
behavior and gain a small touch-operated, read-only walker rooted at the
application's private home.

The build must select exactly one target:

| Build choice | RID | APK ABI | CoreCLR host | Native compiler |
|---|---|---|---|---|
| `Arm64` | `android-arm64` | `arm64-v8a` | `Microsoft.Android.Runtime.CoreCLR.37.android-arm64` | `aarch64-linux-android34-clang` |
| `Arm32` | `android-arm` | `armeabi-v7a` | `Microsoft.Android.Runtime.CoreCLR.37.android-arm` | `armv7a-linux-androideabi34-clang` |

There is one product shape and one source tree. Architecture is build data, not
a fork of recovery behavior.

## Current truth

- `src/Boot/Recovery.ps1` is the application firmware and canonical behavior
  source. On 2026-09-02 it passed the missing-profile, parser-failure,
  runtime-failure, private-home, and successful file-backed profile gates on
  the ARM32 Google TV target.
- `MainActivity.cs` is now only the temporary Android-to-firmware bridge. It is
  not a behavior oracle and has no authority to regain application policy.
- The deployed application already runs SMA and PS1 and exposes its Activity to
  PowerShell.
- The ARM64 native shim is present and has a reproducibility receipt.
- The ignored `.dotnet-p7` SDK/workload installation reproduces the pinned
  Preview 7 ARM32 CoreCLR build. The checked-in ARM32 native shim reproduces
  the recorded hash.
- Android packaging still requires MSBuild project information. Eliminating the
  retained `.csproj` means generating disposable packaging input under
  `build/<architecture>/`, not pretending the Android packager has no contract.

## Layer discipline

PowerShell uses the public .NET and .NET-for-Android surface already packaged
with AndroidSMA. It does not reimplement the operating-system service beneath
that surface.

- Android USB accessory work starts with `Android.Hardware.Usb.UsbManager`, the
  Activity intent, permission, and `OpenAccessory()`.
- Internet work starts with `HttpClient` or managed sockets.
- Android UI work starts with the managed Android view types.
- Private Binder transaction layouts, guessed OEM transaction numbers, JNI
  object construction, and direct device-node access are rejected unless the
  corresponding public API first produces a correctly recorded, reproducible
  failure.
- PowerShell collection semantics must be checked before diagnosing a binding.
  In particular, `@($null)` has count one and is not evidence that Android
  returned an array containing a broken object.

The build experiment must not turn platform archaeology into product source.

## Vocabulary boundary

AndroidSMA begins with an empty authored vocabulary and admits each word on
purpose. Runspaces may reuse the same admitted PS1 commands and behavioral
contracts, but they do not acquire implicit shared state, automatic imports, or
an inherited application namespace.

DirectPort is the lingua franca for concepts that genuinely survive across
substrates. It begins with no predeclared graphics or platform glossary. A
concept and its name enter that vocabulary only after their semantics remain
honest on more than one substrate. Similar spelling is not sufficient evidence,
and a convenient native noun is not automatically ours to generalize.

Platform namespaces and terms remain at the narrow membrane where PS1 touches
their assemblies or tools. For example, an Android `Surface` remains an Android
object unless a separately named DirectPort concept earns a proven contract
across substrates. Android, CoreCLR, SMA, Java, JNI, DirectX, D2D,
AHardwareBuffer, HLSL, XML, JavaScript, and TypeScript names do not become the
project's architecture merely because an implementation uses them. Meaningful
platform differences must not be hidden behind false equivalence.

The reusable contract is the command vocabulary, accepted and returned object
shape, ownership rule, and observable behavior. The exact implementation may
differ by platform or architecture. In-process objects cross a runspace
boundary only through an explicit, ownership-safe handoff; objects that cannot
cross remain at home behind deliberate handles.

Lowering may require private generated CLR type names and dependencies retain
their own namespaces. Those are implementation coordinates, not public
vocabulary. Filesystem layout does not manufacture namespaces, and generated
type names must not leak into `Get-Command`, normal output, or durable scripts.

## Meaning of "compile Recovery.ps1"

The accepted path is:

```text
Recovery.ps1
  -> PowerShell parser and AST
  -> recovery-subset validator
  -> explicit AST-to-IL lowering
  -> PersistedAssemblyBuilder / metadata writer
  -> AndroidSMA.Entry.dll
  -> Android packaging
```

Rejected substitutes:

- embedding PS1 text in an assembly and evaluating it at startup;
- translating PS1 to generated C#;
- invoking Roslyn or CodeDOM;
- checking in a hand-written bootstrap DLL with hidden application policy;
- claiming a runtime-created `DynamicMethod` is a persisted build artifact;
- copying bytes from an assembly produced by another language toolchain.

Android must see a real packaged type derived from `Android.App.Activity` before
SMA can run. That type and its Android lifecycle overrides are emitted IL. This
is an Android entry requirement, not permission to retain C# semantics in the
source tree.

## Recovery compiler boundary

Do not attempt to compile arbitrary PowerShell. Admit the smallest explicit
subset used by the recovery program and reject everything else with source
location diagnostics.

Initial admitted shapes:

- typed parameters and local/script variables;
- constants, arrays, property access, casts, and string interpolation;
- static and instance construction/method calls;
- `if`, `switch`, `foreach`, `try/catch/finally`, and explicit returns;
- function declarations lowered to assembly methods;
- event scriptblocks whose capture set is statically known;
- Android lifecycle entry declarations required for `OnCreate` and
  `OnActivityResult`;
- narrowly enumerated filesystem operations and runspace creation/invocation.

Initial rejection examples:

- dynamic command-name construction;
- unbounded module discovery or implicit imports;
- `Invoke-Expression`;
- runtime type generation inside the recovery program;
- unresolved member invocation;
- arbitrary pipeline binding in the pre-SMA failure path.

Every accepted AST node must name its lowering rule. Unsupported syntax fails
the build; it never silently falls back to an interpreter.

## Boot independence

The recovery screen must still appear when SMA cannot load. Therefore the
emitted entry assembly has two regions:

1. A BCL + Android recovery kernel that can draw the green failure screen,
   browse private home, import a replacement, copy diagnostics, and retry.
2. An SMA application launcher that creates the disposable application
   runspace and invokes `PROFILE.PS1` when SMA is healthy.

The canonical PS1 may describe both regions, but the compiler must prove that
the recovery kernel does not reference SMA types. This is a static dependency
gate, verified again from emitted metadata.

## Preserved visible contract

- Background RGB `(11, 61, 46)` and white text.
- Failure heading `:(` at 64sp.
- Selectable, scrollable details at 15sp.
- Existing clipboard, help, import, and retry behavior.
- Exact detailed PowerShell error information when SMA is available.
- Atomic `.incoming` import replacement.
- Repair without reinstalling the APK.
- `PRIVATE HOME` uses the same surface, never leaves
  `Activity.FilesDir.AbsolutePath`, lists directories before files, and is
  read-only until mutation operations earn separate proof.

## Build-AndroidSMA.ps1 contract

`AssemblyPolicy.psd1` is the canonical assembly admission wall consumed by the
build. An APK assembly absent from that data file is a build failure. Refused
assemblies are fatal; closure-only assemblies require metadata evidence and an
omission receipt before they may remain.

Proposed command surface:

```powershell
.\Build-AndroidSMA.ps1 -Architecture Arm64
.\Build-AndroidSMA.ps1 -Architecture Arm32
.\Build-AndroidSMA.ps1 -Architecture Arm64 -ValidateOnly
.\Build-AndroidSMA.ps1 -Architecture Arm32 -WhatIf
```

Optional switches may select configuration, output root, or validation-only
mode. They must not change product semantics.

`-ValidateOnly` executes every read-only check: SDK and pack resolution, AST
validation, native-tool discovery, assembly-policy validation, and dependency
closure. `-WhatIf` performs those checks and describes every proposed write,
emission, packaging operation, install, or device action. Neither is a fake
success path; both report unresolved prerequisites precisely.

The build performs these stages in order:

1. Resolve the requested architecture through one closed target table.
2. Select the pinned .NET 11 Preview 7 SDK and Android workload.
3. Verify the target CoreCLR host and runtime packs before writing output.
4. Rebuild or verify the target `libpsl-native.so` with the matching NDK
   compiler and recorded hash.
5. Parse `Recovery.ps1`, validate the admitted subset, and emit
   `AndroidSMA.Entry.dll` plus a source-to-IL receipt.
6. Generate the manifest, accessory filter, and transient Android packaging
   project under `build/<architecture>/generated/`.
7. Restore and package using only that generated project.
8. Inspect the APK and fail unless it contains exactly the requested ABI,
   CoreCLR, RyuJIT, SMA, the emitted entry assembly, and admitted dependencies.
9. Fail if Roslyn, CodeAnalysis satellites, C# source, Recovery.ps1 source, or
   the opposite ABI appears in the APK.
10. Write a deterministic receipt containing tool versions, input hashes,
    selected packages, emitted assembly metadata, APK contents, APK hash, and
    output path.

The build never installs or launches the APK unless a separate explicit device
test command is requested.

## Architecture blockers to resolve

### ARM64

- Pin Preview 7 rather than accepting whichever global SDK answers first.
- Confirm the Preview 7 Android ARM64 CoreCLR pack version used by the package.
- Preserve or regenerate the existing ARM64 shim receipt.

### ARM32

- Recreate the local Preview 7 SDK/workload environment reproducibly.
- Restore `Microsoft.NETCore.App.Runtime.android-arm` version
  `11.0.0-preview.7.26381.103`.
- Restore `Microsoft.Android.Runtime.CoreCLR.37.android-arm` version
  `37.0.0-preview.7.2131`.
- Rebuild `armeabi-v7a/libpsl-native.so` with
  `armv7a-linux-androideabi34-clang` and verify the recorded SHA-256
  `523B1455849710A279CCCCC3A02ABB8138050A9F09580C5E2A1E514ED78E85AD`.
- Prove the APK contains `libcoreclr.so` and `libclrjit.so` for ARM32 only.

Missing architecture prerequisites must produce a precise preflight failure;
the build must not substitute Mono, NativeAOT, another ABI, or another SDK.

## Implementation sequence

### Gate 1: behavior oracle

Run `Recovery.ps1` behind the existing Activity and prove every recovery and
private-home behavior. Correct the PS1 while `MainActivity.cs` remains available
for direct comparison.

Status: passed on the physical ARM32 Google TV and ARM64 Galaxy S23 targets for
missing profile, syntax diagnostics, runtime diagnostics, private-home
navigation, and valid profile handoff using the same Recovery source. Import
interruption and process-recreation cases remain. See `DEVICE-PARITY.md`.

### Gate 2: emitter kernel

Emit a trivial Android Activity assembly from a tiny admitted PS1 fixture.
Prove Android packaging discovers the Activity attribute and Android creates
the type. No recovery behavior is moved yet.

### Gate 3: independent green screen

Lower only the failure-screen kernel. Build an APK with SMA deliberately absent
or unloadable and prove the green recovery screen still appears.

### Gate 4: lifecycle and file repair

Lower document import, Activity-result delivery, private-home walking, and
retry. Prove process death/recreation and failed imports do not corrupt files.

### Gate 5: SMA application launch

Lower the SMA boundary, create a fresh application runspace, publish Android
objects, execute file-backed `PROFILE.PS1`, and preserve ErrorRecord details.

### Gate 5A: foreground service

Lower `Foreground.ps1` into an emitted Android `Service` type. Use the public
managed Android service and notification APIs to prove start, foreground
notification, retained SMA ownership, Activity reconnect, clean stop, process
recreation, and integration admission. Do not recover private service-manager
or Binder protocols from prior work.

### Gate 6: both architectures

Package and inspect ARM64 and ARM32 independently. Test the same recovery matrix
on the S23 and Google TV without architecture-specific source edits.

### Gate 7: deletion

Only after all prior gates pass:

- delete retained `MainActivity.cs`;
- delete retained `AndroidSMA.csproj`;
- make `Build-AndroidSMA.ps1` the only supported build entrance;
- retain the old files only through Git history, not copied archaeology inside
  the source tree.

## Definition of done

This work is complete only when a clean checkout can build either architecture
with one PowerShell command, the APK contains an emitted Activity assembly whose
behavior traces to `Recovery.ps1`, both device classes pass the recovery matrix,
and neither C# source nor a retained project file exists in the project.
