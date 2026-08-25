using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;

namespace TerminalMvp;

[Activity(
    Name = "dev.mansfieldplumbing.terminal.MainActivity",
    Label = "PowerShell",
    MainLauncher = true,
    Exported = true,
    LaunchMode = LaunchMode.SingleTop,
    Theme = "@android:style/Theme.Material.NoActionBar")]
public sealed class MainActivity : Activity
{
    protected override void OnCreate(Bundle? state)
    {
        base.OnCreate(state);

        var service = new Intent(this, typeof(PowerShellService));
        bool serviceExperiment = Intent?.Action == PowerShellService.BinderLabAction ||
            Intent?.Action == PowerShellService.PSCustomObjectRunspaceMutationAction ||
            Intent?.Action == PowerShellService.QnnMatMulProofAction ||
            Intent?.Action == PowerShellService.QnnMatMulAddProofAction;
        if (serviceExperiment) service.SetAction(Intent!.Action);
        if (Build.VERSION.SdkInt >= BuildVersionCodes.O)
            StartForegroundService(service);
        else
            StartService(service);

        if (serviceExperiment)
        {
            Finish();
            return;
        }

        if (Build.VERSION.SdkInt >= BuildVersionCodes.Tiramisu &&
            CheckSelfPermission("android.permission.POST_NOTIFICATIONS") != Permission.Granted)
            RequestPermissions(["android.permission.POST_NOTIFICATIONS"], 42);

        PowerShellService.Attach(this, Intent);
    }

    protected override void OnNewIntent(Intent? intent)
    {
        base.OnNewIntent(intent);
        if (intent is null) return;
        if (intent.Action == PowerShellService.BinderLabAction ||
            intent.Action == PowerShellService.PSCustomObjectRunspaceMutationAction ||
            intent.Action == PowerShellService.QnnMatMulProofAction ||
            intent.Action == PowerShellService.QnnMatMulAddProofAction)
        {
            var service = new Intent(this, typeof(PowerShellService));
            service.SetAction(intent.Action);
            if (Build.VERSION.SdkInt >= BuildVersionCodes.O)
                StartForegroundService(service);
            else
                StartService(service);
            return;
        }
        PowerShellService.Attach(this, intent);
    }

    protected override void OnDestroy()
    {
        PowerShellService.Detach(this);
        base.OnDestroy();
    }
}
