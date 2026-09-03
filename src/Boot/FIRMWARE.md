# AndroidSMA application firmware

`Recovery.ps1` is the canonical source for AndroidSMA application firmware.
It is not an embedded startup script and it is not application userland. The
build lowers its admitted PowerShell AST directly into persisted CLR IL. The
APK carries the resulting entry assembly, not the PS1 source.

## Boot boundary

```text
Android + CoreCLR
    -> emitted Recovery firmware
    -> narrow BCL/Android recovery vocabulary
    -> SMA language engine
    -> disposable application runspace
    -> optional capability assemblies
```

The firmware must draw recovery, inspect the private app home, import and
atomically replace files, copy diagnostics, and retry even when SMA cannot
load. SMA is admitted only when a valid PS1 application must be parsed and
executed. Optional PowerShell command assemblies are application capabilities;
they are not firmware prerequisites.

## Important correction

`Get-ChildItem` is not supplied by CoreCLR. Microsoft's cmdlet lives in
`Microsoft.PowerShell.Commands.Management.dll` and uses PowerShell provider
machinery. CoreCLR supplies the useful substrate beneath it: `DirectoryInfo`,
filesystem enumeration, streams, collections, exceptions, and reflection.

AndroidSMA may therefore implement the object behavior it needs directly over
the BCL and expose an intentionally compatible command vocabulary after SMA is
available. It must not copy the entire provider architecture merely to list a
directory.

## Initial firmware operations

- private-root path validation and containment;
- typed file and directory enumeration;
- file metadata and content reading;
- controlled copy, move, removal, and atomic replacement;
- Android views, touch, dialogs, clipboard, intents, and document import;
- logging, CLR exceptions, process, runtime, device, and ABI diagnostics;
- explicit assembly validation/loading;
- creation of the SMA application runspace when the engine is healthy.

Without SMA, firmware does not claim arbitrary PS1 execution, PowerShell
pipeline binding, `PSObject`, `ErrorRecord`, runspaces, or command discovery.
Those belong above the firmware boundary.

## Direct emission contract

No maintained public implementation was found that converts PowerShell source
directly into an ordinary persisted CLR assembly. SMA internally compiles ASTs
to runtime delegates and dynamic call sites, which RyuJIT executes, but it does
not persist those results as a reusable assembly.

The project therefore supplies the missing narrow lowering pass:

```text
PS1 source
    -> public SMA parser and AST
    -> admitted-subset validator
    -> explicit AST-to-IL lowering
    -> PersistedAssemblyBuilder
    -> verifiable managed assembly
    -> RyuJIT when loaded
```

`PersistedAssemblyBuilder` is the assembly sink, not a PowerShell compiler. It
must be driven directly from PS1. Generated C#, Roslyn, CodeDOM, embedded PS1,
and interpreter wrappers are not valid substitutes. Unsupported AST shapes
fail the build with their source location; they never fall back silently.

The first compiler proof is deliberately smaller than Recovery: lower a
minimal `Get-ChildItem.ps1` contract into a persisted assembly whose runtime
implementation uses BCL filesystem objects and has no SMA dependency. That
proves the seam before Android lifecycle lowering is added.

## Weight expectation

The authored firmware and initial command vocabulary should be measured in
kilobytes, not tens of megabytes. The unavoidable size floor is the Android
.NET runtime: CoreCLR, RyuJIT, Android bindings, Java interop, and selected BCL
assemblies. Removing command assemblies is valuable primarily because it
removes dependency closure and policy, not because the two command DLLs alone
are especially large.

The ARM32 bridge proof measured a 59.8 MB signed APK. Its uncompressed managed
inputs included approximately 6.9 MiB of SMA, 1.2 MiB of Management and Utility
commands, and 9.5 MiB of Roslyn assemblies. These are measurements of the
temporary bridge build, not a promised final APK size. The emitted build must
produce a fresh assembly inventory and receipt.

## Current implementation truth

- `Recovery.ps1` is in `src/Boot` and has passed missing-profile, syntax-error,
  runtime-error, private-home, and successful profile-handoff tests on the
  physical ARM32 Google TV target.
- `Build-AndroidSMA.ps1` is the build entrance and currently labels its output
  `BridgeProof` honestly.
- `MainActivity.cs`, `AndroidSMA.csproj`, and the packaged Recovery source are
  temporary proof scaffolding. They remain only until emitted firmware passes
  the same device gates; then the deletion gate removes them from the tree.

The authoritative detailed gates and assembly policy remain under
`Experiments/Build/AndroidSMA` until they graduate through proof.
