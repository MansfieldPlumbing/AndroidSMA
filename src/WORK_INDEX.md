# AndroidSMA working source index

This tree keeps executable PowerShell beside the evidence that constrains it. Nothing listed here participates in the APK build merely by existing; `AndroidSMA.csproj` still compiles only `MainActivity.cs`.

## Boot

- `Boot/Recovery.ps1` is the draft durable PS1 boot/recovery stratum.
- `Boot/RECOVERY_PRESERVATION.md` freezes the current green recovery behavior, its intents, discovered defects, and the device proof gates required before removing semantics from `MainActivity.cs`.

The recovery screen is an invariant. The goal is to remove application policy from `MainActivity.cs`, not remove recovery.

## Assembly

- `Assembly/ASSEMBLY_WALL.csv` requires every packaged assembly to produce a capability receipt. Automated trimming is not the policy.

AST inspection/mutation, dynamic binding, metadata, direct IL emission, RyuJIT, networking, serving, SMA, and an attachable pwsh personality are constitutional capabilities.

## Local device state

Proof credentials and device receipts belong under `.device-tests/`, which is ignored. They do not belong in source. The current Bonsai proof capability is stored there and must be rotated before broader exposure.
