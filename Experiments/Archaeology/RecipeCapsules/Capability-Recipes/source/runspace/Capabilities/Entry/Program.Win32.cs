using System;
using Subsystem.Windows;
using Subsystem.Adb;   // AgentHost / AgentDevice — the `ss agent-host` / `ss agent-device` modes
namespace Subsystem.Capabilities.Entry;

public static class Program
{
    public static int Main(string[] args)
    {
        // ss — the Windows head. One binary, several entry modes:
        //   ss <powershell...>        run argv as PowerShell in the hosted runspace (built-ins + project cmdlets)
        //   ss -Command "..."         explicit command (pwsh-compatible)
        //   ss -EncodedCommand <b64>  base64 UTF-16LE command — quoting-proof, the agent's door
        //   ss -File <path>           run a script file
        //   ss selftest               VOM + Cm kernel self-tests (Layers 1-2), logged to smoketest-log.md
        //   ss test [filter] [--request <id>]  run the tests/ receipts in-proc; --request logs them to a request's EOS
        //   ss diag                   the living diagnostic suite (kernel + toolchain + self-carry), logged to the ledger
        //   ss contextualize [--map|--json] (-c) self-describe the system (contract, components, cmdlets, source map)
        //   ss onboard                the one-shot alignment package — telos · laws · decisions · state · contract
        //   ss help                   usage
        //   (no args)                 help — first contact teaches the modes
        // No args = first contact. Teach the modes — and if this was a double-click (ss owns its console), keep
        // the window open so the help is readable instead of flashing and vanishing.
        // No args = first contact. A DOUBLE-CLICK (owns its console, interactive) brings up the SYSTRAY GATEWAY —
        // the tray presence whose menu opens the shell / TUI / virtual-camera server. A bare shell / redirected
        // launch just prints help.
        if (args.Length == 0)
        {
            if (Interactive.IsDoubleClick()) { Interactive.HideOwnConsole(); return Subsystem.Capabilities.Gateway.Gateway.Run(Array.Empty<string>()); }
            return Help.Print();
        }
        var mode = args[0].ToLowerInvariant();
        return mode switch
        {
            "selftest"                                                       => SelfTest.Run(args[1..]),
            "test" or "-test" or "--test"                                    => Test.Run(args[1..]),
            "diag" or "-diag" or "--diag" or "selfcheck"                     => Diag.Run(args[1..]),
            "help" or "-help" or "--help" or "-h" or "/help" or "-?" or "/?"  => Help.Print(),
            "contextualize" or "-contextualize" or "--contextualize" or "-c" => Contextualize.Run(args[1..]),
            "onboard" or "-onboard" or "--onboard" or "brief"                => Onboard.Run(args[1..]),
            "build" or "-build" or "--build"                                 => Build.Run(args[1..]),
            "check" or "-check" or "--check"                                 => Check.Run(args[1..]),
            "extract" or "-extract" or "--extract"                           => SelfSource.Extract(args[1..]),
            "chat"                                                           => Subsystem.Capabilities.Chat.Chat.Run(args[1..]),
            "dpx-generate" or "dpx-gen"                                      => DpxGenerate.Run(args[1..]),
            "modeldb-consolidate" or "modeldb-consol"                        => ModelDbConsolidate.Run(args[1..]),
            "tts" or "-tts" or "--tts" or "speak"                            => Subsystem.Capabilities.Tts.Tts.Run(args[1..]),
            "surface" or "-surface" or "--surface"                           => Subsystem.Capabilities.Surface.Surface.Run(args[1..]),
            "camera" or "-camera" or "--camera"                              => Subsystem.Capabilities.Camera.Camera.Run(args[1..]),
            "view" or "-view" or "--view"                                    => Subsystem.Capabilities.View.View.Run(args[1..]),
            "ui" or "-ui" or "--ui"                                          => WinShellUi.Run(args[1..]),
            "mcp" or "-mcp" or "--mcp"                                       => Subsystem.Capabilities.Mcp.Mcp.Run(args[1..]),
            "ble-scan"                                                       => DpBleScan.Run(args[1..]),
            "git"                                                            => Git.Run(args[1..]),
            "status" or "st"                                                 => Status.Run(args[1..]),
            "refs"                                                           => Refs.Run(args[1..]),
            "adb"                                                            => Subsystem.Capabilities.Adb.Adb.Run(args[1..]),
            "agent-host"                                                     => AgentHost.Run(args[1..]),
            "agent-device"                                                   => AgentDevice.Run(args[1..]),
            "directport" or "dp"                                             => DirectPortBench.Run(args[1..]),
            "tui"                                                            => Subsystem.Shell.Cell.Tui.Run(args[1..]),
            "cell"                                                           => Subsystem.Shell.Cell.CellShell.Run(args[1..], Subsystem.Capabilities.Shim.Shim.LoadProjectCmdlets),
            "repl"                                                           => Subsystem.Shell.Cell.Repl.Run(args[1..], Subsystem.Capabilities.Shim.Shim.LoadProjectCmdlets),
            "gateway" or "tray"                                             => Subsystem.Capabilities.Gateway.Gateway.Run(args[1..]),
            _                                                                => Subsystem.Capabilities.Shim.Shim.Run(args),
        };
    }
}
