using namespace System
using namespace System.Diagnostics
using namespace System.Globalization
using namespace System.Management.Automation.Runspaces
using namespace System.Runtime.CompilerServices

function Invoke-QnnMatMulProof {
    [string] $nativeLibraryDirectory = $PSAndroid.NativeLibraryDirectory
    if ([string]::IsNullOrWhiteSpace($nativeLibraryDirectory)) {
        throw 'AndroidSMA did not publish ApplicationInfo.NativeLibraryDir.'
    }

    [Environment]::SetEnvironmentVariable('ADSP_LIBRARY_PATH', $nativeLibraryDirectory)
    [Android.Systems.Os]::Setenv('ADSP_LIBRARY_PATH', $nativeLibraryDirectory, $true)
    [AndroidSMA.Qnn.QnnMatMulProof] $proof = [AndroidSMA.Qnn.QnnMatMulProof]::new()
    [Stopwatch] $timer = [Stopwatch]::StartNew()
    [string] $rawResult = $proof.Execute(
        'libQnnHtp.so',
        [string]::Empty,
        [uint32]32,
        [uint32]32,
        $null,
        $null,
        [uint32]0,
        [uint32]73,
        [uint32]8)
    $timer.Stop()

    [Text.RegularExpressions.Match] $relativeMatch =
        [Text.RegularExpressions.Regex]::Match($rawResult, 'maxRel=(?<value>[0-9.]+)')
    [object] $maximumRelativeError = $null
    if ($relativeMatch.Success) {
        $maximumRelativeError = [double]::Parse(
            $relativeMatch.Groups['value'].Value,
            [CultureInfo]::InvariantCulture)
    }

    $receipt = [pscustomobject]@{
        CompletedAt = [DateTimeOffset]::UtcNow
        ApplicationPid = [Android.OS.Process]::MyPid()
        PowerShellTid = [Android.OS.Process]::MyTid()
        RunspaceManagedIdentity = [RuntimeHelpers]::GetHashCode([Runspace]::DefaultRunspace)
        ProofObject = $proof
        ProofObjectRuntimeType = $proof.GetType().FullName
        ProofObjectManagedIdentity = [RuntimeHelpers]::GetHashCode($proof)
        BackendLibrary = 'libQnnHtp.so'
        NativeLibraryDirectory = $nativeLibraryDirectory
        AdspLibraryPath = [Environment]::GetEnvironmentVariable('ADSP_LIBRARY_PATH')
        NativeAdspLibraryPath = [Android.Systems.Os]::Getenv('ADSP_LIBRARY_PATH')
        FeatureK = 32
        FeatureN = 32
        DspArchitecture = 73
        RawResult = $rawResult
        MaximumRelativeError = $maximumRelativeError
        Passed = $rawResult.EndsWith(' PASS', [StringComparison]::Ordinal)
        ElapsedMilliseconds = $timer.Elapsed.TotalMilliseconds
    }

    [Android.Util.Log]::Info('PowerShell',
        "QNN_MATMUL_PROOF passed=$($receipt.Passed) pid=$($receipt.ApplicationPid) tid=$($receipt.PowerShellTid) runspace=$($receipt.RunspaceManagedIdentity) proofType=$($receipt.ProofObjectRuntimeType) proofManaged=$($receipt.ProofObjectManagedIdentity) K=$($receipt.FeatureK) N=$($receipt.FeatureN) dspArch=$($receipt.DspArchitecture) maxRel=$($receipt.MaximumRelativeError) elapsedMs=$([Math]::Round($receipt.ElapsedMilliseconds, 3)) nativeLibraryDirectory=$($receipt.NativeLibraryDirectory) nativeAdspLibraryPath=$($receipt.NativeAdspLibraryPath) raw=$($receipt.RawResult)")
    return $receipt
}
