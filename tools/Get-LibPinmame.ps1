[CmdletBinding()]
param(
    # Test hook only: replaces the pinned SHA-256 to prove a mismatch is refused.
    [string]$ExpectedSha256Override
)

# Downloads the pinned libpinmame release for this OS and process architecture
# into <repo>/libpinmame-3.7.0-477/ and prints the full library path. The
# SHA-256 values are the digests GitHub publishes for the release assets.

$ErrorActionPreference = 'Stop'

$tag = 'v3.7.0-477-6589fc5'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$targetDirectory = Join-Path $repositoryRoot 'libpinmame-3.7.0-477'
$architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()

# Windows PowerShell 5.1 has no $IsWindows; treat it as Windows.
if ($IsMacOS -and $architecture -eq 'Arm64') {
    $asset = 'libpinmame-3.7.0-477-6589fc5-macos-arm64.tar.gz'; $library = 'libpinmame.3.7.0.dylib'
    $sha256 = 'BA517D624FFC526A5181B55DB1CD0DF06C63BA15B7B5D4388CCBF28B2437F598'
}
elseif ($IsMacOS -and $architecture -eq 'X64') {
    $asset = 'libpinmame-3.7.0-477-6589fc5-macos-x64.tar.gz'; $library = 'libpinmame.3.7.0.dylib'
    $sha256 = 'BD32AC08FBDCD2EC447F454A4B8B0A841BFD4A6FD62E9FBA9707B9940713A375'
}
elseif ($IsLinux -and $architecture -eq 'X64') {
    $asset = 'libpinmame-3.7.0-477-6589fc5-linux-x64.tar.gz'; $library = 'libpinmame.so.3.7.0'
    $sha256 = '5E09B42CF26BAFEA29851589EC427A6A166D569F53408C8F7E9CF93A683831CD'
}
elseif (-not $IsMacOS -and -not $IsLinux -and $architecture -eq 'X64') {
    $asset = 'libpinmame-3.7.0-477-6589fc5-win-x64.zip'; $library = 'pinmame64.dll'
    $sha256 = 'A0D6D3672CBDDEDF4A32DFFC99AE3157FB6AFDAEEC8ED2A92D4A2721206F14D3'
}
else {
    throw "No pinned libpinmame build for this OS with a $architecture process."
}
if ($ExpectedSha256Override) { $sha256 = $ExpectedSha256Override.ToUpperInvariant() }

$libraryPath = Join-Path $targetDirectory $library
if (Test-Path -LiteralPath $libraryPath -PathType Leaf) {
    $libraryPath
    return
}

$download = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '-' + $asset)
$url = "https://github.com/vpinball/pinmame/releases/download/$tag/$asset"
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
    }
}
finally {
    $ProgressPreference = $previousProgress
    if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
}

if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) {
    throw "$asset did not contain $library."
}
$libraryPath
