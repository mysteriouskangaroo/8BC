[CmdletBinding()]
param(
    [ValidateRange(600, 36000)]
    [int]$Frames = 1500,
    [switch]$RequireByteIdentical
)

# Builds this tree, then boots the exact eballchp.zip the build packaged in
# libpinmame (headless, unthrottled). Requires PowerShell 7 and the library
# from tools/Get-LibPinmame.ps1.

$ErrorActionPreference = 'Stop'

$asmDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$treeDirectory = Split-Path -Parent $asmDirectory
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $treeDirectory)
$buildDirectory = Join-Path $treeDirectory 'build'
$rebuiltRom = Join-Path $buildDirectory 'u3_cpu.rebuilt.128'
$packagedArchive = Join-Path $repositoryRoot 'VisualPinballX/VPinMAME/roms/eballchp.zip'
$smokeRoot = Join-Path $buildDirectory 'pinmame-smoke'
$romSetDirectory = Join-Path $smokeRoot 'roms'
$testArchive = Join-Path $romSetDirectory 'eballchp.zip'
$reportPath = Join-Path $smokeRoot 'pinmame-boot-test.txt'
$treeName = 'canonical'

. (Join-Path $repositoryRoot 'tools/LibPinmameBoot.ps1')
$libraryPath = & (Join-Path $repositoryRoot 'tools/Get-LibPinmame.ps1')

$buildScript = Join-Path $asmDirectory 'build.ps1'
if ($RequireByteIdentical) {
    & $buildScript -RequireByteIdentical
}
else {
    & $buildScript
}
if (-not (Test-Path -LiteralPath $packagedArchive -PathType Leaf)) {
    throw "The build did not create $packagedArchive"
}

New-Item -ItemType Directory -Path $romSetDirectory -Force | Out-Null
Copy-Item -LiteralPath $packagedArchive -Destination $testArchive -Force

$result = Invoke-EightBallChampBootTest -LibraryPath $libraryPath -VpmPath $smokeRoot -Frames $Frames

$rebuiltHash = (Get-FileHash -Algorithm SHA1 -LiteralPath $rebuiltRom).Hash
$report = @(
    "Eight Ball Champ $treeName PinMAME boot test: $(if ($result.Pass) { 'PASS' } else { 'FAIL' })"
    "Result: $($result.Reason)"
    "Frames emulated: $($result.Frames)"
    "Display events: $($result.DisplayEvents); lamp events: $($result.LampEvents); solenoid events: $($result.SolenoidEvents); sound commands: $($result.SoundEvents)"
    "Stack 00FC-00FF at last frame: $($result.Stack00FC)"
    "U4 RAM bytes written: $($result.U4WrittenBytes)"
    "Event digest (SHA-256): $($result.Digest)"
    "ROM SHA-1: $rebuiltHash"
    "Packaged ROM set: $packagedArchive"
    "Isolated ROM set: $testArchive"
    "libpinmame: $libraryPath"
    'Scope: the ROM booted past the startup checksum and drove the displays; game rules and physical outputs are untested.'
)
$report | Set-Content -LiteralPath $reportPath -Encoding ascii
$report
if (-not $result.Pass) { exit 1 }
