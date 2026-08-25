using Android.Content;
using Android.OS;

namespace TerminalMvp;

public sealed class AndroidServiceConnection : Java.Lang.Object, IServiceConnection
{
    private readonly PowerShellService _owner;
    private readonly Action<ComponentName, IBinder> _connected;
    private readonly Action<ComponentName> _disconnected;
    private readonly Action<ComponentName> _bindingDied;
    private readonly Action<ComponentName> _nullBinding;

    public AndroidServiceConnection(
        PowerShellService owner,
        Action<ComponentName, IBinder> connected,
        Action<ComponentName> disconnected,
        Action<ComponentName> bindingDied,
        Action<ComponentName> nullBinding)
    {
        _owner = owner;
        _connected = connected;
        _disconnected = disconnected;
        _bindingDied = bindingDied;
        _nullBinding = nullBinding;
    }

    public void OnServiceConnected(ComponentName? name, IBinder? service)
    {
        if (name is not null && service is not null)
            _owner.Post(() => _connected(name, service));
    }

    public void OnServiceDisconnected(ComponentName? name)
    {
        if (name is not null) _owner.Post(() => _disconnected(name));
    }

    public void OnBindingDied(ComponentName? name)
    {
        if (name is not null) _owner.Post(() => _bindingDied(name));
    }

    public void OnNullBinding(ComponentName? name)
    {
        if (name is not null) _owner.Post(() => _nullBinding(name));
    }
}
