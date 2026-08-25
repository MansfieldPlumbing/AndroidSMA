namespace TerminalMvp;

// Android's View.postOnAnimation requires an IRunnable with a Java peer.
// PowerShell supplies and owns the Action, including frame policy and reposting.
public sealed class AndroidAnimationRunnable : Java.Lang.Object, Java.Lang.IRunnable
{
    private readonly Action _action;

    public AndroidAnimationRunnable(Action action) => _action = action;

    public void Run() => _action();
}
