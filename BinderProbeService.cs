using Android.App;
using Android.Content;
using Android.OS;

namespace TerminalMvp;

[Service(
    Name = "dev.mansfieldplumbing.terminal.BinderProbeService",
    Exported = false,
    Process = ":binderprobe")]
public sealed class BinderProbeService : Service
{
    private readonly BinderProbe _endpoint = new();

    public override IBinder OnBind(Intent? intent) => _endpoint;
}

internal sealed class BinderProbe : Binder
{
    internal const int GetRemoteIdentity = IBinder.FirstCallTransaction;
    internal const int EchoBinder = IBinder.FirstCallTransaction + 1;
    internal const int Die = IBinder.FirstCallTransaction + 2;

    protected override bool OnTransact(int code, Parcel data, Parcel? reply, int flags)
    {
        switch (code)
        {
            case GetRemoteIdentity:
                if (reply is null) return false;
                reply.WriteNoException();
                reply.WriteInt(Android.OS.Process.MyPid());
                reply.WriteInt(Android.OS.Process.MyTid());
                return true;

            case EchoBinder:
                if (reply is null) return false;
                IBinder? token = data.ReadStrongBinder();
                reply.WriteNoException();
                reply.WriteStrongBinder(token);
                return true;

            case Die:
                reply?.WriteNoException();
                Android.OS.Process.KillProcess(Android.OS.Process.MyPid());
                return true;

            default:
                return base.OnTransact(code, data, reply, flags);
        }
    }
}
