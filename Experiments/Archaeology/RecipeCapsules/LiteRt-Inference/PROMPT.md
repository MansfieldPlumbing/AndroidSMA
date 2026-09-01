# LiteRT inference recipe mission

## What is valuable

These files may explain model loading, tensor description, native lifetime, delegate selection, invocation, and guest/runtime separation.

> # SIREN WARNING
>
> LiteRT is not QNN. Do not merge runtimes, copy native bindings, or prescribe a framework before diagnosing the current model and hardware path. Do not import C# wrappers or let an SDK choose AndroidSMA's architecture.

## Permitted work

Extract neutral tensor, lifetime, and measurement contracts. Rebuild only a narrowly selected PS1 experiment against the runtime actually under test.

## Proof gate

Record exact model, tensor shapes and types, backend, timings, output parity, native allocations, cleanup, and device identity.
