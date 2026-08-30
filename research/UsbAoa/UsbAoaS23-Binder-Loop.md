# UsbAoaS23 Experiment Log

Rules for this log:

- Append results; preserve failures.
- Record observed output, not intended behavior.
- Record every complete literal command used to instantiate or test something.
- Include the working directory, all arguments, target paths, exit code, and relevant output.
- Never shorten commands with `...`, aliases, implied arguments, or reconstructed text.
- If an older command was not retained exactly, mark it `EXACT COMMAND NOT RETAINED`.
- Label hypotheses as hypotheses.
- Never rebuild the APK.
- Never modify an existing source file.
- Stop if a rebuild or manifest change is required.
- No JNI and no reflection over Android objects.
- Android-side USB requests must go through Binder.

## Observed

### Windows AOA negotiation: PASS

Known exact invocation:

```text
working directory: C:\Dev\AndroidSMA\src\UsbAoa
command: .\UsbAoa.ps1 -Start -StopAdb
```

Other commands from this earlier experiment were not retained verbatim:

```text
EXACT COMMAND NOT RETAINED
```

- S23: Samsung SM-S911U.
- AOA `GET_PROTOCOL` returned version 2.
- The phone re-enumerated as `VID_18D1/PID_2D01`.
- Windows exposed `Android Accessory Interface` with WinUSB bulk OUT `0x01` and IN `0x81`.

This proves only Windows-side AOA enumeration and pipe discovery.

### Android Binder service lookup: PASS

```text
EXACT COMMAND NOT RETAINED
```

- `AServiceManager_getService("usb")` returned a binder.
- Reported interface: `android.hardware.usb.IUsbManager`.
- `AIBinder_ping` returned success.

This proves only that the process can reach the USB Binder service.

### Direct device-node open: FAIL, retained

```text
EXACT COMMAND NOT RETAINED
```

- CoreCLR called Bionic `open("/dev/usb_accessory", O_RDWR | O_CLOEXEC)`.
- Result: `-1`.
- `errno`: `13` (`EACCES`).

This route is rejected. It did not request Android USB permission and is not a substitute for Binder.

### Managed accessory lookup: FAIL, rejected

```text
EXACT COMMAND NOT RETAINED
```

- A prior managed Android `AccessoryList` attempt produced one null element.
- A later attempt headed toward Java reflection/JNI to construct an accessory object.

That approach was stopped and rejected. It did not issue the required Binder permission request.

### Android USB permission request: NOT YET PROVEN

No accepted experiment has yet completed:

```text
Binder getCurrentAccessory
Binder hasAccessoryPermission
Binder requestAccessoryPermission
visible Android prompt or Toast
user acceptance
Binder hasAccessoryPermission == true
Binder openAccessory
valid file descriptor
AOA round trip
```

Until that entire sequence succeeds, no functional CLI button is unlocked.

## Current experiment boundary

The next experiment is Gate 0 only:

1. Determine the exact Samsung Android 16 Binder transaction and parcel format without mutating the build.
2. Ask Binder for the current accessory.
3. Ask Binder for current permission.
4. If false, create the required permission-result token through Binder and call `requestAccessoryPermission` through Binder.
5. Check and record whether the phone shows a dialog, Toast, both, or nothing.
6. Re-query permission through Binder.
7. Call `openAccessory` only when permission is true.
8. Attempt one Windows-to-phone-to-Windows PING.

## Unknowns

- Exact transaction codes and parcel shapes on the installed Samsung Android 16 build.
- Whether the existing manifest/runtime can complete the PendingIntent permission path without a rebuild.
- Which permission UI Samsung displays.
- Whether flashlight, speaker, camera, generic compute, or Hexagon can be reached under the no-rebuild/no-JNI boundary.

These are not claims. If Gate 0 proves that a rebuild or manifest change is required, stop and log that failure.

## 2026-08-29 Gate 0 Loop 1: FAIL

Purpose: temporarily deploy `UsbAoaS23.ps1` as the app-storage profile, attempt native Binder `getCurrentAccessory`, capture a receipt, restore the original deployed profile, and stop the app.

Pre-deployment validation:

```text
UTC=2026-08-29T17:13:12.0557159Z
PARSE_ERRORS=0
COMMAND_AST_COUNT=0
forbidden scan: only the receipt text JNI=NO matched
SHA256=1EFDEA9089BE3B2834B9618185DFA4E41D5663574ADCCA03631E686707992903
```

Complete deployment command:

```powershell
$ErrorActionPreference='Stop'
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$backup="PROFILE.PS1.gate0-$stamp.bak"
Write-Output ('UTC=' + [DateTime]::UtcNow.ToString('o'))
Write-Output ('BACKUP_NAME=' + $backup)
Write-Output 'BEFORE_HASH'
adb shell run-as dev.mansfieldplumbing.androidsma sha256sum files/PROFILE.PS1
Write-Output 'BACKUP'
adb shell run-as dev.mansfieldplumbing.androidsma cp files/PROFILE.PS1 "files/$backup"
Write-Output 'PUSH'
adb push .\UsbAoaS23.ps1 /data/local/tmp/UsbAoaS23.ps1
Write-Output 'DEPLOY'
adb shell run-as dev.mansfieldplumbing.androidsma cp /data/local/tmp/UsbAoaS23.ps1 files/PROFILE.PS1
Write-Output 'DEPLOYED_HASH'
adb shell run-as dev.mansfieldplumbing.androidsma sha256sum files/PROFILE.PS1
Write-Output 'CLEAR_OLD_RECEIPT'
adb shell run-as dev.mansfieldplumbing.androidsma rm -f files/UsbAoaS23-Gate0.log
Write-Output 'START'
adb shell am force-stop dev.mansfieldplumbing.androidsma
adb shell am start -W -n dev.mansfieldplumbing.androidsma/.MainActivity
Write-Output 'RECEIPT'
$receipt=''
for($i=0;$i-lt20;$i++){
$receipt=adb shell run-as dev.mansfieldplumbing.androidsma cat files/UsbAoaS23-Gate0.log 2>$null
if($LASTEXITCODE-eq0-and$receipt){break}
Start-Sleep -Milliseconds 250
}
if($receipt){Write-Output $receipt}else{Write-Output 'RECEIPT_MISSING'}
Write-Output 'LOGCAT'
adb logcat -d -t 120 -s AndroidSMA:* libc:* DEBUG:*
Write-Output 'RESTORE'
adb shell am force-stop dev.mansfieldplumbing.androidsma
adb shell run-as dev.mansfieldplumbing.androidsma cp "files/$backup" files/PROFILE.PS1
Write-Output 'RESTORED_HASH'
adb shell run-as dev.mansfieldplumbing.androidsma sha256sum files/PROFILE.PS1
Write-Output 'REMOVE_DEVICE_BACKUP_AND_TEMP'
adb shell run-as dev.mansfieldplumbing.androidsma rm -f "files/$backup"
adb shell rm -f /data/local/tmp/UsbAoaS23.ps1
Write-Output 'FINAL_PROCESS'
adb shell pidof dev.mansfieldplumbing.androidsma
Write-Output ('UTC_END=' + [DateTime]::UtcNow.ToString('o'))
```

Observed result:

```text
UTC=2026-08-29T17:13:38.9268918Z
original deployed profile SHA256=7145c1d95a1e086d62c69a0c67ec9ddafebdc81fffae8d1c16c41ed6ed6c99ac
probe deployed SHA256=1efdea9089be3b2834b9618185dfa4e41d5663574adcca03631e686707992903
Activity start status=ok
AndroidSMA log=RUNSPACE_OPEN
receipt=missing
restored deployed profile SHA256=7145c1d95a1e086d62c69a0c67ec9ddafebdc81fffae8d1c16c41ed6ed6c99ac
final app process=absent
command exit code=0
```

Conclusion: FAIL. No Binder transaction result was recorded. Activity launch and runspace creation do not prove that the script executed. No permission request was attempted, no Android prompt or Toast was observed, and nothing was unlocked.

## 2026-08-29 Gate 0 Loop 2: FAIL

The probe entered, emitted its native type, then failed before Binder because `Marshal.GetFunctionPointerForDelegate` rejects generic `Func<>` and `Action<>` delegate types.

```text
RESULT=FAIL
ERROR_TYPE=System.Management.Automation.MethodInvocationException
ERROR=The specified Type must not be a generic type. (Parameter 'delegate')
restored profile SHA256=7145c1d95a1e086d62c69a0c67ec9ddafebdc81fffae8d1c16c41ed6ed6c99ac
build performed=no
permission request attempted=no
```

## 2026-08-29 Gate 0 Loop 3: PARTIAL PASS

After replacing generic delegates with emitted non-generic Cdecl delegate types:

```text
CLASS_DEFINED=True
SERVICE_ACQUIRED=True
CLASS_ASSOCIATED=1
PREPARE_STATUS=0
TRANSACTION_CODE=3
TRANSACTION_STATUS=0
STATUS_HEADER_READ=0
BINDER_EXCEPTION=0
PRESENCE_READ_STATUS=0
ACCESSORY_PRESENT_MARKER=1
```

This proves only `getCurrentAccessory` transaction 3 returned a present accessory. The deployed profile was restored to SHA256 `7145c1d95a1e086d62c69a0c67ec9ddafebdc81fffae8d1c16c41ed6ed6c99ac`; the app was stopped. No permission request was attempted.

## 2026-08-29 Gate 0 Loop 4: FAIL, system_server crash

Complete instantiation command:

```powershell
$ErrorActionPreference='Stop'
Write-Output ('UTC=' + [DateTime]::UtcNow.ToString('o'))
$tokens=$null
$errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\UsbAoaS23.ps1),[ref]$tokens,[ref]$errors)
$commands=@($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.CommandAst]},$true))
Write-Output ('PARSE_ERRORS=' + $errors.Count)
Write-Output ('COMMAND_AST_COUNT=' + $commands.Count)
if($errors.Count-ne0-or$commands.Count-ne0){throw 'Probe validation failed'}
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$backup="PROFILE.PS1.gate0-$stamp.bak"
Write-Output ('BACKUP_NAME=' + $backup)
Write-Output ('BEFORE_HASH=' + (adb shell run-as dev.mansfieldplumbing.androidsma sha256sum files/PROFILE.PS1))
adb shell run-as dev.mansfieldplumbing.androidsma cp files/PROFILE.PS1 "files/$backup"
adb push .\UsbAoaS23.ps1 /data/local/tmp/UsbAoaS23.ps1
adb shell run-as dev.mansfieldplumbing.androidsma cp /data/local/tmp/UsbAoaS23.ps1 files/PROFILE.PS1
Write-Output ('DEPLOYED_HASH=' + (adb shell run-as dev.mansfieldplumbing.androidsma sha256sum files/PROFILE.PS1))
adb shell run-as dev.mansfieldplumbing.androidsma rm -f files/UsbAoaS23-Gate0.log
adb logcat -c
adb shell am force-stop dev.mansfieldplumbing.androidsma
adb shell am start -W -n dev.mansfieldplumbing.androidsma/.MainActivity
for($i=0;$i-lt60;$i++){
$current=adb shell run-as dev.mansfieldplumbing.androidsma cat files/UsbAoaS23-Gate0.log 2>$null
if($LASTEXITCODE-eq0-and$current){
Write-Output ('POLL=' + $i)
Write-Output $current
if($current-match 'UTC_END='){break}
}
Start-Sleep -Milliseconds 250
}
Write-Output 'PROCESS_BEFORE_TEARDOWN'
adb shell pidof dev.mansfieldplumbing.androidsma
Write-Output 'LOGCAT_BEFORE_TEARDOWN'
adb logcat -d -v brief -s AndroidSMA:* libc:* DEBUG:*
Write-Output 'TEARDOWN'
adb shell am force-stop dev.mansfieldplumbing.androidsma
adb shell run-as dev.mansfieldplumbing.androidsma cp "files/$backup" files/PROFILE.PS1
Write-Output ('RESTORED_HASH=' + (adb shell run-as dev.mansfieldplumbing.androidsma sha256sum files/PROFILE.PS1))
adb shell run-as dev.mansfieldplumbing.androidsma rm -f "files/$backup"
adb shell rm -f /data/local/tmp/UsbAoaS23.ps1
Write-Output ('UTC_END=' + [DateTime]::UtcNow.ToString('o'))
```

Observed failure:

```text
candidate permission transaction code=7
result=system_server SIGSEGV
fault address=0x20
crashed method=android_server_UsbDeviceManager_getMaxPacketSize
IUsbManager.Stub.onTransact was on stack
app process after crash=absent
permission request attempted=no
Android prompt or Toast observed=no
restored profile SHA256=7145c1d95a1e086d62c69a0c67ec9ddafebdc81fffae8d1c16c41ed6ed6c99ac
build performed=no
```

Conclusion: the AOSP branch ordering was not the installed Samsung interface ordering. Transaction 7 was removed from `UsbAoaS23.ps1`. Do not probe transaction numbers by trial because malformed calls can crash privileged services. Extract the generated transaction constants from the phone's installed framework before another Binder transaction.

## Required format for every new command

```text
UTC:
working directory:
command:
exit code:
stdout/stderr:
device-visible result:
files created:
files modified: none
build performed: no
conclusion:
```

Commands that deploy, start, switch AOA mode, transact Binder, or collect a receipt must be logged individually and in execution order. A multi-line PowerShell invocation must be copied in full, including every line.
