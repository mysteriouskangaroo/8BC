param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM switch-to-coil links: in play, switches 01-05 each fire their
# own coil, and only that coil, by play.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/originals/ghidra/HARDWARE_MAP.md "Page 1-18 switch assembly identification" and "Solenoid self-test outputs"'
# Page 1-18 switch 01-05 -> the page 1-18 coil of the same name.
$Coils = [ordered]@{
    'Right Thumper Bumper' = 'Right Thumper Bumper'
    'Left Thumper Bumper'  = 'Left Thumper Bumper'
    'Right Slingshot'      = 'Right Slingshot'
    'Left Slingshot'       = 'Left Slingshot'
    'Saucer'               = 'Saucer'
}
# Frames watched after each hit (measured: the saucer kick comes about 34
# frames after its switch, the others within 2).
$WatchFrames = 600

$byNumber = @{}; foreach ($n in (Get-EbcNames).Solenoids.Keys) { $byNumber[(Get-EbcSolenoid $n)] = $n }

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

foreach ($sw in $Coils.Keys) {
    Test-EbcItem -Name ("Switch {0:D2} {1} fires the {2} coil" -f (Get-EbcSwitch $sw), $sw, $Coils[$sw]) -Doc $Doc -Body {
        $seen = Get-EbcEventCount
        Invoke-EbcSwitchHit $sw
        Step-EbcFrames -Frames $WatchFrames
        $fired = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match '^\d+ sol (\d+) 1$' } | ForEach-Object {
            $n = [int](($_ -split ' ')[2]); if ($byNumber.ContainsKey($n)) { $byNumber[$n] } else { "solenoid $n" } })
        Assert-EbcEqual -Expected @($Coils[$sw]) -Actual $fired -What "coils pulsed within $WatchFrames frames of the '$sw' hit"
    }
}
Complete-EbcTests
