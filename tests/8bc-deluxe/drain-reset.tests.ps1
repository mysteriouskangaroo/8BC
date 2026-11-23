param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe drain reset: on the ball after a drain, the collect location,
# spinner value, saucer qualification, CHAMP completion count and playfield
# multiplier start over, while the CHAMP letters and the orbit value follow
# their operator settings. Two one-player games by play, one with both recall
# settings on and one with both off, each set through the service menu.
#
# On the original ROM, register 48 = 0 resets a 30,000 orbit value at the
# next ball and 48 = 1 keeps it: tests/compare/original-vs-deluxe-orbit-recall
# .tests.ps1 plays both settings on both trees.
#
# Ball 1 of each game moves every state away from its start: an orbit collect
# (the location becomes spinner inactive, the orbit value 30,000), a new
# E-I-G-H-T letter (spinner 100 -> 300), three saucer hits (2x, 3x, 5x
# collected, the first 100,000 lit), two CHAMP completions (2x, the right
# thumper upgraded), then the C and H letters. Ball 2 is then read.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Champ = 'src/8bc-deluxe/gamerules.md "CHAMP"'
$Hole = 'src/8bc-deluxe/gamerules.md "Hole / saucer"'
$Spin = 'src/8bc-deluxe/gamerules.md "Spinner"'
$Collect = 'src/8bc-deluxe/gamerules.md "Deluxe collect feature"'
$Left = 'src/8bc-deluxe/gamerules.md "Left orbit"'
$Manual = 'OPS manual p. 1-5 registers 46 and 48, p. 1-11, p. 1-12'

# OPS manual p. 1-5: register 46 "Recall 'CHAMP' lites out", register 48
# "Recall roll up values", 1 = YES, 0 = NO. p. 1-11: 0 re-lites all C-H-A-M-P
# lites turned off on a previous ball, 1 recalls them; p. 1-12: 1 recalls the
# lit roll-up values from ball to ball, 0 turns recall off.
$ChampRegister = 46
$OrbitRegister = 48
# Recall off is played first, so no earlier game's value can carry into it.
$Settings = @(@{ Name = 'recall off'; Value = 0 }, @{ Name = 'recall on'; Value = 1 })
# "Deluxe collect feature": a new ball starts at orbit inactive, and the
# first newly sunk ball activates the orbit. "Spinner": the collect begins at
# the printed 1,000 every ball. "Hole / saucer": bonus progression resets when
# a new ball starts (2x lit, earned 1x). "CHAMP": the completion counter,
# thumper values and multiplier reset at the start of every ball; the stock
# thumper is 1,000 playfield, 100 displayed (champ-lamps.tests.ps1 units).
$SpinnerStart = 1000
$SaucerStart = '2X blinking in phase'
$EarnedStart = 1
$StockThumper = 1000 / 10
# A Rebound scores 10 playfield, 1 displayed, at 1x ("Required gameplay
# verification").
$Rebound = 1
# "Left orbit"/"Right orbit": activation shows the printed 10,000 from the
# baseline; a retained higher value is preserved. Ball 1's right collect
# advances 10,000 by 20,000 ("Right orbit").
$OrbitStart = 10000
$OrbitAfterBall1 = 30000
# The CHAMP letters collected on ball 1 after the completions.
$Ball1Letters = 'CH'
$Unlit = 10
$Letters = @('C', 'H', 'A', 'M', 'P')
$LampSampleFrames = 32

$ArrowValues = @(10000, 20000, 30000, 40000)
$ArrowLamps = @($ArrowValues | ForEach-Object { Get-EbcLampNumber ('Rollover Lanes {0:N0}' -f $_) })
$SpinValues = @(1000, 3000, 5000)
$SpinLamps = @($SpinValues | ForEach-Object { Get-EbcLampNumber ('Spinner {0:N0}' -f $_) })
$Inserts = [ordered]@{}; foreach ($n in '2X', '3X', '5X', '100,000') { $Inserts[$n] = Get-EbcLampNumber "Saucer $n" }
$LetterLamp = @{}; foreach ($l in $Letters) { $LetterLamp[$l] = Get-EbcLampNumber """$l"" Rollover" }

function Get-Lit($Lamps, $Values) { $v = 0; for ($k = 0; $k -lt $Lamps.Count; $k++) { if (Get-EbcLamp -Number $Lamps[$k]) { $v += $Values[$k] } }; $v }
function Get-Inserts {
    $s = [ordered]@{}; foreach ($n in $Inserts.Keys) { $s[$n] = '' }
    for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; foreach ($n in $Inserts.Keys) { $s[$n] += $(if (Get-EbcLamp -Number $Inserts[$n]) { '#' } else { '.' }) } }
    $lit = @($Inserts.Keys | Where-Object { $s[$_].Contains('#') })
    if (-not $lit.Count) { return 'dark' }
    $pats = @($lit | ForEach-Object { $s[$_] } | Select-Object -Unique)
    if ($pats.Count -eq 1 -and $pats[0].Contains('.')) { return "$($lit -join '+') blinking in phase" }
    ($Inserts.Keys | ForEach-Object { "$_ $($s[$_])" }) -join ', '
}
# CHAMP_LANE_STATE (1040 bits 0-4), the authoritative collected letters, and
# the letter lamps, which light the letters still to be collected
# (champ-lamps.tests.ps1).
function Get-LetterState { $b = Read-EbcByte (Get-EbcRamAddress 'CHAMP_LANE_STATE'); (@(for ($k = 0; $k -lt 5; $k++) { if ($b -band (1 -shl $k)) { $Letters[$k] } }) -join '') }
function Get-DarkLetters { Step-EbcFrames -Frames 1; (@($Letters | Where-Object { -not (Get-EbcLamp -Number $LetterLamp[$_]) }) -join '') }
function Get-Multiplier { $c = Get-EbcChampState; if ($c -band 0x20) { 3 } elseif ($c -band 0x10) { 2 } else { 1 } }
function Invoke-Hit([string]$Switch, [string]$After) { $d = if ($After) { Invoke-EbcScoredHit $Switch -AfterSolenoid $After } else { Invoke-EbcScoredHit $Switch }; Step-EbcFrames -Frames 30; $d }

function Invoke-Game([int]$Recall) {
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number $ChampRegister -Value $Recall | Out-Null
    Set-EbcAdjustment -Number $OrbitRegister -Value $Recall | Out-Null
    Exit-EbcServiceMode | Out-Null
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    # ---- Ball 1 ----
    Invoke-Hit 'Drop Target 1,2,9,10' | Out-Null                    # ball 1: orbit active
    $ball1Orbit = Get-Lit $ArrowLamps $ArrowValues
    Invoke-Hit 'Right Rollover Button' | Out-Null                   # 10,000 collected -> 30,000; spinner inactive
    Step-EbcFrames -Frames 300
    Invoke-Hit 'Drop Target "I"' 'Drop Target 1,2,9,10' | Out-Null  # spinner 100 -> 300
    Step-EbcFrames -Frames 300
    foreach ($k in 1..3) { Invoke-Hit 'Saucer' 'Saucer' | Out-Null } # 2x, 3x, 5x; 100,000 lit
    foreach ($k in 1..2) { Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null }
    Invoke-Hit '"C" Return Lane' | Out-Null
    Invoke-Hit '"H" Top Lane' | Out-Null
    $b1 = [PSCustomObject]@{ Orbit = $ball1Orbit; Location = '{0:X2}' -f ((Read-EbcByte 0x10FB) -band 7); Multiplier = Get-Multiplier; Saucer = Get-Inserts; Letters = Get-LetterState }
    # ---- Ball 2 ----
    if ((Invoke-EbcDrain) -ne 'Served') { throw 'the game ended after ball 1' }
    Step-EbcFrames -Frames 120
    $r = [ordered]@{ Ball1 = $b1 }
    $r.Saucer = Get-Inserts
    $r.Earned = [int](Read-EbcByte 0x1149)                         # gamerules.md "Existing rules": $1149, read only
    $r.Letters = Get-LetterState
    $r.DarkLetters = Get-DarkLetters
    $r.Rebound = Invoke-Hit 'Rebound'
    $r.Thumper = Invoke-Hit 'Right Thumper Bumper'
    $r.ChampState = '{0:X2}' -f (Get-EbcChampState)
    $r.Spin = Invoke-Hit 'Spinner'
    Invoke-Hit 'Drop Target 3,11' | Out-Null                        # first newly sunk ball
    $r.Arrows = Get-Lit $ArrowLamps $ArrowValues
    $r.SpinLamps = Get-Lit $SpinLamps $SpinValues
    Invoke-Hit 'Left Rollover Button' | Out-Null                    # spinner inactive
    Step-EbcFrames -Frames 300
    Invoke-Hit 'Drop Target 4,5,12,13' | Out-Null                   # spinner active
    $r.SpinnerShown = Get-Lit $SpinLamps $SpinValues
    Complete-EbcGame | Out-Null
    Step-EbcFrames -Frames 400
    [PSCustomObject]$r
}

Start-EbcGame
$g = @{}
foreach ($s in $Settings) { $g[$s.Name] = Invoke-Game $s.Value }
foreach ($k in $g.Keys) { $x = $g[$k]; Write-Host ("{0}: ball 1 location {1}, {2}x, saucer {3}, letters {4}; ball 2 saucer {5}, earned {6}x, letters '{7}' (dark lamps '{8}'), rebound {9}, thumper {10}, 10C0 {11}, spin {12}, after first sink arrows {13} spinner lamps {14}, spinner activation {15}" -f $k, $x.Ball1.Location, $x.Ball1.Multiplier, $x.Ball1.Saucer, $x.Ball1.Letters, $x.Saucer, $x.Earned, $x.Letters, $x.DarkLetters, $x.Rebound, $x.Thumper, $x.ChampState, $x.Spin, $x.Arrows, $x.SpinLamps, $x.SpinnerShown) }

Test-EbcItem -Name 'Ball 1 moved every state that a drain resets' -Doc 'test setup' -Body {
    $seen = @($g.Keys | Sort-Object | ForEach-Object { $x = $g[$_].Ball1; "$($_): orbit activation $($x.Orbit), location $($x.Location), $($x.Multiplier)x, saucer $($x.Saucer), letters $($x.Letters)" })
    # Location 02 = spinner inactive (src/8bc-deluxe/asm/symbols.inc).
    $want = @('recall off', 'recall on' | ForEach-Object { "$($_): orbit activation $OrbitStart, location 02, 2x, saucer 100,000 blinking in phase, letters $Ball1Letters" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'state at the end of ball 1'
}
Test-EbcItem -Name 'Drain/new-ball resets collect location, spinner value, saucer qualification, CHAMP count, and multiplier' -Doc "$Doc; $Collect; $Spin; $Hole; $Champ" -Body {
    $seen = @($g.Keys | Sort-Object | ForEach-Object { $x = $g[$_]
        "$($_): unlit spin $($x.Spin); first sink lights the orbit $($x.Arrows -gt 0) and not the spinner $($x.SpinLamps -eq 0); spinner activation shows $($x.SpinnerShown); saucer $($x.Saucer), earned $($x.Earned)x; CHAMP state $($x.ChampState), right thumper $($x.Thumper), Rebound $($x.Rebound)" })
    $want = @('recall off', 'recall on' | ForEach-Object {
        "$($_): unlit spin $Unlit; first sink lights the orbit True and not the spinner True; spinner activation shows $SpinnerStart; saucer $SaucerStart, earned ${EarnedStart}x; CHAMP state 00, right thumper $StockThumper, Rebound $Rebound" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'ball 2 after a drain'
}
Test-EbcItem -Name 'The drain respects the operator settings for retained CHAMP letters and orbit value (registers 46 and 48, on and off)' -Doc "$Doc; $Champ; $Left; $Manual" -Body {
    $seen = @($g.Keys | Sort-Object | ForEach-Object { $x = $g[$_]; "$($_): letters '$($x.Letters)', dark letter lamps '$($x.DarkLetters)', orbit activation shows $($x.Arrows)" })
    $want = @("recall off: letters '', dark letter lamps '', orbit activation shows $OrbitStart", "recall on: letters '$Ball1Letters', dark letter lamps '$Ball1Letters', orbit activation shows $OrbitAfterBall1")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'ball 2 letters and orbit value'
}
Complete-EbcTests
