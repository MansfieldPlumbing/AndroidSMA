# Durable checkpoint — AndroidSMA + Bonsai

## Proven

- `D:\models\Bonsai-8B-Q1_0.gguf` is live under `D:\llama.cpp\llama-server.exe`.
- Model census: 8,188,548,096 parameters, Q1_0, 1,152,704,128 bytes.
- Vulkan full offload is running on the Quadro P2000 with an 8K context.
- Host chat proof passed around 25–27 decode tokens/second.
- Phone `RFCWA0CE47F` executed PowerShell -> direct TCP -> ADB reverse -> desktop llama -> phone and wrote `PHONE BONSAI BRIDGE ALIVE`.
- AndroidSMA reported `PROFILE_OK` for the deployed interactive PS1 profile.
- Desktop PowerShell -> length-framed CLIXML -> admitted chat pipeline -> Bonsai passed with `PSRP BONSAI ALIVE`.
- The desktop PSRP-shaped host binds `10.227.229.53:8091`; llama remains private on `127.0.0.1:8080`.

## Durable artifacts

- `src\Bonsai\Bonsai.Chat.ps1` — stateful Bonsai client; JSON exists only at the llama HTTP boundary.
- `src\Bonsai\Bonsai.Phone.ps1` — small native Android interactive chat surface.
- `src\Bonsai\Bonsai.PhoneSmoke.ps1` — physical phone receipt proof.
- `src\Bonsai\Bonsai.PsrpWire.ps1` — length-framed CLIXML Values.
- `src\Bonsai\Listen-BonsaiPsrp.ps1` — admitted desktop chat pipeline with session state.
- `src\Bonsai\Bonsai.PsrpClient.ps1` — client session/pipeline/stream verbs.
- `.device-tests\bonsai-psrp.capability` — ignored proof capability token; rotate before wider exposure.
- `src\Boot\RECOVERY_PRESERVATION.md` — exact recovery contract and proof gates.
- `src\Boot\Recovery.ps1` — parsed recovery-stratum draft.
- `src\Assembly\ASSEMBLY_WALL.csv` — explicit keep/cut wall including AST/emit/RyuJIT/network invariants.

## Important defect discovered

`MainActivity` sets a session variable named `PSScriptRoot`, then invokes profile text through `AddScript(string)`. The automatic `$PSScriptRoot` inside that anonymous source is empty. The existing help text promises support-file discovery that the current invocation does not actually provide. The recovery map records this as a defect to correct, not behavior to preserve.

## Recovery/MainActivity status

- No files under `C:\dev\AndroidSMA-main` were modified.
- Existing recovery UI/intents remain intact in the installed APK.
- The preservation target includes green recovery, copy, help, import, atomic `.incoming`, diagnostics, automatic profile boot, and fresh-runspace retry.
- Planned replacement is a durable PS1 boot/recovery runspace plus a mechanically emitted/audited Android entry relay. Recovery semantics move out of `MainActivity.cs`; they do not disappear.

## Communication maturity — honest status

- Direct physical phone chat: proven, but the receipt used ADB reverse as the temporary wire.
- PSRP-shaped PowerShell-to-PowerShell chat: proven locally with session, pipeline, Output/Error streams, completion state, CLIXML, and an admitted command.
- It is explicitly **not** claimed to be MS-PSRP wire compatible yet.
- Existing subsystem `PsrpSeam.cs` is JSON RPC over a shared runspace, not real PSRP.
- No-ADB final shape: phone requests/holds Android Network through Binder, connects to the authenticated desktop PSRP-shaped endpoint over LAN; the same CLIXML frames can later ride AOA.
- MCP remains the correct irreducible JSON tooling boundary if/when Bonsai gains tools. It is not used for chat transport.

## Exact next proof

1. Create/import a phone profile that loads `Bonsai.PsrpWire.ps1` and `Bonsai.PsrpClient.ps1`.
2. Bind through the Android network capability to `10.227.229.53:8091` without ADB reverse.
3. Send `NO ADB BONSAI ALIVE`, capture the CLIXML pipeline receipt, and verify conversation continuity over two turns.
4. Add mDNS discovery and pinned TLS after the raw LAN proof; do not expose arbitrary PowerShell.
