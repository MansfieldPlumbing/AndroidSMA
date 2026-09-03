# AndroidSMA working source index

This tree keeps the authored Android manifest and executable PowerShell beside
the evidence that constrains them. `Build-AndroidSMA.ps1` is the only build
entry point; it emits `AndroidSMA.dll` from PowerShell-authored expression
graphs and generates a disposable packaging project under `build/`.

## Android host

- `Android/AndroidManifest.xml` declares the emitted
  `AndroidSMA.MainActivity` entry point.
- `../Scripts/Emit-AndroidSMA.ps1` emits the lifecycle, runspace admission, and
  recovery system as ordinary persisted CLR code.
- `PROFILE.CanvasDemo.ps1` is the minimal profile that starts
  `CanvasDemo.ps1`.

The recovery screen remains available even when `PROFILE.PS1` is absent or
broken. There is no authored `MainActivity.cs`, maintained `.csproj`, or
interpreted recovery script in the production build path.

## Assembly

- `Assembly/ASSEMBLY_WALL.csv` requires every packaged assembly to produce a capability receipt. Automated trimming is not the policy.

AST inspection/mutation, dynamic binding, metadata, direct IL emission, RyuJIT, networking, serving, SMA, and an attachable pwsh personality are constitutional capabilities.

## Local device state

Proof credentials and device receipts belong under `.device-tests/`, which is ignored. They do not belong in source. The current Bonsai proof capability is stored there and must be rotated before broader exposure.
