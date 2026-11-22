param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# loop-score-change orbit rollovers (switches 12 and 13): lamp-level index 1,
# the state of a new ball, still scores 5,000; normal indices 2-11 score
# 1,000 through 10,000, shared by both sides, all by play.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/loop-score-change/notes/SCORING_CHANGES.md "Left and right rollover buttons"'
# SCORING_CHANGES.md: index 1 retains the original table's 5,000-point
# fallback through C9EF.
$IndexOneScore = 5000
# SCORING_CHANGES.md: CC32 subtracts one from normal indices 2-11 and passes
# 1-10 to the thousand-point helper C9F9, producing 1,000 through 10,000.
$NormalIndices = 2..11
$NormalScores = @(1..10 | ForEach-Object { $_ * 1000 })

# Which game state index 1 is (src/loop-score-change/asm/modules/
# 20_scoring_and_switch_rules.asm): CB93-CBA5 load the rollover lamp nibble,
# 1044 OR F0, and count B from 1 along the masks at CC26 (FF, FE, FD, FB, F7,
# F6, F5, F3, F2, F1, F0) until one matches; AWARD_ROLLOVER_BUTTON_SCORE (CBA6)
# passes B to ROLLOVER_SCORE_BY_LEVEL (CC32). So index 1 is 1044 low nibble F,
# no rollover value lamp lit, and CBDF-CBFE then move 1044 to the next mask.
# A new ball holds F there (checked below), so index 1 is each ball's first,
# unlit rollover hit.
$LampAddress = 0x1044
$Masks = @(0xFF, 0xFE, 0xFD, 0xFB, 0xF7, 0xF6, 0xF5, 0xF3, 0xF2, 0xF1, 0xF0)
# OPS manual p. 1-5 register 51 = 0 (100K special), set through the service
# menu as in tests/originals/rollovers.tests.ps1: a fresh NVRAM holds FF in
# 16A0, which the special-lighting code at CBFF-CC22 never matches.
$SpecialRegister = 51
$SpecialSetting = 0

$Left = 'Left Rollover Button'
$Right = 'Right Rollover Button'

function Get-RolloverIndex { [array]::IndexOf($Masks, [int]((Read-EbcByte $LampAddress) -bor 0xF0)) + 1 }

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $SpecialRegister -Value $SpecialSetting | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit -Count 2 | Out-Null
Start-EbcPlay -Players 2 | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'Index 1 (a new ball, no rollover lamp lit) scores 5,000 on switches 12 and 13' -Doc $Doc -Body {
    # Player 1 takes the left orbit at index 1, player 2 the right one.
    $i1 = Get-RolloverIndex
    $p1 = Invoke-EbcScoredHit $Left
    Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'drain to player 2'
    Step-EbcFrames -Frames 120
    Assert-EbcEqual -Expected 2 -Actual (Get-EbcCurrentPlayer) -What 'current player'
    $i2 = Get-RolloverIndex
    $p2 = Invoke-EbcScoredHit $Right
    Assert-EbcEqual -Expected @(1, 1) -Actual @($i1, $i2) -What 'lamp-level index (1044 | F0 against CC26) on each new ball'
    Assert-EbcEqual -Expected @($IndexOneScore, $IndexOneScore) -Actual @($p1, $p2) -What 'index 1 left (player 1) and right (player 2)'
}
Test-EbcItem -Name 'Normal indices 2-11 score 1,000 through 10,000 on alternating sides' -Doc $Doc -Body {
    # Player 2's right orbit was the index-1 hit; alternate sides from here.
    $indices = @(); $deltas = @(); $sides = @()
    for ($k = 1; $k -le $NormalScores.Count; $k++) {
        $side = if ($k % 2) { $Left } else { $Right }
        $sides += ($side -split ' ')[0]; $indices += Get-RolloverIndex; $deltas += Invoke-EbcScoredHit $side
    }
    Assert-EbcEqual -Expected @($NormalIndices) -Actual $indices -What 'lamp-level index before each hit'
    Assert-EbcEqual -Expected $NormalScores -Actual $deltas -What "scores on alternating sides ($($sides -join ', '))"
}
Complete-EbcTests
