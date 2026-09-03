using System.Management.Automation;
using System.Management.Automation.Runspaces;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Util;
using Android.Widget;
using System.Runtime.InteropServices;

namespace AndroidSMA;

// Temporary behavior-proof bridge. Recovery policy lives in Recovery.ps1.
// Build-AndroidSMA.ps1 replaces this type with emitted IL after device parity.
[Activity(
    Name = "dev.mansfieldplumbing.androidsma.MainActivity",
    Label = "AndroidSMA",
    MainLauncher = true,
    Exported = true,
    LaunchMode = LaunchMode.SingleTop,
    Theme = "@android:style/Theme.Material.NoActionBar")]
public sealed class MainActivity : Activity
{
    private static Runspace? s_bootRunspace;
    private static string? s_recoverySource;

    protected override void OnCreate(Bundle? state)
    {
        base.OnCreate(state);
        Dispatch("Create", null, Result.Canceled, null);
    }

    protected override void OnActivityResult(int requestCode, Result resultCode, Intent? data)
    {
        base.OnActivityResult(requestCode, resultCode, data);
        Dispatch("ActivityResult", requestCode, resultCode, data);
    }

    private void Dispatch(string kind, int? requestCode, Result resultCode, Intent? data)
    {
        try
        {
            s_bootRunspace ??= OpenBootRunspace();
            s_recoverySource ??= ReadRecoverySource();
            Runspace.DefaultRunspace = s_bootRunspace;

            var bootEvent = new PSObject();
            bootEvent.Properties.Add(new PSNoteProperty("Kind", kind));
            bootEvent.Properties.Add(new PSNoteProperty("Activity", this));
            bootEvent.Properties.Add(new PSNoteProperty("RequestCode", requestCode));
            bootEvent.Properties.Add(new PSNoteProperty("ResultCode", resultCode));
            bootEvent.Properties.Add(new PSNoteProperty("Data", data));

            using var shell = PowerShell.Create();
            shell.Runspace = s_bootRunspace;
            shell.AddScript(s_recoverySource).AddParameter("Event", bootEvent).Invoke();
            if (shell.HadErrors)
                throw new RuntimeException(string.Join("\n", shell.Streams.Error));
        }
        catch (Exception error)
        {
            Log.Error("AndroidSMA", "RECOVERY_BOOT_FAILED " + error);
            var text = new TextView(this) { Text = "RECOVERY.PS1 FAILED\n\n" + error };
            SetContentView(text);
        }
    }

    private Runspace OpenBootRunspace()
    {
        string home = FilesDir!.AbsolutePath;
        AppDomain.CurrentDomain.SetData("APP_CONTEXT_BASE_DIRECTORY", home);
        AppDomain.CurrentDomain.SetData("APPBASE", home);
        AppContext.SetData("APP_CONTEXT_BASE_DIRECTORY", home);
        NativeLibrary.SetDllImportResolver(typeof(PowerShell).Assembly, (name, assembly, path) =>
            name.Contains("libpsl-native", StringComparison.OrdinalIgnoreCase)
                ? NativeLibrary.Load("libpsl-native.so", assembly, path)
                : IntPtr.Zero);

        var initial = InitialSessionState.Create();
        initial.LanguageMode = PSLanguageMode.FullLanguage;
        initial.ThreadOptions = PSThreadOptions.UseCurrentThread;
        var runspace = RunspaceFactory.CreateRunspace(initial);
        runspace.Open();
        return runspace;
    }

    private string ReadRecoverySource()
    {
        using Stream stream = Assets!.Open("Recovery.ps1");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
}
