# AndroidSMA

AndroidSMA is the smallest useful Android admission host for an in-process
`System.Management.Automation` runspace. Android owns entry and recovery;
`PROFILE.PS1` owns the application.

```text
MainActivity
    -> open or reuse one process-static SMA runspace
    -> dot-source FilesDir/PROFILE.PS1
    -> PowerShell owns everything after admission
```

The compiled host is authored in PowerShell as typed CLR expression graphs and
persisted as `AndroidSMA.dll`. There is no authored C#, maintained `.csproj`,
foreground service, C# work queue, seeded application, Binder bridge, or QNN
bridge. The Android packaging project is generated under `build/temp` and is
disposable.

## Recovery contract

AndroidSMA requires one user-managed file:

```text
FilesDir/
  PROFILE.PS1
  *                # optional files used by PROFILE.PS1
```

If `PROFILE.PS1` is absent or fails, the Activity shows the source, line,
column, source text, and message when available. The recovery screen imports any
selected document into `FilesDir` under its display name. Importing
`PROFILE.PS1` retries with a fresh runspace. Other files, including `config.ini`
or `cat.jpg`, are available to the profile under `$PSScriptRoot`.

The current Activity is available to the profile as `$Activity`. Android's
global application context remains available directly as
`[Android.App.Application]::Context`. The host publishes the fixed file
directory as `$PSScriptRoot` before invoking the profile source.

## Reproduce the toolchain

Use the PowerShell 7.7 preview 4 / .NET 11 host at `C:\bin\pwsh\pwsh.exe`.
Do not use whichever `pwsh` happens to be first on `PATH`.

The Android workload materializer downloads the workload manifests and every
declared pack directly from NuGet. It also explicitly installs and seeds the
NuGet global-package layout for `Microsoft.NETCore.App.Runtime.android-arm`,
including `libcoreclr.so` and `libclrjit.so`, because the supported workload
policy does not deliver the contemporary ARM32 CoreCLR target. Run it elevated
when repairing or recreating the toolchain:

```powershell
C:\bin\pwsh\pwsh.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\Scripts\Install-AndroidWorkload.ps1
```

## Build

`Build-AndroidSMA.ps1` is the only authored build entry point. ARM64 Release is
the default and produces the regular `dev.mansfieldplumbing.androidsma` app:

```powershell
C:\bin\pwsh\pwsh.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\Build-AndroidSMA.ps1
```

Build the ARM32 CoreCLR application for 32-bit Android devices with:

```powershell
C:\bin\pwsh\pwsh.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\Build-AndroidSMA.ps1 -RuntimeIdentifier android-arm
```

Both targets accept `-Configuration Debug`. Debug APKs are debuggable, allowing
ADB `run-as` to replace `PROFILE.PS1` and its supporting scripts directly in
private app storage. Use `-ApplicationId dev.mansfieldplumbing.androidsma.preview`
only when a side-by-side test installation is intentional.

Outputs are isolated by target and configuration:

```text
build/apk/android-arm64/Release/.../dev.mansfieldplumbing.androidsma-Signed.apk
build/apk/android-arm/Release/.../dev.mansfieldplumbing.androidsma-Signed.apk
```

The APK packages the small PowerShell native compatibility shim under the name
expected by SMA: `libpsl-native.so`. Rebuild it with
`native/src/Build-libpsl-native.ps1` when required.

## Lifetime

The runspace is process-static. Activity recreation and normal background/
foreground transitions reuse it; process death starts a new runspace and runs
`PROFILE.PS1` again. AndroidSMA deliberately does not claim stronger lifetime
semantics through a foreground service.

## License

See [`LICENSE`](LICENSE).
