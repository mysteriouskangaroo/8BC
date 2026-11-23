param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe sunk-ball awards: an uncalled first sink scores 250 through the
# playfield multiplier, an already-sunk ball keeps its 500 path and 5,000 lamp
# and leaves the collect alone, and each new sink's award blinks on the other
# three player displays, all by play in a four-player game.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Called = 'src/8bc-deluxe/gamerules.md "Called ball score"'
$Display = 'src/8bc-deluxe/gamerules.md "Sunk-ball award display"'
$Collect = 'src/8bc-deluxe/gamerules.md "Deluxe collect feature"'
$Pool = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM" (first-sink path $CE07)'
$SoundMap = 'src/8bc-deluxe/ghidra/HARDWARE_MAP.md "Squawk & Talk command transport and response map"'

# "Required gameplay verification": an uncalled first sink awards 250 at 1x,
# 500 at 2x, 750 at 3x (2,500 playfield / 10 = 250, times the multiplier).
$UncalledSink = @{ 1 = 250; 2 = 500; 3 = 750 }
# "Called ball score": an already-sunk ball keeps its 5,000 playfield path,
# displayed as 500 before multiplication (5,000 / 10).
$AlreadySunk = 5000 / 10
# "Called ball score": the Called ball score begins at 5,000 playfield,
# displayed 500, and uses the multiplier; this file's called sink is the
# player's first, at 1x.
$FirstCalledAward = 5000 / 10
# Deluxe CHAMP milestones (gamerules.md "CHAMP"): completion 2 lights 2x,
# completion 4 lights 3x. CHAMP_COMPLETION_STATE 10C0 reads 10 for double and
# 20 for triple (GAME_RULE_TRACES.md "Playfield Scores Double and Triple").
$CompletionsTo = @{ 2 = 2; 3 = 2 }
$ChampState = @{ 1 = '00'; 2 = '10'; 3 = '20' }
# "Sunk-ball award display": about three seconds, as a timing window
# FramesPerSecond x 3 +- 20%.
$Fps = (Get-EbcNames).FramesPerSecond
$BlinkMin = [int]($Fps * 3 * 0.8); $BlinkMax = [int]($Fps * 3 * 1.2)
# Frames watched after a sink: past the window's top.
$WatchFrames = $BlinkMax + 120
# The second sink of the replace check follows the first by this many frames,
# well inside the window.
$SecondSinkGap = 30
# Two durations of the same timer, measured from two sinks, agree within this
# many frames (one blink half-phase is about 8 frames).
$SameTimerFrames = 4

# OPS manual p. 1-11: players 1 and 3 shoot solids 1-7, players 2 and 4
# stripes 9-15; 10C3 bit k records the player's (k + 1)th ball of the group.
$FirstBall = @{ 1 = 1; 2 = 9; 3 = 1; 4 = 9 }
# The spoken call: HARDWARE_MAP response map 41-4F are the get/make/sink/
# shoot prompts for ball 1-15 (prompt - 40 = ball).
$PromptLow = 0x41; $PromptHigh = 0x4F
# 5,000 DROP TARGET 3 (GameNames.psd1 Lamps, from the manual's lamp table).
# "Retains the physical 5,000 lamp effect" means the original ROM's effect:
# the lamp flashes while the reset target 3 is worth 5,000 and goes dark when
# that target is hit (GAME_RULE_TRACES.md "Pool-ball drop targets": D034
# updates it through 10BF). tests/compare/original-vs-deluxe-5000-lamp.tests.ps1
# shows the original ROM and Deluxe light it identically frame by frame; this
# file checks the flash and the dark lamp on Deluxe in a four-player game.
$Lamp5000 = Get-EbcLampNumber '5,000 Drop Target 3'
$LampSampleFrames = 32

$ResetBy = @{}
$standups = (Get-EbcNames).StandupDropGroups
foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }
$Disp = (Get-EbcNames).Displays

function Get-DisplayOf([int]$Player) { Get-EbcDisplayText $Disp["Player$Player"] }
function Get-BufferOf([int]$Player) { Get-EbcScoreBufferText (Get-EbcRamAddress "ScoreBuffer$Player") }
# The latest spoken call since event index $Since, as a ball number.
function Get-Call([int]$Since) {
    $p = @(Get-EbcEvents -Since $Since | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { [int]($_ -split ' ')[3] } | Where-Object { $_ -ge $PromptLow -and $_ -le $PromptHigh })
    if (-not $p.Count) { throw "no 'sink the ball' prompt (41-4F) since event $Since ($SoundMap)" }
    $p[-1] - 0x40
}
# Starts the current player's turn: the first scoring switch triggers the
# call (gamerules.md "Called ball score"). Returns the called ball.
function Start-Turn {
    $seen = Get-EbcEventCount
    Step-EbcFrames -Frames 120
    Invoke-EbcScoredHit 'Rebound' | Out-Null
    Get-Call $seen
}
# The balls whose 10C3 bits a sink set.
function Get-NewBalls([int]$Player, [int]$Before, [int]$After) {
    $new = $After -band -bnot $Before
    @(for ($k = 0; $k -lt 7; $k++) { if ($new -band (1 -shl $k)) { $FirstBall[$Player] + $k } })
}
# Sinks a new ball with drop group $Group, watching the four displays every
# frame through their RAM score buffers (1046-1061), which the overlay
# replaces and restores (src/8bc-deluxe/asm/symbols.inc
# DELUXE_SUNK_BALL_SCORE_DISPLAY_BACKUP) and the displays show (Get-EbcScore
# cross-checks them; libpinmame's segment readout shows mixed digits while a
# display is redrawn). Returns the award, the new balls, the texts the other
# three buffers held other than their own scores, the frames they first all
# showed the award and were last restored, and how often the scorer's display
# was blank.
function Measure-Sink([string]$Group, [int]$Call, [int]$Frames = $WatchFrames, [scriptblock]$During) {
    $p = Get-EbcCurrentPlayer
    $others = @(1..4 | Where-Object { $_ -ne $p })
    $pre = @{}; foreach ($o in $others) { $pre[$o] = Get-BufferOf $o }
    $before = Get-EbcScore -Player $p
    $sunk = Get-EbcSunkBalls
    $f0 = Get-EbcFrame
    $shown = @{}; $first = -1; $restored = -1; $blankLive = 0
    $n = Get-EbcSwitch $Group
    for ($k = 0; $k -lt $Frames; $k++) {
        if ($k -eq 0) { Set-EbcSwitch -Number $n -Closed $true }
        if ($k -eq 4) { Set-EbcSwitch -Number $n -Closed $false }
        if ($During) { & $During $k }
        Step-EbcFrames -Frames 1
        $texts = @($others | ForEach-Object { Get-BufferOf $_ })
        $away = @(); for ($i = 0; $i -lt $others.Count; $i++) { if ($texts[$i] -ne $pre[$others[$i]]) { $away += $texts[$i] } }
        for ($i = 0; $i -lt $others.Count; $i++) {
            $o = $others[$i]; $t = $texts[$i]
            if ($t -ne '' -and $t -ne $pre[$o] -and -not $shown.ContainsKey($t)) { $shown[$t] = $k + 1 }
        }
        if ($away.Count -eq $others.Count -and @($away | Where-Object { $_ -ne '' }).Count -eq $others.Count -and $first -lt 0) { $first = $k + 1 }
        if ($first -ge 0 -and $restored -lt 0 -and $away.Count -eq 0) { $restored = $k + 1 }
        if ($restored -ge 0 -and $away.Count -ne 0) { $restored = -1 }
        if ((Get-DisplayOf $p) -eq '') { $blankLive++ }
    }
    Step-EbcFrames -Frames 30
    [PSCustomObject]@{
        Player = $p; Call = $Call; Balls = @(Get-NewBalls $p $sunk (Get-EbcSunkBalls))
        Award = (Get-EbcScore -Player $p) - $before
        Shown = @($shown.Keys | Sort-Object); ShownAt = $shown; First = $first; Restored = $restored
        Duration = $(if ($first -ge 0 -and $restored -ge 0) { $restored - $first } else { -1 })
        LiveBlank = $blankLive; StartFrame = $f0
    }
}
# Hits $Switch, watching the other three players' score buffers every frame
# from the closure for $WatchFrames frames (past any award display). Returns
# the scorer's score change, the texts the others held other than their own
# scores (none when the hit starts no award display), and the pulses of
# solenoid $AfterSolenoid (a standup's drop-group reset) meanwhile.
function Watch-Others([string]$Switch, [string]$AfterSolenoid) {
    $p = Get-EbcCurrentPlayer
    $others = @(1..4 | Where-Object { $_ -ne $p })
    $pre = @{}; foreach ($o in $others) { $pre[$o] = Get-BufferOf $o }
    $before = Get-EbcScore -Player $p
    $seen = Get-EbcEventCount
    $n = Get-EbcSwitch $Switch
    $away = @{}
    for ($k = 0; $k -lt $WatchFrames; $k++) {
        if ($k -eq 0) { Set-EbcSwitch -Number $n -Closed $true }
        if ($k -eq 4) { Set-EbcSwitch -Number $n -Closed $false }
        Step-EbcFrames -Frames 1
        foreach ($o in $others) { $t = Get-BufferOf $o; if ($t -ne $pre[$o]) { $away["P$o '$t'"] = $true } }
    }
    $pulses = if ($AfterSolenoid) { @(Get-EbcEvents -Since $seen | Where-Object { $_ -match ('^\d+ sol {0} 1$' -f (Get-EbcSolenoid $AfterSolenoid)) }).Count } else { 0 }
    [PSCustomObject]@{ Delta = (Get-EbcScore -Player $p) - $before; Away = @($away.Keys | Sort-Object); Pulses = $pulses }
}
function Get-Lamp5000 {
    $lit = 0
    for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; if (Get-EbcLamp -Number $Lamp5000) { $lit++ } }
    $lit
}
function Assert-Multiplier([int]$m) {
    Assert-EbcEqual -Expected $ChampState[$m] -Actual ('{0:X2}' -f (Get-EbcChampState)) -What "CHAMP completion state for ${m}x"
}
function Assert-Uncalled($r, [int]$m) {
    Assert-EbcTrue ($r.Balls.Count -eq 1 -and $r.Balls[0] -ne $r.Call) "balls sunk [$($r.Balls -join ', ')], call ball $($r.Call): expected one uncalled ball"
    Assert-EbcEqual -Expected $UncalledSink[$m] -Actual $r.Award -What "uncalled first sink of ball $($r.Balls -join ', ') (call: ball $($r.Call)) at ${m}x"
}

Start-EbcGame
Add-EbcCredit -Count 4 | Out-Null
Start-EbcPlay -Players 4 | Out-Null
$script:M = @()

# ---- Player 1, ball 1 ----
$script:Call = Start-Turn
Test-EbcItem -Name 'An uncalled first sink scores 250 at 1x' -Doc "$Doc; $Pool; $Called" -Body {
    Assert-Multiplier 1
    $r = Measure-Sink 'Drop Target 3,11' $script:Call
    $script:M += $r
    Assert-Uncalled $r 1
}
Test-EbcItem -Name 'An already-sunk ball scores 500, keeps its 5,000 lamp effect, does not touch the collect and starts no award display' -Doc "$Doc; $Called; $Collect; $Display" -Body {
    # The first sink above activated the orbit (collect-cycle.tests.ps1).
    $seen = @()
    foreach ($stage in 'orbit active', 'spinner inactive') {
        $g = Watch-Others $ResetBy['Drop Target 3,11'] 'Drop Target 3,11'
        if ($g.Pulses -ne 1) { throw "the $($ResetBy['Drop Target 3,11']) hit did not reset Drop Target 3,11 ($($g.Pulses) pulses)" }
        $flashing = Get-Lamp5000
        $hit = Watch-Others 'Drop Target 3,11'
        $dark = Get-Lamp5000
        $spin = Invoke-EbcScoredHit 'Spinner'
        $orbit = Invoke-EbcScoredHit $(if ($stage -eq 'orbit active') { 'Left Rollover Button' } else { 'Right Rollover Button' })
        $seen += '{0}: hit {1}; lamp {2}/{5} lit before, {3}/{5} after; spinner {4}; orbit {6}; other displays on E-I-G-H-T [{7}], on hit [{8}]' -f $stage, $hit.Delta, ($(if ($flashing -gt 0 -and $flashing -lt $LampSampleFrames) { 'flashing' } else { $flashing })), $dark, $spin, $LampSampleFrames, $orbit, ($g.Away -join ', '), ($hit.Away -join ', ')
    }
    # At orbit active the spinner stays unlit (10) and the orbit still
    # collects (1,000 displayed, 10,000 printed; collect-cycle.tests.ps1); at
    # spinner inactive the spinner stays unlit and the orbit scores 500.
    $want = @(
        "orbit active: hit $AlreadySunk; lamp flashing/$LampSampleFrames lit before, 0/$LampSampleFrames after; spinner 10; orbit 1000; other displays on E-I-G-H-T [], on hit []",
        "spinner inactive: hit $AlreadySunk; lamp flashing/$LampSampleFrames lit before, 0/$LampSampleFrames after; spinner 10; orbit 500; other displays on E-I-G-H-T [], on hit []")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'already-sunk hits on ball 3 at 1x'
}
Test-EbcItem -Name 'An uncalled first sink scores 500 at 2x' -Doc "$Doc; $Pool; $Called" -Body {
    for ($c = 0; $c -lt $CompletionsTo[2]; $c++) { Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null }
    Assert-Multiplier 2
    $r = Measure-Sink 'Drop Target 6,14' $script:Call
    $script:M += $r
    Assert-Uncalled $r 2
}
Test-EbcItem -Name 'An uncalled first sink scores 750 at 3x' -Doc "$Doc; $Pool; $Called" -Body {
    for ($c = 0; $c -lt $CompletionsTo[3]; $c++) { Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null }
    Assert-Multiplier 3
    $r = Measure-Sink 'Drop Target 7,15' $script:Call
    $script:M += $r
    Assert-Uncalled $r 3
}

# ---- Player 2 ----
Invoke-EbcDrain | Out-Null
$script:Call = Start-Turn
$script:M += Measure-Sink 'Drop Target 3,11' $script:Call
Test-EbcItem -Name 'A second new sink replaces the shown award and restarts the blink' -Doc "$Doc; $Display; $Called" -Body {
    # The call is the first ball of group 25; an uncalled sink with group 30,
    # then the called ball $SecondSinkGap frames later.
    Assert-EbcEqual -Expected $FirstBall[2] -Actual $script:Call -What "player 2's called ball"
    $called = Get-EbcSwitch 'Drop Target 1,2,9,10'
    $second = { param($k) if ($k -eq $SecondSinkGap) { Set-EbcSwitch -Number $called -Closed $true }; if ($k -eq $SecondSinkGap + 4) { Set-EbcSwitch -Number $called -Closed $false } }
    $r = Measure-Sink 'Drop Target 6,14' $script:Call -During $second
    Assert-EbcEqual -Expected @($FirstBall[2], ($FirstBall[2] + 5)) -Actual @($r.Balls | Sort-Object) -What 'balls sunk (the called first ball of group 25 and the uncalled ball of group 30)'
    # Player 2's single sink above kept the award up for $single frames. The
    # first award (250) shows first and the second sink's called award (500
    # at 1x) replaces it; staying up a single sink's span from when 500 first
    # shows, not from when 250 did, means the timer restarted there.
    $single = $script:M[-1].Duration
    $fromSecond = $r.Restored - $r.ShownAt[[string]$FirstCalledAward]
    Assert-EbcEqual -Expected @([string]$UncalledSink[1], [string]$FirstCalledAward) -Actual $r.Shown -What 'award texts shown on the other displays (sorted)'
    Assert-EbcEqual -Expected ($UncalledSink[1] + $FirstCalledAward) -Actual $r.Award -What "player 2's score change for the two sinks"
    Assert-EbcTrue ($r.ShownAt[[string]$UncalledSink[1]] -lt $r.ShownAt[[string]$FirstCalledAward]) "250 first shown at +$($r.ShownAt[[string]$UncalledSink[1]]), 500 at +$($r.ShownAt[[string]$FirstCalledAward])"
    Assert-EbcTrue ([Math]::Abs($fromSecond - $single) -le $SameTimerFrames) ("displays restored {0} frames after the second award first showed (and {1} after the first); a single sink's award showed for {2}" -f $fromSecond, ($r.Restored - $r.ShownAt[[string]$UncalledSink[1]]), $single)
}

# ---- Players 3 and 4 ----
Invoke-EbcDrain | Out-Null
$script:Call = Start-Turn
$script:M += Measure-Sink 'Drop Target 3,11' $script:Call
Invoke-EbcDrain | Out-Null
$script:Call = Start-Turn
$script:M += Measure-Sink 'Drop Target 3,11' $script:Call

Test-EbcItem -Name 'With each player active in turn, the award shows on the other three displays while the scorer''s live score stays visible' -Doc "$Doc; $Display" -Body {
    $seen = @($script:M | ForEach-Object { 'P{0} {1}x: award {2}, shown [{3}], restored {4}, scorer blank {5}' -f $_.Player, $(if ($_.Award -eq 500) { 2 } elseif ($_.Award -eq 750) { 3 } else { 1 }), $_.Award, ($_.Shown -join ', '), ($_.Restored -ge 0), $_.LiveBlank })
    $want = @(
        "P1 1x: award $($UncalledSink[1]), shown [$($UncalledSink[1])], restored True, scorer blank 0",
        "P1 2x: award $($UncalledSink[2]), shown [$($UncalledSink[2])], restored True, scorer blank 0",
        "P1 3x: award $($UncalledSink[3]), shown [$($UncalledSink[3])], restored True, scorer blank 0",
        "P2 1x: award $($UncalledSink[1]), shown [$($UncalledSink[1])], restored True, scorer blank 0",
        "P3 1x: award $($UncalledSink[1]), shown [$($UncalledSink[1])], restored True, scorer blank 0",
        "P4 1x: award $($UncalledSink[1]), shown [$($UncalledSink[1])], restored True, scorer blank 0")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'uncalled first sinks by player'
}
Test-EbcItem -Name "The award blinks for about three seconds (timing window: $BlinkMin-$BlinkMax frames)" -Doc "$Doc; $Display" -Body {
    $seen = @($script:M | ForEach-Object { 'P{0} award {1}: {2}' -f $_.Player, $_.Award, $(if ($_.Duration -ge $BlinkMin -and $_.Duration -le $BlinkMax) { 'in window' } else { "$($_.Duration) frames" }) })
    $want = @($script:M | ForEach-Object { 'P{0} award {1}: in window' -f $_.Player, $_.Award })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'frames from the award first showing on all three displays to their restore'
}
Test-EbcItem -Name 'A drain during the blink restores every displaced score before the next ball' -Doc "$Doc; $Display" -Body {
    # Player 4 sinks an uncalled ball; the drain closes the outhole while the
    # award is still showing.
    $p = Get-EbcCurrentPlayer
    $others = @(1..4 | Where-Object { $_ -ne $p })
    $pre = @{}; foreach ($o in $others) { $pre[$o] = Get-BufferOf $o }
    $r = Measure-Sink 'Drop Target 6,14' $script:Call -Frames 20
    $during = @($others | ForEach-Object { Get-BufferOf $_ })
    Assert-EbcTrue (@($during | Where-Object { $_ -eq [string]$UncalledSink[1] -or $_ -eq '' }).Count -eq $others.Count) "award not showing when the drain begins: $($during -join ' | ')"
    Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'drain outcome'
    $seen = @($others | ForEach-Object { "P$_ $(Get-DisplayOf $_)" }) + @("P$p live $((Get-DisplayOf $p) -eq (Get-BufferOf $p))")
    $want = @($others | ForEach-Object { "P$_ $($pre[$_])" }) + @("P$p live True")
    Assert-EbcEqual -Expected $want -Actual $seen -What "displays at the next serve (player $(Get-EbcCurrentPlayer) ball $(Get-EbcBallInPlay))"
}
Complete-EbcTests
