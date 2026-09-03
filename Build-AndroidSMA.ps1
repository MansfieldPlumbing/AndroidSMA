#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Arm32', 'Arm64')]
    [string] $Architecture,

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',

    [ValidateSet('Recovery')]
    [string] $Variant = 'Recovery',

    [string] $ApplicationId = 'dev.mansfieldplumbing.androidsma',

    [switch] $ValidateOnly
)

$ErrorActionPreference = 'Stop'

$target = @{
    Arm32 = @{
        Rid = 'android-arm'
        Abi = 'armeabi-v7a'
        CoreClrPack = 'Microsoft.Android.Runtime.CoreCLR.37.android-arm'
        NativeSha256 = '523B1455849710A279CCCCC3A02ABB8138050A9F09580C5E2A1E514ED78E85AD'
    }
    Arm64 = @{
        Rid = 'android-arm64'
        Abi = 'arm64-v8a'
        CoreClrPack = 'Microsoft.Android.Runtime.CoreCLR.37.android-arm64'
        NativeSha256 = '4605293D2EAD6D06CF39C45534C5928B8F40DB3AB2A80B415F7FE36C56961A32'
    }
}[$Architecture]

$recovery = [IO.Path]::Combine($PSScriptRoot, 'src', 'Boot', 'Recovery.ps1')
$bridgeProject = [IO.Path]::Combine($PSScriptRoot, 'AndroidSMA.csproj')
$bridgeSource = [IO.Path]::Combine($PSScriptRoot, 'MainActivity.cs')
$dotnet = [IO.Path]::Combine($PSScriptRoot, '.dotnet-p7', 'dotnet.exe')
$native = [IO.Path]::Combine($PSScriptRoot, 'native', $target.Abi, 'libpsl-native.so')
$nativeBuilder = [IO.Path]::Combine($PSScriptRoot, 'native', 'src', 'Build-libpsl-native.ps1')

foreach ($required in @($recovery, $dotnet, $nativeBuilder)) {
    if (-not [IO.File]::Exists($required)) { throw "Required build input is missing: $required" }
}

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $recovery, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) {
    $first = $parseErrors[0]
    throw "Recovery firmware does not parse at $($first.Extent.StartLineNumber):$($first.Extent.StartColumnNumber): $($first.Message)"
}

$forbiddenCommands = @(
    $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -in @('Add-Type', 'Invoke-Expression', 'Import-Module')
    }, $true)
)
if ($forbiddenCommands.Count) {
    $first = $forbiddenCommands[0].Extent
    throw "Recovery firmware uses a forbidden dynamic/compiler command at $($first.StartLineNumber):$($first.StartColumnNumber): $($first.Text)"
}

$sdkVersion = (& $dotnet --version).Trim()
if ($sdkVersion -ne '11.0.100-preview.7.26381.103') {
    throw "Pinned SDK mismatch. Expected 11.0.100-preview.7.26381.103; found $sdkVersion"
}

$packRoot = [IO.Path]::Combine($PSScriptRoot, '.dotnet-p7', 'packs', $target.CoreClrPack)
if (-not [IO.Directory]::Exists($packRoot)) {
    throw "Required CoreCLR pack is missing: $packRoot"
}

if ([IO.File]::Exists($native)) {
    $actualNativeHash = (Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash
    if ($actualNativeHash -ne $target.NativeSha256) {
        throw "Native shim hash mismatch for $Architecture. Expected $($target.NativeSha256); found $actualNativeHash"
    }
}

$result = [ordered]@{
    Status = 'VALIDATED'
    Stage = 'BridgeProof'
    Variant = $Variant
    Architecture = $Architecture
    Rid = $target.Rid
    Abi = $target.Abi
    Sdk = $sdkVersion
    Recovery = $recovery
}

if ($ValidateOnly) { return [pscustomobject]$result }

# This is an intentionally named transition seam. It packages the proven PS1
# firmware behind the temporary Activity bridge. It must disappear when the
# AST-to-IL emitter reaches the deletion gate; it is never a release success.
foreach ($temporary in @($bridgeProject, $bridgeSource)) {
    if (-not [IO.File]::Exists($temporary)) {
        throw "Bridge-proof input is missing. The emitted firmware build is not implemented yet: $temporary"
    }
}

if ($PSCmdlet.ShouldProcess($native, "Rebuild verified $Architecture native shim")) {
    & $nativeBuilder -Architecture $Architecture | Out-Null
}

if (-not $PSCmdlet.ShouldProcess($ApplicationId, "Build $Variant bridge-proof APK for $Architecture")) {
    return [pscustomobject]$result
}

& $dotnet restore $bridgeProject -r $target.Rid -p:ApplicationId=$ApplicationId
if ($LASTEXITCODE) { throw "Restore failed with exit code $LASTEXITCODE" }

& $dotnet build $bridgeProject -c $Configuration -r $target.Rid `
    -t:SignAndroidPackage -p:ApplicationId=$ApplicationId --no-restore
if ($LASTEXITCODE) { throw "Android build failed with exit code $LASTEXITCODE" }

$outputRoot = [IO.Path]::Combine(
    $PSScriptRoot, 'bin', $Configuration, 'net11.0-android', $target.Rid)
$apk = [IO.Directory]::EnumerateFiles($outputRoot, '*-Signed.apk', [IO.SearchOption]::AllDirectories) |
    Sort-Object { [IO.File]::GetLastWriteTimeUtc($_) } -Descending |
    Select-Object -First 1
if (-not $apk) { throw "Build succeeded but no signed APK was found under $outputRoot" }

$result.Status = 'BRIDGE_PROOF_BUILT'
$result.Apk = $apk
$result.ApkSha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
[pscustomobject]$result
