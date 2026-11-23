param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe orbits: unlit orbit shots, the active left and right collects (score,
# sound, arrow chase, value advance, value preview), the 100,000/Special
# terminal state, and collection in both the opening and repeating orbit
# stages, all by play on one player's first two balls.
#
# Each orbit collect needs the collect cycle (collect-cycle.tests.ps1): after
# it, the spinner is inactive; a newly sunk ball activates it; its first pulse
# moves the location to orbit inactive; the next newly sunk ball activates the
# orbit. The "current value" an active orbit shows is read from the orbit-value
# arrows (GameNames.psd1 Lamps 'Rollover Lanes ...'): the printed legends of
# the lit arrows add up to it.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Left = 'src/8bc-deluxe/gamerules.md "Left orbit"'
$Right = 'src/8bc-deluxe/gamerules.md "Right orbit"'
$Rules = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM"'
$Specials = 'src/8bc-deluxe/gamerules.md "Specials"'

# "Left orbit"/"Right orbit": an inactive orbit awards 500 with sound $31, the
# center rollover's sound.
$Unlit = 500
$CenterSound = 0x31
# "Required gameplay verification": the left collect advances the printed
# value by 10,000 (Deluxe 1,000), the right by 20,000 (Deluxe 2,000),
# saturating at 100,000/Special. A collect scores the current printed value
# / 10 ("Existing rules": printed 10,000 scores 1,000; 100,000 scores 10,000).
$LeftStep = 10000
$RightStep = 20000
$Terminal = 100000
# Activating promotes the 5,000 baseline to the printed 10,000.
$FirstValue = 10000
# "Left orbit": the active left collect keeps its "original single
# collect-sound path". The original ROM sends one command, $00: CB53 loads
# selector $29 into B and calls CAAA, which stores it at 1024 and calls F4DF;
# F4DF leaves B = (~103A) & C0, zero once the score gate passes; CB59-CB5B
# then do TBA / JSR C27E (src/originals/asm/modules, CB4F data bytes and
# CHECK_SCORE_GATE_LAMP_BITS). tests/compare/original-vs-deluxe-orbit-sound
# checks the Deluxe collect against the original ROM. "Right orbit": once
# maxed, the right collect uses that same left-orbit sound ("after the gate,
# the path preserves the same B state used by the working left-orbit collect
# sound"); before the terminal value it sends "$2A twice back-to-back".
$LeftSound = 0x00
$RightSound = 0x2A
# "Back-to-back": no other command between them and at most 30 frames apart
# (the brief's continuous-flow gap).
$BackToBackFrames = 30
# "Right orbit": the terminal collector's loud $6F is suppressed for this hit.
$SpecialSound = 0x6F
# "Specials": collecting any special also awards 25,000 at 1x, in addition to
# the orbit's own 10,000 ("Existing rules").
$SpecialPoints = 25000
# "approximately three seconds": FramesPerSecond x 3 +- 20%.
$Fps = (Get-EbcNames).FramesPerSecond
$BlinkMin = [int]($Fps * 3 * 0.8); $BlinkMax = [int]($Fps * 3 * 1.2)
# OPS manual p. 1-5 register 51, "Roll up lanes spcl flash with": 0 = 100K
# (fresh NVRAM holds FF and the special never lights; tests/originals/rollovers).
$SpecialRegister = 51
$SpecialSetting = 0
# The orbit preview timer (src/8bc-deluxe/asm/symbols.inc
# DELUXE_ORBIT_PREVIEW_TIMER, 1115), read only to find the frame the preview
# starts after the chase.
$PreviewTimer = 0x1115
# A spinner pulse: unlit 10 ("Spinner"); an active pulse starts spinner
# collecting, which stops after about two seconds without a pulse.
$SpinnerUnlit = 10
$SpinnerStopFrames = $Fps * 3

$ArrowValues = @(10000, 20000, 30000, 40000)
$ArrowLamps = @($ArrowValues | ForEach-Object { Get-EbcLampNumber ('Rollover Lanes {0:N0}' -f $_) })
$SpecialLamp = Get-EbcLampNumber 'Rollover Lanes Special'
$Knocker = Get-EbcSolenoid 'Knocker'
$LampSampleFrames = 32

$GroupOf = @{ 1 = 'Drop Target 1,2,9,10'; 2 = 'Drop Target 1,2,9,10'; 3 = 'Drop Target 3,11'; 4 = 'Drop Target 4,5,12,13'
              5 = 'Drop Target 4,5,12,13'; 6 = 'Drop Target 6,14'; 7 = 'Drop Target 7,15' }
$LatchOf = @{ 'Drop Target 1,2,9,10' = 0x01; 'Drop Target 3,11' = 0x04; 'Drop Target 4,5,12,13' = 0x08; 'Drop Target 6,14' = 0x20; 'Drop Target 7,15' = 0x40 }
$ResetBy = @{}
$standups = (Get-EbcNames).StandupDropGroups
foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }

# Sound commands since event index $Since, as [frame, byte] pairs. Speech
# prompts (41-80, HARDWARE_MAP response map) are kept apart from the sound
# commands a hit's clause names. libpinmame
# reports each command twice, the byte then the byte shifted right four
# (GameNames.psd1 Sounds), so the shifted copy is dropped.
function Get-Commands([int]$Since) {
    $ev = @(Get-EbcEvents -Since $Since | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $f = $_ -split ' '; [PSCustomObject]@{ F = [int]$f[0]; B = [int]$f[3] } })
    for ($i = 0; $i -lt $ev.Count; $i++) {
        $ev[$i]
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    }
}
function Format-Commands($c) { (@($c | ForEach-Object { '{0:X2}' -f $_.B }) -join ' ') }
# The printed value the lit arrows show (steady, sampled once).
function Get-ArrowValue { $v = 0; for ($k = 0; $k -lt 4; $k++) { if (Get-EbcLamp -Number $ArrowLamps[$k]) { $v += $ArrowValues[$k] } }; $v }
function Get-ArrowPattern { (@(0..3 | ForEach-Object { if (Get-EbcLamp -Number $ArrowLamps[$_]) { '#' } else { '.' } }) -join '') }
function Get-SpecialLit { $n = 0; for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; if (Get-EbcLamp -Number $SpecialLamp) { $n++ } }; $n }
function Format-Special([int]$n) { if ($n -eq 0) { 'dark' } elseif ($n -eq $LampSampleFrames) { 'steady' } else { 'flashing' } }

# A newly sunk ball: the lowest unsunk ball 1-7 (re-arming its group when
# down), or the lit 8-ball at the saucer once 1-7 are sunk.
function Invoke-NewSink {
    $sunk = Get-EbcSunkBalls
    $next = @(1..7 | Where-Object { -not ($sunk -band (1 -shl ($_ - 1))) })
    if (-not $next.Count) { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null; Step-EbcFrames -Frames 30; return }
    $g = $GroupOf[$next[0]]
    if ((Read-EbcByte (Get-EbcRamAddress 'DROP_TARGET_SWITCH_CLOSURE_LATCHES')) -band $LatchOf[$g]) { Invoke-EbcScoredHit $ResetBy[$g] -AfterSolenoid $g | Out-Null }
    Invoke-EbcScoredHit $g | Out-Null
    if ((Get-EbcSunkBalls) -eq $sunk) { throw "$g sank no new ball" }
}
# From spinner inactive to an active orbit: checks the spinner is unlit,
# activates it, takes its first pulse, waits for spinner collecting to end,
# and activates the orbit. Returns the unlit spinner score.
function Step-ToActiveOrbit {
    $unlit = Invoke-EbcScoredHit 'Spinner'
    Invoke-NewSink
    Invoke-EbcScoredHit 'Spinner' | Out-Null
    Step-EbcFrames -Frames $SpinnerStopFrames
    Invoke-NewSink
    Step-EbcFrames -Frames 30
    $unlit
}
# An active orbit collect, read frame by frame for $Frames frames from the
# closure, then settled. Returns the value shown before it, the score change,
# the sound commands, the arrow patterns per frame, the preview's start frame,
# the last frame an arrow was lit, and the knocker pulses.
function Invoke-Collect([string]$Side, [int]$Frames = 420) {
    $shown = Get-ArrowValue
    $p = [int](Get-EbcCurrentPlayer)
    $addr = Get-EbcRamAddress "ScoreBuffer$p"
    $read = { $t = Get-EbcScoreBufferText $addr; if ($t -eq '') { [long]0 } else { [long]$t } }
    $before = & $read
    $seen = Get-EbcEventCount
    $n = Get-EbcSwitch "$Side Rollover Button"
    $trace = @(); $previewAt = -1; $lastLit = -1
    for ($k = 0; $k -lt $Frames; $k++) {
        if ($k -eq 0) { Set-EbcSwitch -Number $n -Closed $true }
        if ($k -eq 4) { Set-EbcSwitch -Number $n -Closed $false }
        Step-EbcFrames -Frames 1
        $pat = Get-ArrowPattern
        $trace += $pat
        if ($previewAt -lt 0 -and (Read-EbcByte $PreviewTimer) -ne 0) { $previewAt = $k }
        if ($pat -ne '....') { $lastLit = $k }
    }
    # Settle: the pending score (0094-0099) empty and the score unchanged for
    # 150 frames, as Invoke-EbcScoredHit waits.
    $pendingAt = Get-EbcRamAddress 'PENDING_SCORE_10S'
    $last = & $read; $stable = 0
    for ($w = 0; $stable -lt 150; $w++) {
        if ($w -gt 3000) { throw "the $Side collect did not settle" }
        Step-EbcFrames -Frames 1
        $now = & $read
        if ($now -eq $last -and @(Read-EbcRam -Address $pendingAt -Count 6 | Where-Object { $_ -ne 0 }).Count -eq 0) { $stable++ } else { $stable = 0; $last = $now }
    }
    $all = @(Get-Commands $seen)
    [PSCustomObject]@{
        Side = $Side; Shown = $shown; Award = (& $read) - $before
        Commands = @($all | Where-Object { $_.B -lt 0x41 -or $_.B -gt 0x80 }); AllCommands = $all; Trace = $trace; PreviewAt = $previewAt; LastLit = $lastLit
        Knocks = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $Knocker 1$" }).Count
    }
}
# The chase: the four arrows light one at a time from 10,000 up to 40,000.
function Test-Chase($c) {
    $want = @('#...', '.#..', '..#.', '...#'); $i = 0
    foreach ($t in $c.Trace) { if ($i -lt 4 -and $t -eq $want[$i]) { $i++ } }
    $i -eq 4
}
# The preview: the arrows after the preview starts show one pattern, blinking.
# The lamp outputs lag the timer by a frame or two, so the chase's last arrow
# can still show at the preview's start; that leading run is skipped.
function Get-PreviewValue($c) {
    $tail = @($c.Trace[$c.PreviewAt..($c.Trace.Count - 1)])
    $chaseEnd = $c.Trace[$c.PreviewAt - 1]
    $final = @($tail | Where-Object { $_ -ne '....' })[-1]
    $i = 0; if ($chaseEnd -ne $final) { while ($i -lt $tail.Count -and $tail[$i] -eq $chaseEnd) { $i++ } }
    $pats = @($tail[$i..($tail.Count - 1)] | Where-Object { $_ -ne '....' } | Select-Object -Unique)
    if ($pats.Count -ne 1) { return "patterns [$($pats -join ', ')]" }
    $v = 0; for ($k = 0; $k -lt 4; $k++) { if ($pats[0][$k] -eq '#') { $v += $ArrowValues[$k] } }
    $v
}
function Get-BlinkFrames($c) { if ($c.PreviewAt -lt 0) { -1 } else { $c.LastLit - $c.PreviewAt + 1 } }
function Format-Collect($c) {
    "{0} collect of {1}: award {2}, chase {3}, preview shows {4}, arrows dark after {5}" -f $c.Side, $c.Shown, $c.Award, (Test-Chase $c), (Get-PreviewValue $c), ($c.Trace[-1] -eq '....')
}
function Want-Collect([string]$Side, [int]$From, [int]$To) {
    "{0} collect of {1}: award {2}, chase True, preview shows {3}, arrows dark after True" -f $Side, $From, ($From / 10), $To
}

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $SpecialRegister -Value $SpecialSetting | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

# ---- Ball 1: unlit shots at the opening orbit stage ----
$seen = Get-EbcEventCount
$center = Invoke-EbcScoredHit 'Center Rollover Button'
$centerCmds = @(Get-Commands $seen | Where-Object { $_.B -lt 0x41 -or $_.B -gt 0x80 })   # speech excluded
$unlitShots = @()
foreach ($side in 'Left', 'Right') {
    $seen = Get-EbcEventCount
    $d = Invoke-EbcScoredHit "$side Rollover Button"
    $unlitShots += [PSCustomObject]@{ Side = $side; Award = $d; Commands = @(Get-Commands $seen | Where-Object { $_.B -lt 0x41 -or $_.B -gt 0x80 }) }
}
# The first newly sunk ball activates the opening orbit stage.
Invoke-NewSink
Step-EbcFrames -Frames 30
$c = @()
$c += Invoke-Collect 'Left'                       # opening stage, 10K -> 20K
$spin = @(Step-ToActiveOrbit)
$c += Invoke-Collect 'Right'                      # repeating stage, 20K -> 40K
$spin += Step-ToActiveOrbit
$c += Invoke-Collect 'Right'                      # 40K -> 60K
$spin += Step-ToActiveOrbit
$c += Invoke-Collect 'Right'                      # 60K -> 80K
$spin += Step-ToActiveOrbit
$c += Invoke-Collect 'Left'                       # repeating stage, 80K -> 90K
$spin += Step-ToActiveOrbit
$c += Invoke-Collect 'Right'                      # 90K -> 100K, no wrap

Test-EbcItem -Name 'Unlit left and right orbit shots score 500 without advancing the value, with the center rollover''s sound ($31)' -Doc "$Doc; $Left; $Right" -Body {
    $seen = @("center rollover sounds [$(Format-Commands $centerCmds)]") + @($unlitShots | ForEach-Object { "$($_.Side) unlit: $($_.Award), sounds [$(Format-Commands $_.Commands)]" }) + @("first activation shows $($c[0].Shown)")
    $want = @(('center rollover sounds [{0:X2}]' -f $CenterSound)) + @('Left', 'Right' | ForEach-Object { "$_ unlit: $Unlit, sounds [{0:X2}]" -f $CenterSound }) + @("first activation shows $FirstValue")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'unlit orbit shots at the start of ball 1'
}
Test-EbcItem -Name 'The left rollover advances the printed value by 10,000 (Deluxe 1,000) and the right by 20,000 (Deluxe 2,000), each scoring the current value, finishing the upward arrow chase and hiding the arrows' -Doc "$Doc; $Left; $Right; $Rules" -Body {
    $seen = @($c | ForEach-Object { Format-Collect $_ })
    $want = @(
        (Want-Collect 'Left' $FirstValue ($FirstValue + $LeftStep)),
        (Want-Collect 'Right' 20000 (20000 + $RightStep)),
        (Want-Collect 'Right' 40000 (40000 + $RightStep)),
        (Want-Collect 'Right' 60000 (60000 + $RightStep)),
        (Want-Collect 'Left' 80000 (80000 + $LeftStep)),
        (Want-Collect 'Right' 90000 $Terminal))
    Assert-EbcEqual -Expected $want -Actual $seen -What 'collects on ball 1 (each value shown is the previous preview)'
}
Test-EbcItem -Name 'A right advance from 90,000 stops at 100,000/Special with no wrap' -Doc "$Doc; $Right" -Body {
    Assert-EbcEqual -Expected $Terminal -Actual (Get-PreviewValue $c[5]) -What 'value previewed after the right collect of 90,000 (90,000 + 20,000 saturates)'
}
Test-EbcItem -Name 'Every orbit collect moves the collect to spinner inactive' -Doc "$Doc; $Left; $Right" -Body {
    # Read by the first spinner pulse after each collect.
    Assert-EbcEqual -Expected (@($SpinnerUnlit) * $spin.Count) -Actual $spin -What 'spinner score after each collect'
}
Test-EbcItem -Name 'The active left collect uses only its original single collect sound' -Doc "$Doc; $Left" -Body {
    $seen = @($c | Where-Object { $_.Side -eq 'Left' } | ForEach-Object { "left collect of $($_.Shown): [$(Format-Commands $_.Commands)]" })
    $want = @($c | Where-Object { $_.Side -eq 'Left' } | ForEach-Object { "left collect of $($_.Shown): [{0:X2}]" -f $LeftSound })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'sound commands of each active left collect'
}
Test-EbcItem -Name 'The active right collect sends $2A twice back-to-back before the terminal value' -Doc "$Doc; $Right" -Body {
    $seen = @($c | Where-Object { $_.Side -eq 'Right' } | ForEach-Object {
        $r = @($_.Commands | Where-Object { $_.B -eq $RightSound })
        $first2 = @($_.Commands | Select-Object -First 2)
        $b2b = $r.Count -eq 2 -and $first2.Count -eq 2 -and $first2[0].B -eq $RightSound -and $first2[1].B -eq $RightSound -and ($first2[1].F - $first2[0].F) -le $BackToBackFrames
        "right collect of $($_.Shown): `$2A sent $($r.Count) times, first two commands back-to-back $b2b" })
    $want = @($c | Where-Object { $_.Side -eq 'Right' } | ForEach-Object { "right collect of $($_.Shown): `$2A sent 2 times, first two commands back-to-back True" })
    Assert-EbcEqual -Expected $want -Actual $seen -What "right collects below 100,000 (commands: $(($c | Where-Object { $_.Side -eq 'Right' } | ForEach-Object { '[' + (Format-Commands $_.Commands) + ']' }) -join ' '))"
}
Test-EbcItem -Name "The left and right advances blink the new value for about three seconds (timing window: $BlinkMin-$BlinkMax frames)" -Doc "$Doc; $Left; $Right" -Body {
    $seen = @($c | ForEach-Object { $f = Get-BlinkFrames $_; "$($_.Side) collect of $($_.Shown): " + $(if ($f -ge $BlinkMin -and $f -le $BlinkMax) { 'in window' } else { "$f frames" }) })
    $want = @($c | ForEach-Object { "$($_.Side) collect of $($_.Shown): in window" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'frames from the preview start to the last lit arrow'
}

# ---- The 100,000/Special terminal state ----
# At spinner inactive after the 90K -> 100K collect.
$specSpinner = Get-SpecialLit
$spin2 = Invoke-EbcScoredHit 'Spinner'
Invoke-NewSink                                  # spinner active
Invoke-EbcScoredHit 'Spinner' | Out-Null        # orbit inactive
Step-EbcFrames -Frames $SpinnerStopFrames
$specInactive = Get-SpecialLit
$seen = Get-EbcEventCount
$inactiveLeft = Invoke-EbcScoredHit 'Left Rollover Button'
$inactiveKnocks = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $Knocker 1$" }).Count
$specAfterInactive = Get-SpecialLit
Invoke-NewSink                                  # orbit active at 100K
Step-EbcFrames -Frames 30
$specActive = Get-SpecialLit
$special = Invoke-Collect 'Right'
$specAfterCollect = Get-SpecialLit
$spin3 = Step-ToActiveOrbit
$specRelit = Get-SpecialLit
$after = Invoke-Collect 'Left'

Test-EbcItem -Name 'An inactive left rollover at the retained 100,000/Special state scores only 500 and does not consume the special' -Doc "$Doc; $Left" -Body {
    $seen = "inactive left: $inactiveLeft, knocks $inactiveKnocks; special after it $(Format-Special $specAfterInactive), then $(Format-Special $specActive) once the orbit activates"
    $want = "inactive left: $Unlit, knocks 0; special after it dark, then flashing once the orbit activates"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'left rollover with the orbit inactive at 100,000'
}
Test-EbcItem -Name 'The special indication is hidden while neither orbit is active, blinks when the orbit activates, and hides again when that collect advances' -Doc "$Doc; $Left; $Right" -Body {
    $seen = "spinner inactive: $(Format-Special $specSpinner); orbit inactive: $(Format-Special $specInactive); orbit active: $(Format-Special $specActive); after the collect: $(Format-Special $specAfterCollect)"
    $want = 'spinner inactive: dark; orbit inactive: dark; orbit active: flashing; after the collect: dark'
    Assert-EbcEqual -Expected $want -Actual $seen -What 'Rollover Lanes Special lamp with 100,000 retained'
}
Test-EbcItem -Name 'The active orbit collects the printed 100,000/Special for 10,000 Deluxe points' -Doc "$Doc; $Rules; $Right; $Specials" -Body {
    # The orbit's 10,000 plus the 25,000 every special collect adds
    # ("Specials"), with the special award's knocker once and no $6F.
    $six = @($special.AllCommands | Where-Object { $_.B -eq $SpecialSound }).Count
    $seen = "value shown $($special.Shown); score $($special.Award); knocks $($special.Knocks); `$6F sent $six"
    $want = "value shown $Terminal; score $($Terminal / 10 + $SpecialPoints); knocks 1; `$6F sent 0"
    Assert-EbcEqual -Expected $want -Actual $seen -What "right collect at 100,000 (commands [$(Format-Commands $special.Commands)])"
}
Test-EbcItem -Name 'At 100,000 the right collect uses the left collect''s single sound, without $2A or $6F' -Doc "$Doc; $Right" -Body {
    $leftCmds = Format-Commands @($c | Where-Object { $_.Side -eq 'Left' } | Select-Object -First 1).Commands
    $six = @($special.AllCommands | Where-Object { $_.B -eq $SpecialSound }).Count
    $seen = "commands [$(Format-Commands $special.Commands)], `$6F sent $six"
    Assert-EbcEqual -Expected "commands [$leftCmds], `$6F sent 0" -Actual $seen -What 'right collect at 100,000 against the first left collect'
    Assert-EbcEqual -Expected ('{0:X2}' -f $LeftSound) -Actual $leftCmds -What 'the left collect''s commands'
}
Test-EbcItem -Name 'A right advance from 100,000 stays at 100,000/Special, and a later orbit activation restores 100,000' -Doc "$Doc; $Right; $Left" -Body {
    # The special was collected, so it is not relit this ball ("Left orbit":
    # the 10A0 latch); the value still scores.
    $seen = "preview after the right collect of 100,000: $(Get-PreviewValue $special); spinner $spin3; next activation shows $($after.Shown), special $(Format-Special $specRelit); left collect scores $($after.Award)"
    $want = "preview after the right collect of 100,000: $Terminal; spinner $SpinnerUnlit; next activation shows $Terminal, special dark; left collect scores $($Terminal / 10)"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'after the 100,000 collect'
}

# ---- Ball 2: the right rollover collects the opening stage ----
Invoke-EbcDrain | Out-Null
Step-EbcFrames -Frames 120
Invoke-EbcScoredHit 'Rebound' | Out-Null
Invoke-NewSink
Step-EbcFrames -Frames 30
$open = Invoke-Collect 'Right'
$spin4 = Invoke-EbcScoredHit 'Spinner'
Test-EbcItem -Name 'Either rollover collects during both the opening and the repeating active orbit stages' -Doc "$Doc; $Left; $Right" -Body {
    # Ball 1: left in the opening stage, right and left in the repeating
    # stage (above). Ball 2: right in the opening stage, scoring the value its
    # arrows show, then spinner inactive.
    $seen = "opening right collect: shows a value $($open.Shown -ge $FirstValue), award = shown / 10 $($open.Award -eq $open.Shown / 10), chase $(Test-Chase $open); spinner $spin4"
    $want = "opening right collect: shows a value True, award = shown / 10 True, chase True; spinner $SpinnerUnlit"
    Assert-EbcEqual -Expected $want -Actual $seen -What "ball 2 opening stage (shown $($open.Shown), award $($open.Award))"
}
Complete-EbcTests
