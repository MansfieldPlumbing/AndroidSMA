using System.Collections.Concurrent;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Util;

namespace TerminalMvp;

[Service(
    Name = "dev.mansfieldplumbing.terminal.PowerShellService",
    Exported = false,
    ForegroundServiceType = ForegroundService.TypeSpecialUse)]
public sealed class PowerShellService : Service
{
    public const string StopAction = "dev.mansfieldplumbing.terminal.STOP";
    public const string BinderLabAction = "dev.mansfieldplumbing.terminal.BINDER_LAB";
    public const string PSCustomObjectRunspaceMutationAction = "dev.mansfieldplumbing.terminal.PSCUSTOMOBJECT_RUNSPACE_MUTATION";
    public const string QnnMatMulProofAction = "dev.mansfieldplumbing.terminal.QNN_MATMUL_PROOF";
    public const string QnnMatMulAddProofAction = "dev.mansfieldplumbing.terminal.QNN_MATMUL_ADD_PROOF";
    private const string ChannelId = "powershell-runtime";
    private const int NotificationId = 7301;
    private static readonly object StaticGate = new();
    private static PowerShellService? _instance;
    private static WeakReference<MainActivity>? _pendingActivity;
    private static Intent? _pendingIntent;

    private readonly BlockingCollection<Work> _work = new(64);
    private Thread? _thread;
    private Runspace? _runspace;

    public override void OnCreate()
    {
        base.OnCreate();
        lock (StaticGate) _instance = this;
        StartForeground(NotificationId, CreateNotification());
        _thread = new Thread(RunPowerShell)
        {
            IsBackground = true,
            Name = "PowerShell application"
        };
        _thread.Start();

        lock (StaticGate)
        {
            if (_pendingActivity?.TryGetTarget(out var activity) == true)
                QueueActivity("Receive-ActivityAttached", activity, _pendingIntent ?? activity.Intent);
            _pendingActivity = null;
            _pendingIntent = null;
        }
    }

    public override StartCommandResult OnStartCommand(Intent? intent, StartCommandFlags flags, int startId)
    {
        StartForeground(NotificationId, CreateNotification());
        if (intent?.Action == StopAction)
        {
            StopSelf();
            return StartCommandResult.NotSticky;
        }

        var data = new PSObject();
        data.Properties.Add(new PSNoteProperty("Name", "StartCommand"));
        data.Properties.Add(new PSNoteProperty("Intent", intent));
        data.Properties.Add(new PSNoteProperty("Flags", flags));
        data.Properties.Add(new PSNoteProperty("StartId", startId));
        data.Properties.Add(new PSNoteProperty("Timestamp", DateTimeOffset.UtcNow));
        _work.TryAdd(Work.ForFunction("Receive-ServiceEvent", data));
        return StartCommandResult.Sticky;
    }

    public override IBinder? OnBind(Intent? intent) => null;

    public static void Attach(MainActivity activity, Intent? intent)
    {
        lock (StaticGate)
        {
            if (_instance is not null)
                _instance.QueueActivity("Receive-ActivityAttached", activity, intent);
            else
            {
                _pendingActivity = new WeakReference<MainActivity>(activity);
                _pendingIntent = intent;
            }
        }
    }

    public static void Detach(MainActivity activity)
    {
        lock (StaticGate)
        {
            if (_pendingActivity?.TryGetTarget(out var pending) == true && ReferenceEquals(pending, activity))
            {
                _pendingActivity = null;
                _pendingIntent = null;
            }
            _instance?.QueueActivity("Receive-ActivityDetached", activity, null);
        }
    }

    public bool Post(ScriptBlock action, object? argument = null)
        => !_work.IsAddingCompleted && _work.TryAdd(Work.ForScript(action, argument));

    public bool Post(Action action)
        => !_work.IsAddingCompleted && _work.TryAdd(Work.ForAction(action));

    public void RunOnMainThread(Activity activity, Action action)
    {
        activity.RunOnUiThread(() =>
        {
            try
            {
                Runspace.DefaultRunspace = _runspace;
                action();
            }
            catch (Exception error)
            {
                Log.Error("PowerShell", $"Android UI callback failed: {error}");
            }
        });
    }

    public void RunOnMainThread(Activity activity, Runspace runspace, Action action)
    {
        activity.RunOnUiThread(() =>
        {
            try
            {
                Runspace.DefaultRunspace = runspace;
                action();
            }
            catch (Exception error)
            {
                Log.Error("PowerShell", $"Android UI callback failed: {error}");
            }
        });
    }

    private void QueueActivity(string function, MainActivity activity, Intent? intent)
    {
        var data = new PSObject();
        data.Properties.Add(new PSNoteProperty("Activity", activity));
        data.Properties.Add(new PSNoteProperty("Intent", intent));
        data.Properties.Add(new PSNoteProperty("Timestamp", DateTimeOffset.UtcNow));
        _work.TryAdd(Work.ForFunction(function, data));
    }

    private void RunPowerShell()
    {
        try
        {
            InstallNativeResolver();
            string scripts = Path.Combine(FilesDir!.AbsolutePath, "scripts");
            Directory.CreateDirectory(scripts);
            foreach (string name in new[]
                     {
                         "profile.ps1", "binder-lab.ps1", "service.ps1", "start.ps1", "terminal-state.ps1", "terminal.ps1", "canvastest.ps1",
                         "canvastest-dedicated-ui-runspace.ps1", "pscustomobject-runspace-mutation.ps1", "qnn-matmul-proof.ps1",
                         "qnn-matmul-add-proof.ps1",
                         "android.types.ps1xml", "android.format.ps1xml"
                     })
                SeedScript(scripts, name);

            var initial = InitialSessionState.Create();
            initial.LanguageMode = PSLanguageMode.FullLanguage;
            initial.ThreadOptions = PSThreadOptions.UseCurrentThread;
            _runspace = RunspaceFactory.CreateRunspace(initial);
            _runspace.Open();
            Runspace.DefaultRunspace = _runspace;
            _runspace.SessionStateProxy.SetVariable("Service", this);
            _runspace.SessionStateProxy.SetVariable("Application", ApplicationContext);
            _runspace.SessionStateProxy.SetVariable("ScriptRoot", scripts);
            InvokeSource(Path.Combine(scripts, "profile.ps1"));
            InvokeSource(Path.Combine(scripts, "service.ps1"));

            var created = new PSObject();
            created.Properties.Add(new PSNoteProperty("Name", "Created"));
            created.Properties.Add(new PSNoteProperty("Timestamp", DateTimeOffset.UtcNow));
            InvokeFunction("Receive-ServiceEvent", created);

            foreach (Work item in _work.GetConsumingEnumerable())
            {
                try
                {
                    if (item.Callback is not null)
                        item.Callback();
                    else if (item.Script is not null)
                        InvokeScript(item.Script, item.Argument);
                    else if (item.Function is not null)
                        InvokeFunction(item.Function, item.Argument);
                }
                catch (Exception error)
                {
                    // An admitted workload may fail without disposing the persistent
                    // AndroidSMA runspace. Deliberate shutdown still exits the loop.
                    Log.Error("PowerShell", $"Queued PowerShell work failed: {error}");
                }
            }
        }
        catch (Exception error)
        {
            Log.Error("PowerShell", error.ToString());
        }
        finally
        {
            if (_runspace is not null)
            {
                Runspace.DefaultRunspace = null;
                _runspace.Dispose();
                _runspace = null;
            }
        }
    }

    private void InvokeSource(string path)
    {
        using var shell = PowerShell.Create();
        shell.Runspace = _runspace;
        shell.AddScript(File.ReadAllText(path), useLocalScope: false).Invoke();
        LogErrors(shell, Path.GetFileName(path));
    }

    private void InvokeFunction(string name, object? argument)
    {
        using var shell = PowerShell.Create();
        shell.Runspace = _runspace;
        shell.AddCommand(name).AddArgument(argument).Invoke();
        LogErrors(shell, name);
    }

    private void InvokeScript(ScriptBlock script, object? argument)
    {
        using var shell = PowerShell.Create();
        shell.Runspace = _runspace;
        shell.AddScript("& $args[0] $args[1]", useLocalScope: false)
            .AddArgument(script).AddArgument(argument).Invoke();
        LogErrors(shell, "queued script");
    }

    private static void LogErrors(PowerShell shell, string source)
    {
        foreach (ErrorRecord error in shell.Streams.Error)
            Log.Error("PowerShell", $"{source}: {error}");
    }

    private void SeedScript(string directory, string name)
    {
        string target = Path.Combine(directory, name);
        if (File.Exists(target)) return;
        using Stream source = Assets!.Open(name);
        using FileStream destination = File.Create(target);
        source.CopyTo(destination);
    }

    private static void InstallNativeResolver()
    {
        NativeLibrary.SetDllImportResolver(typeof(PowerShell).Assembly, (name, assembly, path) =>
            name.Contains("libpsl-native", StringComparison.OrdinalIgnoreCase)
                ? NativeLibrary.Load("libpsl-android.so", assembly, null)
                : IntPtr.Zero);
    }

    private Notification CreateNotification()
    {
        var notifications = (NotificationManager)GetSystemService(NotificationService)!;
        if (Build.VERSION.SdkInt >= BuildVersionCodes.O)
            notifications.CreateNotificationChannel(new NotificationChannel(
                ChannelId, "PowerShell runtime", NotificationImportance.Low)
            { Description = "Keeps the PowerShell application and remote sessions alive." });

        var open = new Intent(this, typeof(MainActivity));
        open.AddFlags(ActivityFlags.SingleTop);
        var openPending = PendingIntent.GetActivity(this, 7302, open,
            PendingIntentFlags.UpdateCurrent | PendingIntentFlags.Immutable);
        var stop = new Intent(this, typeof(PowerShellService));
        stop.SetAction(StopAction);
        var stopPending = PendingIntent.GetService(this, 7303, stop,
            PendingIntentFlags.UpdateCurrent | PendingIntentFlags.Immutable);

        return new Notification.Builder(this, ChannelId)
            .SetSmallIcon(Android.Resource.Drawable.IcDialogInfo)
            .SetContentTitle("PowerShell is running")
            .SetContentText("The application runspace survives Activity recreation.")
            .SetContentIntent(openPending)
            .SetOngoing(true)
            .SetOnlyAlertOnce(true)
            .SetCategory(Notification.CategoryService)
            .AddAction(new Notification.Action.Builder(null, "Open", openPending).Build())
            .AddAction(new Notification.Action.Builder(null, "Stop PowerShell", stopPending).Build())
            .Build();
    }

    public override void OnDestroy()
    {
        var stopping = new PSObject();
        stopping.Properties.Add(new PSNoteProperty("Name", "Stopping"));
        stopping.Properties.Add(new PSNoteProperty("Timestamp", DateTimeOffset.UtcNow));
        _work.TryAdd(Work.ForFunction("Receive-ServiceEvent", stopping));
        _work.CompleteAdding();
        _thread?.Join(TimeSpan.FromSeconds(5));
        StopForeground(StopForegroundFlags.Remove);
        lock (StaticGate)
        {
            if (ReferenceEquals(_instance, this)) _instance = null;
        }
        base.OnDestroy();
    }

    private sealed class Work
    {
        public string? Function { get; private init; }
        public ScriptBlock? Script { get; private init; }
        public Action? Callback { get; private init; }
        public object? Argument { get; private init; }
        public static Work ForFunction(string function, object? argument) =>
            new() { Function = function, Argument = argument };
        public static Work ForScript(ScriptBlock script, object? argument) =>
            new() { Script = script, Argument = argument };
        public static Work ForAction(Action action) => new() { Callback = action };
    }
}
