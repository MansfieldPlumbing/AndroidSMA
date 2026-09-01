# Native HLE and PE research mission

## What is valuable

The native HLE and PE specimens record mapping, import resolution, command-line and file services, and entry-point invocation. The narrow interest is whether stringsw64a.exe can be instantiated inside CoreCLR on Android as platform-engineering research.

> # SIREN WARNING
>
> This is not part of recovery, foreground service, commands, or the research-wire MVP. Do not compile it into the app, grant arbitrary PE execution, cargo-cult machine code, or let this lane delay the honest Android build.

## Permitted work

Keep this separately authorized. Document PE architecture, relocation, imports, TLS, exceptions, HLE surface, memory protection, ABI transitions, and one named binary's needs.

## Proof gate

Require a threat model, architecture match, bounded imports, W^X transitions, relocations, file-I/O sandbox, crash containment, teardown, and Windows output parity.
