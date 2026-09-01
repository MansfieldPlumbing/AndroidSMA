# USB AOA correction

Date: 2026-09-01

The investigation went below the correct application boundary.

AndroidSMA already packages the .NET Android bindings and exposes its live
Activity to PowerShell as `$Activity`. A PS1 probe running inside the deployed
application successfully obtained `Android.Hardware.Usb.UsbManager` from
`Mono.Android.dll`.

The earlier apparent result of "one null accessory" was misread. In
PowerShell, `@($null)` is a one-element array containing null. At the time of
the probe the application had not been launched by an AOA accessory intent, so
a null `AccessoryList` was expected. This was not evidence that the managed
Android binding was broken.

Raw Binder transactions, guessed Samsung transaction numbers, JNI object
construction, and direct `/dev/usb_accessory` access were unnecessary and
unsafe. One guessed Binder transaction crashed `system_server`.

Future work must remain at the public managed Android boundary:

1. Generate the standard AOA manifest intent and accessory filter.
2. Receive the accessory from the Activity intent.
3. Use `UsbManager` for permission and `OpenAccessory()`.
4. Connect the resulting streams to the existing framed CLIXML session.
5. Use ADB only for temporary deployment and independent observation while the
   AOA wire is unfinished.

Do not descend into platform internals until the public managed API has been
tested correctly and produced a recorded, reproducible failure.

The PowerShell runtime is present in the deployed application; PS1 executed
this proof. Missing optional PowerShell commands or a `pwsh` executable must
not be confused with a missing SMA runtime.
