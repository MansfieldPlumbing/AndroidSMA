param(
    [string]$AndroidSdkDirectory = 'C:\Users\Scott\AndroidSdk',
    [string]$JavaSdkDirectory = 'C:\bin\jdk'
)

$ErrorActionPreference = 'Stop'
$experimentDirectory = $PSScriptRoot
$project = Join-Path $experimentDirectory 'AndroidSMA.experimental.csproj'
$result = Join-Path $experimentDirectory 'RETEST-RESULT.txt'

$env:LIB = ''
dotnet build $project -c Debug `
    -p:JavaSdkDirectory=$JavaSdkDirectory `
    -p:AndroidSdkDirectory=$AndroidSdkDirectory

$apk = Get-ChildItem (Join-Path $experimentDirectory 'bin') -Recurse `
    -Filter '*Signed.apk' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $apk) {
    throw 'Signed experimental APK not found.'
}

adb install -r $apk.FullName
$listing = adb shell cmd app_function list-app-functions
$matches = $listing | Select-String `
    -Pattern 'dev\.mansfieldplumbing\.androidsma|stageProfileRepair' `
    -Context 2,10

@(
    'AppFunctions PROFILE.PS1 repair retest'
    'Timestamp: ' + [DateTimeOffset]::UtcNow.ToString('O')
    'Device: ' + (adb shell getprop ro.product.model)
    'API: ' + (adb shell getprop ro.build.version.sdk)
    ''
    if ($matches) { $matches | Out-String } else { 'NOT INDEXED' }
) | Set-Content -LiteralPath $result -Encoding utf8

Get-Content -LiteralPath $result
if (-not $matches) {
    throw 'Android did not index stageProfileRepair. Stop.'
}

Write-Host 'INDEXED. Proceed manually with ADB invocation, APPLY/REJECT, and retail Gemini discovery.'
