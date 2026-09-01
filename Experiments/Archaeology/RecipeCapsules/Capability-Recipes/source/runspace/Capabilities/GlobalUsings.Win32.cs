global using Subsystem.Capabilities.Adb;
global using Subsystem.Capabilities.Bluetooth;
global using Subsystem.Capabilities.Camera;
global using Subsystem.Capabilities.Chat;
global using Subsystem.Capabilities.Core;
global using Subsystem.Capabilities.Diagnostics;
global using Subsystem.Capabilities.Dpx;
global using Subsystem.Capabilities.Entry;
global using Subsystem.Capabilities.Gate;
global using Subsystem.Capabilities.Gateway;
global using Subsystem.Capabilities.LiteRt;
global using Subsystem.Capabilities.Management;
global using Subsystem.Capabilities.Mcp;
global using Subsystem.Capabilities.Remedy;
global using Subsystem.Capabilities.ScreenStream;
global using Subsystem.Capabilities.Shim;
global using Subsystem.Capabilities.Surface;
global using Subsystem.Capabilities.Terminal;
global using Subsystem.Capabilities.Tts;
global using Subsystem.Capabilities.Usb;
global using Subsystem.Capabilities.View;
global using Subsystem.Capabilities.WebView;

global using Adb = Subsystem.Capabilities.Adb.Adb;
global using Gateway = Subsystem.Capabilities.Gateway.Gateway;
global using Mcp = Subsystem.Capabilities.Mcp.Mcp;
global using Chat = Subsystem.Capabilities.Chat.Chat;
global using Tts = Subsystem.Capabilities.Tts.Tts;
global using Surface = Subsystem.Capabilities.Surface.Surface;
global using Camera = Subsystem.Capabilities.Camera.Camera;
global using View = Subsystem.Capabilities.View.View;
global using Shim = Subsystem.Capabilities.Shim.Shim;

namespace Subsystem.Windows
{
    public static class SelfBundle
    {
        public static object Read(byte[] exe) => Subsystem.Capabilities.Management.SelfBundle.Read(exe);
        public static object ManagedAssemblies(object m) => Subsystem.Capabilities.Management.SelfBundle.ManagedAssemblies((Subsystem.Capabilities.Management.BundleManifest)m);
    }
}
namespace Subsystem.Adb {}

namespace Subsystem
{
    public sealed class MainActivity
    {
        public static MainActivity? Instance { get; } = new();
        public AppFilesDir FilesDir { get; } = new();
        public sealed class AppFilesDir
        {
            public string AbsolutePath => System.IO.Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), 
                "Subsystem"
            );
        }
    }

    public static class Dg
    {
        public static void Log(string source, string message) => Subsystem.Capabilities.Diagnostics.Dg.Log(source, message);
        public static void Trace(string source, string message) => Subsystem.Capabilities.Diagnostics.Dg.Trace(source, message);
        public static void Debug(string source, string message) => Subsystem.Capabilities.Diagnostics.Dg.Debug(source, message);
        public static void Info(string source, string message) => Subsystem.Capabilities.Diagnostics.Dg.Info(source, message);
        public static void Warn(string source, string message) => Subsystem.Capabilities.Diagnostics.Dg.Warn(source, message);
        public static void Error(string source, string message) => Subsystem.Capabilities.Diagnostics.Dg.Error(source, message);
        public static void Warn(string source, Exception ex) => Subsystem.Capabilities.Diagnostics.Dg.Warn(source, ex);
        public static void Error(string source, Exception ex) => Subsystem.Capabilities.Diagnostics.Dg.Error(source, ex);
        public static void RecordCrash(Exception? ex, string source) => Subsystem.Capabilities.Diagnostics.Dg.RecordCrash(ex, source);
        public static bool ConsoleVerbose {
            get => Subsystem.Capabilities.Diagnostics.Dg.ConsoleVerbose;
            set => Subsystem.Capabilities.Diagnostics.Dg.ConsoleVerbose = value;
        }
        public static string Snapshot() => Subsystem.Capabilities.Diagnostics.Dg.Snapshot();
        public static string[] Recent(int n) => Subsystem.Capabilities.Diagnostics.Dg.Recent(n);
    }
}
