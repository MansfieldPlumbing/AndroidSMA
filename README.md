Yep — exactly. Use **four backticks on the outside** so the inner triple-backtick blocks survive intact.

````markdown
# AndroidSMA Preview

> **PowerShell is the Android application.**

AndroidSMA embeds `System.Management.Automation` in-process inside an Android
application. A persistent PowerShell runspace owns application state and
presentation policy; Android supplies lifecycle and native platform objects.


## Package

`dev.mansfieldplumbing.androidsma.preview`

## Application shape

```text
Android process
  -> persistent System.Management.Automation environment
  -> PowerShell application
  -> PowerShell-owned packed-cell UI
  -> Android RuntimeShader
  -> hardware Surface presentation
```

The Preview exposes one PowerShell-owned application surface:

```text
1 QNN
2 PAN
3 COLORS
4 GLYPHS
5 GRID
6 NOISE
```

## Physical Hexagon QNN proof

```text
PowerShell-supplied tensors
  -> focused CLR QNN boundary
  -> QNN MatMul
  -> QNN ElementWiseAdd
  -> libQnnHtp.so
  -> CDSP
  -> physical Hexagon V73 HTP
  -> returned output
  -> independent CPU reference check
```

Tested graph:

```text
input       [1,32]
weights     [32,32]
MatMul      [1,32]
bias        [1,32]
ElementWiseAdd
output      [1,32]
```

The displayed `MAX REL` value compares returned QNN output against an
independently computed CPU reference.

PASS criterion:

```text
maxRel < 0.02
```

`MAX REL: 0.00000` is displayed to five decimal places and should not be
interpreted as a claim of mathematically exact zero error.

## Timing

The displayed QNN elapsed time is **whole-method timing**.

It includes host-side work surrounding graph execution and is **not** an HTP
kernel latency measurement.

## Packed-cell renderer

```text
PowerShell Build-Cells
  -> uint32[] packed cells
  -> direct ByteBuffer / Bitmap upload
  -> Android RuntimeShader
  -> one hardware Canvas.DrawPaint
  -> Surface presentation
```

PowerShell retains application semantics including modes, hit testing, input,
palette, cell construction, and presentation policy.

Frozen canvas SHA-256:

```text
987C54023ABAD366F387442D9CB004DBE4877BCE51E0298B75B7CB0CF77E0465
```

## Nonclaims

This Preview does not claim:

- arbitrary PowerShell-authored QNN topology
- a general-purpose QNN framework
- isolated HTP kernel timing
- that whole-method latency equals HTP execution latency
- that every PowerShell or Android workload can sustain the demonstrated presentation cadence
````

