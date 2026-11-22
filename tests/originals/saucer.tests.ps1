param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM saucer (switch 05): the 10C1 progression 01 -> 02 -> 04 -> 08,
# the repeatable 100,000 award through the playfield multiplier at 08, and
# the 8-ball collection once balls 1-7 are sunk (10C3 = 7F), all by play.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM"'
$Champ = 'src/originals/ghidra/GAME_RULE_TRACES.md "Playfield Scores Double and Triple"'
# gamerules.md: 10C1 runs through 2x, 3x and 5x (brief: 01 -> 02 -> 04 -> 08).
# D07F-D089 shifts the low bits and keeps bit 80. At game start C4D4-C4DD
# stores 80 there when NVRAM 168B bit 40 is set (a fresh NVRAM holds FF), and
# CD0D also sets it, so the progression is read through mask 0F.
$Progression = @('01', '02', '04', '08')
$ProgressionMask = 0x0F
# gamerules.md: bit 08 selects the repeatable 100,000 award (C96C), through
# the current playfield multiplier.
$TerminalAward = 100000
# gamerules.md: the 8-ball collection (CEDC) advances the pool-bonus lamps
# through 120K, 240K and 120K+240K and clears 10C3. The first collection
# lights the physical BONUS 120,000 lamp and leaves BONUS 240,000 dark
# (lamp numbers from the manual's lamp driver table; GameNames.psd1 Lamps).
$Lamp120K = Get-EbcLampNumber 'Bonus 120,000'
$Lamp240K = Get-EbcLampNumber 'Bonus 240,000'
# Frames sampled for a lamp's state (covers the 16-frame blink cycle twice).
$LampSampleFrames = 32

# Drop targets for balls 1-7 in sink order; a group re-arms when the
# E-I-G-H-T target behind it is hit (GameNames.psd1 StandupDropGroups).
$Sinks = @(
    @{ Drop = 'Drop Target 1,2,9,10' }, @{ Drop = 'Drop Target 1,2,9,10'; Rearm = $true },
    @{ Drop = 'Drop Target 3,11' }, @{ Drop = 'Drop Target 4,5,12,13' },
    @{ Drop = 'Drop Target 4,5,12,13'; Rearm = $true },
    @{ Drop = 'Drop Target 6,14' }, @{ Drop = 'Drop Target 7,15' })
$standups = (Get-EbcNames).StandupDropGroups
$ResetBy = @{}; foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }

function Get-Progression { '{0:X2}' -f ((Read-EbcByte 0x10C1) -band $ProgressionMask) }
# '<frames lit>/<frames sampled>' for each bonus lamp, e.g. '0/32 0/32'.
function Get-BonusLamps {
    $lit = @(0, 0)
    for ($k = 0; $k -lt $LampSampleFrames; $k++) {
        Step-EbcFrames -Frames 1
        if (Get-EbcLamp -Number $Lamp120K) { $lit[0]++ }
        if (Get-EbcLamp -Number $Lamp240K) { $lit[1]++ }
    }
    '120K {0}/{2} 240K {1}/{2}' -f $lit[0], $lit[1], $LampSampleFrames
}
# The saucer handler ends with the kick (D0B9-D0BD).
function Invoke-Saucer { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' }

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'Saucer progression 10C1 goes 01 -> 02 -> 04 -> 08' -Doc $Doc -Body {
    $seen = @(Get-Progression)
    for ($k = 1; $k -lt $Progression.Count; $k++) { Invoke-Saucer | Out-Null; $seen += Get-Progression }
    Assert-EbcEqual -Expected $Progression -Actual $seen -What '10C1 & 0F on the new ball and after each saucer hit'
}
Test-EbcItem -Name 'At 08 the saucer awards 100,000 through the playfield multiplier' -Doc $Doc -Body {
    $at1x = Invoke-Saucer
    Complete-EbcChamp | Out-Null
    Assert-EbcEqual -Expected '10' -Actual ('{0:X2}' -f (Get-EbcChampState)) -What "10C0 for 2x ($Champ)"
    $at2x = Invoke-Saucer
    Assert-EbcEqual -Expected @($TerminalAward, (2 * $TerminalAward)) -Actual @($at1x, $at2x) -What 'saucer scores at 1x and 2x'
    Assert-EbcEqual -Expected '08' -Actual (Get-Progression) -What '10C1 & 0F after the awards'
}
Test-EbcItem -Name 'With 10C3 = 7F the next saucer hit runs the 8-ball collection' -Doc $Doc -Body {
    foreach ($s in $Sinks) {
        if ($s.Rearm) { Invoke-EbcScoredHit $ResetBy[$s.Drop] -AfterSolenoid $s.Drop | Out-Null }
        Invoke-EbcScoredHit $s.Drop | Out-Null
    }
    Assert-EbcEqual -Expected '7F' -Actual ('{0:X2}' -f (Get-EbcSunkBalls)) -What '10C3 after sinking balls 1-7'
    Assert-EbcEqual -Expected "120K 0/$LampSampleFrames 240K 0/$LampSampleFrames" -Actual (Get-BonusLamps) -What 'bonus lamps lit before the collection'
    Invoke-Saucer | Out-Null
    Assert-EbcEqual -Expected "120K $LampSampleFrames/$LampSampleFrames 240K 0/$LampSampleFrames" -Actual (Get-BonusLamps) -What 'bonus lamps lit after the collection'
    Assert-EbcEqual -Expected '00' -Actual ('{0:X2}' -f (Get-EbcSunkBalls)) -What '10C3 after the collection (new rack)'
}
Complete-EbcTests
