param([string]$Tree, [string]$VpmZip, [string]$ObserveTo,
      [string]$ChildMode, [string]$MachineDirectory, [string]$ResultPath,
      [int]$Setting)
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

# Separate processes are required: libpinmame permits one boot per process.
# Reuse only the private NVRAM directory and the exact source-built archive.
if ($ChildMode) {
    $library = & (Join-Path $PSScriptRoot '../../tools/Get-LibPinmame.ps1')
    Start-EbcMachine -LibraryPath $library -VpmPath $MachineDirectory -PreserveNvram
    try {
        Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $true
        Step-EbcFrames -Frames 1500
        Enter-EbcServiceMode | Out-Null
        if ($ChildMode -eq 'write') {
            Set-EbcAdjustment -Number 52 -Value $Setting | Out-Null
        } else {
            Invoke-EbcKey '5'; Invoke-EbcKey '2'; Invoke-EbcKey 'Enter'
            Step-EbcFrames -Frames 60
        }
        $display = [int](Get-EbcDisplayText (Get-EbcNames).Displays.Player1)
        Exit-EbcServiceMode | Out-Null
        $bytes = Read-EbcRam -Address 0x168E -Count 2
        [PSCustomObject]@{
            Display = $display
            Stored = (($bytes[0] -shr 4) -bor ($bytes[1] -band 0xF0))
        } | ConvertTo-Json | Set-Content -LiteralPath $ResultPath
    }
    finally { Stop-EbcMachine }
    exit 0
}

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$root = [IO.Path]::GetFullPath((Join-Path $repo 'build/game-tests'))
$work = [IO.Path]::GetFullPath((Join-Path $root ('spinner-nvram-' + [guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path (Join-Path $work 'roms') -Force | Out-Null
Copy-Item -LiteralPath $VpmZip -Destination (Join-Path $work 'roms/eballchp.zip')
$pwsh = (Get-Process -Id $PID).Path
try {
    foreach ($value in @(30, 60, 0)) {
        Test-EbcItem -Name "Register 52 = $value persists across a complete emulator power cycle" -Doc 'src/8bc-deluxe/gamerules.md "Spinner", register 52' -Body {
            foreach ($mode in @('write', 'read')) {
                $result = Join-Path $work "$mode.json"
                & $pwsh -NoProfile -File $PSCommandPath -ChildMode $mode -MachineDirectory $work -ResultPath $result -Setting $value
                if ($LASTEXITCODE -ne 0) { throw "$mode process failed with exit $LASTEXITCODE" }
                $observation = Get-Content -LiteralPath $result -Raw | ConvertFrom-Json
                Assert-EbcEqual -Expected $value -Actual $observation.Display -What "$mode service display"
                Assert-EbcEqual -Expected $value -Actual $observation.Stored -What "$mode NVRAM value"
            }
        }
    }
}
finally {
    if (-not $work.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing to delete test directory outside build/game-tests.'
    }
    Remove-Item -LiteralPath $work -Recurse -Force
}
Complete-EbcTests
