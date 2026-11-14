[CmdletBinding()]
param(
    [ValidateRange(60, 36000)]
    [int]$Frames = 600,
    [switch]$RequireByteIdentical
)

$ErrorActionPreference = 'Stop'

$asmDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$originalsDirectory = Split-Path -Parent $asmDirectory
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $originalsDirectory)
$buildDirectory = Join-Path $originalsDirectory 'build'
$rebuiltRom = Join-Path $buildDirectory 'u3_cpu.rebuilt.128'
$pinmame = Join-Path $repositoryRoot 'pinmame\pinmame.exe'
$packagedArchive = Join-Path $repositoryRoot 'VisualPinballX\VPinMAME\roms\eballchp.zip'
$smokeRoot = Join-Path $buildDirectory 'pinmame-smoke'
$romSetDirectory = Join-Path $smokeRoot 'roms'
$testArchive = Join-Path $romSetDirectory 'eballchp.zip'
$cfgDirectory = Join-Path $smokeRoot 'cfg'
$nvramDirectory = Join-Path $smokeRoot 'nvram'
$snapshotDirectory = Join-Path $smokeRoot 'snap'
$waveDirectory = Join-Path $smokeRoot 'wave'
$reportPath = Join-Path $smokeRoot 'pinmame-smoke-test.txt'

if (-not (Test-Path -LiteralPath $pinmame -PathType Leaf)) {
    throw "PinMAME was not found at $pinmame"
}
$buildScript = Join-Path $asmDirectory 'build.ps1'
if ($RequireByteIdentical) {
    & $buildScript -RequireByteIdentical
}
else {
    & $buildScript
}
if ($LASTEXITCODE -ne 0) { throw "Canonical ROM build failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $packagedArchive -PathType Leaf)) {
    throw "The build did not create $packagedArchive"
}

foreach ($directory in @($romSetDirectory, $cfgDirectory, $nvramDirectory,
        $snapshotDirectory, $waveDirectory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

Copy-Item -LiteralPath $packagedArchive -Destination $testArchive -Force

$pinmameArguments = @(
    'eballchp'
    '-rompath', $romSetDirectory
    '-cfg_directory', $cfgDirectory
    '-nvram_directory', $nvramDirectory
    '-snapshot_directory', $snapshotDirectory
    '-wave_directory', $waveDirectory
    '-noreadconfig'
    '-window'
    '-noddraw'
    '-nodirect3d'
    '-nosound'
    '-noartwork'
    '-nothrottle'
    '-skip_disclaimer'
    '-skip_gameinfo'
    '-frames_to_run', $Frames.ToString()
)

& $pinmame @pinmameArguments
$pinmameExitCode = $LASTEXITCODE
if ($pinmameExitCode -ne 0) {
    throw "PinMAME smoke test failed with exit code $pinmameExitCode"
}

$rebuiltHash = (Get-FileHash -Algorithm SHA1 -LiteralPath $rebuiltRom).Hash
$report = @(
    'Eight Ball Champ loop-score-change PinMAME smoke test: PASS'
    "Frames executed: $Frames"
    "ROM SHA-1: $rebuiltHash"
    "PinMAME exit code: $pinmameExitCode"
    "Packaged ROM set: $packagedArchive"
    "Isolated ROM set: $testArchive"
    'Scope: load, reset, and sustained emulation only; interactive rule and service tests remain required.'
)
$report | Set-Content -LiteralPath $reportPath -Encoding ascii
$report
