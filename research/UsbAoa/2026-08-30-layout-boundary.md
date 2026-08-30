# Spike: UsbAoa layout and implementation boundary

Date: 2026-08-30
Status: exploratory note; no implementation change

## Question

Which material under `src/UsbAoa` is implementation source, and which material
belongs outside `src`?

## Preliminary finding

The Android project boundary is the repository root. The active UsbAoa
implementation belongs under `src/UsbAoa`; exploratory investigations belong
under `spikes/UsbAoa`.

The current `src/UsbAoa/artifacts` tree contains test evidence, downloaded
analysis dependencies, a framework JAR, screenshots, logs, and a review ZIP.
Those are not implementation source. Requirements, governance, recovered
experiments, and test-run evidence also need explicit non-source locations.

## Boundary under review

- `src/UsbAoa`: current implementation only.
- `spikes/UsbAoa`: experiments, recovered variants, investigation notes, and
  time-bounded proofs.
- A separate root-level location should hold durable test evidence if that
  evidence is intentionally versioned.
- Generated build output remains in `bin` and `obj`.

## Explicit non-goals

This spike does not rebuild the app, alter the project file, change the
PowerShell profile, or move pre-existing project files before their roles are
verified.
