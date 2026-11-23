[CmdletBinding()]
param(
    # Test hook only: replaces the pinned SHA-256 to prove a mismatch is refused.
    [string]$ExpectedSha256Override
)

# Downloads the pinned DASM 2.20.14.1 release for this OS into the repository
# root, where the src/*/asm/build.ps1 scripts expect it. The release publishes
# no digests; these SHA-256 values were recorded from it on 2026-11-21.

$ErrorActionPreference = 'Stop'

$version = '2.20.14.1'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Windows PowerShell 5.1 has no $IsWindows; treat it as Windows.
if ($IsMacOS) {
    $platform = 'osx-x64'; $asset = "dasm-$version-osx-x64.tar.gz"
    $sha256 = '58EBB7FAC917CA0884FE97DC07C2BDE6A0247962902B98A8C993C410B6F67340'
}
elseif ($IsLinux) {
    $platform = 'linux-x64'; $asset = "dasm-$version-linux-x64.tar.gz"
    $sha256 = 'C2546D7A3A5C06F2642C8303CE5FB3E747493700F0C14A5B6C14E7719183B262'
}
else {
    $platform = 'win-x64'; $asset = "dasm-$version-win-x64.zip"
    $sha256 = 'C6EDDBF66D451C2C924DD7609DAFFC647E9D302426B00082B7417811BBC172F3'
}
if ($ExpectedSha256Override) { $sha256 = $ExpectedSha256Override.ToUpperInvariant() }

$targetDirectory = Join-Path $repositoryRoot "dasm-$version-$platform"
$binaryName = if ($IsMacOS -or $IsLinux) { 'dasm' } else { 'dasm.exe' }
$binary = Join-Path $targetDirectory $binaryName

function Test-DasmBinary {
    $banner = & $binary 2>&1 | Select-Object -First 1
    if ("$banner" -ne "DASM $version") {
        throw "$binary reports '$banner'; expected 'DASM $version'."
    }
}

if (Test-Path -LiteralPath $binary -PathType Leaf) {
    Test-DasmBinary
    $binary
    return
}

$download = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '-' + $asset)
$url = "https://github.com/dasm-assembler/dasm/releases/download/$version/$asset"
$previousProgress = $ProgressPreference
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile $download -UseBasicParsing
    $ProgressPreference = $previousProgress

    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash
    if ($actual -ne $sha256) {
        throw "$asset SHA-256 is $actual; expected $sha256. Refusing to unpack."
    }

    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    if ($asset.EndsWith('.zip')) {
        Expand-Archive -LiteralPath $download -DestinationPath $targetDirectory -Force
    }
    else {
        & tar -xzf $download -C $targetDirectory
        if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
        & chmod +x $binary
    }
}
finally {
    $ProgressPreference = $previousProgress
    if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
}

Test-DasmBinary
$binary
