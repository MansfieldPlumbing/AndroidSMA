using namespace System
using namespace System.Diagnostics
using namespace System.Globalization
using namespace System.Management.Automation.Runspaces
using namespace System.Runtime.CompilerServices

function Invoke-QnnMatMulAddProof {
    [string] $nativeLibraryDirectory = $PSAndroid.NativeLibraryDirectory
    if ([string]::IsNullOrWhiteSpace($nativeLibraryDirectory)) {
        throw 'AndroidSMA did not publish ApplicationInfo.NativeLibraryDir.'
    }

    [uint32] $featureK = 32
    [uint32] $featureN = 32
    [float[]] $weights = [float[]]::new([int]($featureK * $featureN))
    [float[]] $inputValues = [float[]]::new([int]$featureK)
    [float[]] $bias = [float[]]::new([int]$featureN)

    for ([int] $index = 0; $index -lt $weights.Length; $index++) {
        $weights[$index] = [float]((($index % 17) - 8) / 64.0)
    }
    for ([int] $index = 0; $index -lt $inputValues.Length; $index++) {
        $inputValues[$index] = [float](($index - 15.5) / 16.0)
    }
    for ([int] $index = 0; $index -lt $bias.Length; $index++) {
        $bias[$index] = [float](((($index % 9) - 4) * 0.25) + ($index / 128.0))
    }

    [Environment]::SetEnvironmentVariable('ADSP_LIBRARY_PATH', $nativeLibraryDirectory)
    [Android.Systems.Os]::Setenv('ADSP_LIBRARY_PATH', $nativeLibraryDirectory, $true)

    [AndroidSMA.Qnn.QnnMatMulAddProof] $proof =
        [AndroidSMA.Qnn.QnnMatMulAddProof]::new()
    [Stopwatch] $timer = [Stopwatch]::StartNew()
    [string] $rawResult = $proof.Execute(
        'libQnnHtp.so',
        $featureK,
        $featureN,
        $weights,
        $inputValues,
        $bias)
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
        NativeAdspLibraryPath = [Android.Systems.Os]::Getenv('ADSP_LIBRARY_PATH')
        GraphOperations = [string[]]@('MatMul', 'ElementWiseAdd')
        FeatureK = $featureK
        FeatureN = $featureN
        WeightsManagedIdentity = [RuntimeHelpers]::GetHashCode($weights)
        InputManagedIdentity = [RuntimeHelpers]::GetHashCode($inputValues)
        BiasManagedIdentity = [RuntimeHelpers]::GetHashCode($bias)
        WeightFirst = $weights[0]
        WeightLast = $weights[-1]
        InputFirst = $inputValues[0]
        InputLast = $inputValues[-1]
        BiasFirst = $bias[0]
        BiasLast = $bias[-1]
        RawResult = $rawResult
        MaximumRelativeError = $maximumRelativeError
        Passed = $rawResult.EndsWith(' PASS', [StringComparison]::Ordinal)
        ElapsedMilliseconds = $timer.Elapsed.TotalMilliseconds
    }

    [Android.Util.Log]::Info('PowerShell',
        "QNN_MATMUL_ADD_PROOF passed=$($receipt.Passed) pid=$($receipt.ApplicationPid) tid=$($receipt.PowerShellTid) runspace=$($receipt.RunspaceManagedIdentity) proofType=$($receipt.ProofObjectRuntimeType) proofManaged=$($receipt.ProofObjectManagedIdentity) operations=$([string]::Join(',', $receipt.GraphOperations)) K=$($receipt.FeatureK) N=$($receipt.FeatureN) weightsManaged=$($receipt.WeightsManagedIdentity) inputManaged=$($receipt.InputManagedIdentity) biasManaged=$($receipt.BiasManagedIdentity) weightFirst=$($receipt.WeightFirst) weightLast=$($receipt.WeightLast) inputFirst=$($receipt.InputFirst) inputLast=$($receipt.InputLast) biasFirst=$($receipt.BiasFirst) biasLast=$($receipt.BiasLast) maxRel=$($receipt.MaximumRelativeError) elapsedMs=$([Math]::Round($receipt.ElapsedMilliseconds, 3)) nativeLibraryDirectory=$($receipt.NativeLibraryDirectory) nativeAdspLibraryPath=$($receipt.NativeAdspLibraryPath) raw=$($receipt.RawResult)")
    return $receipt
}
