param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe B-A-L-L / E-I-G-H-T bonus: the four B-A-L-L inserts through five
# completions, the fifth kept in RAM, five letters at every bonus multiplier,
# the credit display during the bonus, per-player restore in a four-player
# game, and the new-game reset. All by play, no RAM writes.
#
# An E-I-G-H-T letter: its drop group goes down (sinking that group's next
# ball, if any), then its standup scores the letter and raises the group
# (GameNames.psd1 StandupDropGroups; spinner.tests.ps1). Letters are counted
# here from the hits, by the doc's rule ("Spinner": an already-lit letter
# still scores but does not advance; completing the word awards a B-A-L-L
# letter and rearms the five letters), so each bonus expectation follows the
# play, not the ROM's counters.
#
# Bonus multipliers by play on a new ball (saucer.tests.ps1, measured there):
# saucer hits give 2x, 3x, 5x (which lights 100,000 at once); the next hit
# collects 100,000; then each collect transition (an active orbit collect or
# the first active-spinner pulse, reached by sinking a new ball first)
# relights the next of 7x, 8x, 10x with 100,000, and a hit collects it. The
# earned multiplier is read from 1149 as saucer.tests.ps1 does, to confirm
# the play reached it.
#
# The bonus plays $37 with every 1,500-point sunk-ball step and $38 with every
# 1,000-point E-I-G-H-T step (src/8bc-deluxe/asm/modules/
# 10_game_state_and_drop_reset.asm $C7FC, $C90C). The B-A-L-L/E-I-G-H-T
# portion is the score change from the frame before the first $38 to the
# first later command that is not $38; the rack portion is the change before.
# Clauses of gamerules.md "Required gameplay verification" checked here
# (tools/tests/Test-DeluxeCoverage.ps1):
# Clause: Complete E-I-G-H-T at least five times
# Clause: In a four-player game, give Player 1
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$BallDoc = 'src/8bc-deluxe/gamerules.md "B-A-L-L and E-I-G-H-T bonus"'
$Pool = 'src/8bc-deluxe/gamerules.md "Pool-ball bonus"'
$Saucer = 'src/8bc-deluxe/gamerules.md "Hole / saucer"'
$Impl = 'src/8bc-deluxe/gamerules.md "Deluxe implementation state"'

# "Required gameplay verification": at 1x five B-A-L-L letters contribute
# 25,000, plus 1,000 for each partial E-I-G-H-T letter, multiplied at
# 2x/3x/5x/7x/8x/10x. ("B-A-L-L and E-I-G-H-T bonus": each letter is five
# scaled 1,000-point units, or 5,000; 5 * 5,000 = 25,000.)
$FiveLetters = 25000
$BallLetterValue = 5000
$PartialLetterValue = 1000
$Multipliers = @(1, 2, 3, 5, 7, 8, 10)
# "Pool-ball bonus": each rack is 8 * 1,500 = 12,000; each partial-rack ball 1,500.
$RackValue = 8 * 1500
$PartialBallValue = 1500
# "the credit display changes to `05` after the rack bonus"; the four-player
# clause: Player 1's next ball restores `04` racks and `05` B-A-L-L letters.
$FiveShown = '05'
$FourShown = '04'
# "all four physical B-A-L-L inserts are lit after the fourth completion,
# begin blinking together with the fifth completion".
$AllLitAt = 4
$BlinkAt = 5
# The fifth completion "is retained in RAM": the active-player counter 1104
# and the Player 1-4 counters 110A-110D; the eight per-player totals are the
# rack counters 1106-1109 and these ("Deluxe implementation state";
# src/8bc-deluxe/ghidra/HARDWARE_MAP.md "U4 RAM: Deluxe allocation").
$ActiveBallLetters = 0x1104
$PlayerBallLetters = 0x110A
$PlayerRacks = 0x1106
$EarnedMultiplier = 0x1149
$SoundRackStep = 0x37
$SoundLetterStep = 0x38
$LampSampleFrames = 64

$BallLamps = [ordered]@{ B = (Get-EbcLampNumber 'Ball "B"'); A = (Get-EbcLampNumber 'Ball "A"'); L1 = (Get-EbcLampNumber 'Ball "L" 1'); L2 = (Get-EbcLampNumber 'Ball "L" 2') }
$RackLamps = [ordered]@{ '120K' = (Get-EbcLampNumber 'Bonus 120,000'); '240K' = (Get-EbcLampNumber 'Bonus 240,000') }
$LetterOf = [ordered]@{ E = 'Drop Target "E"'; I = 'Drop Target "I"'; G = 'Drop Target "G"'; H = 'Drop Target "H"'; T = 'Drop Target "T"' }
$standups = (Get-EbcNames).StandupDropGroups
$ResetBy = @{}; foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }
$LetterByStandup = @{}; foreach ($k in $LetterOf.Keys) { $LetterByStandup[$LetterOf[$k]] = $k }
$GroupOf = @{ 1 = 'Drop Target 1,2,9,10'; 2 = 'Drop Target 1,2,9,10'; 3 = 'Drop Target 3,11'; 4 = 'Drop Target 4,5,12,13'
              5 = 'Drop Target 4,5,12,13'; 6 = 'Drop Target 6,14'; 7 = 'Drop Target 7,15' }
$LatchOf = @{ 'Drop Target 1,2,9,10' = 0x01; 'Drop Target 3,11' = 0x04; 'Drop Target 4,5,12,13' = 0x08; 'Drop Target 6,14' = 0x20; 'Drop Target 7,15' = 0x40 }

# ---- Letter and rack bookkeeping from the play, per player ----
function Reset-Counts { $script:Lit = @{}; $script:Words = @{}; $script:Racks = @{}; foreach ($p in 1..4) { $script:Lit[$p] = [Collections.Generic.HashSet[string]]::new(); $script:Words[$p] = 0; $script:Racks[$p] = 0 } }
function Add-Letter([string]$L) {
    $p = [int](Get-EbcCurrentPlayer)
    if ($script:Lit[$p].Add($L) -and $script:Lit[$p].Count -eq 5) { $script:Words[$p]++; $script:Lit[$p].Clear() }
}
function Invoke-Letter([string]$L) {
    $g = $standups[$LetterOf[$L]]
    Invoke-EbcScoredHit $g | Out-Null
    Invoke-EbcScoredHit $LetterOf[$L] -AfterSolenoid $g | Out-Null
    Add-Letter $L
}
function Complete-Word { $p = [int](Get-EbcCurrentPlayer); $w = $script:Words[$p]; foreach ($L in $LetterOf.Keys) { if ($script:Words[$p] -eq $w) { Invoke-Letter $L } } }
function Invoke-EightBall {
    Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
    if ((Get-EbcSunkBalls) -ne 0) { throw 'the 8-ball did not start a new rack' }
    $script:Racks[[int](Get-EbcCurrentPlayer)]++
    Step-EbcFrames -Frames 30
}
# Sinks the lowest unsunk ball (raising its group with its standup, a letter,
# when the group is down); with balls 1-7 sunk, collects the 8-ball instead.
function Invoke-NewSink {
    $sunk = Get-EbcSunkBalls
    if ($sunk -eq 0x7F) { Invoke-EightBall; return }
    $g = $GroupOf[@(1..7 | Where-Object { -not ($sunk -band (1 -shl ($_ - 1))) })[0]]
    if ((Read-EbcByte (Get-EbcRamAddress 'DROP_TARGET_SWITCH_CLOSURE_LATCHES')) -band $LatchOf[$g]) {
        Invoke-EbcScoredHit $ResetBy[$g] -AfterSolenoid $g | Out-Null
        Add-Letter $LetterByStandup[$ResetBy[$g]]
    }
    Invoke-EbcScoredHit $g | Out-Null
    if ((Get-EbcSunkBalls) -eq $sunk) { throw "$g sank no new ball" }
    Step-EbcFrames -Frames 30
}
function Invoke-Rack { while ((Get-EbcSunkBalls) -ne 0x7F) { Invoke-NewSink }; Invoke-EightBall }

# ---- Bonus multiplier by play (see the header) ----
function Get-Location { (Read-EbcByte 0x10FB) -band 0x07 }   # DELUXE_COLLECT_STATE, read only to choose the next shot
function Invoke-Transition {
    if (((Get-Location) -band 3) -eq 2) {
        if (-not ((Get-Location) -band 0x04)) { Invoke-NewSink }
        Invoke-EbcScoredHit 'Spinner' | Out-Null
        Step-EbcFrames -Frames 300                                 # spinner collecting ends
    }
    else {
        if (-not ((Get-Location) -band 0x04)) { Invoke-NewSink }
        Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
        Step-EbcFrames -Frames 30
    }
}
# A saucer hit; with balls 1-7 sunk it is also the 8-ball collection.
function Invoke-Saucer {
    $eight = (Get-EbcSunkBalls) -eq 0x7F
    Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
    if ($eight) { $script:Racks[[int](Get-EbcCurrentPlayer)]++ }
    Step-EbcFrames -Frames 30
}
function Set-BonusMultiplier([int]$m) {
    $hits = @{ 1 = 0; 2 = 1; 3 = 2; 5 = 3; 7 = 4; 8 = 4; 10 = 4 }[$m]
    for ($k = 0; $k -lt $hits; $k++) { Invoke-Saucer }            # 2x, 3x, 5x, then the first 100,000
    foreach ($step in 7, 8, 10) { if ($m -ge $step) { Invoke-Transition; Invoke-Saucer } }
    $earned = [int](Read-EbcByte $EarnedMultiplier)
    if ($earned -ne $m) { throw "the play reached ${earned}x, not ${m}x" }
}

# ---- Lamps ----
function Get-Inserts($Lamps) {
    $s = [ordered]@{}; foreach ($n in $Lamps.Keys) { $s[$n] = '' }
    for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; foreach ($n in $Lamps.Keys) { $s[$n] += $(if (Get-EbcLamp -Number $Lamps[$n]) { '#' } else { '.' }) } }
    $lit = @($Lamps.Keys | Where-Object { $s[$_].Contains('#') })
    if (-not $lit.Count) { return 'dark' }
    $pats = @($lit | ForEach-Object { $s[$_] } | Select-Object -Unique)
    if ($pats.Count -eq 1 -and -not $pats[0].Contains('.')) { return "$($lit -join '+') steady" }
    if ($pats.Count -eq 1) { return "$($lit -join '+') blinking in phase" }
    ($Lamps.Keys | ForEach-Object { "$_ $($s[$_])" }) -join ', '
}

# ---- The drain bonus ----
function Measure-Bonus {
    $p = [int](Get-EbcCurrentPlayer)
    $addr = Get-EbcRamAddress "ScoreBuffer$p"
    $read = { $t = Get-EbcScoreBufferText $addr; if ($t -eq '') { [long]0 } else { [long]$t } }
    $sunk = Get-EbcSunkBalls
    $r = [PSCustomObject]@{ Player = $p; Multiplier = [int](Read-EbcByte $EarnedMultiplier); Racks = $script:Racks[$p]; Partial = @(0..6 | Where-Object { $sunk -band (1 -shl $_) }).Count
                            Words = $script:Words[$p]; Letters = $script:Lit[$p].Count; Before = (& $read); Frames = @{}; RackTotal = 0; BallTotal = 0; BallPhase = @() }
    $seen = Get-EbcEventCount
    $sol = Get-EbcSolenoid 'Outhole'
    Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $true
    for ($k = 0; ; $k++) {
        if ($k -gt 9000) { throw 'no serve or game over within 9000 frames of the drain' }
        Step-EbcFrames -Frames 1
        $r.Frames[[long](Get-EbcFrame)] = [PSCustomObject]@{ Score = (& $read); Credit = (Get-EbcDisplayText (Get-EbcNames).Displays.Credits); Status = (Get-EbcDisplayText (Get-EbcNames).Displays.Status) }
        if (@(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $sol 1$" }).Count -or (Test-EbcGameOver)) { break }
    }
    Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $false
    $ev = @(Get-EbcEvents -Since $seen | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $x = $_ -split ' '; [PSCustomObject]@{ F = [long]$x[0]; B = [int]$x[3] } })
    $cmds = @(for ($i = 0; $i -lt $ev.Count; $i++) {
        $ev[$i]
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    })
    $s38 = @($cmds | Where-Object { $_.B -eq $SoundLetterStep })
    if (-not $s38.Count) { throw "player $p's bonus played no `$38" }
    $start = $s38[0].F - 1
    $end = @($cmds | Where-Object { $_.F -ge $s38[-1].F -and $_.B -ne $SoundLetterStep } | Select-Object -First 1)
    if (-not $end.Count) { throw 'no command after the last $38' }
    $r.RackTotal = $r.Frames[$start].Score - $r.Before
    $r.BallTotal = $r.Frames[$end[0].F].Score - $r.Frames[$start].Score
    $s37 = @($cmds | Where-Object { $_.B -eq $SoundRackStep })
    $rackFrom = if ($s37.Count) { $s37[0].F } else { $start }
    $r | Add-Member -NotePropertyName RackPhase -NotePropertyValue @($r.Frames.Keys | Where-Object { $_ -ge $rackFrom -and $_ -lt $start } | Sort-Object | ForEach-Object { $r.Frames[$_] })
    $r.BallPhase = @($r.Frames.Keys | Where-Object { $_ -ge $start -and $_ -lt $end[0].F } | Sort-Object | ForEach-Object { $r.Frames[$_] })
    $r
}
function Get-Shown($Frames, [string]$What) { @($Frames | ForEach-Object { $_.$What } | Select-Object -Unique) }
function Format-BallPortion($d) { "P{0} {1}x, {2} B-A-L-L letters + {3} letters: {4}" -f $d.Player, $d.Multiplier, $d.Words, $d.Letters, $d.BallTotal }
function Want-BallPortion($d) { "P{0} {1}x, {2} B-A-L-L letters + {3} letters: {4}" -f $d.Player, $d.Multiplier, $d.Words, $d.Letters, ($d.Multiplier * ($(if ($d.Words -eq 5) { $FiveLetters } else { $d.Words * $BallLetterValue }) + $d.Letters * $PartialLetterValue)) }
# Steps to the given player's given ball, draining other turns (an
# E-I-G-H-T completion can award an extra ball, OPS manual p. 1-11, so the
# order of turns is not fixed). Each drain's bonus runs; only measured
# drains are checked.
function Enter-Turn([int]$Player, [int]$Ball) {
    for ($k = 0; $k -lt 16; $k++) {
        Step-EbcFrames -Frames 120
        if ([int](Get-EbcCurrentPlayer) -eq $Player -and [int](Get-EbcBallInPlay) -eq $Ball) { return }
        Invoke-EbcScoredHit 'Rebound' | Out-Null
        if ((Invoke-EbcDrain) -eq 'GameOver') { throw "game over before player $Player's ball $Ball" }
    }
    throw "player $Player's ball $Ball not reached in 16 drains"
}

Start-EbcGame
Add-EbcCredit -Count 12 | Out-Null

# ================= Game 1: three players, seven multipliers =================
Reset-Counts
Start-EbcPlay -Players 3 | Out-Null
# Player 1, ball 1: five completions, two letters of the sixth word, 1x.
Enter-Turn 1 1
$progress = @()
for ($c = 1; $c -le 5; $c++) { Complete-Word; $progress += "completion ${c}: $(Get-Inserts $BallLamps)" }
$ram5 = 'active {0}, player 1 {1}' -f (Read-EbcByte $ActiveBallLetters), (Read-EbcByte $PlayerBallLetters)
Invoke-Letter 'E'; Invoke-Letter 'I'
$drains = @()
$drains += Measure-Bonus
# Player 2, ball 1: five completions, one letter, 2x. Player 3: five, 3x.
Enter-Turn 2 1
for ($c = 1; $c -le 5; $c++) { Complete-Word }
Invoke-Letter 'G'
Set-BonusMultiplier 2
$drains += Measure-Bonus
Enter-Turn 3 1
for ($c = 1; $c -le 5; $c++) { Complete-Word }
Set-BonusMultiplier 3
$drains += Measure-Bonus
# Ball 2: players 1-3 at 5x, 7x, 8x. Ball 3: player 1 at 10x.
foreach ($t in @(@(1, 2, 5), @(2, 2, 7), @(3, 2, 8), @(1, 3, 10))) { Enter-Turn $t[0] $t[1]; Set-BonusMultiplier $t[2]; $drains += Measure-Bonus }
Complete-EbcGame | Out-Null

Test-EbcItem -Name 'All four B-A-L-L inserts are lit after the fourth E-I-G-H-T completion and blink together from the fifth' -Doc "$Doc; $BallDoc" -Body {
    # Through $AllLitAt completions the inserts light one more letter each
    # (the original progression); from $BlinkAt all four blink together.
    $names = @($BallLamps.Keys)
    $want = @(1..5 | ForEach-Object {
        $state = if ($_ -ge $BlinkAt) { "$($names -join '+') blinking in phase" } else { "$($names[0..([Math]::Min($_, $AllLitAt) - 1)] -join '+') steady" }
        "completion ${_}: $state" })
    Assert-EbcEqual -Expected $want -Actual $progress -What "B-A-L-L inserts over $LampSampleFrames frames after each completion (player 1)"
}
Test-EbcItem -Name 'The fifth E-I-G-H-T completion is retained in RAM' -Doc "$Doc; $BallDoc; $Impl" -Body {
    Assert-EbcEqual -Expected 'active 5, player 1 5' -Actual $ram5 -What 'B-A-L-L counters 1104 and 110A after five completions'
}
Test-EbcItem -Name 'Five B-A-L-L letters contribute 25,000 plus 1,000 per partial E-I-G-H-T letter at 1x, multiplied at 2x/3x/5x/7x/8x/10x' -Doc "$Doc; $BallDoc; $Saucer" -Body {
    Assert-EbcEqual -Expected (($Multipliers | ForEach-Object { "${_}x" }) -join ' ') -Actual (($drains | ForEach-Object { "$($_.Multiplier)x" }) -join ' ') -What 'multipliers reached at the seven drains'
    Assert-EbcEqual -Expected @($drains | ForEach-Object { Want-BallPortion $_ }) -Actual @($drains | ForEach-Object { Format-BallPortion $_ }) -What 'B-A-L-L/E-I-G-H-T portion at each drain'
}
$first = $drains[0]
Write-Output ("INFO {0}/ball-bonus :: player 1's 1x B-A-L-L phase: credit display [{1}], status display [{2}]" -f $Tree, ((Get-Shown $first.BallPhase 'Credit') -join ', '), ((Get-Shown $first.BallPhase 'Status') -join ', '))
Test-EbcItem -Name 'After the rack bonus the credit display changes to 05 for five B-A-L-L letters' -Doc "$Doc; $BallDoc" -Body {
    Assert-EbcEqual -Expected @($FiveShown) -Actual @(Get-Shown $first.BallPhase 'Credit') -What ("credit display (GameNames Displays.Credits) through player 1's B-A-L-L phase (status display showed [{0}])" -f ((Get-Shown $first.BallPhase 'Status') -join ', '))
}

# ================= Game 2: four players =================
Reset-Counts
Start-EbcPlay -Players 4 | Out-Null
# Player 1: five completions, then four racks. Player 2: one rack and one
# completion. Player 3: two completions. Player 4: nothing.
Enter-Turn 1 1
for ($c = 1; $c -le 5; $c++) { Complete-Word }
for ($k = 1; $k -le 4; $k++) { Invoke-Rack }
Enter-Turn 2 1; Invoke-Rack; Complete-Word
Enter-Turn 3 1; Complete-Word; Complete-Word
Enter-Turn 4 1
# Ball 2: each player's inserts, then player 1's bonus.
$turns = @{}
Enter-Turn 1 2
$turns[1] = "P1: racks $(Get-Inserts $RackLamps); B-A-L-L $(Get-Inserts $BallLamps)"
# A ball drained before its first score is served again without a bonus
# (GameTest.psm1 Invoke-EbcDrain).
Invoke-EbcScoredHit 'Rebound' | Out-Null
$p1 = Measure-Bonus
foreach ($pl in 2..4) {
    Enter-Turn $pl 2
    $turns[$pl] = "P${pl}: racks $(Get-Inserts $RackLamps); B-A-L-L $(Get-Inserts $BallLamps)"
}
Test-EbcItem -Name 'In a four-player game Player 1''s next ball restores 04 racks and 05 B-A-L-L letters for the bonus' -Doc "$Doc; $BallDoc; $Pool" -Body {
    $want = "4 racks + {0} balls: {1}; {2}" -f $p1.Partial, ($p1.Multiplier * (4 * $RackValue + $p1.Partial * $PartialBallValue)), (Want-BallPortion $p1)
    $seen = "{0} racks + {1} balls: {2}; {3}" -f $p1.Racks, $p1.Partial, $p1.RackTotal, (Format-BallPortion $p1)
    Assert-EbcEqual -Expected $want -Actual $seen -What "player 1's ball-2 bonus at $($p1.Multiplier)x"
}
Write-Output ("INFO {0}/ball-bonus :: player 1's ball-2 bonus: rack phase credit display [{1}], status display [{2}]; B-A-L-L phase credit display [{3}], status display [{4}]" -f $Tree, ((Get-Shown $p1.RackPhase 'Credit') -join ', '), ((Get-Shown $p1.RackPhase 'Status') -join ', '), ((Get-Shown $p1.BallPhase 'Credit') -join ', '), ((Get-Shown $p1.BallPhase 'Status') -join ', '))
Test-EbcItem -Name 'In a four-player game Player 1''s next ball shows 04 racks and then 05 B-A-L-L letters on the credit display' -Doc "$Doc; $BallDoc; $Pool" -Body {
    Assert-EbcEqual -Expected "rack phase [$FourShown]; B-A-L-L phase [$FiveShown]" -Actual ("rack phase [{0}]; B-A-L-L phase [{1}]" -f ((Get-Shown $p1.RackPhase 'Credit') -join ', '), ((Get-Shown $p1.BallPhase 'Credit') -join ', ')) -What "credit display (GameNames Displays.Credits) during player 1's ball-2 bonus"
}
Test-EbcItem -Name 'Both blink indications resume only on Player 1''s turn; every other player''s inserts are steady for only their own totals' -Doc "$Doc; $BallDoc; $Pool" -Body {
    # Original progression: one rack lights 120K; one letter lights B, two B and A.
    $want = @('P1: racks 120K+240K blinking in phase; B-A-L-L B+A+L1+L2 blinking in phase', 'P2: racks 120K steady; B-A-L-L B steady', 'P3: racks dark; B-A-L-L B+A steady', 'P4: racks dark; B-A-L-L dark')
    Assert-EbcEqual -Expected $want -Actual @(1..4 | ForEach-Object { $turns[$_] }) -What 'inserts at the start of each player''s second ball'
}
Invoke-EbcScoredHit 'Rebound' | Out-Null
Invoke-EbcDrain | Out-Null
Complete-EbcGame | Out-Null
Start-EbcPlay -Players 4 | Out-Null
Step-EbcFrames -Frames 60
$after = '{0}; {1}' -f ((Read-EbcRam -Address $PlayerRacks -Count 4) -join ' '), ((Read-EbcRam -Address $PlayerBallLetters -Count 4) -join ' ')
Test-EbcItem -Name 'A new game returns all eight per-player rack and B-A-L-L totals to zero' -Doc "$Doc; $BallDoc; $Impl" -Body {
    Assert-EbcEqual -Expected '0 0 0 0; 0 0 0 0' -Actual $after -What 'rack counters 1106-1109; B-A-L-L counters 110A-110D after a new game starts'
}
Complete-EbcTests
