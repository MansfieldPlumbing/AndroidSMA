using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Android.App;
using Android.App.AppFunctions;
using Android.App.AppSearch;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Provider;
using Android.Runtime;
using Android.Util;
using Android.Views;
using Android.Widget;
using Color = Android.Graphics.Color;

namespace AndroidSMA;

[Activity(
    Name = "dev.mansfieldplumbing.androidsma.MainActivity",
    Label = "AndroidSMA",
    MainLauncher = true,
    Exported = true,
    LaunchMode = LaunchMode.SingleTop,
    Theme = "@android:style/Theme.Material.NoActionBar")]
public sealed class MainActivity : Activity
{
    private const string LogTag = "AndroidSMA";
    private const int PickFile = 1001;
    private static readonly object RuntimeGate = new();
    private static Runspace? s_runspace;

    private string ProfilePath => Path.Combine(FilesDir!.AbsolutePath, "PROFILE.PS1");
    private string PendingProfilePath => Path.Combine(FilesDir!.AbsolutePath, "PROFILE.PS1.pending");

    protected override void OnCreate(Bundle? state)
    {
        base.OnCreate(state);
        StartProfile();
    }

    private void StartProfile()
    {
        if (File.Exists(PendingProfilePath))
        {
            long bytes = new FileInfo(PendingProfilePath).Length;
            ShowRecovery("REPAIR PENDING",
                "source: " + PendingProfilePath +
                "\nbytes: " + bytes +
                "\nmessage: Apply or reject the staged PROFILE.PS1 repair.");
            return;
        }

        if (!File.Exists(ProfilePath))
        {
            ShowRecovery(":(", FormatFailure(
                new FileNotFoundException("PROFILE.PS1 is missing.", ProfilePath)));
            return;
        }

        try
        {
            Runspace runspace = GetOrCreateRunspace();
            Runspace.DefaultRunspace = runspace;
            runspace.SessionStateProxy.SetVariable("Activity", this);
            runspace.SessionStateProxy.SetVariable("PSScriptRoot", FilesDir!.AbsolutePath);

            using var shell = PowerShell.Create();
            shell.Runspace = runspace;
            shell.AddScript(File.ReadAllText(ProfilePath), useLocalScope: false).Invoke();

            if (shell.HadErrors)
                throw new ProfileException(shell.Streams.Error);

            Log.Info(LogTag, $"PROFILE_OK runspace={runspace.InstanceId}");
        }
        catch (Exception error)
        {
            string details = FormatFailure(error);
            ResetRuntime();
            Log.Error(LogTag, "PROFILE_FAILED " + details);
            ShowRecovery(":(", details);
        }
    }

    private static Runspace GetOrCreateRunspace()
    {
        lock (RuntimeGate)
        {
            if (s_runspace is not null)
                return s_runspace;

            InitialSessionState initial = InitialSessionState.Create();
            initial.LanguageMode = PSLanguageMode.FullLanguage;
            initial.ThreadOptions = PSThreadOptions.UseCurrentThread;
            s_runspace = RunspaceFactory.CreateRunspace(initial);
            s_runspace.Open();
            Log.Info(LogTag, $"RUNSPACE_OPEN runspace={s_runspace.InstanceId}");
            return s_runspace;
        }
    }

    private static void ResetRuntime()
    {
        lock (RuntimeGate)
        {
            Runspace.DefaultRunspace = null;
            s_runspace?.Dispose();
            s_runspace = null;
        }
    }

    private void Retry()
    {
        ResetRuntime();
        StartProfile();
    }

    private void Pick()
    {
        var picker = new Intent(Intent.ActionOpenDocument);
        picker.AddCategory(Intent.CategoryOpenable);
        picker.SetType("*/*");
        StartActivityForResult(picker, PickFile);
    }

    protected override void OnActivityResult(int requestCode, Result resultCode, Intent? data)
    {
        base.OnActivityResult(requestCode, resultCode, data);
        if (resultCode != Result.Ok || data?.Data is null)
            return;

        if (requestCode != PickFile)
            return;

        string? incoming = null;
        try
        {
            string name = GetDisplayName(data.Data);
            if (string.IsNullOrWhiteSpace(name) || name is "." or ".." ||
                name.Contains('/') || name.Contains('\\'))
                throw new IOException("The selected document name is invalid.");

            if (name.Equals("PROFILE.PS1", StringComparison.OrdinalIgnoreCase))
                name = "PROFILE.PS1";

            string destination = Path.Combine(FilesDir!.AbsolutePath, name);
            incoming = destination + ".incoming";
            using Stream source = ContentResolver!.OpenInputStream(data.Data)
                ?? throw new IOException("The selected document could not be opened.");
            using (var target = new FileStream(incoming, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                source.CopyTo(target);
                target.Flush(flushToDisk: true);
            }
            File.Move(incoming, destination, overwrite: true);
            Log.Info(LogTag, $"IMPORTED {Path.GetFileName(destination)}");

            if (name == "PROFILE.PS1")
                Retry();
            else
                ShowRecovery("IMPORTED: " + name,
                    "source: " + destination + "\nline: —\ncolumn: —\nmessage: Select RETRY.");
        }
        catch (Exception error)
        {
            if (incoming is not null)
                File.Delete(incoming);
            ShowRecovery(":(", FormatFailure(error));
        }
    }

    private string GetDisplayName(Android.Net.Uri uri)
    {
        using var cursor = ContentResolver!.Query(
            uri, [IOpenableColumns.DisplayName], null, null, null);
        if (cursor is null || !cursor.MoveToFirst())
            throw new IOException("The selected document has no display name.");

        int column = cursor.GetColumnIndex(IOpenableColumns.DisplayName);
        string? name = column >= 0 ? cursor.GetString(column) : null;
        return name ?? throw new IOException("The selected document has no display name.");
    }

    private void ShowRecovery(string title, string details)
    {
        var layout = new LinearLayout(this)
        {
            Orientation = Orientation.Vertical
        };
        layout.SetBackgroundColor(Color.Rgb(11, 61, 46));
        int padding = Dp(24);
        layout.SetPadding(padding, padding, padding, padding);

        var heading = new TextView(this)
        {
            Text = title
        };
        heading.SetTextColor(Color.White);
        heading.SetTextSize(ComplexUnitType.Sp, 64);
        layout.AddView(heading);

        var message = new TextView(this) { Text = details };
        message.SetTextIsSelectable(true);
        message.SetTextColor(Color.White);
        message.SetTextSize(ComplexUnitType.Sp, 15);
        var messageLayout = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MatchParent, 0, 1f)
        {
            TopMargin = Dp(16),
            BottomMargin = Dp(16)
        };
        var scroll = new ScrollView(this);
        scroll.AddView(message);
        layout.AddView(scroll, messageLayout);

        if (title == "REPAIR PENDING")
        {
            AddButton(layout, "APPLY PROFILE.PS1", () =>
            {
                File.Move(PendingProfilePath, ProfilePath, overwrite: true);
                Retry();
            });
            AddButton(layout, "REJECT", () =>
            {
                File.Delete(PendingProfilePath);
                StartProfile();
            });
        }
        else if (title == ":(")
            AddButton(layout, "COPY TO CLIPBOARD", () =>
            {
                var clipboard = (ClipboardManager)GetSystemService(ClipboardService)!;
                clipboard.PrimaryClip = ClipData.NewPlainText("AndroidSMA error", details);
            });
        AddButton(layout, "HELP", () =>
        {
            string helpText =
                "1. Select IMPORT FILE.\n\n" +
                "2. Select any document. AndroidSMA copies it to private app storage using its display name.\n\n" +
                "3. A file named PROFILE.PS1 starts automatically. Import an application entry script under that name to boot it.\n\n" +
                "4. Other imported files are available to PROFILE.PS1 under $PSScriptRoot.\n\n" +
                "5. RETRY disposes the failed runspace and invokes PROFILE.PS1 again.\n\n" +
                "6. Android Settings > Apps > AndroidSMA > Storage > Clear storage removes all imported files.\n\n" +
                "CURRENT DETAILS\n\n" + details;
            var help = new AlertDialog.Builder(this);
            help.SetTitle("HELP");
            help.SetMessage(helpText);
            help.SetNeutralButton("COPY TO CLIPBOARD", (_, _) =>
            {
                var clipboard = (ClipboardManager)GetSystemService(ClipboardService)!;
                clipboard.PrimaryClip = ClipData.NewPlainText("AndroidSMA help", helpText);
            });
            help.SetPositiveButton("OK", (_, _) => { });
            help.Show();
        });
        if (title != "REPAIR PENDING")
        {
            AddButton(layout, "IMPORT FILE", Pick);
            AddButton(layout, "RETRY", Retry);
        }
        SetContentView(layout);
    }

    private void AddButton(LinearLayout parent, string text, Action action)
    {
        var button = new Button(this) { Text = text };
        button.Click += (_, _) => action();
        var parameters = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MatchParent, ViewGroup.LayoutParams.WrapContent)
        {
            TopMargin = Dp(8)
        };
        parent.AddView(button, parameters);
    }

    private int Dp(int value) => (int)TypedValue.ApplyDimension(
        ComplexUnitType.Dip, value, Resources!.DisplayMetrics);

    private string FormatFailure(Exception error)
    {
        string failure = error switch
        {
            ProfileException profileError =>
                string.Join("\n\n", profileError.Errors.Select(FormatErrorRecord)),
            RuntimeException runtimeError when runtimeError.ErrorRecord is not null =>
                FormatErrorRecord(runtimeError.ErrorRecord),
            _ => "message: " + OneLine(error.Message) +
                 "\nexception: " + error.GetType().FullName +
                 "\nsource: " + ProfilePath +
                 "\nline: —\ncolumn: —"
        };

        string runspace = s_runspace?.InstanceId.ToString() ?? "—";
        IList<string> abis = Build.SupportedAbis ?? [];
        return failure +
            "\n\ntimestamp: " + DateTimeOffset.UtcNow.ToString("O") +
            "\npid: " + System.Environment.ProcessId +
            "\ntid: " + Android.OS.Process.MyTid() +
            "\npackage: " + PackageName +
            "\ndevice: " + OneLine($"{Build.Manufacturer} {Build.Model}") +
            "\nandroid: " + Build.VERSION.Release +
            "\napi: " + (int)Build.VERSION.SdkInt +
            "\nabi: " + string.Join(",", abis) +
            "\ndotnet: " + RuntimeInformation.FrameworkDescription +
            "\nrunspace: " + runspace;
    }

    private string FormatErrorRecord(ErrorRecord error)
    {
        InvocationInfo? invocation = error.InvocationInfo;
        string source = string.IsNullOrWhiteSpace(invocation?.ScriptName)
            ? ProfilePath
            : invocation.ScriptName;
        string line = invocation?.ScriptLineNumber > 0
            ? invocation.ScriptLineNumber.ToString()
            : "—";
        string column = invocation?.OffsetInLine > 0
            ? invocation.OffsetInLine.ToString()
            : "—";
        string sourceLine = string.IsNullOrWhiteSpace(invocation?.Line)
            ? "—"
            : OneLine(invocation.Line);
        string message = OneLine(error.Exception?.Message ?? error.ToString());
        string stack = string.IsNullOrWhiteSpace(error.ScriptStackTrace)
            ? "—"
            : OneLine(error.ScriptStackTrace);
        return "message: " + message +
            "\nexception: " + (error.Exception?.GetType().FullName ?? "—") +
            "\nfullyQualifiedErrorId: " + OneLine(error.FullyQualifiedErrorId) +
            "\ncategory: " + error.CategoryInfo.Category +
            "\ncategoryReason: " + OneLine(error.CategoryInfo.Reason) +
            "\ntargetName: " + OneLine(error.CategoryInfo.TargetName) +
            "\ntargetType: " + OneLine(error.CategoryInfo.TargetType) +
            "\nsource: " + source +
            "\nline: " + line +
            "\ncolumn: " + column +
            "\nsourceText: " + sourceLine +
            "\nscriptStackTrace: " + stack;
    }

    private static string OneLine(string? value) => string.IsNullOrWhiteSpace(value)
        ? "—"
        : value.Replace('\r', ' ').Replace('\n', ' ').Trim();

    private sealed class ProfileException(PSDataCollection<ErrorRecord> errors)
        : Exception("PROFILE.PS1 reported one or more errors.")
    {
        public ErrorRecord[] Errors { get; } = errors.ToArray();
    }
}

/*
 * ANDROID API 36+ ONLY — EXPERIMENTAL APPFUNCTIONS ADMISSION SEAM.
 *
 * This concrete Service exists because Android AppFunctions requires an
 * AppFunctionService for system-privileged agents. It is not an AndroidSMA
 * lifetime service and does not own SMA, PowerShell, UI, or application state.
 *
 * The function never replaces PROFILE.PS1. It writes PROFILE.PS1.pending and
 * opens MainActivity. The user must explicitly select APPLY PROFILE.PS1 before
 * the active profile changes. Devices below API 36 cannot invoke this type.
 */
[SupportedOSPlatform("android36.0")]
[Service(
    Name = "dev.mansfieldplumbing.androidsma.ProfileRepairAppFunctionService",
    Permission = "android.permission.BIND_APP_FUNCTION_SERVICE",
    Exported = true)]
public sealed class ProfileRepairAppFunctionService : AppFunctionService
{
    private const string FunctionId =
        "AndroidSMA.ProfileRepairAppFunctionService#stageProfileRepair";

    public override void OnExecuteFunction(
        ExecuteAppFunctionRequest request,
        string callingPackage,
        SigningInfo callingPackageSigningInfo,
        CancellationSignal cancellationSignal,
        IOutcomeReceiver callback)
    {
        try
        {
            if (request.FunctionIdentifier != FunctionId)
                throw new AppFunctionException(
                    AppFunctionError.FunctionNotFound, "Unknown function.");

            string? profileText = request.Parameters.GetPropertyString("profileText");
            if (string.IsNullOrWhiteSpace(profileText))
                throw new AppFunctionException(
                    AppFunctionError.InvalidArgument, "profileText is required.");

            byte[] bytes = System.Text.Encoding.UTF8.GetBytes(profileText);
            if (bytes.Length > 1_048_576)
                throw new AppFunctionException(
                    AppFunctionError.InvalidArgument, "profileText exceeds 1 MiB.");

            string pending = Path.Combine(FilesDir!.AbsolutePath, "PROFILE.PS1.pending");
            string incoming = pending + ".incoming";
            using (var target = new FileStream(
                       incoming, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                target.Write(bytes);
                target.Flush(flushToDisk: true);
            }
            File.Move(incoming, pending, overwrite: true);

            var open = new Intent(this, typeof(MainActivity));
            open.AddFlags(ActivityFlags.NewTask | ActivityFlags.ClearTop);
            StartActivity(open);

            var resultBuilder = new GenericDocument.Builder("androidsma", "stage", "result");
            resultBuilder.SetPropertyString(ExecuteAppFunctionResponse.PropertyReturnValue,
                ["PROFILE.PS1 staged. User confirmation is required in AndroidSMA."]);
            GenericDocument result = resultBuilder.Build();
            callback.OnResult(new ExecuteAppFunctionResponse(result));
        }
        catch (AppFunctionException error)
        {
            callback.OnError(error.JavaCast<Java.Lang.Object>());
        }
        catch (Exception error)
        {
            var appError = new AppFunctionException(
                AppFunctionError.AppUnknownError, error.Message);
            callback.OnError(appError.JavaCast<Java.Lang.Object>());
        }
    }
}
