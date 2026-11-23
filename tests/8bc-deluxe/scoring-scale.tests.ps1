param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe score scale: manual/playfield awards score one tenth, the ones digit
# carries, and the replay, extra-ball and High Score to Date settings are
# entered at one tenth through the service-mode keypad and award at those
# scores, all by play.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Deluxe score scale"; "Required gameplay verification"'
$Settings = 'src/8bc-deluxe/gamerules.md "Startup speech" (threshold table); "Required gameplay verification"'
$Manual = 'OPS manual p. 1-5 register table, p. 1-9 "High score feature; register 24", p. 1-10 "High score to date ... register 26", "High score feature adjustments; register 12,13 & 14"'

# gamerules.md "Required gameplay verification": a manual/playfield 10-point
# Rebound scores 1, a 500-point target scores 50, a 3,000-point CHAMP lane
# scores 300, and a combined 4,500-point award path scores 450 (10 / 10,
# 500 / 10, 3,000 / 10, 4,500 / 10).
$Rebound = 10 / 10
$Target500 = 500 / 10
$ChampLane = 3000 / 10
$Combined = 4500 / 10
# The "500-point target": gamerules.md "Left orbit" names "the playfield's
# 500-point center rollover" (switch 29), the one 500-point playfield award
# the doc identifies. (OPS manual p. 1-11 values the pool-table drop targets
# at 500, but gamerules.md "Existing rules" makes their first sink 2,500.)
$Target500Switch = 'Center Rollover Button'
# The doc gives no single 4,500-point switch; this path combines three
# playfield awards it names, hit back to back so their pending scores add
# together: a CHAMP lane (3,000), a stock thumper (1,000; gamerules.md "CHAMP":
# "raise ... from 1,000") and the center rollover (500). 3,000 + 1,000 + 500
# = 4,500.
$CombinedPath = @('"M" Top Lane', 'Left Thumper Bumper', 'Center Rollover Button')
# Ones-digit carries: 9 -> 10, 99 -> 100, 999 -> 1,000.
$Carries = @(9, 99, 999)
# Stock thumper, displayed: 1,000 / 10.
$Thumper = 1000 / 10

# gamerules.md threshold table, 3-ball column and extra-ball row, at one tenth:
# 1,500,000 / 10, 3,000,000 / 10, 4,000,000 / 10, 2,000,000 / 10,
# 3,700,000 / 10. Registers 12-14 are the thresholds and 15 the High Score to
# Date (gamerules.md; manual p. 1-5).
$FirstReplay = 1500000 / 10
$SecondReplay = 3000000 / 10
$HighScoreToDate = 4000000 / 10
$FirstExtraBall = 2000000 / 10
$SecondExtraBall = 3700000 / 10
$Threshold1 = 12; $Threshold2 = 13; $Threshold3 = 14; $HighScoreRegister = 15
# Supporting settings, named and set (manual p. 1-5, 1-9, 1-10):
# register 24 = 3 makes thresholds award a replay, 2 an extra ball;
# register 26 = 3 awards three credits for beating High Score to Date;
# register 29 = 0 turns Match off so it cannot add a credit at game end;
# register 31 = 1 allows every replay earned (p. 1-5 table, "Free games
# allowed"); register 14 = 0 turns the third threshold off.
$ReplayMode = 3; $ExtraBallMode = 2
$HighScoreCredits = 3
$Supporting = @(@(24, $ReplayMode), @(26, $HighScoreCredits), @(29, 0), @(31, 1), @($Threshold3, 0))

# Scores are pumped toward a threshold by thumper hits at triple (four Deluxe
# CHAMP completions: gamerules.md "CHAMP", 3K thumpers through 3x) in settled
# chunks of $Chunk hits to within $Approach points (more than one chunk scores,
# so the approach cannot reach the threshold), then measured one hit at a time
# until the score crosses.
$Chunk = 10
$Approach = 15000
$PumpSwitch = 'Right Thumper Bumper'
$Knocker = Get-EbcSolenoid 'Knocker'

function Get-Buffer { $t = Get-EbcScoreBufferText (Get-EbcRamAddress ('ScoreBuffer{0}' -f (Get-EbcCurrentPlayer))); if ($t) { [long]$t } else { [long]0 } }
function Get-Knocks([int]$Since) { @(Get-EbcEvents -Since $Since | Where-Object { $_ -match "^\d+ sol $Knocker 1$" }).Count }
# Bulk hits that only reach a state: the score is read afterwards.
function Invoke-Bulk($Switch, [int]$Count) { if ($Count -gt 0) { Invoke-EbcSwitchHit $Switch -Count $Count; Step-EbcFrames -Frames 120 } }
# Pumps the current player's score to the hit that reaches $Threshold. Returns
# the credits and knocker pulses during the approach, and the measured hits:
# score before and after, credit change and knocker pulses of each.
function Invoke-Crossing([long]$Threshold) {
    if ((Get-EbcChampState) -ne 0x20) { for ($c = 0; $c -lt 4; $c++) { Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null } }
    $credits = Get-EbcCredits; $seen = Get-EbcEventCount
    while ((Get-Buffer) -lt $Threshold - $Approach) { Invoke-Bulk $PumpSwitch $Chunk }
    $approach = [PSCustomObject]@{ Credits = (Get-EbcCredits) - $credits; Knocks = Get-Knocks $seen }
    $hits = @()
    while ((Get-Buffer) -lt $Threshold) {
        $before = Get-Buffer; $c = Get-EbcCredits; $seen = Get-EbcEventCount
        $delta = Invoke-EbcScoredHit $PumpSwitch
        $hits += [PSCustomObject]@{ Before = $before; After = $before + $delta; Credits = (Get-EbcCredits) - $c; Knocks = Get-Knocks $seen }
    }
    [PSCustomObject]@{ Approach = $approach; Hits = $hits }
}
# A replay at $Threshold: nothing during the approach or the measured hits
# below it, then one credit and one knocker pulse on the hit that reaches it.
function Assert-ReplayAt([long]$Threshold) {
    $r = Invoke-Crossing $Threshold
    $last = $r.Hits[-1]
    $earlier = @($r.Hits | Select-Object -SkipLast 1 | Where-Object { $_.Credits -or $_.Knocks })
    Assert-EbcEqual -Expected '0 credits, 0 knocks' -Actual ('{0} credits, {1} knocks' -f $r.Approach.Credits, $r.Approach.Knocks) -What "award while pumping to $($Threshold - $Approach)"
    Assert-EbcEqual -Expected 0 -Actual $earlier.Count -What "measured hits below $Threshold that awarded ($(($earlier | ForEach-Object { "$($_.Before)->$($_.After)" }) -join ', '))"
    Assert-EbcEqual -Expected '+1 credit, 1 knock' -Actual ('+{0} credit, {1} knock' -f $last.Credits, $last.Knocks) -What "award on the hit $($last.Before) -> $($last.After) that reaches $Threshold"
}
# Plays the rest of the game out; returns the credit change and knocker
# pulses from the last drain to game over.
function Complete-Game {
    $c = Get-EbcCredits; $seen = Get-EbcEventCount
    Complete-EbcGame | Out-Null
    Step-EbcFrames -Frames 300
    [PSCustomObject]@{ Credits = (Get-EbcCredits) - $c; Knocks = Get-Knocks $seen }
}

Start-EbcGame

Test-EbcItem -Name 'Thresholds and High Score to Date entered at one tenth (150,000, 300,000, 400,000) are accepted by the displays' -Doc "$Settings; $Manual" -Body {
    Enter-EbcServiceMode | Out-Null
    # Set-EbcAdjustment throws unless Player 1 shows the stored value.
    foreach ($s in $Supporting) { Set-EbcAdjustment -Number $s[0] -Value $s[1] | Out-Null }
    Set-EbcAdjustment -Number $Threshold1 -Value $FirstReplay | Out-Null
    Set-EbcAdjustment -Number $Threshold2 -Value $SecondReplay | Out-Null
    Set-EbcAdjustment -Number $HighScoreRegister -Value $HighScoreToDate | Out-Null
    Exit-EbcServiceMode | Out-Null
}

Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'Carries use the ones digit across 9 -> 10, 99 -> 100 and 999 -> 1,000' -Doc $Doc -Body {
    Assert-EbcEqual -Expected 0 -Actual (Get-EbcScore -Player 1) -What 'score at the start of ball 1'
    # Reach each value below a carry by play, then score one Rebound (1).
    # 9 = 9 x 1.
    Invoke-Bulk 'Rebound' 9
    # 99 = 10 + 50 (center rollover) + 39 x 1.
    $to99 = { Invoke-Bulk $Target500Switch 1; Invoke-Bulk 'Rebound' 39 }
    # 999 = 100 + 300 + 300 (C and H lanes) + 100 + 100 (both stock thumpers)
    #       + 50 (center rollover) + 49 x 1.
    $to999 = { Invoke-Bulk '"C" Return Lane' 1; Invoke-Bulk '"H" Top Lane' 1; Invoke-Bulk 'Left Thumper Bumper' 1; Invoke-Bulk 'Right Thumper Bumper' 1; Invoke-Bulk $Target500Switch 1; Invoke-Bulk 'Rebound' 49 }
    $reach = @{ 9 = {}; 99 = $to99; 999 = $to999 }
    $seen = @()
    foreach ($below in $Carries) {
        & $reach[$below]
        $before = Get-EbcScore -Player 1
        Invoke-EbcScoredHit 'Rebound' | Out-Null
        $seen += '{0} -> {1} (display {2})' -f $before, (Get-EbcScore -Player 1), (Get-EbcDisplayText (Get-EbcNames).Displays.Player1)
    }
    $want = @($Carries | ForEach-Object { '{0} -> {1} (display {1})' -f $_, ($_ + $Rebound) })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'score before and after the Rebound at each carry'
}
Test-EbcItem -Name 'A manual/playfield 10-point Rebound scores 1' -Doc $Doc -Body {
    Assert-EbcEqual -Expected $Rebound -Actual (Invoke-EbcScoredHit 'Rebound') -What 'Rebound at 1x'
}
Test-EbcItem -Name 'A 500-point target scores 50 (the center rollover, switch 29)' -Doc $Doc -Body {
    Assert-EbcEqual -Expected $Target500 -Actual (Invoke-EbcScoredHit $Target500Switch) -What 'Center Rollover Button at 1x'
}
Test-EbcItem -Name 'A 3,000-point CHAMP lane scores 300' -Doc $Doc -Body {
    Assert-EbcEqual -Expected $ChampLane -Actual (Invoke-EbcScoredHit '"A" Top Lane') -What '"A" Top Lane at 1x'
}
Test-EbcItem -Name 'A combined 4,500-point award path scores 450 (lane 3,000 + thumper 1,000 + center rollover 500)' -Doc $Doc -Body {
    $before = Get-EbcScore -Player 1
    foreach ($s in $CombinedPath[0..1]) { Invoke-EbcSwitchHit $s }
    Invoke-EbcScoredHit $CombinedPath[2] | Out-Null
    Assert-EbcEqual -Expected $Combined -Actual ((Get-EbcScore -Player 1) - $before) -What "score change of $($CombinedPath -join ' + ') hit back to back at 1x ($ChampLane + $Thumper + $Target500)"
}
Test-EbcItem -Name 'Game 1: the first replay is awarded at 150,000' -Doc "$Settings; $Manual" -Body { Assert-ReplayAt $FirstReplay }
Test-EbcItem -Name 'Game 1: the second replay is awarded at 300,000' -Doc "$Settings; $Manual" -Body { Assert-ReplayAt $SecondReplay }
Test-EbcItem -Name 'Game 1: a game ending between 300,000 and 400,000 gets no High Score to Date award' -Doc "$Settings; $Manual" -Body {
    $final = Get-Buffer
    Assert-EbcTrue ($final -lt $HighScoreToDate) "game 1 score $final is not below $HighScoreToDate"
    $r = Complete-Game
    Assert-EbcEqual -Expected '+0 credits, 0 knocks' -Actual ('+{0} credits, {1} knocks' -f $r.Credits, $r.Knocks) -What "award at game over with $final"
}
Test-EbcItem -Name 'Game 2: replays again at 150,000 and 300,000' -Doc "$Settings; $Manual" -Body {
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    Assert-ReplayAt $FirstReplay
    Assert-ReplayAt $SecondReplay
}
Test-EbcItem -Name 'Game 2: a game ending above 400,000 gets the High Score to Date award' -Doc "$Settings; $Manual" -Body {
    Invoke-Crossing ($HighScoreToDate + $Approach) | Out-Null
    $final = Get-Buffer
    $r = Complete-Game
    Assert-EbcEqual -Expected ('+{0} credits, {0} knocks' -f $HighScoreCredits) -Actual ('+{0} credits, {1} knocks' -f $r.Credits, $r.Knocks) -What "award at game over with $final (register 26 = $HighScoreCredits)"
}
Test-EbcItem -Name 'Extra-ball thresholds entered at one tenth (200,000, 370,000) are accepted by the displays' -Doc "$Settings; $Manual" -Body {
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number 24 -Value $ExtraBallMode | Out-Null
    Set-EbcAdjustment -Number $Threshold1 -Value $FirstExtraBall | Out-Null
    Set-EbcAdjustment -Number $Threshold2 -Value $SecondExtraBall | Out-Null
    Exit-EbcServiceMode | Out-Null
}
Test-EbcItem -Name 'Game 3: extra balls are awarded at 200,000 and 370,000' -Doc "$Settings; $Manual" -Body {
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    $seen = @()
    foreach ($t in @($FirstExtraBall, $SecondExtraBall)) {
        $r = Invoke-Crossing $t
        $last = $r.Hits[-1]
        # An extra ball adds no credit; the drain then serves the same ball.
        $credits = $r.Approach.Credits + @($r.Hits | ForEach-Object { $_.Credits } | Measure-Object -Sum).Sum
        $outcome = Invoke-EbcDrain
        $seen += '{0}: +{1} credits, {2} player {3} ball {4}' -f $t, $credits, $outcome, (Get-EbcCurrentPlayer), (Get-EbcBallInPlay)
        Step-EbcFrames -Frames 120
    }
    # With no further threshold, the next drain moves on to ball 2.
    Invoke-EbcScoredHit 'Rebound' | Out-Null
    $seen += 'no threshold: {0} player {1} ball {2}' -f (Invoke-EbcDrain), (Get-EbcCurrentPlayer), (Get-EbcBallInPlay)
    $want = @("${FirstExtraBall}: +0 credits, Served player 1 ball 1", "${SecondExtraBall}: +0 credits, Served player 1 ball 1", 'no threshold: Served player 1 ball 2')
    Assert-EbcEqual -Expected $want -Actual $seen -What 'credits and the next serve after each threshold'
}
Complete-EbcTests
