using namespace System
using namespace System.IO

[Android.OS.Binder] $runtimeBinder = [Android.OS.Binder]::new()
[Android.OS.Bundle] $binderProof = [Android.OS.Bundle]::new()
$binderProof.PutBinder('powershell.runtime', $runtimeBinder)
[Android.OS.IBinder] $roundTrippedBinder = $binderProof.GetBinder('powershell.runtime')
if (-not $runtimeBinder.Equals($roundTrippedBinder)) {
    throw 'Android did not preserve the PowerShell-created Binder identity.'
}
$binderProof.Dispose()

$global:PSAndroid = [pscustomobject]@{
    StartedAt = [DateTimeOffset]::UtcNow
    ScriptRoot = [Path]::GetFullPath([string]$ScriptRoot)
    DataRoot = [Path]::GetFullPath($Application.FilesDir.AbsolutePath)
    Service = $Service
    RuntimeBinder = $runtimeBinder
    NativeLibraryDirectory = $Application.ApplicationInfo.NativeLibraryDir
}

[Android.Util.Log]::Info('PowerShell', "profile.ps1 loaded; Binder=$($runtimeBinder.GetType().FullName); scripts=$($PSAndroid.ScriptRoot)")

$binderLabPath = [Path]::Combine($PSAndroid.ScriptRoot, 'binder-lab.ps1')
if ([File]::Exists($binderLabPath)) {
    [scriptblock] $binderLabSource = [scriptblock]::Create([File]::ReadAllText($binderLabPath))
    . $binderLabSource
}

$pscustomObjectMutationPath = [Path]::Combine($PSAndroid.ScriptRoot, 'pscustomobject-runspace-mutation.ps1')
if ([File]::Exists($pscustomObjectMutationPath)) {
    [scriptblock] $pscustomObjectMutationSource =
        [scriptblock]::Create([File]::ReadAllText($pscustomObjectMutationPath))
    . $pscustomObjectMutationSource
}

$qnnMatMulProofPath = [Path]::Combine($PSAndroid.ScriptRoot, 'qnn-matmul-proof.ps1')
if ([File]::Exists($qnnMatMulProofPath)) {
    [scriptblock] $qnnMatMulProofSource =
        [scriptblock]::Create([File]::ReadAllText($qnnMatMulProofPath))
    . $qnnMatMulProofSource
}

$qnnMatMulAddProofPath = [Path]::Combine($PSAndroid.ScriptRoot, 'qnn-matmul-add-proof.ps1')
if ([File]::Exists($qnnMatMulAddProofPath)) {
    [scriptblock] $qnnMatMulAddProofSource =
        [scriptblock]::Create([File]::ReadAllText($qnnMatMulAddProofPath))
    . $qnnMatMulAddProofSource
}
