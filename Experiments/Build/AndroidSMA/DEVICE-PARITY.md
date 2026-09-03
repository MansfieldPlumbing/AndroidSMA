# Recovery firmware device parity

Date: 2026-09-02 (America/New_York)

Status: bridge proof passed; this is not the emitted-firmware deletion gate.

The same `src/Boot/Recovery.ps1` source and the same
`Build-AndroidSMA.ps1` entrance were exercised on both target architectures.
No architecture-specific recovery source edits were made.

| Target | Device | Android/API | Requested build | Runtime ABI | Result |
|---|---|---|---|---|---|
| ARM32 | onn. 4K Plus Streaming (`CUSA2508000094`) | Android 14 / API 34 | `Arm32` / `android-arm` | `armeabi-v7a` | Pass |
| ARM64 | Samsung Galaxy S23 SM-S911U (`RFCWA0CE47F`) | Android 16 / API 36 | `Arm64` / `android-arm64` | `arm64-v8a` | Pass |

## Shared matrix

- Missing `PROFILE.PS1` draws the green recovery surface.
- Syntax failure reports the SMA parser message and source coordinates.
- Terminating runtime failure reports the underlying `ErrorRecord`, source,
  line, column, and script stack.
- `PRIVATE HOME` opens through touch and lists the real app-private root.
- A valid file-backed profile runs in a fresh application runspace and sees
  `$PSScriptRoot` as `Activity.FilesDir.AbsolutePath`.

The ARM64 test package was
`dev.mansfieldplumbing.androidsma.preview64`. Its signed bridge-proof APK had
SHA-256:

```text
AA107CEC956A1A49A9AEFE1F8F07AC89ED90B0FC36B0675B133A996DB6E7B72F
```

Both builds used SDK `11.0.100-preview.7.26381.103`. The verified native-shim
hashes were:

```text
armeabi-v7a  523B1455849710A279CCCCC3A02ABB8138050A9F09580C5E2A1E514ED78E85AD
arm64-v8a    4605293D2EAD6D06CF39C45534C5928B8F40DB3AB2A80B415F7FE36C56961A32
```

Screenshots and injected profile fixtures remain ignored device-test outputs.
They are evidence used to write this receipt, not product source.

## Consequence

Recovery behavior and architecture selection are now controlled variables.
The next experiment is the smallest direct PS1-AST-to-persisted-IL proof. Any
failure introduced there must not be explained away as an ARM32/ARM64 source
fork or an unproven recovery contract.
