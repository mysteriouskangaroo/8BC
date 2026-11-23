param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe Called ball score: the spoken call, its award at 1x/2x/3x in place of
# the 250 first-sink award, the flashing numbered target lamp, the 8-ball's
# award and advance, the new rack's call, per-player values in a four-player
# game, and the 50,000 cap (seeded). All by play except the cap.
#
# The call is the latest "sink the N ball" prompt (HARDWARE_MAP response map
# 41-4F, prompt - 40 = ball). The game calls an available ball (measured: the
# lowest unsunk ball whose drop group is up), so this file sinks the called
# ball by hitting its group, after re-arming the group with its E-I-G-H-T
# standup when the group is down (GameNames.psd1 StandupDropGroups).
# The award a sink shows is read from the other three players' RAM score
# buffers, which the award display replaces (sunk-ball-awards.tests.ps1).
# Clauses of gamerules.md "Required gameplay verification" checked here
# (tools/tests/Test-DeluxeCoverage.ps1):
# Clause: With each player active in turn
# Clause: Follow the spoken call
# Clause: Verify the individually numbered physical
# Clause: Complete a rack with the lit 8-ball
# Clause: Advance Called Ball to 50,000
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Called = 'src/8bc-deluxe/gamerules.md "Called ball score"'
$Display = 'src/8bc-deluxe/gamerules.md "Sunk-ball award display"'
$SoundMap = 'src/8bc-deluxe/ghidra/HARDWARE_MAP.md "Squawk & Talk command transport and response map"'

# "Called ball score": the value begins at 5,000 playfield, displayed 500, and
# every successful called ball advances it by 5,000 playfield: 5,000 / 10 = 500.
$StartValue = 5000 / 10
$Step = 5000 / 10
# "Required gameplay verification": the first three successful called balls
# award 500/1,000/1,500 at 1x, 1,000/2,000/3,000 at 2x, 1,500/3,000/4,500 at 3x.
$FirstThree = @{ 1 = @(500, 1000, 1500); 2 = @(1000, 2000, 3000); 3 = @(1500, 3000, 4500) }
# "An uncalled first sink retains its normal 2,500 playfield value, displayed
# as 250 before multiplication."
$Uncalled = 2500 / 10
# "The value stops advancing at 50,000 playfield / 5,000 displayed"; at the
# cap a call awards 5,000 at 1x, 10,000 at 2x, 15,000 at 3x (verification).
$CapValue = 50000 / 10
$CapAward = @{ 1 = 5000; 2 = 10000; 3 = 15000 }
# The stored progression is one byte of displayed 500-point units
# (src/8bc-deluxe/asm/symbols.inc DELUXE_CALLED_BALL_SCORE_500S 110E, active
# player; DELUXE_PLAYER_CALLED_BALL_SCORE_500S 110F-1112, players 1-4). The
# seeded item writes both as the game holds them after nine advances.
$ActiveCalled = 0x110E
$PlayerCalled = 0x110F
$CapUnits = [byte]($CapValue / $Step)
# CHAMP milestones (gamerules.md "CHAMP"): completion 2 lights 2x, completion
# 4 lights 3x; 10C0 reads 10 for double and 20 for triple.
$ChampState = @{ 1 = '00'; 2 = '10'; 3 = '20' }
# OPS manual p. 1-11: players 1 and 3 shoot solids 1-7, players 2 and 4
# stripes 9-15; 10C3 bit k is the player's (k + 1)th ball of the group.
$FirstBall = @{ 1 = 1; 2 = 9; 3 = 1; 4 = 9 }
$PromptLow = 0x41; $PromptHigh = 0x4F
# HARDWARE_MAP response map: 6C is the 8-ball prompt.
$EightBallPrompt = 0x6C
# Numbered drop-target lamps (GameNames.psd1 Lamps, from the manual's lamp
# table). A lamp "flashes" when it is lit on some but not all of the sampled
# frames.
$LampSampleFrames = 64
$NumberedBalls = @(1..7) + @(9..15)
$LampOf = @{}; foreach ($b in $NumberedBalls) { $LampOf[$b] = Get-EbcLampNumber "Drop Target $b" }
$Lamp5000 = Get-EbcLampNumber '5,000 Drop Target 3'

# Ball k of a rack (k = 1-7; stripes are k + 8) sits in this drop group
# (drop-targets.tests.ps1: group 25 sinks ball 1 then 2, group 28 4 then 5).
$GroupOf = @{ 1 = 'Drop Target 1,2,9,10'; 2 = 'Drop Target 1,2,9,10'; 3 = 'Drop Target 3,11'; 4 = 'Drop Target 4,5,12,13'
              5 = 'Drop Target 4,5,12,13'; 6 = 'Drop Target 6,14'; 7 = 'Drop Target 7,15' }
# A down group's latch in 10C5 (GameNames.psd1 StandupDropGroups comment:
# switches 25, 27, 28, 30, 31 set bits 01, 04, 08, 20, 40).
$LatchOf = @{ 'Drop Target 1,2,9,10' = 0x01; 'Drop Target 3,11' = 0x04; 'Drop Target 4,5,12,13' = 0x08; 'Drop Target 6,14' = 0x20; 'Drop Target 7,15' = 0x40 }
$ResetBy = @{}
$standups = (Get-EbcNames).StandupDropGroups
foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }

function Get-BufferOf([int]$Player) { Get-EbcScoreBufferText (Get-EbcRamAddress "ScoreBuffer$Player") }
function Get-RackIndex([int]$Ball) { if ($Ball -gt 8) { $Ball - 8 } else { $Ball } }
# The latest spoken call since the current turn began, as a ball number.
function Get-Call {
    $p = @(Get-EbcEvents -Since $script:TurnSeen | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { [int]($_ -split ' ')[3] } | Where-Object { $_ -ge $PromptLow -and $_ -le $PromptHigh })
    if (-not $p.Count) { throw "no 'sink the ball' prompt (41-4F) this turn ($SoundMap)" }
    $p[-1] - 0x40
}
# Steps until a 41-4F prompt arrives after event index $Since; returns the
# ball and the frame.
function Wait-Call([int]$Since, [int]$MaxFrames = 1500, [switch]$NoThrow) {
    for ($k = 0; $k -le $MaxFrames; $k++) {
        $p = @(Get-EbcEvents -Since $Since | Where-Object { $f = $_ -split ' '; $f[1] -eq 'snd' -and [int]$f[3] -ge $PromptLow -and [int]$f[3] -le $PromptHigh })
        if ($p.Count) { $f = $p[0] -split ' '; return [PSCustomObject]@{ Ball = [int]$f[3] - 0x40; Frame = [int]$f[0] } }
        Step-EbcFrames -Frames 1
    }
    if ($NoThrow) { return $null }
    throw "no 'sink the ball' prompt within $MaxFrames frames"
}
# The numbered lamps flashing over $LampSampleFrames frames, and the 5,000
# drop target 3 lamp's lit count.
function Get-Flashing {
    $lit = @{}; foreach ($b in $NumberedBalls) { $lit[$b] = 0 }; $k5 = 0
    for ($k = 0; $k -lt $LampSampleFrames; $k++) {
        Step-EbcFrames -Frames 1
        foreach ($b in $NumberedBalls) { if (Get-EbcLamp -Number $LampOf[$b]) { $lit[$b]++ } }
        if (Get-EbcLamp -Number $Lamp5000) { $k5++ }
    }
    [PSCustomObject]@{ Flashing = @($NumberedBalls | Where-Object { $lit[$_] -gt 0 -and $lit[$_] -lt $LampSampleFrames }); Lamp5000 = $k5 }
}
function Start-Turn {
    $script:TurnSeen = Get-EbcEventCount
    Step-EbcFrames -Frames 120
    Invoke-EbcScoredHit 'Rebound' | Out-Null
    Get-Call | Out-Null
}
function Set-Multiplier([int]$m) {
    for ($c = 0; $c -lt 4 -and (Get-Multiplier) -lt $m; $c++) { Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null }
    Assert-EbcEqual -Expected $ChampState[$m] -Actual ('{0:X2}' -f (Get-EbcChampState)) -What "CHAMP completion state for ${m}x"
}
# Hits $Switch, sampling the other three score buffers every frame until the
# scorer's score settles (after $AfterSolenoid's pulse, if given). Returns the
# score change, the newly sunk balls and the award texts shown.
function Measure-Hit([string]$Switch, [string]$AfterSolenoid) {
    $p = [int](Get-EbcCurrentPlayer)
    $others = @(1..4 | Where-Object { $_ -ne $p })
    $pre = @{}; foreach ($o in $others) { $pre[$o] = Get-BufferOf $o }
    $before = Get-EbcScore -Player $p
    $sunk = Get-EbcSunkBalls
    $seen = Get-EbcEventCount
    $pattern = if ($AfterSolenoid) { '^\d+ sol {0} 1$' -f (Get-EbcSolenoid $AfterSolenoid) } else { '' }
    $kick = -1
    $pendingAt = Get-EbcRamAddress 'PENDING_SCORE_10S'
    $shown = [Collections.Generic.List[string]]::new()
    $n = Get-EbcSwitch $Switch
    $last = $null; $stable = 0
    for ($k = 0; $stable -lt 150; $k++) {
        if ($k -gt 6000) { throw "the '$Switch' hit did not settle within 6000 frames" }
        if ($k -eq 0) { Set-EbcSwitch -Number $n -Closed $true }
        if ($k -eq 4) { Set-EbcSwitch -Number $n -Closed $false }
        Step-EbcFrames -Frames 1
        foreach ($o in $others) { $t = Get-BufferOf $o; if ($t -ne '' -and $t -ne $pre[$o] -and -not $shown.Contains($t)) { $shown.Add($t) } }
        if ($AfterSolenoid -and $kick -lt 0) {
            $e = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match $pattern })
            if ($e.Count) { $kick = [int]($e[0] -split ' ')[0] } else { continue }
        }
        $now = Get-BufferOf $p
        $pending = @(Read-EbcRam -Address $pendingAt -Count 6 | Where-Object { $_ -ne 0 }).Count
        if ($now -eq $last -and $pending -eq 0) { $stable++ } else { $stable = 0; $last = $now }
    }
    $new = (Get-EbcSunkBalls) -band -bnot $sunk
    $balls = @(for ($j = 0; $j -lt 7; $j++) { if ($new -band (1 -shl $j)) { $FirstBall[$p] + $j } })
    [PSCustomObject]@{ Award = (Get-EbcScore -Player $p) - $before; Balls = $balls; Shown = @($shown); Kick = $kick; Seen = $seen }
}
# Re-arms the group of $Ball when its latch shows it down.
function Reset-GroupOf([int]$Ball) {
    $g = $GroupOf[(Get-RackIndex $Ball)]
    if ((Read-EbcByte (Get-EbcRamAddress 'DROP_TARGET_SWITCH_CLOSURE_LATCHES')) -band $LatchOf[$g]) {
        Invoke-EbcScoredHit $ResetBy[$g] -AfterSolenoid $g | Out-Null
    }
}
# Sinks the spoken ball and waits for the next call (unless -NoWait).
# Returns the hit's measurement with the call it followed.
function Test-Sunk([int]$Ball) { ((Get-EbcSunkBalls) -band (1 -shl ((Get-RackIndex $Ball) - 1))) -ne 0 }
function Invoke-CalledSink([switch]$NoWait) {
    $call = Get-Call
    if (Test-Sunk $call) {
        # Every unsunk ball's group is down, so nothing was called: re-arm the
        # lowest unsunk ball's group and wait for its call.
        $p = [int](Get-EbcCurrentPlayer)
        $u = @(1..7 | Where-Object { -not ((Get-EbcSunkBalls) -band (1 -shl ($_ - 1))) })[0] + $FirstBall[$p] - 1
        $seen = Get-EbcEventCount
        Reset-GroupOf $u
        Wait-Call $seen | Out-Null
        $call = Get-Call
    }
    Reset-GroupOf $call
    $call = Get-Call                  # re-arming can bring a lower ball back into play
    Reset-GroupOf $call
    $r = Measure-Hit $GroupOf[(Get-RackIndex $call)]
    if ($r.Balls.Count -ne 1 -or $r.Balls[0] -ne $call) { throw "called ball $call, but the hit sank [$($r.Balls -join ', ')]" }
    $r | Add-Member -NotePropertyName Call -NotePropertyValue $call
    Add-DocAward $r
    if (-not $NoWait -and (Get-EbcSunkBalls) -ne 0x7F) { Wait-Call $r.Seen 600 -NoThrow | Out-Null; Step-EbcFrames -Frames 30 }
    $r
}
function Get-Multiplier { $c = Get-EbcChampState; if ($c -band 0x20) { 3 } elseif ($c -band 0x10) { 2 } else { 1 } }
# The doc's award for a success: the player's value (500 plus 500 per earlier
# success, 8-balls included, stopping at 5,000) times the multiplier
# ("Called ball score"). Records it on the hit as Expected, then counts the
# success. $script:Successes restarts at a new game.
function Add-DocAward($r) {
    $p = [int](Get-EbcCurrentPlayer)
    $m = Get-Multiplier
    $r | Add-Member -NotePropertyName Multiplier -NotePropertyValue $m
    $r | Add-Member -NotePropertyName Expected -NotePropertyValue ([Math]::Min($CapValue, $StartValue + $Step * $script:Successes[$p]) * $m)
    $script:Successes[$p]++
    $script:Awards += $r
}
# Collects the lit 8-ball (balls 1-7 sunk) and waits for the new rack's call.
function Invoke-EightBall {
    Assert-EbcEqual -Expected '7F' -Actual ('{0:X2}' -f (Get-EbcSunkBalls)) -What '10C3 before the 8-ball'
    $r = Measure-Hit 'Saucer' 'Saucer'
    $r | Add-Member -NotePropertyName Call -NotePropertyValue 8
    Add-DocAward $r
    Assert-EbcEqual -Expected '00' -Actual ('{0:X2}' -f (Get-EbcSunkBalls)) -What '10C3 after the 8-ball (new rack)'
    $c = Wait-Call $r.Seen
    $r | Add-Member -NotePropertyName NextCall -NotePropertyValue $c
    $r | Add-Member -NotePropertyName EightPrompts -NotePropertyValue @(Get-EbcEvents -Since $r.Seen | Where-Object { $f = $_ -split ' '; $f[1] -eq 'snd' -and [int]$f[3] -eq $EightBallPrompt -and [int]$f[0] -gt $r.Kick }).Count
    Step-EbcFrames -Frames 30
    $r
}
# A called sink's score change is its award; the 8-ball's score change also
# holds the saucer's own scoring, so only its shown award is listed.
function Format-Sink($r) { if ($r.Call -eq 8) { "{0}x 8-ball: shown [{1}]" -f $r.Multiplier, ($r.Shown -join ', ') } else { "{0}x ball {1}: award {2}, shown [{3}]" -f $r.Multiplier, $r.Call, $r.Award, ($r.Shown -join ', ') } }

$script:Awards = @()
$script:Successes = @{ 1 = 0; 2 = 0; 3 = 0; 4 = 0 }
Start-EbcGame
Add-EbcCredit -Count 8 | Out-Null
Start-EbcPlay -Players 4 | Out-Null

# ================= Game 1, player 1, ball 1 (solids, 1x) =================
Start-Turn
$first = Get-Call
$f0 = Get-Flashing
# The canonical reminder repeats an unsunk call; its interval bounds
# "immediately" for the new rack's call below.
$rem = Wait-Call (Get-EbcEventCount) 3000
$firstPromptFrame = [int](@(Get-EbcEvents -Since $script:TurnSeen | Where-Object { $f = $_ -split ' '; $f[1] -eq 'snd' -and [int]$f[3] -eq $first + 0x40 })[0] -split ' ')[0]
$ReminderFrames = $rem.Frame - $firstPromptFrame
$p1 = @()
$p1 += Invoke-CalledSink                       # first success
$fAfter1 = Get-Flashing
$callBeforeWrong = Get-Call
# An incorrect first sink: an available ball of another group.
$wrongGroup = @('Drop Target 4,5,12,13', 'Drop Target 6,14', 'Drop Target 7,15') | Where-Object { $_ -ne $GroupOf[(Get-RackIndex $callBeforeWrong)] } | Select-Object -First 1
$wrongSeen = Get-EbcEventCount
$wrong = Measure-Hit $wrongGroup
Step-EbcFrames -Frames 60
$fWrong = Get-Flashing
$callsAfterWrong = @(Get-EbcEvents -Since $wrongSeen | Where-Object { $f = $_ -split ' '; $f[1] -eq 'snd' -and [int]$f[3] -ge $PromptLow -and [int]$f[3] -le $PromptHigh } | ForEach-Object { [int]($_ -split ' ')[3] - 0x40 })
$callAfterWrong = Get-Call
$p1 += Invoke-CalledSink                       # second success
$p1 += Invoke-CalledSink                       # third success
$fAfter3 = Get-Flashing
$callAfter3 = Get-Call

Test-EbcItem -Name 'The first three successful called balls award 500/1,000/1,500 at 1x, replacing the 250 first-sink award' -Doc "$Doc; $Called" -Body {
    Assert-EbcEqual -Expected $FirstThree[1] -Actual @($p1 | ForEach-Object { $_.Award }) -What "player 1's first three called sinks at 1x (balls $(($p1 | ForEach-Object { $_.Call }) -join ', '))"
}
Test-EbcItem -Name 'An incorrect first sink scores 250 and does not advance the Called ball value' -Doc "$Doc; $Called" -Body {
    Assert-EbcTrue ($wrong.Balls.Count -eq 1 -and $wrong.Balls[0] -ne $callBeforeWrong) "the incorrect sink sank [$($wrong.Balls -join ', ')] with ball $callBeforeWrong called"
    Assert-EbcEqual -Expected @($StartValue, $Uncalled, ($StartValue + $Step)) -Actual @($p1[0].Award, $wrong.Award, $p1[1].Award) -What "first success, incorrect sink of ball $($wrong.Balls -join ''), second success"
}
Test-EbcItem -Name 'The spoken ball''s numbered drop-target lamp flashes (targets 1-7 for solids) and the 5,000 lamp is not used for it' -Doc "$Doc; $Called" -Body {
    # The 5,000 drop target 3 lamp is dark while target 3 is up with ball 3
    # unsunk (original behavior: tests/compare/original-vs-deluxe-5000-lamp),
    # so a call of ball 3 must not light it.
    $seen = @("call $first -> flashing [$($f0.Flashing -join ', ')], 5,000 DT3 lit $($f0.Lamp5000)", "call $callBeforeWrong -> flashing [$($fAfter1.Flashing -join ', ')], 5,000 DT3 lit $($fAfter1.Lamp5000)", "call $callAfter3 -> flashing [$($fAfter3.Flashing -join ', ')], 5,000 DT3 lit $($fAfter3.Lamp5000)")
    $want = @("call $first -> flashing [$first], 5,000 DT3 lit 0", "call $callBeforeWrong -> flashing [$callBeforeWrong], 5,000 DT3 lit 0", "call $callAfter3 -> flashing [$callAfter3], 5,000 DT3 lit 0")
    Assert-EbcTrue (@(@($first, $callBeforeWrong, $callAfter3) | Where-Object { $_ -lt 1 -or $_ -gt 7 }).Count -eq 0) "solid calls $first, $callBeforeWrong, $callAfter3"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'numbered lamps flashing for each call (player 1, solids)'
}
Test-EbcItem -Name 'No sunk ball keeps the called indication' -Doc "$Doc; $Called" -Body {
    # Each sample is taken after a called sink; none of the balls sunk by then
    # may flash.
    $seen = @("after ball $($p1[0].Call): flashing sunk [$(@($fAfter1.Flashing | Where-Object { $_ -eq $p1[0].Call }) -join ', ')]",
              "after balls $(($p1[0..2] | ForEach-Object { $_.Call }) -join ', ') and $($wrong.Balls -join ''): flashing sunk [$(@($fAfter3.Flashing | Where-Object { $_ -in @($p1[0..2] | ForEach-Object { $_.Call }) + $wrong.Balls }) -join ', ')]")
    $want = @("after ball $($p1[0].Call): flashing sunk []", "after balls $(($p1[0..2] | ForEach-Object { $_.Call }) -join ', ') and $($wrong.Balls -join ''): flashing sunk []")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'sunk balls among the flashing numbered lamps'

}
Test-EbcItem -Name 'An incorrect sink leaves or moves the flash only as dictated by the next spoken call' -Doc "$Doc; $Called" -Body {
    $seen = "calls spoken after the incorrect sink [$($callsAfterWrong -join ', ')]; flashing [$($fWrong.Flashing -join ', ')]"
    $want = "calls spoken after the incorrect sink [$($callsAfterWrong -join ', ')]; flashing [$callAfterWrong]"
    Assert-EbcEqual -Expected $want -Actual $seen -What "flash after sinking ball $($wrong.Balls -join '') with ball $callBeforeWrong called"
}

# Rest of the rack, then the 8-ball.
while ((Get-EbcSunkBalls) -ne 0x7F) { $p1 += Invoke-CalledSink }
$eight1 = Invoke-EightBall
$fRack = Get-Flashing
$afterRack = Invoke-CalledSink
Test-EbcItem -Name 'The rack''s 8-ball awards the current Called ball value, then advances it by 5,000 playfield points (500)' -Doc "$Doc; $Called; $Display" -Body {
    # Each success before the 8-ball advanced the value once.
    $current = $eight1.Expected
    Assert-EbcEqual -Expected @([string]$current, ($current + $Step)) -Actual @(($eight1.Shown -join ', '), $afterRack.Award) -What "8-ball award shown after $($p1.Count) successes, then the new rack's first called sink"
}
Test-EbcItem -Name 'The new rack immediately calls and flashes ball 1 for solids, with no stale reminder delay or wrong target flash' -Doc "$Doc; $Called" -Body {
    $wait = $eight1.NextCall.Frame - $eight1.Kick
    $seen = "first call ball $($eight1.NextCall.Ball); 8-ball prompts after the kick $($eight1.EightPrompts); flashing [$($fRack.Flashing -join ', ')]; sooner than one reminder interval $($wait -lt $ReminderFrames)"
    $want = "first call ball 1; 8-ball prompts after the kick 0; flashing [1]; sooner than one reminder interval True"
    Write-Host "new rack (player 1): call $wait frames after the saucer kick; reminder interval $ReminderFrames frames"
    Assert-EbcEqual -Expected $want -Actual $seen -What "new rack (call $wait frames after the saucer kick; reminder interval $ReminderFrames frames)"
}
Invoke-EbcDrain | Out-Null

# ================= Player 2, ball 1 (stripes, 2x): a whole rack =================
Start-Turn
Set-Multiplier 2
$fP2 = Get-Flashing
$callP2 = Get-Call
$p2 = @()
while ((Get-EbcSunkBalls) -ne 0x7F) { $p2 += Invoke-CalledSink }
$eight2 = Invoke-EightBall                       # an 8-ball at 2x
$fRack2 = Get-Flashing
$p2 += Invoke-CalledSink
$p2 += Invoke-CalledSink                         # ten advances: the cap
Test-EbcItem -Name 'The first three successful called balls award 1,000/2,000/3,000 at 2x' -Doc "$Doc; $Called" -Body {
    Assert-EbcEqual -Expected $FirstThree[2] -Actual @($p2[0..2] | ForEach-Object { $_.Award }) -What "player 2's first three called sinks at 2x (balls $(($p2[0..2] | ForEach-Object { $_.Call }) -join ', '))"
}
Test-EbcItem -Name 'The spoken ball''s numbered drop-target lamp flashes (targets 9-15 for stripes)' -Doc "$Doc; $Called" -Body {
    Assert-EbcTrue ($callP2 -ge 9 -and $callP2 -le 15) "player 2's call is ball $callP2"
    Assert-EbcEqual -Expected @($callP2) -Actual $fP2.Flashing -What "numbered lamps flashing for call $callP2 (player 2, stripes)"
}
Test-EbcItem -Name 'The new rack immediately calls and flashes ball 9 for stripes' -Doc "$Doc; $Called" -Body {
    $wait = $eight2.NextCall.Frame - $eight2.Kick
    $seen = "first call ball $($eight2.NextCall.Ball); 8-ball prompts after the kick $($eight2.EightPrompts); flashing [$($fRack2.Flashing -join ', ')]; sooner than one reminder interval $($wait -lt $ReminderFrames)"
    $want = "first call ball 9; 8-ball prompts after the kick 0; flashing [9]; sooner than one reminder interval True"
    Assert-EbcEqual -Expected $want -Actual $seen -What "player 2's new rack (call $wait frames after the saucer kick)"
}
Invoke-EbcDrain | Out-Null

# ================= Player 3, ball 1 (solids, 3x) =================
Start-Turn
Set-Multiplier 3
$p3 = @(Invoke-CalledSink; Invoke-CalledSink; Invoke-CalledSink; Invoke-CalledSink)
Test-EbcItem -Name 'The first three successful called balls award 1,500/3,000/4,500 at 3x' -Doc "$Doc; $Called" -Body {
    Assert-EbcEqual -Expected $FirstThree[3] -Actual @($p3[0..2] | ForEach-Object { $_.Award }) -What "player 3's first three called sinks at 3x (balls $(($p3[0..2] | ForEach-Object { $_.Call }) -join ', '))"
}
Invoke-EbcDrain | Out-Null

# ================= Player 4, ball 1 (stripes, 1x) =================
Start-Turn
$p4 = @(Invoke-CalledSink)
Invoke-EbcDrain | Out-Null

# Each player's next value: 500 plus 500 per success (8-balls included).
$next = @{}
$next[1] = $StartValue + $Step * ($p1.Count + 2)    # p1 successes, the 8-ball and the new rack's sink
$next[2] = [Math]::Min($CapValue, $StartValue + $Step * ($p2.Count + 1))   # p2 sinks and the 8-ball
$next[3] = $StartValue + $Step * $p3.Count
$next[4] = $StartValue + $Step * $p4.Count
# ================= Ball 2 for players 1-4 =================
$ball2 = @{}
foreach ($pl in 1..4) {
    Start-Turn
    $ball2[$pl] = @(Invoke-CalledSink; Invoke-CalledSink)
    Invoke-EbcDrain | Out-Null
}
Test-EbcItem -Name 'In a four-player game each player''s Called ball value is restored independently after drains and other players'' turns' -Doc "$Doc; $Called" -Body {
    $seen = @(1..4 | ForEach-Object { "P$_ ball 2: first called sink $($ball2[$_][0].Award)" })
    $want = @(1..4 | ForEach-Object { "P$_ ball 2: first called sink $($next[$_])" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'first called sink of each player''s second ball at 1x'
}
Test-EbcItem -Name 'The value stops at 50,000 playfield (5,000 at 1x) without wrapping, reached by play' -Doc "$Doc; $Called" -Body {
    # Player 2 reached the cap on ball 1 (nine advances and more); both sinks award it.
    Assert-EbcEqual -Expected @($CapAward[1], $CapAward[1]) -Actual @($ball2[2] | ForEach-Object { $_.Award }) -What "player 2's two called sinks on ball 2 ($($p2.Count + 1) successes on ball 1)"
}

Complete-EbcGame | Out-Null

# ================= Game 2 =================
Start-EbcPlay -Players 4 | Out-Null
$script:Successes = @{ 1 = 0; 2 = 0; 3 = 0; 4 = 0 }
$game2 = @{}
foreach ($pl in 1..4) {
    Start-Turn
    $game2[$pl] = Invoke-CalledSink
    if ($pl -lt 4) { Invoke-EbcDrain | Out-Null }
}
Test-EbcItem -Name 'A new game returns all four Called ball values to 5,000 (500 displayed)' -Doc "$Doc; $Called" -Body {
    $seen = @(1..4 | ForEach-Object { "P${_}: first called sink $($game2[$_].Award)" })
    $want = @(1..4 | ForEach-Object { "P${_}: first called sink $StartValue" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'game 2, ball 1, first called sink of each player at 1x'
}

Test-EbcItem -Name 'Successful called balls and the collected 8-ball show their exact multiplied Called ball award' -Doc "$Doc; $Display; $Called" -Body {
    # Each expected award is the doc's (Add-DocAward): the player's value
    # from their earlier successes times the multiplier in force. A called
    # sink scores and shows it; an 8-ball shows it.
    $seen = @($script:Awards | ForEach-Object { Format-Sink $_ })
    $want = @($script:Awards | ForEach-Object {
        if ($_.Call -eq 8) { "{0}x 8-ball: shown [{1}]" -f $_.Multiplier, $_.Expected } else { "{0}x ball {1}: award {2}, shown [{2}]" -f $_.Multiplier, $_.Call, $_.Expected } })
    $eightAt = @($script:Awards | Where-Object { $_.Call -eq 8 } | ForEach-Object { "$($_.Multiplier)x" })
    Assert-EbcTrue (@($eightAt | Where-Object { $_ -ne '1x' }).Count -gt 0) "8-balls collected at [$($eightAt -join ', ')]: none above 1x"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'every successful called sink and 8-ball'
}

# ================= Seeded: Called ball at 50,000 =================
Test-EbcItem -Name 'With Called ball at 50,000 (seeded), successful calls and collected 8-balls award 5,000/10,000/15,000 at 1x/2x/3x without advancing or wrapping' -Doc "$Doc; $Called" -Seeded -Body {
    # Player 4, ball 1 of game 2 continues: the game's own state after nine
    # advances is 0A in the active byte and the player's record.
    $pl = [int](Get-EbcCurrentPlayer)
    Write-EbcRam -Address $ActiveCalled -Bytes @($CapUnits)
    Write-EbcRam -Address ($PlayerCalled + $pl - 1) -Bytes @($CapUnits)
    $script:Successes[$pl] = $CapUnits - 1
    $r = @()
    $r += Invoke-CalledSink
    $r += Invoke-CalledSink
    Set-Multiplier 2
    $r += Invoke-CalledSink
    Set-Multiplier 3
    while ((Get-EbcSunkBalls) -ne 0x7F) { $r += Invoke-CalledSink }
    $e = Invoke-EightBall
    $r += Invoke-CalledSink
    $seen = @($r | ForEach-Object { "$($_.Multiplier)x ball $($_.Call): $($_.Award)" }) + @("3x 8-ball shown: $($e.Shown -join ', ')", ('stored units {0:X2}' -f (Read-EbcByte $ActiveCalled)))
    $want = @($r | ForEach-Object { "$($_.Multiplier)x ball $($_.Call): $($CapAward[$_.Multiplier])" }) + @("3x 8-ball shown: $($CapAward[3])", ('stored units {0:X2}' -f $CapUnits))
    Assert-EbcEqual -Expected $want -Actual $seen -What 'awards at the cap'
}
Complete-EbcTests
