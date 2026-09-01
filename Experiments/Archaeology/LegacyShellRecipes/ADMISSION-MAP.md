# Legacy shell recipe admission map

Status: read-only archaeology map; no import authority

## Rule

The legacy tree is evidence, not a dependency. A recipe may inform a new PS1,
PSD1, or shader implementation only when it naturally fits AndroidSMA's current
substrate and passes an independent proof. No file is copied into product
source, no old namespace or module boundary is preserved by default, and no C#
or JSON is laundered through PowerShell.

Public .NET and .NET-for-Android APIs are the first implementation boundary.
Private platform machinery is considered only after the public API is exercised
correctly and produces a reproducible failure.

## Strong candidates

### Terminal state machine

Sources:

- `S:\subsystem\src\shell\lib\ansi\parser.js`
- `S:\subsystem\src\shell\lib\ansi\buffer.js`
- `S:\subsystem\src\shell\lib\ansi\renderer.js`
- `S:\subsystem\src\shell\lib\ansi\terminal.js`

The parser and screen buffer are the strongest near-mechanical JS-to-PS1
candidates. The renderer and terminal controller contain valuable dirty-region,
cell, input, cursor, and scheduling recipes, but their DOM/Canvas membrane must
be replaced by Android Canvas or another admitted presentation surface.

Proof: replay a fixed VT corpus through both implementations and compare every
cell, attribute, cursor position, mode, scroll region, and emitted response.

### USB AOA

Source: `S:\subsystem\src\runspace\Device\Android\DpxAoa.cs`

This is a recipe witness for the correct public Android route:
`UsbManager`, accessory intent/list, `OpenAccessory()`,
`ParcelFileDescriptor`, and streams. Re-express that call sequence in PS1. Do
not import the class or its surrounding architecture.

Proof: Windows-to-phone-to-Windows byte round trip where ADB carries none of the
proof bytes.

### Android public capabilities

Sources:

- `Android\Readers.cs`
- `Android\Actuators.cs`
- `Android\Surfaces.cs`
- `Android\Light.cs`
- `Android\DpxBleAdvert.cs`

These mostly record public managed Android API sequences for battery, storage,
memory, sensors, connectivity, flashlight, haptics, audio, clipboard,
notifications, application discovery, ambient light, and BLE. Each capability
must become a small PS1 experiment against the live `$Activity` or application
context. Only proven, currently needed capabilities may later enter source.

Proof: one typed receipt per capability, including permission and lifecycle
behavior; no raw Binder or JNI fallback.

### Signal algorithms

Sources:

- `S:\subsystem\src\runspace\Device\Morse.cs`
- `S:\subsystem\src\runspace\Device\V21.cs`

The encoders, decoders, framing, sample processing, and self-tests are suitable
algorithmic recipes. Android light/audio access is a separate public-API
membrane.

Proof: fixed vectors, randomized round trips, damaged-signal cases, and parity
against retained receipts—not line-count resemblance.

### Compositor and shaders

Sources:

- `shell\compositor\engine.js`
- `shell\compositor\shaders.js`
- selected `shell\shaders\*.frag`
- `shell\shell\shader-bg.js`

Admit camera math, packed scene layout, world/screen transforms, dirty-frame
policy, shader algorithms, visibility throttling, and hybrid immediate/retained
ideas. Replace WebGPU/WebGL, DOM, browser lifecycle, fetch, and animation-frame
calls with the admitted Android graphics and lifecycle surface. Shader source
remains shader source; it is not hidden in JSON.

Proof: compare transforms and packed scene buffers numerically, then demonstrate
the same retained scene under the proven Android presentation path.

## Conditional candidates

### Editor and controls

`codeedit.js` contains tokenizer/highlighter and editing-state recipes;
`accontrols.js` contains rocker, slider, directional-pad, and stepper interaction
recipes. DOM creation and CSS are not portable implementation. Extract state
machines only after a concrete Android surface needs them.

### Shell and presenter files

`Shell.js`, `UiObject.js`, `Registry.js`, `presenter.js`, object directories,
and `.obp` presenters may inform ownership, focus, window choreography, touch,
file browsing, task presentation, and visual composition. They are browser
applications, not AndroidSMA source candidates. Port one behavior at a time into
an unlike PS1 demonstration.

The file presenter is a UX reference for the private-home walker. Its HTML,
CSS, fetch protocol, and registry assumptions are not dependencies.

### Themes and static data

Schemes, applications, cards, models, prompts, and tool declarations stored in
JavaScript or JSON are definitions to interrogate, not formats to retain. A
needed definition must be rewritten explicitly as PSD1 or direct PS1 data and
must discard fields that have no admitted consumer. The image asset requires a
separate provenance and product-use decision.

### Session experiments

The old PowerShell bootstrap, module, browser client, and shell functions may
inform framing, continuity, file-lane, error, and cancellation tests. Their
protocol names, JSON messages, HTTP endpoints, module boundary, and command
vocabulary are not inherited. Current framed CLIXML work remains an experiment.

## Separate cryptographic experiment

The SPAKE25519 implementation is located outside the supplied shell list:

- `S:\subsystem\src\runspace\Adb\Spake25519Client.cs`
- `S:\subsystem\src\runspace\Adb\Spake2.cs`
- `S:\subsystem\src\runspace\Adb\AdbPairingClient.cs` contains its old consumer.

The consumer is rejected because AndroidSMA is ending ADB-shaped research. The
algorithm may still be valuable as a general pairing primitive, but only in a
standalone cryptographic experiment. A PS1 implementation must reproduce the
existing byte-for-byte BoringSSL agreement, fixed vectors, invalid-peer cases,
key erasure behavior, and transcript binding before any use is discussed.

## Rejected by default

- `Subsystem.psm1` as a product/module boundary.
- JSON registries and JSON session messages.
- HTML/iframe architecture as the Android substrate.
- `Shell.css.tmp` and other drift residue.
- The unsafe PE loader as an application capability. It belongs only in a
  separately authorized loader experiment with an explicit threat model.
- Any C# file, compiled copy, generated C# translation, or opaque assembly from
  the legacy tree.
- Any presenter or terminology already explicitly banned from AndroidSMA.

## Promotion sequence

1. Name one required AndroidSMA behavior.
2. Read only the smallest source that demonstrates that behavior.
3. Separate algorithm/state from browser, Android, transport, or process
   membrane.
4. Write a fresh PS1/PSD1/shader experiment in the current vocabulary.
5. Prove parity with vectors or observable behavior and prove the new platform
   boundary independently.
6. Keep the experiment outside `src` until an unlike consumer proves it is not
   merely a port-shaped souvenir.
