# AndroidSMA development governance

## Authority

Apply authority in this order: the user's current explicit instructions, repository `AGENTS.md`, the acceptance requirements, proven on-device behavior, and finally experimental convenience. Stop before a change when these conflict or broader authority is required.

## Default mode

- Default to read-only inspection.
- Existing source files are immutable without explicit authorization for a named change.
- Never modify `MainActivity.cs`.
- Never rebuild or alter the manifest. Stop if either is required.
- Put experiments in separate, clearly named new files.
- Never silently promote an experiment into the application path.
- State the exact files and runtime state affected before a mutation.
- Preserve every failure.

## Application boundary

After `PROFILE.PS1` starts, PowerShell is the application. Compiled code is limited to Android Activity entry, SMA/runspace admission, direct publication of `$Activity`, profile recovery/document import, and disposal of failed runspaces. Do not add compiled routing, UI, Binder bridges, services, managers, adapters, or helpers. Do not use JNI or reflection over Android objects.

## Direct-object rule

Use the real `$Activity`, SMA runspaces, Android framework objects, Binder, and .NET files/streams/sockets directly. Do not create wrappers merely to rename or forward calls. Recover and understand an old script's original invocation contract before adapting it. Do not patch each workload independently to accommodate a runtime.

## Historical integrity

- Preserve recovered scripts byte-for-byte.
- Record Git blob IDs and SHA-256 hashes.
- Never edit the recovered copy.
- Name derivatives differently and identify their source hash.
- Test the unchanged original against its original boot contract first.
- If removed compiled facilities are required, identify the dependency and stop before proposing a rebuild.

Recovered Canvas Git blobs:

```text
canvastest.ps1                         0b72b4598fca70c2773975f679a3c4082bf7a3bb
canvastest-dedicated-ui-runspace.ps1   fb0294a9b2e3ff864e5f1282e2ccabfc05ef5a18
```

## Surface scripts

A workload owns only workload state, input interpretation, frame construction, rendering, and workload telemetry. It does not own rotation, foregrounding, Activity lifecycle, transport, authentication, permissions, deployment, or compatibility mutation. Orientation is an observed precondition controlled by Android or the user.

Canvas acceptance requires the user/device in landscape, AndroidSMA foreground, the original Canvas instantiated unchanged, visible physical-screen rendering, measured telemetry near 120 FPS, and reported dropped-frame behavior. `Canvas READY` alone is insufficient.

## Projection session

The projection runtime owns the persistent app runspace, PID/UID identity, direct `$Activity`, two command doors, reconnectable session state, file transfer/hashing, HTTP telemetry, error propagation, teardown, and one standard workload invocation boundary. It must not rewrite workloads. The current ASMA framed transport is not PSRP until standards-compliant PSRP behavior is implemented and proven.

## ADB boundary

ADB is allowed only for initial deployment/enabling, emergency recovery when every in-band lane is dead, and independent observation. It is not the normal command, file, Binder, permission, or UI data path. After the development lane is alive, diagnosis and commands use AndroidSMA.

## Binder and permissions

Authorization requests originate from AndroidSMA's UID. Request through the Android framework/Binder, observe the dialog or Toast, record the user response, query resulting state, exercise the resource, and retain the result. Do not substitute ADB grants, guessed transactions, or cosmetic enumeration.

## Change admission

Before a mutation, answer: what capability is tested; which layer owns it; exact files/state changed; whether the original is preserved; rollback; observable proof; failure containment; and whether a rebuild or new authority is required. If unclear, inspect or stop.

## Proof states

Use only `NOT ATTEMPTED`, `IN PROGRESS`, `FAILED`, `BLOCKED`, or `PASSED`. A queued callback, successful pipeline return, filename, hash, log label, or device label is not functional proof.

## Evidence

Store runs under `artifacts/runs/YYYY-MM-DDTHHMMSSZ-purpose/` with literal commands, results, hashes, logs, screenshots, exit information, failed inputs, and derivative diffs. If a historical command is unknown, write `EXACT COMMAND NOT RETAINED`. Later success never erases failure.

## Durable scripts

```text
PC:    C:\Dev\AndroidSMA\src\UsbAoa\PS1
Phone: /data/user/0/dev.mansfieldplumbing.androidsma/files/PS1
```

Synchronize through AndroidSMA and record both hashes.

## Gates

```text
Gate 0  Persistent session, files, HTTP, Binder permission, AOA duplex
Gate 1  Flashlight
Gate 2  Speaker
Gate 3  Camera
Gate 4  Generic deterministic compute
Gate 5  Hexagon v73 with runtime-backend evidence
Gate 6  Truthful Windows enumeration
```

## Stop conditions

Stop if a rebuild/manifest change is required, the original cannot be recovered, an unauthorized existing-source change is proposed, permission would not originate from AndroidSMA, a missing platform dependency requires compiled code, all in-band lanes die, evidence contradicts a claim, or ownership of behavior is unclear.

## Current state at packaging

- Both Canvas originals are recovered exactly and stored on PC and phone.
- Neither original has been successfully instantiated under the current minimal runtime.
- `CanvasS23.ps1` is a failed, noncanonical experiment that incorrectly introduced rotation.
- Rotation caused an Activity configuration change and AndroidSMA PID 7970 crashed.
- No Canvas or 120-FPS result exists.
- The ASMA transport has worked but is not PSRP.
- No rebuild occurred.
