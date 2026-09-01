# SPAKE25519 and pairing recipe mission

## What is valuable

The wheel is the managed SPAKE25519 implementation, HKDF derivation, key encoding, transcript sequence, discovery observations, and interoperability evidence against BoringSSL.

> # SIREN WARNING
>
> The old ADB pairing stack is not AndroidSMA's research wire. Do not revive, wrap, rename, or port the connection classes as a unit. Do not alter cryptographic constants or arithmetic during stylistic translation. A round trip alone is not a security proof.

## Permitted work

Isolate the primitive from its old consumer. Produce a fresh PS1 experiment with explicit bytes, transcript inputs, deterministic vectors, and key erasure.

## Proof gate

Reproduce byte-for-byte BoringSSL agreement, fixed vectors, malformed-peer rejection, wrong-password failure, transcript binding, derived-key agreement, and secret cleanup.
