# AndroidSMA constitutional rules

PowerShell is the application. Compiled code exists only to admit
`System.Management.Automation` to `FilesDir/PROFILE.PS1` and to provide recovery
before PowerShell can run.

Once `PROFILE.PS1` starts successfully, C# application semantics are finished.
If PowerShell can perform an operation after that boundary, remove the compiled
implementation entirely.

## Naming and abstraction prohibition

Do not create application abstractions whose primary purpose is to wrap, route,
coordinate, own, or rename functionality that can be expressed directly.

These names are presumptively prohibited:

```text
*Handler
*Manager
*Helper
*Engine
*Coordinator
*Provider
*Controller
*Factory
*Broker
*Host
*Service
*Context
*Adapter
```

A prohibited abstraction may exist only when Android or .NET requires that
concrete type or lifecycle component. Renaming the abstraction does not satisfy
this rule. Remove any type whose primary function is indirection.

Prefer, in order:

```text
one file
private method
direct API call
direct object
direct PowerShell invocation
```

Do not add an interface or forwarding type around an operation. Use a private
method when it is sufficient. Compiled structure requires an executable
platform requirement. Naming conventions, separation of concerns, testability,
possible future use, and conventional C# architecture are not requirements.

## Current compiled boundary

`MainActivity.cs` is the sole compiled source. Its only permitted jobs are:

- Android Activity entry and document-picker results.
- Create or reuse the process-static SMA runspace.
- Read `FilesDir/PROFILE.PS1` and pass its source directly to SMA. Android SMA
  does not resolve the absolute Android path as a PowerShell command.
- Publish the current Activity as `$Activity`.
- Render missing/broken-profile recovery and import a selected document into
  `FilesDir` under its display name.
- Dispose a failed runspace before retry.

Do not add a foreground service, work queue, event router, script seeder,
application asset catalog, Binder bridge, QNN bridge, or compiled application UI
without a focused on-device experiment proving the platform requires the exact
minimal primitive.

The native resolver stays absent unless an on-device boot test proves that
packaging the shim as `libpsl-native.so` is insufficient.
