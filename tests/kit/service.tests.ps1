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
$SecondRegister = 50
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
# Manual p. 1-4: a stored register stays selected for corrections; p. 1-3:
# Clear (KEYBD/CLR) shows 00, ready for another register number.
Test-EbcItem -Name 'Set-EbcAdjustment sets two registers in one session' -Doc $Doc -Body {
    Enter-EbcServiceMode | Out-Null
    Assert-EbcEqual -Expected $ExpectedKeyPresses -Actual (Set-EbcAdjustment -Number $BallsRegister -Value $FactoryBalls) -What 'key presses for register 23 (status 00)'
    # Register 50 = 1 keeps the Squawk & Talk board selected (manual p. 1-10;
    # a fresh NVRAM already has it). Clear, 5, 0, Enter, 1, Enter.
    Assert-EbcEqual -Expected ($ExpectedKeyPresses + 1) -Actual (Set-EbcAdjustment -Number $SecondRegister -Value 1) -What 'key presses for register 50 (Clear first)'
    Assert-EbcEqual -Expected $FactoryBalls -Actual (Get-BallsSetting) -What 'balls-per-game byte after both entries'
    Exit-EbcServiceMode | Out-Null
}
# Manual p. 1-3: the register number's digits appear in the Match/Credit
# display as they are pressed. After Clear (00), each digit d shows 0d.
Test-EbcItem -Name 'Every digit key reaches the keypad' -Doc 'OPS manual p. 1-3 KEYBOARD ENTRY; tools/GameNames.psd1 ServiceKeys' -Body {
    Enter-EbcServiceMode | Out-Null
    $seen = @(foreach ($d in 0..9) {
        Invoke-EbcKey 'Clear'; Step-EbcFrames -Frames 60
        Invoke-EbcKey ([string]$d); Step-EbcFrames -Frames 30
        "key ${d}: $(Get-EbcStatusText)" })
    Assert-EbcEqual -Expected @(0..9 | ForEach-Object { "key ${_}: 0$_" }) -Actual $seen -What 'Match/Credit display after Clear and one digit'
    Invoke-EbcKey 'Clear'; Step-EbcFrames -Frames 60
    Exit-EbcServiceMode | Out-Null
}
Complete-EbcTests
