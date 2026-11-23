param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM orbit rollovers (switches 12 and 13): unlit 5,000, lit values
# advancing by 10,000 and shared by both sides, and the orbit special lit at
# 100,000.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM"'
# gamerules.md: the unlit/default orbit score is 5,000 (C9EF); the lit value
# advances by 10,000; at 100,000 the special lights.
$Unlit = 5000
$Step = 10000
$SpecialAt = 100000
# OPS manual p. 1-5 register 51, "Roll up lanes spcl flash with": 0 = 100K.
# A fresh NVRAM holds FF there (16A0, adjustment table entry at C129), which
# selects no value, so the operator sets it through the service menu.
$SpecialRegister = 51
$SpecialSetting = 0
# Special lit: CC0C-CC22 sets 10C2 bit 10 when the orbit value reaches the
# register 51 value; CBB2-CBC6 collects it (audit 16C6, award C1D6).
$SpecialLitAddress = 0x10C2
$SpecialLitMask = 0x10

$Left = 'Left Rollover Button'
$Right = 'Right Rollover Button'

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $SpecialRegister -Value $SpecialSetting | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit -Count 2 | Out-Null
Start-EbcPlay -Players 2 | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'Unlit switches 12 and 13 score 5,000' -Doc $Doc -Body {
    # Player 1 takes the left orbit unlit, player 2 the right one.
    $p1 = Invoke-EbcScoredHit $Left
    Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'drain to player 2'
    Step-EbcFrames -Frames 120
    Assert-EbcEqual -Expected 2 -Actual (Get-EbcCurrentPlayer) -What 'current player'
    $p2 = Invoke-EbcScoredHit $Right
    Assert-EbcEqual -Expected @($Unlit, $Unlit) -Actual @($p1, $p2) -What 'unlit left (player 1) and right (player 2)'
}
Test-EbcItem -Name 'Lit values advance by 10,000 and stay synchronized left and right' -Doc $Doc -Body {
    # Player 2's right orbit was the unlit hit; alternate sides from here.
    $deltas = @(); $sides = @()
    for ($k = 1; $k -le 9; $k++) {
        $side = if ($k % 2) { $Left } else { $Right }
        $sides += $side; $deltas += Invoke-EbcScoredHit $side
    }
    Assert-EbcEqual -Expected @(1..9 | ForEach-Object { $_ * $Step }) -Actual $deltas -What "scores on alternating sides ($(($sides | ForEach-Object { ($_ -split ' ')[0] }) -join ', '))"
}
Test-EbcItem -Name 'At 100,000 an orbit special lights' -Doc $Doc -Body {
    # The last hit scored 90,000 and advanced the value to 100,000.
    $lit = (Read-EbcByte $SpecialLitAddress) -band $SpecialLitMask
    Assert-EbcEqual -Expected ('{0:X2}' -f $SpecialLitMask) -Actual ('{0:X2}' -f $lit) -What "special-lit bit of 10C2 with the value at $SpecialAt"
    Assert-EbcEqual -Expected $SpecialAt -Actual (Invoke-EbcScoredHit $Left) -What 'next orbit score (the lit value)'
}
Complete-EbcTests
