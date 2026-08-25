# AndroidSMA Preview

Minimal physical-device proof application built from the frozen
QNN-R002 AndroidSMA specimen.

Baseline source:
2026-08-22 QNN-R002 MatMul + ElementWiseAdd physical Hexagon HTP proof.

This repository begins as a byte-for-byte copy of the frozen source
specimen. Subsequent commits turn it into a small two-slice preview:

- PowerShell-owned 120 Hz Android canvas
- PowerShell-driven QNN MatMul -> ElementWiseAdd on Hexagon HTP

The frozen proof directory remains untouched.
