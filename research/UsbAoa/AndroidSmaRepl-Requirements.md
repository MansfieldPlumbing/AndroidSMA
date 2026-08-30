# AndroidSMA Projection/REPL Requirements

This file is the acceptance contract. A capability remains incomplete until a live phone test proves it.

## Immutable constraints

- Never rebuild the APK.
- If a required capability needs a rebuild or manifest change, stop and report that exact blocker.
- Never modify an existing workspace source file. New files are allowed.
- Never modify or replace `MainActivity.cs`.
- Do not move application semantics into C# or use C# as a routing/proxy layer.
- Do not use JNI or reflection over Android objects.
- Android framework authorization and privileged framework requests must originate from AndroidSMA through Binder under the AndroidSMA process identity.
- Do not use cmdlet invocations inside runtime PS1 files.
- If a host-side cmdlet helper becomes unavoidable, create it only under `C:\Dev\AndroidSMA\src\Cmdlets\` as `*Cmdlet.psm1`.
- Prefer direct .NET methods, SMA runspaces, native P/Invoke, Binder, and direct PowerShell execution.
- Keep PowerShell low-level, terse, and `$`-left-aligned.
- Preserve existing user files and unrelated work.

## Process and identity

- The server must run inside `dev.mansfieldplumbing.androidsma`, not in ADB, a shell process, or a Windows proxy.
- The remote command runspace must share the AndroidSMA PID, Linux UID, package sandbox, `FilesDir`, Binder caller identity, and live `$Activity`.
- Session HELLO and HTTP health must report endpoint, session ID, process name, PID, UID, ports, root, and security state.
- Identity must be provable in-band from `/proc/self/cmdline`, `/proc/self/status`, and `[Environment]::ProcessId`.

## Lifecycle

- `PROFILE.PS1` must start the server in a process-held child runspace and return promptly.
- Android must report `PROFILE_OK`; a blocking profile loop is a failure.
- The projection server must survive PC detach and accept reattachment while the AndroidSMA process remains alive.
- Session variables and state must persist across detach/reattach.
- `.exit` detaches without destroying the phone session.
- `.stop` cleanly terminates the session, development listener, clean listener, HTTP listener, pipelines, sockets, and child runspaces.
- A failed client request must not kill the server or unrelated session state.

## Two PowerShell doors

### Development door

- Default port: `45888`.
- Show full HELLO identity, session metadata, request IDs, completion states, errors, and transport telemetry.
- Provide enough in-band telemetry to diagnose the phone without ADB after bootstrap.
- Expose retained app log/health information in-band.

### Clean door

- Default port: `45890`.
- Use the prompt `PS (AndroidSMA)Home:> `.
- Hide HELLO and protocol bookkeeping during normal use.
- Match the visible behavior and formatting of an ordinary PowerShell REPL as closely as possible.
- Show command output and useful native-looking errors without transport wrappers.
- Use `>> ` for incomplete multiline input.

Both doors must attach to the same persistent AndroidSMA session and observe the same variables and file state.

## PowerShell remoting fidelity

- A Windows PowerShell 7 process must be able to connect remotely using the PS1 client.
- Do not call the custom framed protocol “PSRP.” It is PSRP only after standards-compliant PSRP framing/session behavior is implemented and tested.
- Evaluate whether PSRP can be layered over the proven duplex transport after the basic lane is stable.
- Support ordinary PowerShell state, expressions, errors, multiline input, and process inspection such as `Get-Process` when the required module is available.
- Android child runspaces must use initialization APIs that work in the packaged SMA host; desktop-only success is insufficient.

## File and AST projection

- The PC must be able to create new `.ps1` files in AndroidSMA `FilesDir` through the app session.
- The PC must be able to read, hash, list, execute, and replace phone-side `.ps1` files.
- New-file creation must refuse an existing target.
- Replacement must write a unique temporary file, preserve a timestamped recovery copy, and rename atomically.
- Reject rooted paths, traversal outside `FilesDir`, empty paths, oversized paths/payloads, and non-PS1 targets.
- Support PowerShell parser/AST inspection from the phone runspace.
- Support token/extent-based symbol mutation and AST-directed file changes without laundering edits through compiled code.
- Prove round-trip file hashes between PC and phone.

## Projection and foreground UI

- The persistent phone runspace must receive the live `$Activity` directly from the existing profile boundary.
- PowerShell must be able to schedule UI work on the Activity UI thread.
- The PC must be able to request AndroidSMA to come to the foreground through the app session, not through an ADB `am start` command.
- The first visual proof is a full green AndroidSMA surface with a centered white checkmark.
- A successful script return is not visual proof. Verify the actual foreground Activity and captured screen.
- Treat Android background-activity launch restrictions as a live constraint; do not claim foreground control until observed.

## Binder and permissions

- Binder requests must originate from the AndroidSMA process/session.
- The development door must be able to ping and transact with Binder services using direct native Binder calls.
- USB AOA flow must be:

```text
getCurrentAccessory
hasAccessoryPermission
requestAccessoryPermission with a valid Binder-backed PendingIntent/result token
Android system dialog/Toast observed
user accepts
hasAccessoryPermission == true
openAccessory returns a valid descriptor
Windows -> phone -> Windows framed round trip
```

- Do not substitute a shell grant, ADB command, direct `/dev/usb_accessory` open, cosmetic INF, or guessed Binder transaction.
- Extract transaction constants from the installed Samsung framework before calls.
- Permission dialogs must be requested by the phone app.
- Camera/torch permission must likewise be requested by the phone app and the actual Android response recorded.
- If the installed manifest prevents the permission and a rebuild is required, stop.

## HTTP proof

- The same PS1 must host a low-level HTTP server from the AndroidSMA process.
- Default port: `45889`.
- Required initial routes:

```text
GET /health
GET /files
GET /log or equivalent in-band telemetry
GET /
```

- Unknown paths return `404`.
- Unsupported methods return `405`.
- Responses use correct status, content type, content length, connection close, and no-store behavior.
- HTTP must share the server lifecycle and report the same PID/session identity.

## ADB boundary

- ADB is allowed only for initial deployment/enabling, emergency recovery while every in-band lane is down, and independent test observation during development.
- ADB must not execute normal projected commands, create the green-check UI, grant permissions, or carry the final operational data path.
- As soon as the development door is alive, telemetry and diagnosis must come through the projection server.
- Final operation must not require `adb forward`.
- The permanent lane must be direct app TCP or Binder-authorized AOA.
- Demonstrate reconnect after app restart without ADB being the command/telemetry channel.

## Transport and security sequencing

- First prove reliable duplex communication, sessions, file operations, UI projection, Binder access, and lifecycle.
- Security over the wire follows the communication proof.
- Until security is implemented, explicitly report `auth=NONE`; do not imply confidentiality or authentication.
- Development and clean doors must have bounded frame sizes, request IDs, protocol versioning, UTF-8 encoding, little-endian framing, timeouts, and deterministic disconnect handling.
- Preserve the frame protocol when moving from TCP bootstrap to AOA.

## Stress and edge cases

Test and retain results for:

- repeated commands and state mutation;
- detach/reattach and cross-door state;
- terminating and non-terminating errors;
- pipeline timeout and recovery;
- client disconnect during response;
- server reconnect after malformed client traffic;
- partial reads/writes;
- bad magic/version/opcode;
- oversized command/frame/file;
- duplicate create;
- atomic replace and recovery backup;
- missing file;
- rooted path and traversal attempts;
- UTF-8 and multiline commands;
- HTTP health/files/root/404/405;
- Activity foreground/background transitions;
- process death and restart;
- AOA disconnect/reconnect.

No stress-test failure may be erased by a later pass.

## Evidence retention

- Save every run on the PC under:

```text
artifacts/runs/YYYY-MM-DDTHHMMSSZ-short-purpose/
```

- Preserve failures on both phone and PC when possible.
- Each run folder should contain, when applicable:

```text
commands.txt
result.md
logcat.txt
app-log.txt
hashes.txt
screen.png
failed payload or minimal reproducing diff
```

- Record complete literal commands, working directory, arguments, paths, timestamps, exit codes, relevant output, device-visible result, created/modified files, and whether a build occurred.
- Never reconstruct an unknown historical command; mark it `EXACT COMMAND NOT RETAINED`.

## Capability unlock order

No menu button appears before its live proof passes:

```text
Gate 0  Persistent app-owned projection session, file channel, HTTP, Binder permission, openAccessory, AOA round trip
Gate 1  Flashlight on/off
Gate 2  Speaker test buffer
Gate 3  Camera single frame
Gate 4  Deterministic generic compute
Gate 5  Hexagon v73 only with runtime backend evidence
Gate 6  Truthful Windows Device Manager projection for proven functions
```

An INF name, DLL filename, library presence, enumeration label, or successful script return is never sufficient proof by itself.
