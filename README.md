# AndroidSMA

> **PowerShell is the Android application.**

AndroidSMA is an experimental Android application substrate built around an in-process `System.Management.Automation` runtime.

It does not launch PowerShell as a subprocess, and it is not a terminal emulator that happens to contain `pwsh`. AndroidSMA hosts a persistent PowerShell runspace inside the Android process. Android supplies lifecycle and native platform objects; PowerShell owns application behavior, state, and presentation policy.

```text
Android process
    ↓
.NET for Android
    ↓
System.Management.Automation
    ↓
persistent PowerShell runspace
    ↓
PowerShell application
```

## What this repository demonstrates

AndroidSMA has been exercised on physical Android hardware with:

- persistent in-process PowerShell runspaces
- Android lifecycle and foreground-service integration
- direct Android object use from PowerShell
- Binder/JNI object experiments across runspaces
- PowerShell-owned `SurfaceView` / hardware Canvas presentation
- packed-cell rendering and dedicated PowerShell UI runspaces
- optional Qualcomm QNN / Hexagon HTP experiments on ARM64 devices
- .NET 11 Preview 7 CoreCLR execution on a 32-bit Android 14 / `armeabi-v7a` device

The terminal, renderer, QNN experiments, and future TV/server surfaces are applications and capabilities built on the substrate. They are not the definition of AndroidSMA itself.

## Development targets

The repository currently has two intentionally distinct development lines:

| Target | Status | Focus |
| --- | --- | --- |
| ARM64 | Primary R&D line | Android phones, runtime/UI experiments, Qualcomm QNN / Hexagon work |
| ARM32 CoreCLR | Proven secondary line | 32-bit Android / Google TV and appliance experiments |

The current repository root is the existing ARM64 preview lineage. It is being cleaned up incrementally rather than through a destructive layout rewrite.

ARM32 build notes and receipts live under [`ARM32/CoreCLR`](ARM32/CoreCLR/README.md).

## Application model

The intended ownership boundary is deliberately simple:

```text
Android lifecycle
      ↓
thin compiled host / platform seams
      ↓
persistent SMA runspace
      ↓
PowerShell
      ↓
Android capabilities
```

The guiding rule is:

> **PowerShell owns meaning. Compiled code owns representation only where an executable experiment demonstrates that PowerShell cannot directly express the required capability.**

That means compiled C# or native code may provide a narrow capability seam, but application policy should remain in PowerShell whenever the platform allows it.

## Building the current ARM64 preview

The current root project targets .NET 11 Android and PowerShell 7.7 preview.

Typical build prerequisites are:

- PowerShell 7
- .NET 11 Preview SDK with the Android workload
- Android SDK
- Android NDK for rebuilding the PowerShell native compatibility shim

From the repository root:

```powershell
dotnet restore .\Terminal.Mvp.csproj
dotnet build .\Terminal.Mvp.csproj -c Debug
```

The ARM64 QNN experiments expect Qualcomm runtime libraries in `native/arm64-v8a`. Those Qualcomm binaries are external build/runtime dependencies and are not redistributed by this repository. The non-QNN AndroidSMA source remains useful independently of those optional experiments.

The PowerShell compatibility shim can be rebuilt from the source under `native/src`.

## ARM32 CoreCLR

A separate `android-arm` / `armeabi-v7a` target has been built and run on a real 32-bit Android 14 Google TV device with .NET 11 Preview 7 CoreCLR and PowerShell 7.7 preview.

That target required a local Preview 7 SDK/workload environment because the machine-wide Windows workload state remained associated with an older Android workload manifest during the experiment.

See [`ARM32/CoreCLR/README.md`](ARM32/CoreCLR/README.md) for the known-good SDK/runtime package versions, build invocation, API 34 compatibility note, and current status.

## Source status

The repository is research software and still looks like a construction site in places. That is intentional for now: working source and physical-device receipts take priority over cosmetic restructuring.

The current cleanup policy is conservative:

- preserve working source
- keep generated build/runtime debris out of Git
- document demonstrated behavior separately from plans
- move or deduplicate code only when the target boundaries are clear

## License

See [`LICENSE`](LICENSE).
