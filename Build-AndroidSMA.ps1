#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [ValidateSet('android-arm64', 'android-arm')]
    [string] $RuntimeIdentifier = 'android-arm64',

    [string] $ApplicationId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Emit the real AndroidSMA assembly from the authored PowerShell graph.
$androidSmaDll = Join-Path $PSScriptRoot 'build\generated\AndroidSMA.dll'
& (Join-Path $PSScriptRoot 'Scripts\Emit-AndroidSMA.ps1') -OutputPath $androidSmaDll
if (-not [IO.File]::Exists($androidSmaDll)) {
    throw "AndroidSMA.dll was not emitted: $androidSmaDll"
}

# Android's supported packaging toolchain still evaluates a project. Keep that
# project disposable and generated: it contains no application source or logic.
$packagingDirectory = Join-Path $PSScriptRoot "build\temp\$RuntimeIdentifier\$Configuration"
[IO.Directory]::CreateDirectory($packagingDirectory) | Out-Null
$packagingProject = Join-Path $packagingDirectory 'PackagingHost.csproj'
$authoredManifest = Join-Path $PSScriptRoot 'src\Android\AndroidManifest.xml'
$generatedManifest = Join-Path $packagingDirectory 'AndroidManifest.xml'
$debuggable = $Configuration -eq 'Debug'
$manifestXml = [IO.File]::ReadAllText($authoredManifest)
if ($debuggable) {
    $manifestXml = $manifestXml.Replace('<application', '<application android:debuggable="true"')
}
[IO.File]::WriteAllText($generatedManifest, $manifestXml, [Text.UTF8Encoding]::new($false))
$manifestPath = 'AndroidManifest.xml'
$resourceGlob = Join-Path $PSScriptRoot 'src\Android\Resources\**\*'
$androidAbi = if ($RuntimeIdentifier -eq 'android-arm64') { 'arm64-v8a' } else { 'armeabi-v7a' }
$nativeLibrary = Join-Path $PSScriptRoot "native\$androidAbi\libpsl-native.so"
$apkOutput = Join-Path $PSScriptRoot "build\apk\$RuntimeIdentifier\$Configuration\"
if ([string]::IsNullOrWhiteSpace($ApplicationId)) {
    $ApplicationId = 'dev.mansfieldplumbing.androidsma'
}
if (-not [IO.File]::Exists($nativeLibrary)) {
    throw "Native PowerShell library is missing for $RuntimeIdentifier`: $nativeLibrary"
}
$smaPackageVersion = $PSVersionTable.PSVersion.ToString()
$debugSymbols = $debuggable.ToString().ToLowerInvariant()
$debugType = if ($debuggable) { 'portable' } else { 'none' }

$projectXml = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net11.0-android</TargetFramework>
    <RuntimeIdentifier>$RuntimeIdentifier</RuntimeIdentifier>
    <OutputType>Exe</OutputType>
    <AssemblyName>AndroidSMA.PackagingHost</AssemblyName>
    <ApplicationId>$ApplicationId</ApplicationId>
    <ApplicationVersion>1</ApplicationVersion>
    <ApplicationDisplayVersion>1.0</ApplicationDisplayVersion>
    <SupportedOSPlatformVersion>26</SupportedOSPlatformVersion>
    <PublishTrimmed>false</PublishTrimmed>
    <PublishReadyToRun>false</PublishReadyToRun>
    <EmbedAssembliesIntoApk>true</EmbedAssembliesIntoApk>
    <DebugSymbols>$debugSymbols</DebugSymbols>
    <DebugType>$debugType</DebugType>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <AndroidManifest>$manifestPath</AndroidManifest>
    <BaseIntermediateOutputPath>$(Join-Path $packagingDirectory 'obj\')</BaseIntermediateOutputPath>
    <OutputPath>$apkOutput</OutputPath>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.PowerShell.SDK" Version="$smaPackageVersion">
      <ExcludeAssets>native</ExcludeAssets>
    </PackageReference>
    <Reference Include="AndroidSMA">
      <HintPath>$androidSmaDll</HintPath>
      <Private>true</Private>
    </Reference>
    <AndroidNativeLibrary Include="$nativeLibrary" Link="$androidAbi\libpsl-native.so" />
    <AndroidResource Include="$resourceGlob" Link="Resources\%(RecursiveDir)%(Filename)%(Extension)" />
  </ItemGroup>
</Project>
"@
[IO.File]::WriteAllText($packagingProject, $projectXml, [Text.UTF8Encoding]::new($false))

& dotnet publish $packagingProject -c $Configuration -r $RuntimeIdentifier --no-self-contained
if ($LASTEXITCODE -ne 0) {
    throw "Android packaging failed with exit code $LASTEXITCODE."
}

$signedApk = Get-ChildItem $apkOutput -Recurse -Filter '*-Signed.apk' -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $signedApk) { throw "The Android toolchain did not produce a signed APK beneath $apkOutput" }

"SMA_PACKAGE_VERSION=$smaPackageVersion"
"CONFIGURATION=$Configuration"
"DEBUGGABLE=$debuggable"
"RUNTIME_IDENTIFIER=$RuntimeIdentifier"
"ANDROID_ABI=$androidAbi"
"APPLICATION_ID=$ApplicationId"
'PACKAGING_PROJECT=Disposable'
"APK_EXISTS=$([IO.File]::Exists($signedApk.FullName))"
"APK=$($signedApk.FullName)"
