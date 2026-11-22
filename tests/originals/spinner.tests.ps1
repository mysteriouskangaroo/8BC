param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM spinner (switch 32): its value 10B1 changes with each C-H-A-M-P
# completion up to the 5,000 lamp, and each spin scores the lit value through
# the playfield multiplier, all reached by play.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM"'
$Manual = 'OPS manual p. 1-11 "CHAMP Feature" and p. 1-5 register 49'
$Champ = 'src/originals/ghidra/GAME_RULE_TRACES.md "Playfield Scores Double and Triple"'
# OPS manual p. 1-5: register 49 "Spinner start at", 1 = 1000 points. A fresh
# NVRAM already starts at 1,000 (168D = FF; C524-C535 lights the 1,000 bit when
# 168D bit 20 is set, and storing 0 in register 49 clears that bit, measured),
# so the setting is made explicit through the service menu.
$StartRegister = 49
$StartSetting = 1
# gamerules.md: 10B1's three lamp bits are 1,000, 3,000 and 5,000, changed by
# completing C-H-A-M-P; a completion after the 5,000 lamp keeps it. Manual
# p. 1-11: each completion increases the value, up to a maximum of 5,000.
# Lit value after 0, 1, 2, 3 and 4 completions:
$LitValue = @(1000, 3000, 5000, 5000, 5000)
# GAME_RULE_TRACES "Playfield Scores Double and Triple" (manual p. 1-11:
# "playfield scores double/triple"): 1x, 2x, 3x, 3x, 3x after 0-4 completions.
$Multiplier = @(1, 2, 3, 3, 3)
$ExpectedSpin = @(0..4 | ForEach-Object { $LitValue[$_] * $Multiplier[$_] })   # 1,000, 6,000, 15,000, 15,000, 15,000
$SpinsPerStage = 2

$script:Values = @()   # 10B1 after 0-4 completions
$script:Spins = @()    # each spin's score, $SpinsPerStage per stage

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $StartRegister -Value $StartSetting | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

for ($c = 0; $c -le 4; $c++) {
    if ($c -gt 0) { Complete-EbcChamp | Out-Null }
    $script:Values += '{0:X2}' -f (Read-EbcByte 0x10B1)
    for ($k = 0; $k -lt $SpinsPerStage; $k++) { $script:Spins += Invoke-EbcScoredHit 'Spinner' }
}

Test-EbcItem -Name 'Spinner value 10B1 changes with each C-H-A-M-P completion until the 5,000 lamp, then holds' -Doc $Doc -Body {
    # Three different lit values (start, completion 1, completion 2), then the
    # 5,000 bit kept on completions 3 and 4.
    $v = $script:Values
    Assert-EbcEqual -Expected 3 -Actual @($v[0], $v[1], $v[2] | Select-Object -Unique).Count -What "distinct 10B1 values over completions 0-2 (10B1: $($v -join ', '))"
    Assert-EbcEqual -Expected @($v[2], $v[2]) -Actual @($v[3], $v[4]) -What '10B1 after completions 3 and 4 (the 5,000 lamp kept)'
}
Test-EbcItem -Name 'Each spin scores the lit value through the playfield multiplier' -Doc "$Manual; $Champ" -Body {
    $expected = @($ExpectedSpin | ForEach-Object { for ($k = 0; $k -lt $SpinsPerStage; $k++) { $_ } })
    Assert-EbcEqual -Expected $expected -Actual $script:Spins -What 'spin scores, two per stage, after 0-4 completions'
}
Complete-EbcTests
