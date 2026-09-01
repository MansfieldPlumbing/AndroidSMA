# Bug Report

## Android canvas schedules callbacks while idle

Location: `src/CanvasDemo.ps1:735-739`

The callback schedules itself with `PostOnAnimation` before calling the frame function. When the frame function returns because no work is pending, the next callback remains scheduled.

Expected: schedule from input, resize, attachment, or active animation; stop after the final required frame.

Check: zero callbacks over five idle seconds; touch, resize, and animation still produce frames.

## Windows DirectPort wakes PowerShell on idle timeout

Locations:

- `C:\dev\DirectPortSMA\Desktop.ps1:2547-2548`
- `C:\dev\DirectPortSMA\Src\DirectPort\Windows\powershell\DirectPort.Canvas2D.Native.cpp:1305-1315`

Desktop passes `100` to `Pump` while idle. The native wait returns when that timeout expires even when no message exists.

Expected: idle wait returns only for a message, explicit signal, or requested deadline.

Check: no return over five idle seconds; input, resize, close, signals, and active animation still wake correctly.

## JSON is unapproved

Locations:

- `src/Bonsai/Bonsai.Chat.ps1`
- `src/Bonsai/Bonsai.PhoneSmoke.ps1`
- `research/UsbAoa/Aoa-CommandSurface.ps1`
- `research/UsbAoa/Enter-AoaConsole.ps1`
- `research/UsbAoa/AndroidSmaRepl.ps1`

These paths serialize messages, results, or status as JSON. JSON is not an approved project format and must not enter the retained implementation.

Expected: PowerShell objects and streams cross internal boundaries without JSON conversion.
