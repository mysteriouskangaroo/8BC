param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Service-mode helpers: keypad entry of an operator adjustment, the way the
# manual describes it (docs/Eight_Ball_Champ_OPS.pdf pages 1-3 and 1-4).
# Usage: pwsh tests/kit/service.tests.ps1 -Tree originals -VpmZip src/originals/build/game-tests/eballchp.zip
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

# Manual p. 1-3: a fresh NVRAM resets balls per game (REGISTER 23) to 3.
# Manual p. 1-4: "the feature is located in REGISTER 23".
$Doc = 'OPS manual p. 1-3/1-4, REGISTER 23 balls per game'
$BallsRegister = 23
$FactoryBalls = 3
$NewBalls = 5
# Presses this schedule needs (measured): the first self-test press at frame
# 1500 enters keypad mode; keying 2, 3, Enter, 5, Enter is 5 key presses; one
# Cancel leaves.
$ExpectedEntryPresses = 1
$ExpectedKeyPresses = 5
$ExpectedExitPresses = 1

function Get-BallsSetting { (Read-EbcByte (Get-EbcRamAddress 'BallsPerGame')) -shr 4 }

Start-EbcGame
Test-EbcItem -Name 'Set-EbcAdjustment changes a setting' -Doc $Doc -Body {
    Assert-EbcEqual -Expected $FactoryBalls -Actual (Get-BallsSetting) -What 'balls-per-game byte before (fresh NVRAM)'
    Assert-EbcEqual -Expected $ExpectedEntryPresses -Actual (Enter-EbcServiceMode) -What 'self-test presses to reach keypad mode'
    Assert-EbcEqual -Expected $ExpectedKeyPresses -Actual (Set-EbcAdjustment -Number $BallsRegister -Value $NewBalls) -What 'key presses to set register 23'
    Assert-EbcEqual -Expected $NewBalls -Actual (Get-BallsSetting) -What 'balls-per-game byte after Set-EbcAdjustment'
    Assert-EbcEqual -Expected $ExpectedExitPresses -Actual (Exit-EbcServiceMode) -What 'Cancel presses to leave service mode'

    Assert-EbcEqual -Expected 1 -Actual (Add-EbcCredit) -What 'credits after one coin'
    $null = Start-EbcPlay
    $balls = Complete-EbcGame
    Assert-EbcEqual -Expected $NewBalls -Actual $balls -What 'balls in a one-player game'
}
Complete-EbcTests
