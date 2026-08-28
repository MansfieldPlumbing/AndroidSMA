# API 36 AppFunctions profile-repair experiment

Status: preserved source artifact; excluded from every production build.

## Purpose

Expose one Android system capability:

```text
stageProfileRepair(profileText)
```

The function accepts no path and never overwrites `PROFILE.PS1`. It writes at
most 1 MiB of UTF-8 text to `PROFILE.PS1.pending`, opens AndroidSMA, and requires
the user to select `APPLY PROFILE.PS1` or `REJECT`.

## S23 result — 2026-08-28

Device: Samsung SM-S911U, Android 16, API 36.

Proven:

1. The experimental APK built with zero warnings and zero errors.
2. The APK installed successfully.
3. The installed manifest contained the exported service, the required
   `android.permission.BIND_APP_FUNCTION_SERVICE` permission, and the
   `android.app.appfunctions.AppFunctionService` intent action.
4. Both XML metadata assets were present in the APK.
5. `adb shell cmd app_function help` was available on the device.

Failed:

```text
adb shell cmd app_function list-app-functions
```

did not index `dev.mansfieldplumbing.androidsma` or `stageProfileRepair`.
The direct API 36 `android.app.appfunctions` manifest property and the Jetpack
`android.app.appfunctions.v2` plus schema properties were both tested. Because
Android did not register the function, invocation, pending-file creation,
APPLY/REJECT, and retail Gemini discovery could not be tested.

Conclusion: not admitted to the production substrate today. The idea and exact
implementation are retained for later Android/Gemini rollout testing.

## Contents

- `ExperimentalMainActivity.cs` — complete Activity and API 36 service source.
- `AndroidManifest.experimental.xml` — exact final experimental manifest.
- `AndroidSMA.experimental.csproj` — exact experimental project definition.
- `profile_repair_app_functions.xml` — function metadata.
- `app_functions_schema.xsd` — AppFunctions schema asset.
- `RESULT.md` — forensic S23 result and production decision.
- `RETEST.ps1` — builds, installs, queries indexing, and records the result.

## Clean reimplementation

Do not add a library, interface, provider, coordinator, or generalized repair
surface. Reimplement only the platform-required seam:

1. Copy the `ProfileRepairAppFunctionService` block from
   `ExperimentalMainActivity.cs` into production source. Keep the API 36 comment.
2. Copy the pending-file check and APPLY/REJECT branch from the experimental
   Activity. Do not permit the service to replace `PROFILE.PS1` directly.
3. Add the service declaration from `AndroidManifest.experimental.xml` to the
   production manifest.
4. Copy `app_functions_schema.xsd` and
   `profile_repair_app_functions.xml` to the repository root and include those
   two exact files as `AndroidAsset` items in `AndroidSMA.csproj`.
5. Build and install the APK, then prove indexing before doing any more work.

The capability must remain exactly:

```text
profileText -> PROFILE.PS1.pending -> visible APPLY or REJECT -> retry
```

No arbitrary path, remote overwrite, automatic apply, or additional callable
function is permitted.

## Re-test

After reimplementation, run:

```powershell
adb shell cmd app_function list-app-functions |
    Select-String -Pattern 'dev\.mansfieldplumbing\.androidsma|stageProfileRepair' -Context 2,10
```

If indexed, invoke it with:

```powershell
adb shell cmd app_function execute-app-function `
    --package dev.mansfieldplumbing.androidsma `
    --function 'AndroidSMA.ProfileRepairAppFunctionService#stageProfileRepair' `
    --parameters '{"profileText":"Write-Output repaired"}'
```

Then verify `PROFILE.PS1.pending`, APPLY/REJECT, repair/retry, and finally ask
retail Gemini: `Fix AndroidSMA.`

## Production exclusion

`AndroidSMA.csproj` explicitly removes all C# sources, Android resources, and
Android assets below `experiments\`. This folder has zero compiled participation.
