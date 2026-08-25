using namespace System
using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces
using namespace System.Runtime.CompilerServices

function Get-AndroidObjectReceipt {
    param(
        [Parameter(Mandatory)][string] $Label,
        [Parameter(Mandatory)] $Value
    )

    $jniIdentity = $null
    $peerHandle = $null
    if ($Value -is [Java.Interop.IJavaPeerable]) {
        [Java.Interop.IJavaPeerable] $peer = $Value
        $jniIdentity = $peer.JniIdentityHashCode
        try { $peerHandle = $peer.PeerReference.Handle.ToInt64() } catch { }
    }

    $alive = $null
    $ping = $null
    if ($Value -is [Android.OS.IBinder]) {
        [Android.OS.IBinder] $binder = $Value
        $alive = $binder.IsBinderAlive
        $ping = $binder.PingBinder()
    }

    [pscustomobject]@{
        Label = $Label
        Value = $Value
        RuntimeType = $Value.GetType().FullName
        ManagedIdentityHash = [RuntimeHelpers]::GetHashCode($Value)
        JniIdentityHash = $jniIdentity
        JniPeerHandle = $peerHandle
        BinderAlive = $alive
        BinderPing = $ping
        ObservedPid = [Android.OS.Process]::MyPid()
        ObservedTid = [Android.OS.Process]::MyTid()
    }
}

function Write-AndroidObjectReceipt {
    param([Parameter(Mandatory)] $Receipt)

    [Android.Util.Log]::Info('BinderLab',
        ('OBJECT label={0} runtimeType={1} managedIdentityHash={2} jniIdentityHash={3} jniPeerHandle={4} binderAlive={5} binderPing={6} observedPid={7} observedTid={8}' -f
            $Receipt.Label,
            $Receipt.RuntimeType,
            $Receipt.ManagedIdentityHash,
            $Receipt.JniIdentityHash,
            $Receipt.JniPeerHandle,
            $Receipt.BinderAlive,
            $Receipt.BinderPing,
            $Receipt.ObservedPid,
            $Receipt.ObservedTid))
}

function Write-AndroidIdentityRelationship {
    param(
        [Parameter(Mandatory)][string] $Label,
        [Parameter(Mandatory)] $Original,
        [Parameter(Mandatory)] $Returned
    )

    $receipt = [pscustomobject]@{
        Label = $Label
        Original = $Original
        Returned = $Returned
        ManagedReferenceEqual = [object]::ReferenceEquals($Original, $Returned)
        ObjectEqualsResult = $Original.Equals($Returned)
        OriginalType = $Original.GetType().FullName
        ReturnedType = $Returned.GetType().FullName
        OriginalManagedIdentityHash = [RuntimeHelpers]::GetHashCode($Original)
        ReturnedManagedIdentityHash = [RuntimeHelpers]::GetHashCode($Returned)
        ObservedPid = [Android.OS.Process]::MyPid()
        ObservedTid = [Android.OS.Process]::MyTid()
    }
    [Android.Util.Log]::Info('BinderLab',
        ('RELATION label={0} managedReferenceEqual={1} objectEqualsResult={2} originalRuntimeType={3} returnedRuntimeType={4} originalManagedIdentityHash={5} returnedManagedIdentityHash={6} observedPid={7} observedTid={8}' -f
            $receipt.Label,
            $receipt.ManagedReferenceEqual,
            $receipt.ObjectEqualsResult,
            $receipt.OriginalType,
            $receipt.ReturnedType,
            $receipt.OriginalManagedIdentityHash,
            $receipt.ReturnedManagedIdentityHash,
            $receipt.ObservedPid,
            $receipt.ObservedTid))
    return $receipt
}

function Invoke-LocalBinderReceipt {
    [Android.OS.Binder] $token = $PSAndroid.RuntimeBinder

    [Android.OS.Bundle] $bundle = [Android.OS.Bundle]::new()
    $bundle.PutBinder('binder.lab', $token)
    [Android.OS.IBinder] $fromBundle = $bundle.GetBinder('binder.lab')

    [Android.OS.Parcel] $parcel = [Android.OS.Parcel]::Obtain()
    try {
        $parcel.WriteStrongBinder($token)
        $parcel.SetDataPosition(0)
        [Android.OS.IBinder] $fromParcel = $parcel.ReadStrongBinder()
    }
    finally {
        $parcel.Recycle()
    }

    $tokenReceipt = Get-AndroidObjectReceipt 'owner.token' $token
    $bundleReceipt = Get-AndroidObjectReceipt 'owner.bundle-returned' $fromBundle
    $parcelReceipt = Get-AndroidObjectReceipt 'owner.parcel-returned' $fromParcel
    Write-AndroidObjectReceipt $tokenReceipt
    Write-AndroidObjectReceipt $bundleReceipt
    Write-AndroidObjectReceipt $parcelReceipt

    $bundleRelationship = Write-AndroidIdentityRelationship 'Bundle PutBinder/GetBinder' $token $fromBundle
    $parcelRelationship = Write-AndroidIdentityRelationship 'Parcel WriteStrongBinder/ReadStrongBinder' $token $fromParcel

    [pscustomobject]@{
        Token = $token
        Bundle = $bundle
        FromBundle = $fromBundle
        FromParcel = $fromParcel
        TokenReceipt = $tokenReceipt
        BundleReceipt = $bundleReceipt
        ParcelReceipt = $parcelReceipt
        BundleRelationship = $bundleRelationship
        ParcelRelationship = $parcelRelationship
    }
}

function Invoke-CrossRunspaceIdentityReceipt {
    param(
        [Parameter(Mandatory)][Android.OS.IBinder] $Binder,
        [Parameter(Mandatory)][Android.OS.Bundle] $Bundle
    )

    [InitialSessionState] $initial = [InitialSessionState]::Create()
    $initial.LanguageMode = [PSLanguageMode]::FullLanguage
    $initial.ThreadOptions = [PSThreadOptions]::ReuseThread
    $initial.Variables.Add([SessionStateVariableEntry]::new('BinderSpecimen', $Binder, 'Direct owner reference'))
    $initial.Variables.Add([SessionStateVariableEntry]::new('BundleSpecimen', $Bundle, 'Direct owner reference'))

    [Runspace] $runspace = [RunspaceFactory]::CreateRunspace($initial)
    $runspace.Open()
    [PowerShell] $shell = [PowerShell]::Create()
    try {
        $shell.Runspace = $runspace
        [void]$shell.AddScript(@'
$binderPeer = [Java.Interop.IJavaPeerable]$BinderSpecimen
$bundlePeer = [Java.Interop.IJavaPeerable]$BundleSpecimen
$ChildPrivateSentinel = [guid]::NewGuid().ToString('N')
[pscustomobject]@{
    Binder = $BinderSpecimen
    Bundle = $BundleSpecimen
    BinderType = $BinderSpecimen.GetType().FullName
    BundleType = $BundleSpecimen.GetType().FullName
    BinderManagedIdentity = [Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($BinderSpecimen)
    BundleManagedIdentity = [Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($BundleSpecimen)
    BinderJniIdentity = $binderPeer.JniIdentityHashCode
    BundleJniIdentity = $bundlePeer.JniIdentityHashCode
    BinderPeerHandle = $binderPeer.PeerReference.Handle.ToInt64()
    BundlePeerHandle = $bundlePeer.PeerReference.Handle.ToInt64()
    BinderAlive = $BinderSpecimen.IsBinderAlive
    BinderPing = $BinderSpecimen.PingBinder()
    Pid = [Android.OS.Process]::MyPid()
    Tid = [Android.OS.Process]::MyTid()
    MainLooperThread = [object]::ReferenceEquals(
        [Android.OS.Looper]::MyLooper(), [Android.OS.Looper]::MainLooper)
    PrivateSentinel = $ChildPrivateSentinel
}

'@)
        [Collections.ObjectModel.Collection[PSObject]] $output = $shell.Invoke()
        if ($shell.HadErrors) { throw $shell.Streams.Error[0] }
        if ($output.Count -ne 1) {
            throw "The child runspace produced $($output.Count) receipt objects; exactly one was expected."
        }
        $child = $output[0]
    }
    finally {
        $shell.Dispose()
        $runspace.Dispose()
    }

    $binderRelationship = Write-AndroidIdentityRelationship 'owner -> child runspace -> owner Binder' $Binder $child.Binder
    $bundleRelationship = Write-AndroidIdentityRelationship 'owner -> child runspace -> owner Bundle' $Bundle $child.Bundle
    [Android.Util.Log]::Info('BinderLab',
        ('CHILD binderType={0} bundleType={1} binderManaged={2} bundleManaged={3} binderJni={4} bundleJni={5} binderPeer={6} bundlePeer={7} alive={8} ping={9} pid={10} tid={11} mainLooper={12} sentinel={13}' -f
            $child.BinderType,
            $child.BundleType,
            $child.BinderManagedIdentity,
            $child.BundleManagedIdentity,
            $child.BinderJniIdentity,
            $child.BundleJniIdentity,
            $child.BinderPeerHandle,
            $child.BundlePeerHandle,
            $child.BinderAlive,
            $child.BinderPing,
            $child.Pid,
            $child.Tid,
            $child.MainLooperThread,
            $child.PrivateSentinel))

    [pscustomobject]@{
        Child = $child
        BinderRelationship = $binderRelationship
        BundleRelationship = $bundleRelationship
        OwnerPid = [Android.OS.Process]::MyPid()
        OwnerTid = [Android.OS.Process]::MyTid()
        OwnerHasChildSentinel = $null -ne $ExecutionContext.SessionState.PSVariable.Get('ChildPrivateSentinel')
    }
}

function Invoke-UiThreadAffinityReceipt {
    param(
        [Parameter(Mandatory)][Android.App.Activity] $Activity,
        [Parameter(Mandatory)][Android.Views.View] $View
    )

    [InitialSessionState] $initial = [InitialSessionState]::Create()
    $initial.LanguageMode = [PSLanguageMode]::FullLanguage
    $initial.ThreadOptions = [PSThreadOptions]::ReuseThread
    $initial.Variables.Add([SessionStateVariableEntry]::new('ViewSpecimen', $View, 'Direct owner reference'))

    [Runspace] $runspace = [RunspaceFactory]::CreateRunspace($initial)
    $runspace.Open()
    [PowerShell] $shell = [PowerShell]::Create()
    try {
        $shell.Runspace = $runspace
        [void]$shell.AddScript(@'
$peer = [Java.Interop.IJavaPeerable]$ViewSpecimen
[pscustomobject]@{
    View = $ViewSpecimen
    RuntimeType = $ViewSpecimen.GetType().FullName
    ManagedIdentity = [Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($ViewSpecimen)
    JniIdentity = $peer.JniIdentityHashCode
    PeerHandle = $peer.PeerReference.Handle.ToInt64()
    Pid = [Android.OS.Process]::MyPid()
    Tid = [Android.OS.Process]::MyTid()
    MainLooperThread = [object]::ReferenceEquals(
        [Android.OS.Looper]::MyLooper(), [Android.OS.Looper]::MainLooper)
}
'@)
        [Collections.ObjectModel.Collection[PSObject]] $output = $shell.Invoke()
        if ($shell.HadErrors) { throw $shell.Streams.Error[0] }
        if ($output.Count -ne 1) {
            throw "The child runspace produced $($output.Count) View receipts; exactly one was expected."
        }
        $child = $output[0]
    }
    finally {
        $shell.Dispose()
        $runspace.Dispose()
    }

    $relationship = Write-AndroidIdentityRelationship 'owner -> child runspace -> owner View' $View $child.View
    $receipt = [pscustomobject]@{
        View = $View
        Child = $child
        Relationship = $relationship
        OwnerPid = [Android.OS.Process]::MyPid()
        OwnerTid = [Android.OS.Process]::MyTid()
        OwnerMainLooperThread = [object]::ReferenceEquals(
            [Android.OS.Looper]::MyLooper(), [Android.OS.Looper]::MainLooper)
        Runnable = $null
        Posted = $false
        MainThread = $null
        MainThreadAction = $null
        AdmittedMainThread = $null
    }

    [Action] $onMain = [Action]{
        $mainPeer = [Java.Interop.IJavaPeerable]$View
        $receipt.MainThread = [pscustomobject]@{
            View = $View
            RuntimeType = $View.GetType().FullName
            ManagedIdentity = [RuntimeHelpers]::GetHashCode($View)
            JniIdentity = $mainPeer.JniIdentityHashCode
            PeerHandle = $mainPeer.PeerReference.Handle.ToInt64()
            Pid = [Android.OS.Process]::MyPid()
            Tid = [Android.OS.Process]::MyTid()
            MainLooperThread = [object]::ReferenceEquals(
                [Android.OS.Looper]::MyLooper(), [Android.OS.Looper]::MainLooper)
        }
        [Android.Util.Log]::Info('BinderLab',
            ('VIEW_MAIN type={0} managed={1} jni={2} peer={3} pid={4} tid={5} mainLooper={6}' -f
                $receipt.MainThread.RuntimeType,
                $receipt.MainThread.ManagedIdentity,
                $receipt.MainThread.JniIdentity,
                $receipt.MainThread.PeerHandle,
                $receipt.MainThread.Pid,
                $receipt.MainThread.Tid,
                $receipt.MainThread.MainLooperThread))
    }.GetNewClosure()
    [TerminalMvp.AndroidAnimationRunnable] $runnable =
        [TerminalMvp.AndroidAnimationRunnable]::new($onMain)
    $receipt.Runnable = $runnable
    $receipt.Posted = $View.Post([Java.Lang.IRunnable] $runnable)

    [Action] $onAdmittedMain = [Action]{
        $mainPeer = [Java.Interop.IJavaPeerable]$View
        $receipt.AdmittedMainThread = [pscustomobject]@{
            View = $View
            RuntimeType = $View.GetType().FullName
            ManagedIdentity = [RuntimeHelpers]::GetHashCode($View)
            JniIdentity = $mainPeer.JniIdentityHashCode
            PeerHandle = $mainPeer.PeerReference.Handle.ToInt64()
            Pid = [Android.OS.Process]::MyPid()
            Tid = [Android.OS.Process]::MyTid()
            MainLooperThread = [object]::ReferenceEquals(
                [Android.OS.Looper]::MyLooper(), [Android.OS.Looper]::MainLooper)
        }
        [Android.Util.Log]::Info('BinderLab',
            ('VIEW_ADMITTED_MAIN type={0} managed={1} jni={2} peer={3} pid={4} tid={5} mainLooper={6}' -f
                $receipt.AdmittedMainThread.RuntimeType,
                $receipt.AdmittedMainThread.ManagedIdentity,
                $receipt.AdmittedMainThread.JniIdentity,
                $receipt.AdmittedMainThread.PeerHandle,
                $receipt.AdmittedMainThread.Pid,
                $receipt.AdmittedMainThread.Tid,
                $receipt.AdmittedMainThread.MainLooperThread))
    }.GetNewClosure()
    $receipt.MainThreadAction = $onAdmittedMain
    $PSAndroid.Service.RunOnMainThread($Activity, $onAdmittedMain)

    [Android.Util.Log]::Info('BinderLab',
        ('VIEW_CHILD type={0} managed={1} jni={2} peer={3} pid={4} tid={5} mainLooper={6}; ownerTid={7} ownerMainLooper={8} posted={9}' -f
            $child.RuntimeType,
            $child.ManagedIdentity,
            $child.JniIdentity,
            $child.PeerHandle,
            $child.Pid,
            $child.Tid,
            $child.MainLooperThread,
            $receipt.OwnerTid,
            $receipt.OwnerMainLooperThread,
            $receipt.Posted))
    return $receipt
}

function Invoke-PowerShellServiceConnectionAttempt {
    $receipt = [pscustomobject]@{
        AttemptedAt = [DateTimeOffset]::UtcNow
        Pid = [Android.OS.Process]::MyPid()
        Tid = [Android.OS.Process]::MyTid()
        Intent = $null
        Connection = $null
        Bound = $false
        Connected = $null
        Disconnected = $null
        BindingDied = $null
        NullBinding = $null
        FailureType = $null
        FailureMessage = $null
    }

    [string] $classSource = @'
class PowerShellBinderProbeConnection : Android.Content.IServiceConnection {
    [object] $Receipt

    PowerShellBinderProbeConnection([object] $Receipt) {
        $this.Receipt = $Receipt
    }

    [void] OnServiceConnected([Android.Content.ComponentName] $Name, [Android.OS.IBinder] $Service) {
        $this.Receipt.Connected = [pscustomobject]@{
            Name = $Name
            Service = $Service
            Pid = [Android.OS.Process]::MyPid()
            Tid = [Android.OS.Process]::MyTid()
        }
    }

    [void] OnServiceDisconnected([Android.Content.ComponentName] $Name) {
        $this.Receipt.Disconnected = [pscustomobject]@{
            Name = $Name
            Pid = [Android.OS.Process]::MyPid()
            Tid = [Android.OS.Process]::MyTid()
        }
    }

    [void] OnBindingDied([Android.Content.ComponentName] $Name) {
        $this.Receipt.BindingDied = [pscustomobject]@{
            Name = $Name
            Pid = [Android.OS.Process]::MyPid()
            Tid = [Android.OS.Process]::MyTid()
        }
    }

    [void] OnNullBinding([Android.Content.ComponentName] $Name) {
        $this.Receipt.NullBinding = [pscustomobject]@{
            Name = $Name
            Pid = [Android.OS.Process]::MyPid()
            Tid = [Android.OS.Process]::MyTid()
        }
    }
}

[PowerShellBinderProbeConnection]::new($args[0])
'@

    try {
        [scriptblock] $factory = [scriptblock]::Create($classSource)
        $receipt.Connection = & $factory $receipt
        [Android.Content.Intent] $intent = [Android.Content.Intent]::new(
            $Application, [TerminalMvp.BinderProbeService])
        $receipt.Intent = $intent
        $receipt.Bound = $Application.BindService(
            $intent,
            [Android.Content.IServiceConnection] $receipt.Connection,
            [Android.Content.Bind]::AutoCreate)
    }
    catch {
        $receipt.FailureType = $_.Exception.GetType().FullName
        $receipt.FailureMessage = $_.Exception.Message
    }

    [Android.Util.Log]::Info('BinderLab',
        ('SERVICE_CONNECTION_ATTEMPT connectionType={0} bound={1} failureType={2} failure={3} pid={4} tid={5}' -f
            $receipt.Connection?.GetType().FullName,
            $receipt.Bound,
            $receipt.FailureType,
            $receipt.FailureMessage,
            $receipt.Pid,
            $receipt.Tid))
    return $receipt
}

function Invoke-RemoteBinderTransactions {
    param([Parameter(Mandatory)][Android.OS.IBinder] $RemoteBinder)

    $remoteReceipt = Get-AndroidObjectReceipt 'remote.endpoint' $RemoteBinder
    Write-AndroidObjectReceipt $remoteReceipt

    [Android.OS.Parcel] $identityData = [Android.OS.Parcel]::Obtain()
    [Android.OS.Parcel] $identityReply = [Android.OS.Parcel]::Obtain()
    [int] $identityCode = [Android.OS.IBinder]::FirstCallTransaction
    [bool] $identityAccepted = $RemoteBinder.Transact(
        $identityCode, $identityData, $identityReply, [Android.OS.TransactionFlags]::None)
    $identityReply.ReadException()
    [int] $remotePid = $identityReply.ReadInt()
    [int] $remoteTid = $identityReply.ReadInt()

    [Android.OS.Parcel] $echoData = [Android.OS.Parcel]::Obtain()
    [Android.OS.Parcel] $echoReply = [Android.OS.Parcel]::Obtain()
    [Android.OS.IBinder] $original = $PSAndroid.RuntimeBinder
    $echoData.WriteStrongBinder($original)
    [int] $echoCode = [Android.OS.IBinder]::FirstCallTransaction + 1
    [bool] $echoAccepted = $RemoteBinder.Transact(
        $echoCode, $echoData, $echoReply, [Android.OS.TransactionFlags]::None)
    $echoReply.ReadException()
    [Android.OS.IBinder] $returned = $echoReply.ReadStrongBinder()
    $echoRelationship = Write-AndroidIdentityRelationship 'origin Binder -> remote process -> origin' $original $returned
    $returnedReceipt = Get-AndroidObjectReceipt 'remote.echo-returned' $returned
    Write-AndroidObjectReceipt $returnedReceipt

    $receipt = [pscustomobject]@{
        RemoteBinder = $RemoteBinder
        RemoteReceipt = $remoteReceipt
        IdentityCode = $identityCode
        IdentityDataParcel = $identityData
        IdentityReplyParcel = $identityReply
        IdentityAccepted = $identityAccepted
        RemotePid = $remotePid
        RemoteTid = $remoteTid
        CallerPid = [Android.OS.Process]::MyPid()
        CallerTid = [Android.OS.Process]::MyTid()
        EchoCode = $echoCode
        EchoDataParcel = $echoData
        EchoReplyParcel = $echoReply
        EchoAccepted = $echoAccepted
        OriginalBinder = $original
        ReturnedBinder = $returned
        ReturnedReceipt = $returnedReceipt
        EchoRelationship = $echoRelationship
    }
    [Android.Util.Log]::Info('BinderLab',
        ('REMOTE_TRANSACTIONS runtimeType={0} identityAccepted={1} callerPid={2} callerTid={3} remotePid={4} remoteTid={5} echoAccepted={6} echoManagedReferenceEqual={7} echoObjectEqualsResult={8}' -f
            $remoteReceipt.RuntimeType,
            $identityAccepted,
            $receipt.CallerPid,
            $receipt.CallerTid,
            $remotePid,
            $remoteTid,
            $echoAccepted,
            $echoRelationship.ManagedReferenceEqual,
            $echoRelationship.ObjectEqualsResult))
    return $receipt
}

function Connect-BinderProbeWithAdmittedPeer {
    $receipt = [pscustomobject]@{
        AttemptedAt = [DateTimeOffset]::UtcNow
        Intent = $null
        Connection = $null
        Bound = $false
        Connected = $null
        Disconnected = $null
        BindingDied = $null
        NullBinding = $null
        Transactions = $null
        Coexistence = $null
        FailureType = $null
        FailureMessage = $null
    }

    [Action[Android.Content.ComponentName,Android.OS.IBinder]] $onConnected =
        [Action[Android.Content.ComponentName,Android.OS.IBinder]]{
            param($name, $service)
            $receipt.Connected = [pscustomobject]@{
                Name = $name
                Service = $service
                RuntimeType = $service.GetType().FullName
                Pid = [Android.OS.Process]::MyPid()
                Tid = [Android.OS.Process]::MyTid()
                MainLooperThread = [object]::ReferenceEquals(
                    [Android.OS.Looper]::MyLooper(), [Android.OS.Looper]::MainLooper)
            }
            [Android.Util.Log]::Info('BinderLab',
                ('SERVICE_CONNECTED component={0} type={1} pid={2} tid={3} mainLooper={4}' -f
                    $name.FlattenToShortString(),
                    $service.GetType().FullName,
                    $receipt.Connected.Pid,
                    $receipt.Connected.Tid,
                    $receipt.Connected.MainLooperThread))
            try {
                $receipt.Transactions = Invoke-RemoteBinderTransactions -RemoteBinder $service
            }
            catch {
                $receipt.FailureType = $_.Exception.GetType().FullName
                $receipt.FailureMessage = $_.Exception.Message
                [Android.Util.Log]::Error('BinderLab', "REMOTE_TRANSACTIONS_FAILED $($_.Exception)")
            }
        }.GetNewClosure()

    [Action[Android.Content.ComponentName]] $onDisconnected =
        [Action[Android.Content.ComponentName]]{
            param($name)
            $receipt.Disconnected = [pscustomobject]@{
                Name = $name
                Pid = [Android.OS.Process]::MyPid()
                Tid = [Android.OS.Process]::MyTid()
            }
        }.GetNewClosure()

    [Action[Android.Content.ComponentName]] $onBindingDied =
        [Action[Android.Content.ComponentName]]{
            param($name)
            $receipt.BindingDied = [pscustomobject]@{
                Name = $name
                Pid = [Android.OS.Process]::MyPid()
                Tid = [Android.OS.Process]::MyTid()
            }
        }.GetNewClosure()

    [Action[Android.Content.ComponentName]] $onNullBinding =
        [Action[Android.Content.ComponentName]]{
            param($name)
            $receipt.NullBinding = [pscustomobject]@{
                Name = $name
                Pid = [Android.OS.Process]::MyPid()
                Tid = [Android.OS.Process]::MyTid()
            }
        }.GetNewClosure()

    try {
        $receipt.Connection = [TerminalMvp.AndroidServiceConnection]::new(
            $PSAndroid.Service, $onConnected, $onDisconnected, $onBindingDied, $onNullBinding)
        $receipt.Intent = [Android.Content.Intent]::new(
            $Application, [TerminalMvp.BinderProbeService])
        $receipt.Bound = $Application.BindService(
            $receipt.Intent,
            [Android.Content.IServiceConnection] $receipt.Connection,
            [Android.Content.Bind]::AutoCreate)
    }
    catch {
        $receipt.FailureType = $_.Exception.GetType().FullName
        $receipt.FailureMessage = $_.Exception.Message
    }

    [Android.Util.Log]::Info('BinderLab',
        ('ADMITTED_CONNECTION type={0} bound={1} failureType={2} failure={3} pid={4} tid={5}' -f
            $receipt.Connection?.GetType().FullName,
            $receipt.Bound,
            $receipt.FailureType,
            $receipt.FailureMessage,
            [Android.OS.Process]::MyPid(),
            [Android.OS.Process]::MyTid()))
    return $receipt
}

function Invoke-BinderRendererCoexistenceReceipt {
    param([Parameter(Mandatory)] $AndroidCanvasEdge)

    if ($null -eq $global:BinderLab.Remote?.Connected?.Service) {
        throw 'The remote Binder endpoint is not connected.'
    }
    if ($null -eq $AndroidCanvasEdge?.Surface) {
        throw 'The frozen renderer does not currently retain a SurfaceView.'
    }

    $edgeBefore = $AndroidCanvasEdge
    [Android.Views.SurfaceView] $surfaceBefore = $edgeBefore.Surface
    [Android.OS.IBinder] $remoteBinder = $global:BinderLab.Remote.Connected.Service
    [bool] $aliveBefore = $remoteBinder.IsBinderAlive
    [bool] $pingBefore = $remoteBinder.PingBinder()

    $transactions = Invoke-RemoteBinderTransactions -RemoteBinder $remoteBinder

    $edgeAfter = $AndroidCanvasEdge
    [Android.Views.SurfaceView] $surfaceAfter = $edgeAfter.Surface
    [Java.Interop.IJavaPeerable] $surfacePeer = $surfaceAfter
    $receipt = [pscustomobject]@{
        ObservedAt = [DateTimeOffset]::UtcNow
        OwnerPid = [Android.OS.Process]::MyPid()
        OwnerTid = [Android.OS.Process]::MyTid()
        RemoteBinder = $remoteBinder
        RemoteAliveBefore = $aliveBefore
        RemotePingBefore = $pingBefore
        RemoteAliveAfter = $remoteBinder.IsBinderAlive
        RemotePingAfter = $remoteBinder.PingBinder()
        EdgeManagedReferenceEqual = [object]::ReferenceEquals($edgeBefore, $edgeAfter)
        EdgeManagedIdentityHash = [RuntimeHelpers]::GetHashCode($edgeAfter)
        SurfaceManagedReferenceEqual = [object]::ReferenceEquals($surfaceBefore, $surfaceAfter)
        SurfaceManagedIdentityHash = [RuntimeHelpers]::GetHashCode($surfaceAfter)
        SurfaceJniIdentityHash = $surfacePeer.JniIdentityHashCode
        SurfaceJniPeerHandle = $surfacePeer.PeerReference.Handle.ToInt64()
        SurfaceGeneration = $edgeAfter.Generation
        AnimationRunnable = $edgeAfter.Tick
        Transactions = $transactions
    }
    [Android.Util.Log]::Info('BinderLab',
        ('COEXISTENCE ownerPid={0} ownerTid={1} remoteAliveBefore={2} remotePingBefore={3} remoteAliveAfter={4} remotePingAfter={5} edgeManagedReferenceEqual={6} edgeManagedIdentityHash={7} surfaceManagedReferenceEqual={8} surfaceManagedIdentityHash={9} surfaceJniIdentityHash={10} surfaceJniPeerHandle={11} surfaceGeneration={12} echoManagedReferenceEqual={13}' -f
            $receipt.OwnerPid,
            $receipt.OwnerTid,
            $receipt.RemoteAliveBefore,
            $receipt.RemotePingBefore,
            $receipt.RemoteAliveAfter,
            $receipt.RemotePingAfter,
            $receipt.EdgeManagedReferenceEqual,
            $receipt.EdgeManagedIdentityHash,
            $receipt.SurfaceManagedReferenceEqual,
            $receipt.SurfaceManagedIdentityHash,
            $receipt.SurfaceJniIdentityHash,
            $receipt.SurfaceJniPeerHandle,
            $receipt.SurfaceGeneration,
            $receipt.Transactions.EchoRelationship.ManagedReferenceEqual))
    return $receipt
}

function Invoke-BinderRendererDedicatedUiRunspaceCoexistenceReceipt {
    param([Parameter(Mandatory)] $UiApplicationState)

    if ($null -eq $UiApplicationState.UiRunspace) {
        throw 'The dedicated UI runspace object is not present.'
    }
    if ($null -eq $UiApplicationState.AndroidCanvasEdge) {
        throw 'The dedicated UI runspace Android-canvas edge object is not present.'
    }
    if ($null -eq $UiApplicationState.Surface) {
        throw 'The dedicated UI runspace did not publish its SurfaceView reference.'
    }

    [Runspace] $ownerRunspace = [Runspace]::DefaultRunspace
    $edge = $UiApplicationState.AndroidCanvasEdge
    $edgeSurface = $edge.Surface
    [Android.Views.SurfaceView] $surfaceBefore = $UiApplicationState.Surface
    [Android.OS.IBinder] $remoteBinder = $global:BinderLab.Remote.Connected.Service
    [bool] $remoteAliveBefore = $remoteBinder.IsBinderAlive
    [bool] $remotePingBefore = $remoteBinder.PingBinder()
    $transactions = Invoke-RemoteBinderTransactions -RemoteBinder $remoteBinder
    [Android.Views.SurfaceView] $surfaceAfter = $UiApplicationState.Surface
    [Java.Interop.IJavaPeerable] $surfacePeer = $surfaceAfter
    $receipt = [pscustomobject]@{
        ObservedAt = [DateTimeOffset]::UtcNow
        OwnerRunspace = $ownerRunspace
        UiRunspace = $UiApplicationState.UiRunspace
        ScriptRunspace = $UiApplicationState.ScriptRunspace
        OwnerUiRunspaceManagedReferenceEqual = [object]::ReferenceEquals(
            $ownerRunspace, $UiApplicationState.UiRunspace)
        UiScriptRunspaceManagedReferenceEqual = [object]::ReferenceEquals(
            $UiApplicationState.UiRunspace, $UiApplicationState.ScriptRunspace)
        OwnerRunspaceManagedIdentityHash = [RuntimeHelpers]::GetHashCode($ownerRunspace)
        UiRunspaceManagedIdentityHash = [RuntimeHelpers]::GetHashCode($UiApplicationState.UiRunspace)
        ScriptRunspaceManagedIdentityHash = [RuntimeHelpers]::GetHashCode($UiApplicationState.ScriptRunspace)
        OwnerPid = [Android.OS.Process]::MyPid()
        OwnerTid = [Android.OS.Process]::MyTid()
        UiScriptPid = $UiApplicationState.ScriptPid
        UiScriptTid = $UiApplicationState.ScriptTid
        AndroidMainPid = $UiApplicationState.AndroidMainPid
        AndroidMainTid = $UiApplicationState.AndroidMainTid
        AndroidMainLooper = $UiApplicationState.AndroidMainLooper
        UiStateManagedIdentityHashOnOwner = [RuntimeHelpers]::GetHashCode($UiApplicationState)
        UiStateManagedIdentityHashOnScriptThread = $UiApplicationState.UiStateManagedIdentityHashOnScriptThread
        UiStateManagedIdentityHashOnAndroidMain = $UiApplicationState.UiStateManagedIdentityHashOnAndroidMain
        EdgeManagedIdentityHashOnOwner = [RuntimeHelpers]::GetHashCode($edge)
        EdgeSurfacePresentOnOwner = $null -ne $edgeSurface
        PublishedSurfacePresentOnOwner = $null -ne $surfaceBefore
        EdgeSurfacePublishedSurfaceManagedReferenceEqualOnOwner = [object]::ReferenceEquals(
            $edgeSurface, $surfaceBefore)
        EdgeSurfacePublishedSurfaceManagedReferenceEqualOnAndroidMain =
            $UiApplicationState.EdgeSurfacePublishedSurfaceManagedReferenceEqualOnAndroidMain
        SurfaceManagedReferenceEqual = [object]::ReferenceEquals($surfaceBefore, $surfaceAfter)
        SurfaceManagedIdentityHash = [RuntimeHelpers]::GetHashCode($surfaceAfter)
        SurfaceJniIdentityHash = $surfacePeer.JniIdentityHashCode
        SurfaceJniPeerHandle = $surfacePeer.PeerReference.Handle.ToInt64()
        RemoteBinder = $remoteBinder
        RemoteAliveBefore = $remoteAliveBefore
        RemotePingBefore = $remotePingBefore
        RemoteAliveAfter = $remoteBinder.IsBinderAlive
        RemotePingAfter = $remoteBinder.PingBinder()
        Transactions = $transactions
    }
    [Android.Util.Log]::Info('BinderLab',
        ('DEDICATED_UI_RUNSPACE_COEXISTENCE ownerRunspaceManagedIdentityHash={0} uiRunspaceManagedIdentityHash={1} scriptRunspaceManagedIdentityHash={2} ownerUiRunspaceManagedReferenceEqual={3} uiScriptRunspaceManagedReferenceEqual={4} ownerPid={5} ownerTid={6} uiScriptPid={7} uiScriptTid={8} androidMainPid={9} androidMainTid={10} androidMainLooper={11} uiStateManagedIdentityHashOnOwner={12} uiStateManagedIdentityHashOnScriptThread={13} uiStateManagedIdentityHashOnAndroidMain={14} edgeManagedIdentityHashOnOwner={15} edgeSurfacePresentOnOwner={16} publishedSurfacePresentOnOwner={17} edgeSurfacePublishedSurfaceManagedReferenceEqualOnOwner={18} edgeSurfacePublishedSurfaceManagedReferenceEqualOnAndroidMain={19} surfaceManagedReferenceEqual={20} surfaceManagedIdentityHash={21} surfaceJniIdentityHash={22} surfaceJniPeerHandle={23} remoteAliveAfter={24} remotePingAfter={25} echoManagedReferenceEqual={26}' -f
            $receipt.OwnerRunspaceManagedIdentityHash,
            $receipt.UiRunspaceManagedIdentityHash,
            $receipt.ScriptRunspaceManagedIdentityHash,
            $receipt.OwnerUiRunspaceManagedReferenceEqual,
            $receipt.UiScriptRunspaceManagedReferenceEqual,
            $receipt.OwnerPid,
            $receipt.OwnerTid,
            $receipt.UiScriptPid,
            $receipt.UiScriptTid,
            $receipt.AndroidMainPid,
            $receipt.AndroidMainTid,
            $receipt.AndroidMainLooper,
            $receipt.UiStateManagedIdentityHashOnOwner,
            $receipt.UiStateManagedIdentityHashOnScriptThread,
            $receipt.UiStateManagedIdentityHashOnAndroidMain,
            $receipt.EdgeManagedIdentityHashOnOwner,
            $receipt.EdgeSurfacePresentOnOwner,
            $receipt.PublishedSurfacePresentOnOwner,
            $receipt.EdgeSurfacePublishedSurfaceManagedReferenceEqualOnOwner,
            $receipt.EdgeSurfacePublishedSurfaceManagedReferenceEqualOnAndroidMain,
            $receipt.SurfaceManagedReferenceEqual,
            $receipt.SurfaceManagedIdentityHash,
            $receipt.SurfaceJniIdentityHash,
            $receipt.SurfaceJniPeerHandle,
            $receipt.RemoteAliveAfter,
            $receipt.RemotePingAfter,
            $receipt.Transactions.EchoRelationship.ManagedReferenceEqual))
    return $receipt
}

$localReceipt = Invoke-LocalBinderReceipt
$crossRunspaceReceipt = Invoke-CrossRunspaceIdentityReceipt -Binder $localReceipt.Token -Bundle $localReceipt.Bundle

$global:BinderLab = [pscustomobject]@{
    StartedAt = [DateTimeOffset]::UtcNow
    Local = $localReceipt
    CrossRunspace = $crossRunspaceReceipt
    UiThread = $null
    RemoteConnectionAttempt = $null
    Remote = $null
    CoexistenceReceipt = $null
    CoexistenceFailure = $null
}

$global:BinderLab.RemoteConnectionAttempt = Invoke-PowerShellServiceConnectionAttempt

[Android.Util.Log]::Info('BinderLab',
    "READY pid=$([Android.OS.Process]::MyPid()) tid=$([Android.OS.Process]::MyTid()) ownerHasChildSentinel=$($crossRunspaceReceipt.OwnerHasChildSentinel)")
