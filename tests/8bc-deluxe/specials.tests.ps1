param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe specials: the additional points every special collection awards at
# 1x, 2x and 3x, with the original special award, sound and knocker once, by
# play over nine one-player games.
#
# Routes collected (the five Special registers, OPS manual p. 1-12: 120K,
# E-I-G-H-T, roll-up lanes, left outlane, right outlane):
#   E-I-G-H-T (completions 2 and 3; completion 1 awards an Extra Ball,
#     manual p. 1-11): 1x and 2x in game 1, 3x in game 2.
#   Roll-up lanes (orbit) at 100,000: 2x in game 1, 3x in game 2, 1x in
#     game 3. Its
#     already-collected latch (10A0 bit 20) stays set on later balls of the
#     same game, on Deluxe and on the original ROM
#     (tests/compare/original-vs-deluxe-orbit-special-later-ball.tests.ps1),
#     so it is collected once per game. The doc says the latch blocks a relight
#     only "during the same ball" ("Left orbit"); the item for that FAILs.
#   Left and right outlane: 3x only (lit only by CHAMP completion 5, which
#     keeps 3x), on two balls. Collecting either outlane turns both off
#     (measured; manual p. 1-11).
#   120K: 1x, 2x and 3x, each from a pair of games played identically, with
#     register 44 = 1 (the Special is awarded with the 120K, the first
#     8-ball) and 44 = 0 (awarded with 240K, so the first 8-ball has none).
#     The paired games' seven sink scores are compared first.
#
# "Additional score" is the collecting switch event's score change minus the
# same shot's change with no special lit, at the same multiplier: the orbit
# collect at 100,000 once its special is collected (same ball), the outlane
# hit before completion 5 (same ball), the E-I-G-H-T letter before the
# completing one (same round) or the completing letter of completion 1, and
# the 120K pair's 8-ball collection.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Specials = 'src/8bc-deluxe/gamerules.md "Specials"'
$Manual = 'OPS manual p. 1-9 register 25, p. 1-11, p. 1-12'

# "Collect each available special at 1x, 2x, and 3x and verify its
# additional score is respectively 25,000, 50,000, and 75,000." The clause
# does not label these values. They are read as displayed points: the
# "Specials" trace adds "two scaled multiplier-aware 10,000 awards plus one
# scaled multiplier-aware 5,000 award", and the doc's "scaled 10,000 award"
# ("Hole / saucer") is a displayed 10,000. Listed for the user's ruling.
$Additional = @{ 1 = 25000; 2 = 50000; 3 = 75000 }
# "The original special award and knocker behavior still occur exactly
# once": register 25 = 3 makes the award a replay (manual p. 1-9), one
# credit; the knocker pulses once; the Special sound $6F ("Specials" trace:
# "most special collectors enter at $C1D6, which plays sound $6F ... one
# original collector enters $C1DB directly") is sent once. The 120K collector
# is the one measured without $6F, so it expects none.
$AwardRegister = 25; $AwardReplay = 3
$CreditsPerSpecial = 1
$KnocksPerSpecial = 1
$SpecialSound = 0x6F
$SoundsPerSpecial = 1
# Register 51 = 0: the roll-up lanes special flashes at 100K; register 48 = 1
# recalls the roll-up values from ball to ball (manual p. 1-5, p. 1-12).
$OrbitSpecialRegister = 51; $OrbitSpecialAt100K = 0
$RecallRegister = 48; $RecallOn = 1
# Register 44 "Special at 120K/240K": 1 = award with 120K, 0 = award with
# 240K (manual p. 1-5, p. 1-11).
$RackRegister = 44
$Terminal = 100000
$ArrowValues = @(10000, 20000, 30000, 40000)
$ArrowLamps = @($ArrowValues | ForEach-Object { Get-EbcLampNumber ('Rollover Lanes {0:N0}' -f $_) })
$Knocker = Get-EbcSolenoid 'Knocker'

$GroupOf = @{ 1 = 'Drop Target 1,2,9,10'; 2 = 'Drop Target 1,2,9,10'; 3 = 'Drop Target 3,11'; 4 = 'Drop Target 4,5,12,13'
              5 = 'Drop Target 4,5,12,13'; 6 = 'Drop Target 6,14'; 7 = 'Drop Target 7,15' }
$LatchOf = @{ 'Drop Target 1,2,9,10' = 0x01; 'Drop Target 3,11' = 0x04; 'Drop Target 4,5,12,13' = 0x08; 'Drop Target 6,14' = 0x20; 'Drop Target 7,15' = 0x40 }
$standups = (Get-EbcNames).StandupDropGroups
$ResetBy = @{}; foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }

function Get-Commands([int]$Since) {
    $ev = @(Get-EbcEvents -Since $Since | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $f = $_ -split ' '; [PSCustomObject]@{ F = [int]$f[0]; B = [int]$f[3] } })
    for ($i = 0; $i -lt $ev.Count; $i++) {
        $ev[$i].B
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    }
}
function Get-Multiplier { $c = Get-EbcChampState; if ($c -band 0x20) { 3 } elseif ($c -band 0x10) { 2 } else { 1 } }
function Get-ArrowValue { $v = 0; for ($k = 0; $k -lt 4; $k++) { if (Get-EbcLamp -Number $ArrowLamps[$k]) { $v += $ArrowValues[$k] } }; $v }
function Get-Location { (Read-EbcByte 0x10FB) -band 0x07 }   # DELUXE_COLLECT_STATE, read only to choose the next shot
# A newly sunk ball: the lowest unsunk ball 1-7 (re-arming its group first),
# or the 8-ball at the saucer once balls 1-7 are sunk.
function Invoke-NewSink {
    $sunk = Get-EbcSunkBalls
    $next = @(1..7 | Where-Object { -not ($sunk -band (1 -shl ($_ - 1))) })
    if (-not $next.Count) { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null; Step-EbcFrames -Frames 30; return }
    $g = $GroupOf[$next[0]]
    if ((Read-EbcByte (Get-EbcRamAddress 'DROP_TARGET_SWITCH_CLOSURE_LATCHES')) -band $LatchOf[$g]) { Invoke-EbcScoredHit $ResetBy[$g] -AfterSolenoid $g | Out-Null }
    Invoke-EbcScoredHit $g | Out-Null
    if ((Get-EbcSunkBalls) -eq $sunk) { throw "$g sank no new ball" }
    Step-EbcFrames -Frames 30
}
# Plays the collect cycle until an orbit stage is active (collect-cycle
# .tests.ps1): states 4 = active, low bits 2 = spinner, 1/3 = orbit.
function Invoke-ToActiveOrbit {
    for ($k = 0; $k -lt 6; $k++) {
        $loc = Get-Location
        if (($loc -band 4) -and ($loc -band 3) -ne 2) { Step-EbcFrames -Frames 30; return }
        if (($loc -band 3) -eq 2 -and ($loc -band 4)) { Invoke-EbcScoredHit 'Spinner' | Out-Null; Step-EbcFrames -Frames 300; continue }
        Invoke-NewSink
    }
    throw "no active orbit (collect state $('{0:X2}' -f (Read-EbcByte 0x10FB)))"
}
# A switch event with its score change, credits, knocker pulses and $6F count.
function Invoke-Measured([string]$Switch, [string]$After) {
    $credits = Get-EbcCredits; $seen = Get-EbcEventCount
    $d = if ($After) { Invoke-EbcScoredHit $Switch -AfterSolenoid $After } else { Invoke-EbcScoredHit $Switch }
    Step-EbcFrames -Frames 60
    [PSCustomObject]@{ Switch = $Switch; M = (Get-Multiplier); Score = $d; Credits = (Get-EbcCredits) - $credits
        Knocks = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $Knocker 1$" }).Count
        Sixf = @(Get-Commands $seen | Where-Object { $_ -eq $SpecialSound }).Count }
}
# The orbit special and its baseline on this ball: activate the orbit at
# 100,000, collect it with the left rollover (special), then collect again.
function Invoke-OrbitSpecial {
    Invoke-ToActiveOrbit
    $shown = Get-ArrowValue
    if ($shown -ne $Terminal) { throw "the orbit shows $shown, not $Terminal" }
    $s = Invoke-Measured 'Left Rollover Button'
    Invoke-ToActiveOrbit
    $b = Invoke-Measured 'Left Rollover Button'
    [PSCustomObject]@{ Route = 'orbit'; Special = $s; Base = $b }
}
function Invoke-Drain { Invoke-EbcDrain | Out-Null; Step-EbcFrames -Frames 120; Invoke-EbcScoredHit 'Rebound' | Out-Null }
function Invoke-Completions([int]$n) { for ($k = 0; $k -lt $n; $k++) { Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null } }
# An E-I-G-H-T letter: lowers its group (a sink, or an already-sunk hit),
# then hits the standup. Returns the standup's measurement.
function Invoke-EightLetter([string]$Standup) {
    $g = $standups[$Standup]
    if (-not ((Read-EbcByte (Get-EbcRamAddress 'DROP_TARGET_SWITCH_CLOSURE_LATCHES')) -band $LatchOf[$g])) { Invoke-EbcScoredHit $g | Out-Null }
    Invoke-Measured $Standup
}

# Sets the registers and starts a one-player game.
function Start-Game([int]$Rack120K) {
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number $AwardRegister -Value $AwardReplay | Out-Null
    Set-EbcAdjustment -Number $OrbitSpecialRegister -Value $OrbitSpecialAt100K | Out-Null
    Set-EbcAdjustment -Number $RecallRegister -Value $RecallOn | Out-Null
    Set-EbcAdjustment -Number $RackRegister -Value $Rack120K | Out-Null
    Exit-EbcServiceMode | Out-Null
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
}
# One E-I-G-H-T round: returns the completing letter (T) and the letter
# before it (H), which scores at the same multiplier without completing.
function Invoke-EightRound { $m = @(foreach ($l in $Letters) { Invoke-EightLetter $l }); [PSCustomObject]@{ Last = $m[-1]; Before = $m[-2] } }
function Invoke-OrbitTo100K { for ($k = 0; $k -lt 5; $k++) { Invoke-ToActiveOrbit; Invoke-EbcScoredHit 'Right Rollover Button' | Out-Null; Step-EbcFrames -Frames 300 } }
function Finish-Game { Complete-EbcGame | Out-Null; Step-EbcFrames -Frames 400 }
# One rack at the given multiplier: balls 1-7, then the 8-ball's saucer hit,
# measured, with each sink's score for comparing the paired games.
function Invoke-Rack([int]$Completions) {
    Invoke-Completions $Completions
    $sinks = @(); for ($k = 0; $k -lt 7; $k++) { $sunk = Get-EbcSunkBalls; Invoke-NewSink; $sinks += Get-EbcScoreBufferText (Get-EbcRamAddress 'ScoreBuffer1') }
    $m = Invoke-Measured 'Saucer' 'Saucer'
    [PSCustomObject]@{ Sinks = ($sinks -join ','); Eight = $m }
}

$Letters = @('Drop Target "E"', 'Drop Target "I"', 'Drop Target "G"', 'Drop Target "H"', 'Drop Target "T"')
Start-EbcGame
$r = @()
# ---- Game 1, ball 1 (1x): E-I-G-H-T completion 1 (an Extra Ball) and 2
# (a Special); then the orbit to 100,000, 2x, and the orbit Special ----
Start-Game 1
$e1 = Invoke-EightRound
$e2 = Invoke-EightRound
$r += [PSCustomObject]@{ Route = 'E-I-G-H-T'; Special = $e2.Last; Base = $e1.Last }
Invoke-OrbitTo100K
Invoke-Completions 2
$r += Invoke-OrbitSpecial
$e3 = Invoke-EightRound                                          # completion 3 at 2x
$r += [PSCustomObject]@{ Route = 'E-I-G-H-T'; Special = $e3.Last; Base = $e3.Before }
# ---- Game 1, next ball: the recalled 100,000 orbit, then 3x and the left
# outlane Special, then the right outlane ----
Invoke-Drain
Invoke-ToActiveOrbit
$laterShown = Get-ArrowValue
$later = Invoke-Measured 'Left Rollover Button'
Invoke-Completions 4
$leftBase = Invoke-Measured 'Left Outlane'
$rightBase = Invoke-Measured 'Right Outlane'
Invoke-Completions 1                                              # completion 5: both outlane specials
$r += [PSCustomObject]@{ Route = 'left outlane'; Special = (Invoke-Measured 'Left Outlane'); Base = $leftBase }
$rightAfterLeft = Invoke-Measured 'Right Outlane'
# ---- Game 1, next ball: the right outlane Special ----
Invoke-Drain
Invoke-Completions 4
$rightBase2 = Invoke-Measured 'Right Outlane'
Invoke-Completions 1
$r += [PSCustomObject]@{ Route = 'right outlane'; Special = (Invoke-Measured 'Right Outlane'); Base = $rightBase2 }
Finish-Game
# ---- Game 2 (3x): E-I-G-H-T and orbit Specials ----
Start-Game 1
Invoke-Completions 4
$f1 = Invoke-EightRound
$f2 = Invoke-EightRound
$r += [PSCustomObject]@{ Route = 'E-I-G-H-T'; Special = $f2.Last; Base = $f1.Last }
Invoke-OrbitTo100K
$r += Invoke-OrbitSpecial
Finish-Game
# ---- Game 3 (1x): the orbit Special ----
Start-Game 1
Invoke-OrbitTo100K
$r += Invoke-OrbitSpecial
Finish-Game
# ---- 120K/240K: paired games, same play, register 44 = 1 (the Special is
# awarded with 120K) against 44 = 0 (awarded with 240K, so the 120K
# collection has none) ----
$rack = @{}
foreach ($m in 0, 2, 4) { foreach ($setting in 1, 0) { Start-Game $setting; $rack["$m/$setting"] = Invoke-Rack $m; Finish-Game } }

Write-Host ("E-I-G-H-T completion 3 at 2x: {0} credits +{1} knocks {2}; later ball orbit shows {3}: {4} credits +{5} knocks {6}; right outlane after left: {7} credits +{8} knocks {9}" -f $e3.Last.Score, $e3.Last.Credits, $e3.Last.Knocks, $laterShown, $later.Score, $later.Credits, $later.Knocks, $rightAfterLeft.Score, $rightAfterLeft.Credits, $rightAfterLeft.Knocks)
$pairs = @()
foreach ($m in 0, 2, 4) { $pairs += [PSCustomObject]@{ Route = '120K'; Special = $rack["$m/1"].Eight; Base = $rack["$m/0"].Eight; SinksA = $rack["$m/1"].Sinks; SinksB = $rack["$m/0"].Sinks } }
$r += $pairs
foreach ($k in $rack.Keys) { Write-Host ("rack {0}: sinks {1}; 8-ball {2} credits +{3} knocks {4} 6F {5}" -f $k, $rack[$k].Sinks, $rack[$k].Eight.Score, $rack[$k].Eight.Credits, $rack[$k].Eight.Knocks, $rack[$k].Eight.Sixf) }
foreach ($x in $r) { Write-Host ("{0} at {1}x: special {2} (credits +{3}, knocks {4}, 6F {5}); without {6} (credits +{7}, knocks {8}, 6F {9})" -f $x.Route, $x.Special.M, $x.Special.Score, $x.Special.Credits, $x.Special.Knocks, $x.Special.Sixf, $x.Base.Score, $x.Base.Credits, $x.Base.Knocks, $x.Base.Sixf) }

Test-EbcItem -Name 'The paired 120K games score their seven sinks identically' -Doc 'test setup' -Body {
    Assert-EbcEqual -Expected @($pairs | ForEach-Object { $_.SinksB }) -Actual @($pairs | ForEach-Object { $_.SinksA }) -What 'scores after each sink, register 44 = 1 against 44 = 0'
}
Test-EbcItem -Name 'Collecting each available special at 1x, 2x, and 3x adds respectively 25,000, 50,000, and 75,000' -Doc "$Doc; $Specials" -Body {
    $seen = @($r | ForEach-Object { "$($_.Route) special at $($_.Special.M)x: additional $($_.Special.Score - $_.Base.Score)" })
    $want = @($r | ForEach-Object { "$($_.Route) special at $($_.Special.M)x: additional $($Additional[$_.Special.M])" })
    Assert-EbcEqual -Expected $want -Actual $seen -What ('score change with the special minus without (' + (($r | ForEach-Object { "$($_.Route) $($_.Special.Score) - $($_.Base.Score)" }) -join '; ') + ')')
    Assert-EbcEqual -Expected @('1x', '2x', '3x') -Actual @($r | ForEach-Object { "$($_.Special.M)x" } | Sort-Object -Unique) -What 'multipliers covered'
}
Test-EbcItem -Name 'The original special award and knocker behavior still occur exactly once' -Doc "$Doc; $Specials; $Manual" -Body {
    $seen = @($r | ForEach-Object { "$($_.Route) at $($_.Special.M)x: credits +$($_.Special.Credits), knocks $($_.Special.Knocks), `$6F $($_.Special.Sixf); without the special: credits +$($_.Base.Credits), knocks $($_.Base.Knocks), `$6F $($_.Base.Sixf)" })
    $want = @($r | ForEach-Object { $six = if ($_.Route -eq '120K') { 0 } else { $SoundsPerSpecial }; "$($_.Route) at $($_.Special.M)x: credits +$CreditsPerSpecial, knocks $KnocksPerSpecial, `$6F $six; without the special: credits +0, knocks 0, `$6F 0" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'replay credit, knocker pulses and Special sounds per collecting hit'
}
Test-EbcItem -Name 'The orbit special is collected again on a later ball (the 10A0 latch blocks a relight only during the same ball)' -Doc "$Doc; src/8bc-deluxe/gamerules.md ""Left orbit""; $Specials" -Body {
    # "Left orbit": "The original already-collected latch in $10A0 bit $20
    # prevents it from being relit after collection during the same ball."
    # The next ball's active left collect at the recalled 100,000 should
    # therefore collect the Special again: 10,000 plus 25,000 at 1x, a credit
    # and a knock. The original ROM also keeps the latch on later balls
    # (tests/compare/original-vs-deluxe-orbit-special-later-ball), so this
    # FAIL is a doc/ROM mismatch that the original shares.
    $seen = "next ball: shows $laterShown, score $($later.Score) at $($later.M)x, credits +$($later.Credits), knocks $($later.Knocks)"
    $want = "next ball: shows $Terminal, score $($Terminal / 10 + $Additional[1]) at 1x, credits +$CreditsPerSpecial, knocks $KnocksPerSpecial"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'active left collect at the recalled 100,000 after ball 1''s orbit Special'
}
Complete-EbcTests
