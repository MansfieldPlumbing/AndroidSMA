param(
    [string]$NdkRoot = 'N:\bin\ndk'
)

$ErrorActionPreference = 'Stop'

$ExpectedSha256 =
    '4605293D2EAD6D06CF39C45534C5928B8F40DB3AB2A80B415F7FE36C56961A32'

$Clang = Join-Path $NdkRoot `
    'toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android34-clang.cmd'

$Source = Join-Path $PSScriptRoot 'libc.null.c'
$NativeRoot = Split-Path $PSScriptRoot -Parent
$OutputDir = Join-Path $NativeRoot 'arm64-v8a'
$Output = Join-Path $OutputDir 'libpsl-android.so'
$Candidate = Join-Path $env:TEMP 'libpsl-android.rebuild.so'

if (-not (Test-Path $Clang)) {
    throw "Android clang not found: $Clang"
}

New-Item -ItemType Directory -Force $OutputDir | Out-Null
Remove-Item $Candidate -Force -ErrorAction SilentlyContinue

& $Clang `
    -O0 `
    -fPIC `
    -shared `
    $Source `
    '-Wl,-z,max-page-size=16384' `
    -o $Candidate

if ($LASTEXITCODE -ne 0) {
    throw "clang failed with exit code $LASTEXITCODE"
}

$Actual = (Get-FileHash $Candidate -Algorithm SHA256).Hash

if ($Actual -ne $ExpectedSha256) {
    throw @"
libpsl-android.so reproducibility failure.

Expected: $ExpectedSha256
Actual:   $Actual

The generated binary was NOT promoted.
"@
}

Copy-Item $Candidate $Output -Force

$Item = Get-Item $Output

[pscustomobject]@{
    Status = 'PASS'
    Length = $Item.Length
    SHA256 = $Actual
    Output = $Output
}