# AppFunctions PROFILE.PS1 Repair Experiment

Target: Samsung SM-S911U (S23), Android 16, API 36

Date: 2026-08-28

Result: **NOT ADMITTED TO PRODUCTION BUILD**

## Proven

- Experimental source compiled with zero warnings and zero errors.
- APK installed successfully.
- Device exposed `adb shell cmd app_function`.
- Installed service declaration and Binder permission were present.
- AppFunctions metadata and schema assets were packaged.

## Failure

- Android did not index the declared function.
- A second manifest-only registration attempt using the direct API 36
  `android.app.appfunctions` property did not change the result.
- Invocation and retail Gemini discovery were therefore not reachable.

## Production consequence

- All AppFunctions code, service declarations, and metadata were removed.
- AndroidSMA recovery remains independent of AppFunctions.
- The root project explicitly excludes `experiments\**` from compilation,
  Android resources, and Android assets.

## Preserved capability

```text
stageProfileRepair(profileText)
    -> PROFILE.PS1.pending
    -> explicit APPLY / REJECT
    -> APPLY replaces PROFILE.PS1
    -> retry SMA admission
```

The function accepts no path, cannot directly replace the active profile, and
limits input to 1 MiB of UTF-8 text.

Retest when Android/Gemini AppFunctions indexing or retail discovery changes:

```powershell
.\RETEST.ps1
```
