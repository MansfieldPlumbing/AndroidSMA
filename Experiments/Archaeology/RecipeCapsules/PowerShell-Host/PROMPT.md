# PowerShell host behavior mission

## What is valuable

The wheels are parser completeness, multiline state, ANSI highlighting, help presentation, session continuity, translation boundaries, terminal interaction, cancellation, and error reporting.

> # SIREN WARNING
>
> Do not resurrect the old host, alias vocabulary, monolithic terminal, module boundary, shared globals, or process topology. SMA already is the host. Never compile these files as the shortcut.

## Permitted work

Extract one observable behavior at a time into fresh PS1 fixtures. Let SMA's parser and AST remain authoritative. Keep Console.ps1 separate from retained session ownership.

## Proof gate

Parser corpus, multiline input, cancellation, ordered streams, resize/input, failure recovery, and two-command continuity must pass independently.
