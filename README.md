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

The compiled host is one C# file. There is no foreground service, C# work
queue, seeded application, Binder bridge, QNN bridge, or compiled UI policy
after a profile starts successfully.

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

## Build and install

Prerequisites are the .NET 11 SDK with the Android workload and an Android SDK.

```powershell
dotnet restore .\AndroidSMA.csproj
dotnet build .\AndroidSMA.csproj -c Debug
dotnet build .\AndroidSMA.csproj -c Debug -t:Install
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
