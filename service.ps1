using namespace System
using namespace System.Collections.Concurrent
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces
using namespace System.Reflection
using namespace System.Threading

[scriptblock] $terminalStateSource = [scriptblock]::Create(
    [IO.File]::ReadAllText([IO.Path]::Combine($PSAndroid.ScriptRoot, 'terminal-state.ps1')))
. $terminalStateSource

function Add-CommandsFromAssembly {
    param([Parameter(Mandatory)][InitialSessionState] $InitialState,
          [Parameter(Mandatory)][Assembly] $Assembly)
    foreach ($type in $Assembly.GetTypes()) {
        [object[]] $cmdletAttributes = $type.GetCustomAttributes([CmdletAttribute], $false)
        [CmdletAttribute] $cmdlet = if ($cmdletAttributes.Count) { $cmdletAttributes[0] } else { $null }
        if ($null -ne $cmdlet -and -not $type.IsAbstract) {
            $InitialState.Commands.Add([SessionStateCmdletEntry]::new(
                "$($cmdlet.VerbName)-$($cmdlet.NounName)", $type, $null))
        }
    }
}

function New-CommandRunspace {
    [InitialSessionState] $initial = [InitialSessionState]::Create()
    $initial.LanguageMode = [PSLanguageMode]::FullLanguage
    $initial.ThreadOptions = [PSThreadOptions]::ReuseThread
    $initial.Types.Add([SessionStateTypeEntry]::new(
        [IO.Path]::Combine($PSAndroid.ScriptRoot, 'android.types.ps1xml')))
    $initial.Formats.Add([SessionStateFormatEntry]::new(
        [IO.Path]::Combine($PSAndroid.ScriptRoot, 'android.format.ps1xml')))
    [Assembly] $automation = [PSObject].Assembly
    foreach ($providerName in 'Alias','Environment','FileSystem','Function','Variable') {
        [Type] $providerType = $automation.GetType("Microsoft.PowerShell.Commands.${providerName}Provider", $true)
        $initial.Providers.Add([SessionStateProviderEntry]::new($providerName, $providerType, $null))
    }
    [Assembly[]] $assemblies = @(
        [PSObject].Assembly
        [Assembly]::Load('Microsoft.PowerShell.Commands.Management')
        [Assembly]::Load('Microsoft.PowerShell.Commands.Utility')
    )
    foreach ($assembly in $assemblies) {
        Add-CommandsFromAssembly -InitialState $initial -Assembly $assembly
    }
    [Runspace] $runspace = [RunspaceFactory]::CreateRunspace($initial)
    $runspace.Open()
    [PowerShell] $shell = [PowerShell]::Create()
    try {
        $shell.Runspace = $runspace
        [void]$shell.AddScript(@'
$env:HOME = $args[0]
$env:POWERSHELL_TELEMETRY_OPTOUT = '1'
$null = New-PSDrive -Name Home -PSProvider FileSystem -Root $env:HOME -Scope Global
Set-Location -LiteralPath $env:HOME
'@).AddArgument($PSAndroid.DataRoot).Invoke()
        if ($shell.HadErrors) { throw $shell.Streams.Error[0] }
    }
    finally { $shell.Dispose() }
    return $runspace
}

function New-DedicatedUiRunspaceApplicationState {
    [InitialSessionState] $initial = [InitialSessionState]::Create()
    $initial.LanguageMode = [PSLanguageMode]::FullLanguage
    $initial.ThreadOptions = [PSThreadOptions]::ReuseThread
    [Runspace] $runspace = [RunspaceFactory]::CreateRunspace($initial)
    $runspace.Open()
    $state = [pscustomobject]@{
        OwnerRunspace = [Runspace]::DefaultRunspace
        UiRunspace = $runspace
        ScriptRunspace = $null
        AndroidCanvasEdge = $null
        Surface = $null
        UiStateManagedIdentityHashOnScriptThread = $null
        UiStateManagedIdentityHashOnAndroidMain = $null
        EdgeSurfacePublishedSurfaceManagedReferenceEqualOnAndroidMain = $null
        ScriptPid = $null
        ScriptTid = $null
        AndroidMainPid = $null
        AndroidMainTid = $null
        AndroidMainLooper = $null
    }
    $runspace.SessionStateProxy.SetVariable('PSAndroid', $global:PSAndroid)
    $runspace.SessionStateProxy.SetVariable('UiRunspace', $runspace)
    $runspace.SessionStateProxy.SetVariable('UiApplicationState', $state)
    [Android.Util.Log]::Info('PowerShell',
        "DEDICATED_UI_RUNSPACE_CREATED ownerRunspaceManagedIdentityHash=$([System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($state.OwnerRunspace)) uiRunspaceManagedIdentityHash=$([System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($runspace)) ownerPid=$([Android.OS.Process]::MyPid()) ownerTid=$([Android.OS.Process]::MyTid())")
    return $state
}

function Invoke-DedicatedUiRunspaceCanvasTest {
    param([Parameter(Mandatory)] $Event)

    if ($null -eq $script:DedicatedUiRunspaceApplicationState -or
        $script:DedicatedUiRunspaceApplicationState.UiRunspace.RunspaceStateInfo.State -ne [RunspaceState]::Opened) {
        $script:DedicatedUiRunspaceApplicationState = New-DedicatedUiRunspaceApplicationState
    }

    $state = $script:DedicatedUiRunspaceApplicationState
    [PowerShell] $shell = [PowerShell]::Create()
    try {
        $shell.Runspace = $state.UiRunspace
        [string] $source = [IO.File]::ReadAllText(
            [IO.Path]::Combine($PSAndroid.ScriptRoot, 'canvastest-dedicated-ui-runspace.ps1'))
        [void]$shell.AddScript($source, $false).AddParameter('Event', $Event).Invoke()
        if ($shell.HadErrors) { throw $shell.Streams.Error[0] }
    }
    finally { $shell.Dispose() }

    if ($null -eq $state.AndroidCanvasEdge) {
        throw 'The dedicated UI runspace did not publish its Android-canvas edge object.'
    }
    [Android.Util.Log]::Info('PowerShell',
        "DEDICATED_UI_RUNSPACE_SCRIPT_COMPLETE uiRunspaceManagedIdentityHash=$([System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($state.UiRunspace)) edgeManagedIdentityHash=$([System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($state.AndroidCanvasEdge)) ownerPid=$([Android.OS.Process]::MyPid()) ownerTid=$([Android.OS.Process]::MyTid()) uiScriptPid=$($state.ScriptPid) uiScriptTid=$($state.ScriptTid)")
}

$script:Terminal = New-TerminalState -Columns 80 -Rows 24 -Scrollback 4000
$script:CommandRunspace = New-CommandRunspace
$script:Submissions = [ConcurrentDictionary[string,object]]::new()
$script:StreamSequence = [long[]]::new(1)
$script:Activity = $null
$script:Surface = $null
$script:Ime = $null
$script:DedicatedUiRunspaceApplicationState = $null
$script:ReceiveCommandStreamAction = { param($item) Receive-CommandStream $item }
$script:CompleteCommandAction = { param($item) Complete-CommandSubmission $item }

function Add-StreamEvent {
    param([Parameter(Mandatory)] $Collection,
          [Parameter(Mandatory)][string] $Stream,
          [Parameter(Mandatory)][string] $SubmissionId)
    [long[]] $sequence = $script:StreamSequence
    [object] $applicationService = $PSAndroid.Service
    [scriptblock] $receiveAction = $script:ReceiveCommandStreamAction
    [scriptblock] $receive = {
        param($sender, $eventArgs)
        $value = $sender[$eventArgs.Index]
        $entry = [pscustomobject]@{
            SubmissionId = $SubmissionId
            Stream = $Stream
            Value = $value
            Sequence = [Interlocked]::Increment([ref]$sequence[0])
        }
        [void]$applicationService.Post($receiveAction, $entry)
    }.GetNewClosure()
    $Collection.add_DataAdded($receive)
}

function Start-CommandSubmission {
    param([Parameter(Mandatory)][string] $Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return $null }
    [string] $id = [Guid]::NewGuid().ToString('N')
    [PowerShell] $shell = [PowerShell]::Create()
    $shell.Runspace = $script:CommandRunspace
    [void]$shell.AddScript($Command, $false)
    [System.Management.Automation.PSDataCollection[PSObject]] $success =
        [System.Management.Automation.PSDataCollection[PSObject]]::new()
    [List[object]] $entries = [List[object]]::new()
    $submission = [pscustomobject]@{
        Id = $id; Command = $Command; Shell = $shell; Success = $success
        Entries = $entries; StartedAt = [DateTimeOffset]::UtcNow; Async = $null
    }
    if (-not $script:Submissions.TryAdd($id, $submission)) {
        $shell.Dispose(); throw "Could not admit submission $id"
    }
    Add-StreamEvent $success Success $id
    Add-StreamEvent $shell.Streams.Error Error $id
    Add-StreamEvent $shell.Streams.Warning Warning $id
    Add-StreamEvent $shell.Streams.Verbose Verbose $id
    Add-StreamEvent $shell.Streams.Debug Debug $id
    Add-StreamEvent $shell.Streams.Information Information $id
    Add-StreamEvent $shell.Streams.Progress Progress $id
    [object] $applicationService = $PSAndroid.Service
    [scriptblock] $completeAction = $script:CompleteCommandAction
    [scriptblock] $stateChanged = {
        param($sender, $eventArgs)
        [PSInvocationState] $state = $eventArgs.InvocationStateInfo.State
        if ($state -in [PSInvocationState]::Completed, [PSInvocationState]::Failed, [PSInvocationState]::Stopped) {
            $completion = [pscustomobject]@{
                SubmissionId = $id; State = $state; Reason = $eventArgs.InvocationStateInfo.Reason
            }
            [void]$applicationService.Post($completeAction, $completion)
        }
    }.GetNewClosure()
    $shell.add_InvocationStateChanged($stateChanged)
    $submission.Async = $shell.BeginInvoke[PSObject,PSObject]($null, $success)
    return $id
}

function Receive-CommandStream {
    param([Parameter(Mandatory)] $Entry)
    [object] $submission = $null
    if (-not $script:Submissions.TryGetValue([string]$Entry.SubmissionId, [ref]$submission)) { return }
    $submission.Entries.Add($Entry)
    if ($Entry.Stream -ne 'Success') {
        [string] $text = switch ($Entry.Stream) {
            Error { "ERROR: $($Entry.Value)" }
            Warning { "WARNING: $($Entry.Value)" }
            Verbose { "VERBOSE: $($Entry.Value)" }
            Debug { "DEBUG: $($Entry.Value)" }
            Information { [string]$Entry.Value.MessageData }
            Progress { "PROGRESS: $($Entry.Value.Activity) $($Entry.Value.PercentComplete)%" }
        }
        if ($text) { Add-TerminalText $script:Terminal ($text + "`r`n") }
        Request-TerminalDraw
    }
}

function Format-SuccessOutput {
    param([object[]] $Value)
    if ($Value.Count -eq 0) { return '' }
    [PowerShell] $formatter = [PowerShell]::Create()
    try {
        $formatter.Runspace = $script:CommandRunspace
        [void]$formatter.AddCommand('Out-String').AddParameter('Stream')
        [Collections.ObjectModel.Collection[PSObject]] $formatted = $formatter.Invoke($Value)
        return ($formatted -join "`r`n")
    }
    finally { $formatter.Dispose() }
}

function Complete-CommandSubmission {
    param([Parameter(Mandatory)] $Completion)
    [object] $submission = $null
    if (-not $script:Submissions.TryRemove([string]$Completion.SubmissionId, [ref]$submission)) { return }
    [object[]] $ordered = $submission.Entries.ToArray()
    [Array]::Sort[object]($ordered, [Comparison[object]]{ param($left,$right) $left.Sequence.CompareTo($right.Sequence) })
    [List[object]] $successValues = [List[object]]::new()
    foreach ($entry in $ordered) { if ($entry.Stream -eq 'Success') { $successValues.Add($entry.Value) } }
    [object[]] $success = $successValues.ToArray()
    [string] $formatted = Format-SuccessOutput $success
    if ($formatted) { Add-TerminalText $script:Terminal $formatted }
    if ($Completion.State -eq [PSInvocationState]::Stopped) { Add-TerminalText $script:Terminal "^C`r`n" }
    elseif ($Completion.State -eq [PSInvocationState]::Failed -and $Completion.Reason) {
        Add-TerminalText $script:Terminal ("FAILED: $($Completion.Reason.Message)`r`n")
    }
    $script:LastSubmission = [pscustomobject]@{
        Id = $submission.Id; Command = $submission.Command; State = $Completion.State
        Entries = $ordered; CompletedAt = [DateTimeOffset]::UtcNow
    }
    $submission.Shell.Dispose()
    Add-TerminalText $script:Terminal (Get-TerminalPrompt)
    Request-TerminalDraw
}

function Stop-CommandSubmission {
    param([Parameter(Mandatory)][string] $SubmissionId)
    [object] $submission = $null
    if ($script:Submissions.TryGetValue($SubmissionId, [ref]$submission)) {
        [void]$submission.Shell.BeginStop($null, $null)
    }
}

function Get-TerminalPrompt {
    [PowerShell] $shell = [PowerShell]::Create()
    try {
        $shell.Runspace = $script:CommandRunspace
        [void]$shell.AddScript("'PS ' + (Get-Location).Path + '> '")
        return [string]($shell.Invoke()[0].BaseObject)
    }
    finally { $shell.Dispose() }
}

function Receive-ServiceEvent {
    param($Event)
    [Android.Util.Log]::Info('PowerShell', "Service event: $($Event.Name)")
    if ($Event.Name -eq 'StartCommand' -and
        $Event.Intent?.Action -eq 'dev.mansfieldplumbing.terminal.QNN_MATMUL_ADD_PROOF') {
        try {
            $global:QnnMatMulAddProofFailure = $null
            $global:QnnMatMulAddProofReceipt = Invoke-QnnMatMulAddProof
        }
        catch {
            $global:QnnMatMulAddProofFailure = [pscustomobject]@{
                FailedAt = [DateTimeOffset]::UtcNow
                RuntimeType = $_.Exception.GetType().FullName
                Message = $_.Exception.Message
                ApplicationPid = [Android.OS.Process]::MyPid()
                PowerShellTid = [Android.OS.Process]::MyTid()
            }
            [Android.Util.Log]::Error('PowerShell',
                "QNN_MATMUL_ADD_PROOF_FAILED runtimeType=$($global:QnnMatMulAddProofFailure.RuntimeType) message=$($global:QnnMatMulAddProofFailure.Message) pid=$($global:QnnMatMulAddProofFailure.ApplicationPid) tid=$($global:QnnMatMulAddProofFailure.PowerShellTid)")
        }
    }
    if ($Event.Name -eq 'StartCommand' -and
        $Event.Intent?.Action -eq 'dev.mansfieldplumbing.terminal.QNN_MATMUL_PROOF') {
        try {
            $global:QnnMatMulProofFailure = $null
            $global:QnnMatMulProofReceipt = Invoke-QnnMatMulProof
        }
        catch {
            $global:QnnMatMulProofFailure = [pscustomobject]@{
                FailedAt = [DateTimeOffset]::UtcNow
                RuntimeType = $_.Exception.GetType().FullName
                Message = $_.Exception.Message
                ApplicationPid = [Android.OS.Process]::MyPid()
                PowerShellTid = [Android.OS.Process]::MyTid()
            }
            [Android.Util.Log]::Error('PowerShell',
                "QNN_MATMUL_PROOF_FAILED runtimeType=$($global:QnnMatMulProofFailure.RuntimeType) message=$($global:QnnMatMulProofFailure.Message) pid=$($global:QnnMatMulProofFailure.ApplicationPid) tid=$($global:QnnMatMulProofFailure.PowerShellTid)")
        }
    }
    if ($Event.Name -eq 'StartCommand' -and
        $Event.Intent?.Action -eq 'dev.mansfieldplumbing.terminal.PSCUSTOMOBJECT_RUNSPACE_MUTATION') {
        try {
            if ($null -eq $script:DedicatedUiRunspaceApplicationState -or
                $null -eq $script:DedicatedUiRunspaceApplicationState.Surface) {
                throw 'The PSCustomObject runspace mutation receipt requires the explicitly published dedicated-UI-runspace SurfaceView.'
            }
            $global:PSCustomObjectRunspaceMutationReceipt =
                Invoke-PSCustomObjectRunspaceMutationReceipt `
                    -SurfaceView $script:DedicatedUiRunspaceApplicationState.Surface `
                    -ReplacementAndroidObject $PSAndroid.RuntimeBinder
        }
        catch {
            $global:PSCustomObjectRunspaceMutationFailure = [pscustomobject]@{
                FailedAt = [DateTimeOffset]::UtcNow
                RuntimeType = $_.Exception.GetType().FullName
                Message = $_.Exception.Message
                OwnerPid = [Android.OS.Process]::MyPid()
                OwnerTid = [Android.OS.Process]::MyTid()
            }
            [Android.Util.Log]::Error('PowerShell',
                "PSCUSTOMOBJECT_RUNSPACE_MUTATION_FAILED runtimeType=$($global:PSCustomObjectRunspaceMutationFailure.RuntimeType) message=$($global:PSCustomObjectRunspaceMutationFailure.Message) ownerPid=$($global:PSCustomObjectRunspaceMutationFailure.OwnerPid) ownerTid=$($global:PSCustomObjectRunspaceMutationFailure.OwnerTid)")
        }
    }
    if ($Event.Name -eq 'StartCommand' -and
        $Event.Intent?.Action -eq 'dev.mansfieldplumbing.terminal.BINDER_LAB' -and
        $null -ne $global:BinderLab) {
        try {
            if ($null -eq $global:BinderLab.Remote) {
                $global:BinderLab.Remote = Connect-BinderProbeWithAdmittedPeer
            }
            else {
                $global:BinderLab.CoexistenceFailure = $null
                if ($null -ne $script:DedicatedUiRunspaceApplicationState -and
                    $null -ne $script:DedicatedUiRunspaceApplicationState.AndroidCanvasEdge) {
                    $global:BinderLab.CoexistenceReceipt =
                        Invoke-BinderRendererDedicatedUiRunspaceCoexistenceReceipt `
                            -UiApplicationState $script:DedicatedUiRunspaceApplicationState
                }
                else {
                    $global:BinderLab.CoexistenceReceipt =
                        Invoke-BinderRendererCoexistenceReceipt -AndroidCanvasEdge $script:AndroidCanvasEdge
                }
            }
        }
        catch {
            [Android.OS.IBinder] $remoteBinderAfterFailure = $null
            if ($null -ne $global:BinderLab.Remote -and
                $null -ne $global:BinderLab.Remote.Connected -and
                $null -ne $global:BinderLab.Remote.Connected.Service) {
                $remoteBinderAfterFailure = $global:BinderLab.Remote.Connected.Service
            }
            [string] $remoteBinderRuntimeType = $null
            [object] $remoteBinderAlive = $null
            [object] $remoteBinderPing = $null
            if ($null -ne $remoteBinderAfterFailure) {
                $remoteBinderRuntimeType = $remoteBinderAfterFailure.GetType().FullName
                $remoteBinderAlive = $remoteBinderAfterFailure.IsBinderAlive
                $remoteBinderPing = $remoteBinderAfterFailure.PingBinder()
            }
            $failure = [pscustomobject]@{
                FailedAt = [DateTimeOffset]::UtcNow
                RuntimeType = $_.Exception.GetType().FullName
                Message = $_.Exception.Message
                OwnerPid = [Android.OS.Process]::MyPid()
                OwnerTid = [Android.OS.Process]::MyTid()
                RemoteBinderRuntimeType = $remoteBinderRuntimeType
                RemoteBinderAlive = $remoteBinderAlive
                RemoteBinderPing = $remoteBinderPing
            }
            $global:BinderLab.CoexistenceFailure = $failure
            [Android.Util.Log]::Error('BinderLab',
                "COEXISTENCE_FAILED runtimeType=$($failure.RuntimeType) message=$($failure.Message) ownerPid=$($failure.OwnerPid) ownerTid=$($failure.OwnerTid) remoteBinderRuntimeType=$($failure.RemoteBinderRuntimeType) remoteBinderAlive=$($failure.RemoteBinderAlive) remoteBinderPing=$($failure.RemoteBinderPing)")
        }
    }
    if ($Event.Name -eq 'Created' -and $script:Terminal.CursorRow -eq 0 -and $script:Terminal.CursorColumn -eq 0) {
        Add-TerminalText $script:Terminal "PowerShell 7 on Android`r`n"
        Add-TerminalText $script:Terminal (Get-TerminalPrompt)
    }
    if ($Event.Name -eq 'Stopping') {
        foreach ($pair in $script:Submissions.GetEnumerator()) {
            try { [void]$pair.Value.Shell.BeginStop($null, $null) } catch { }
        }
        $script:CommandRunspace.Dispose()
    }
}

function Receive-ActivityAttached {
    param($Event)
    $script:Activity = $Event.Activity
    if ($null -ne $global:BinderLab -and
        $null -ne $script:AndroidCanvasEdge -and
        $null -ne $script:AndroidCanvasEdge.Surface) {
        $global:BinderLab.UiThread = Invoke-UiThreadAffinityReceipt -Activity $Event.Activity -View $script:AndroidCanvasEdge.Surface
    }
    [string] $surfaceName = $Event.Intent?.GetStringExtra('surface')
    if ($surfaceName -notin 'start.ps1','qnn-ui.ps1','terminal.ps1','canvastest.ps1','canvastest-dedicated-ui-runspace.ps1') {
        $surfaceName = 'start.ps1'
    }
    if ($surfaceName -eq 'canvastest-dedicated-ui-runspace.ps1') {
        Invoke-DedicatedUiRunspaceCanvasTest -Event $Event
        return
    }
    [scriptblock] $surfaceSource = [scriptblock]::Create(
        [IO.File]::ReadAllText([IO.Path]::Combine($PSAndroid.ScriptRoot, $surfaceName)))
    . $surfaceSource -Event $Event
}

function Receive-ActivityDetached {
    param($Event)
    if ([object]::ReferenceEquals($script:Activity, $Event.Activity)) {
        if ($null -ne $script:DedicatedUiRunspaceApplicationState -and
            $null -ne $script:DedicatedUiRunspaceApplicationState.AndroidCanvasEdge -and
            [object]::ReferenceEquals(
                $script:DedicatedUiRunspaceApplicationState.AndroidCanvasEdge.Activity,
                $Event.Activity)) {
            $script:DedicatedUiRunspaceApplicationState.AndroidCanvasEdge.Active = $false
        }
        $script:Activity = $null; $script:Surface = $null; $script:Ime = $null
        if ($null -ne $script:AndroidCanvas) {
            $script:AndroidCanvas.Activity = $null
            $script:AndroidCanvas.Surface = $null
            $script:AndroidCanvas.Ime = $null
        }
    }
}
