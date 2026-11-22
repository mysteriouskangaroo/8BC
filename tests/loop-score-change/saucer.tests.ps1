param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# loop-score-change saucer (switch 05): the ordinary 500-point saucer score and
# the 10C1 progression 01 -> 02 -> 04 -> 08 are unchanged, and at 08 the
# fully lit saucer awards 10,000 through the playfield multiplier, all by play.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/loop-score-change/notes/SCORING_CHANGES.md "Fully lit saucer"'
$Champ = 'src/originals/ghidra/GAME_RULE_TRACES.md "Playfield Scores Double and Triple"'
# SCORING_CHANGES.md: the ordinary saucer branch (D07A) scores 500 and is
# unchanged; scored here on a new ball at 1x.
$Ordinary = 500
# SCORING_CHANGES.md: the 01 -> 02 -> 04 -> 08 progression through the 2x, 3x
# and 5x lamps is unchanged (D07A-D089 shift the low bits). At game start
# C4D4-C4DD store 80 in 10C1 when NVRAM 168B bit 40 is set (a fresh NVRAM
# holds FF), so the progression is read through mask 0F.
$Progression = @('01', '02', '04', '08')
$ProgressionMask = 0x0F
# SCORING_CHANGES.md: with 10C1 bit 08 set, the call at D070 targets C9A4,
# the 10,000-point multiplier-aware helper: 10,000, 20,000, 30,000 at 1x, 2x, 3x.
$TerminalAward = 10000
$Multipliers = @(1, 2, 3)
# 10C0 for double and triple (GAME_RULE_TRACES.md table; tests/originals/champ).
$ChampStates = @('10', '20')

function Get-Progression { '{0:X2}' -f ((Read-EbcByte 0x10C1) -band $ProgressionMask) }
# The saucer handler ends with the kick (D0B9-D0BD).
function Invoke-Saucer { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' }

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'Ordinary saucer hits score 500 while 10C1 goes 01 -> 02 -> 04 -> 08' -Doc $Doc -Body {
    $seen = @(Get-Progression); $scores = @()
    for ($k = 1; $k -lt $Progression.Count; $k++) { $scores += Invoke-Saucer; $seen += Get-Progression }
    Assert-EbcEqual -Expected $Progression -Actual $seen -What '10C1 & 0F on the new ball and after each saucer hit'
    Assert-EbcEqual -Expected @(1..($Progression.Count - 1) | ForEach-Object { $Ordinary }) -Actual $scores -What 'ordinary saucer scores at 1x'
}
Test-EbcItem -Name 'At 08 the saucer awards 10,000, 20,000 and 30,000 at 1x, 2x and 3x' -Doc $Doc -Body {
    $scores = @(Invoke-Saucer)
    for ($k = 0; $k -lt $ChampStates.Count; $k++) {
        Complete-EbcChamp | Out-Null
        Assert-EbcEqual -Expected $ChampStates[$k] -Actual ('{0:X2}' -f (Get-EbcChampState)) -What "10C0 for $($Multipliers[$k + 1])x ($Champ)"
        $scores += Invoke-Saucer
    }
    Assert-EbcEqual -Expected @($Multipliers | ForEach-Object { $TerminalAward * $_ }) -Actual $scores -What 'fully lit saucer scores at 1x, 2x and 3x'
    Assert-EbcEqual -Expected '08' -Actual (Get-Progression) -What '10C1 & 0F after the awards'
}
Complete-EbcTests
