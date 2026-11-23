param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe spinner: its value steps and lamps, the active score at 1x/2x/3x,
# the unlit 10, the score/sound tiers, the E-I-G-H-T letter awards and
# advances, the value preview, spinner collecting and its stop timer, all by
# play on one player's first ball.
#
# The collect cycle (collect-cycle.tests.ps1): a newly sunk ball activates the
# current location; an orbit collect moves it to spinner inactive; the first
# active-spinner pulse moves it to orbit inactive and starts spinner
# collecting. Each spinner activation below is reached that way. A drop group
# is down after its drop target is hit, and its E-I-G-H-T standup raises it
# again (GameNames.psd1 StandupDropGroups); a standup hit counts as a letter
# only while its group is down, and hitting a group whose balls are already
# sunk lowers it without a new sink (measured, sunk-ball-awards.tests.ps1).
# The 8-ball collection starts a new rack and raises every group (measured).
# The spinner value is read from its three value lamps (GameNames.psd1 Lamps
# 'Spinner 1,000/3,000/5,000'): the printed legends of the lit lamps add up to
# it, the doc's binary counter.
# Clauses of gamerules.md "Required gameplay verification" checked here
# (tools/tests/Test-DeluxeCoverage.ps1):
# Clause: Verify spinner values and lamps
# Clause: Verify activating spinner collect or
# Clause: With spinner collect inactive
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Spin = 'src/8bc-deluxe/gamerules.md "Spinner"'
$Rules = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM"'
$Collect = 'src/8bc-deluxe/gamerules.md "Deluxe collect feature"'

# "Spinner": an unlit spinner scores 10 per spin without the multiplier.
$Unlit = 10
# "Spinner": the printed sequence 1,000 -> 3,000 -> 4,000 -> 5,000 -> 6,000
# -> 8,000 -> 9,000 awards 100 -> 300 -> 400 -> 500 -> 600 -> 800 -> 900 and
# stays at 900; it begins at the printed 1,000 every ball.
$Printed = @(1000, 3000, 4000, 5000, 6000, 8000, 9000)
$Award = @(100, 300, 400, 500, 600, 800, 900)
# "Required gameplay verification": the score / original-sound tiers are
# 10 -> 100 sound, 100 -> 1K sound, 300/400 -> 3K sound, 500/600/800/900 ->
# 5K sound. "Original" means the command the original ROM sends for that
# award. The original spinner (CA3B) queues 2E for its 5,000 lamp and
# decrements it once per lower tier: 2D for 3,000, 2C for 1,000, 2B for 100
# (src/originals/asm/modules/20_scoring_and_switch_rules.asm, data at CA3B);
# measured on the original ROM, each spin sends that byte as its only sound
# command (register 49 = 0 for the 100 spin, then the 1,000, 3,000 and 5,000
# lamps). tests/compare/original-vs-deluxe-spinner-sound.tests.ps1 checks the
# Deluxe tiers against the original ROM.
$Sound100 = 0x2B; $Sound1K = 0x2C; $Sound3K = 0x2D; $Sound5K = 0x2E
$TierSound = @{ 10 = $Sound100; 100 = $Sound1K; 300 = $Sound3K; 400 = $Sound3K; 500 = $Sound5K; 600 = $Sound5K; 800 = $Sound5K; 900 = $Sound5K }
# "Required gameplay verification": every dedicated E-I-G-H-T target hit
# awards 250 at 1x, 500 at 2x, 750 at 3x.
$LetterAward = @{ 1 = 250; 2 = 500; 3 = 750 }
# CHAMP completions 2 and 4 light 2x and 3x (gamerules.md "CHAMP").
# "about three seconds" / "about two seconds": FramesPerSecond x 3 or x 2,
# +- 20% (the brief's timing windows).
$Fps = (Get-EbcNames).FramesPerSecond
$PreviewMin = [int]($Fps * 3 * 0.8); $PreviewMax = [int]($Fps * 3 * 1.2)
$StopMin = [int]($Fps * 2 * 0.8); $StopMax = [int]($Fps * 2 * 1.2)
# Pulses 40 frames apart keep spinning; four of them span 160 frames, longer
# than the longest stop the doc allows ($StopMax), so they score only if each
# refreshes the timer. A pulse $StopMin - 1 frames after the last is still
# within "roughly two seconds"; one $StopMax + 6 frames after is past it.
$RefreshGap = 40
$GapsAt100 = @(0, $RefreshGap, $RefreshGap, $RefreshGap, $RefreshGap, ($StopMin - 1), ($StopMax + 6))
# Register 49 (OPS manual p. 1-5, "Spinner start at": 1 = 1000 points). The
# doc starts every ball at the printed 1,000; the setting is made explicit.
$StartRegister = 49
$StartSetting = 1
# Timers read only, to find frames: the spinner preview (src/8bc-deluxe/asm/
# symbols.inc DELUXE_SPINNER_PREVIEW_TIMER, 1114) and spinner collecting
# (DELUXE_SPINNER_COLLECTING_TIMER, 10FC).
$PreviewTimer = 0x1114
$CollectingTimer = 0x10FC
# Frames read after a letter hit: past any preview.
$WatchFrames = [int]($Fps * 3 * 1.2) + 90
# The preview's unlit pulse comes this many frames after the preview starts.
$PulseIntoPreview = 40
# A sink closes this many frames after the first active pulse (spinner
# collecting).
$SinkAfterPulse = 20
$SinkAfterReset = 12

$SpinValues = @(1000, 3000, 5000)
$SpinLamps = @($SpinValues | ForEach-Object { Get-EbcLampNumber ('Spinner {0:N0}' -f $_) })
$ArrowLamps = @(10000, 20000, 30000, 40000 | ForEach-Object { Get-EbcLampNumber ('Rollover Lanes {0:N0}' -f $_) })
$BallB = Get-EbcLampNumber 'Ball "B"'
$LampSampleFrames = 32
$standups = (Get-EbcNames).StandupDropGroups
$ResetBy = @{}; foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }
$LetterOf = @{ E = 'Drop Target "E"'; I = 'Drop Target "I"'; G = 'Drop Target "G"'; H = 'Drop Target "H"'; T = 'Drop Target "T"' }

function Get-Pattern($Lamps) { (@($Lamps | ForEach-Object { if (Get-EbcLamp -Number $_) { '#' } else { '.' } }) -join '') }
function ConvertTo-Spin([string]$p) { $v = 0; for ($k = 0; $k -lt 3; $k++) { if ($p[$k] -eq '#') { $v += $SpinValues[$k] } }; $v }
# The value the spinner lamps show, sampled for $LampSampleFrames frames:
# the value when the lamps are steady, else 'blinking' or 'dark'.
function Get-SpinShown {
    $pats = @(@(for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; Get-Pattern $SpinLamps }) | Select-Object -Unique)
    if ($pats.Count -eq 1) { if ($pats[0] -eq '...') { 'dark' } else { ConvertTo-Spin $pats[0] } } else { 'blinking' }
}
function Get-ArrowsLit { (Get-Pattern $ArrowLamps) -ne '....' }
function Get-Multiplier { $c = Get-EbcChampState; if ($c -band 0x20) { 3 } elseif ($c -band 0x10) { 2 } else { 1 } }
function Get-Score { $t = Get-EbcScoreBufferText (Get-EbcRamAddress ("ScoreBuffer{0}" -f (Get-EbcCurrentPlayer))); if ($t -eq '') { [long]0 } else { [long]$t } }
function Get-Pending { @(Read-EbcRam -Address (Get-EbcRamAddress 'PENDING_SCORE_10S') -Count 6 | Where-Object { $_ -ne 0 }).Count }
# The score plus the pending score not yet counted onto it. Deluxe moves the
# pending queues 0094-0099 down one display digit (gamerules.md "Deluxe score
# scale"); measured: a 250 letter award holds 05 at 0095 and 02 at 0096.
function Get-Total { $p = Read-EbcRam -Address (Get-EbcRamAddress 'PENDING_SCORE_10S') -Count 6; $t = Get-Score; $w = 1; foreach ($d in $p) { $t += $d * $w; $w *= 10 }; $t }
# Sound commands since event index $Since, each once (libpinmame also reports
# the byte shifted right four, GameNames.psd1 Sounds), speech prompts 41-80
# (HARDWARE_MAP response map) excluded.
function Get-Commands([int]$Since) {
    $ev = @(Get-EbcEvents -Since $Since | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $f = $_ -split ' '; [PSCustomObject]@{ F = [int]$f[0]; B = [int]$f[3] } })
    for ($i = 0; $i -lt $ev.Count; $i++) {
        if ($ev[$i].B -lt 0x41 -or $ev[$i].B -gt 0x80) { '{0:X2}' -f $ev[$i].B }
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    }
}
function Wait-Settled([int]$Frames = 30, [int]$MaxFrames = 3000) {
    $last = Get-Score; $stable = 0
    for ($w = 0; $stable -lt $Frames; $w++) {
        if ($w -gt $MaxFrames) { throw "the score did not settle within $MaxFrames frames (frame $(Get-EbcFrame))" }
        Step-EbcFrames -Frames 1
        $now = Get-Score
        if ($now -eq $last -and (Get-Pending) -eq 0) { $stable++ } else { $stable = 0; $last = $now }
    }
}
# Spinner pulses: the first closes now, each later one $Gaps[i] frames after
# the previous closure (each held 4 frames). Each pulse's score is the change
# in the score plus pending score (Get-Total) from its closure to the next
# closure (or to the settled score). Optionally closes $Sink $SinkAt
# frames after the first closure. Records the collecting timer and the orbit
# arrows every frame.
function Invoke-Pulses([int[]]$Gaps, [string]$Sink, [int]$SinkAt = -1) {
    $at = @(); $t = 0; foreach ($g in $Gaps) { $t += $g; $at += $t }
    $end = [Math]::Max($at[-1], $SinkAt) + 8
    $n = Get-EbcSwitch 'Spinner'
    $scores = @(); $seen = @(); $timer = @(); $arrows = @()
    for ($k = 0; $k -le $end; $k++) {
        $i = [Array]::IndexOf($at, $k)
        if ($i -ge 0) { $scores += Get-Total; $seen += Get-EbcEventCount; Set-EbcSwitch -Number $n -Closed $true }
        if ([Array]::IndexOf($at, $k - 4) -ge 0) { Set-EbcSwitch -Number $n -Closed $false }
        if ($Sink -and $k -eq $SinkAt) { $atSink = Get-Total; Set-EbcSwitch -Number (Get-EbcSwitch $Sink) -Closed $true }
        if ($Sink -and $k -eq $SinkAt + 4) { Set-EbcSwitch -Number (Get-EbcSwitch $Sink) -Closed $false }
        Step-EbcFrames -Frames 1
        $timer += Read-EbcByte $CollectingTimer
        $arrows += Get-ArrowsLit
    }
    $tail = Get-EbcEventCount
    Wait-Settled
    $scores += $(if ($Sink) { $atSink } else { Get-Total }); $seen += $tail
    $out = @()
    for ($i = 0; $i -lt $at.Count; $i++) {
        $out += [PSCustomObject]@{ At = $at[$i]; Score = $scores[$i + 1] - $scores[$i]; Sounds = (@(Get-Commands $seen[$i] | Select-Object -First 1) -join ' '); AllSounds = (@(Get-Commands $seen[$i]) -join ' ') }
    }
    [PSCustomObject]@{ Pulses = $out; Timer = $timer; Arrows = $arrows; At = $at }
}
# One pulse: score and its sound commands (until the next action).
function Invoke-Pulse { $r = Invoke-Pulses @(0); Step-EbcFrames -Frames 30; $r.Pulses[0] }
# Steps until spinner collecting has ended (the collecting timer at 0), then
# 30 frames more.
function Wait-SpinnerStopped { for ($k = 0; (Read-EbcByte $CollectingTimer) -ne 0; $k++) { if ($k -gt 1200) { throw 'spinner collecting did not end within 1,200 frames' }; Step-EbcFrames -Frames 1 }; Step-EbcFrames -Frames 30 }
# A newly sunk ball through $Group; throws if it sank nothing new.
function Invoke-Sink([string]$Group) {
    $sunk = Get-EbcSunkBalls
    Invoke-EbcScoredHit $Group | Out-Null
    if ((Get-EbcSunkBalls) -eq $sunk) { throw "$Group sank no new ball (10C3 $('{0:X2}' -f $sunk))" }
    Step-EbcFrames -Frames 30
}
function Invoke-EightBall { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null; Step-EbcFrames -Frames 30 }
function Invoke-OrbitCollect { $d = Invoke-EbcScoredHit 'Left Rollover Button'; Step-EbcFrames -Frames 30; $d }
# A letter hit: its score; it lowers nothing and raises its group.
function Invoke-Letter([string]$L) { $d = Invoke-EbcScoredHit $LetterOf[$L] -AfterSolenoid $standups[$LetterOf[$L]]; $d }
# A letter hit with a per-frame record of the spinner lamps and the preview
# timer for $WatchFrames frames. With -Pulse, one spinner pulse closes
# $PulseIntoPreview frames after the preview starts; with -Sink, $Sink closes
# $SinkAfterReset frames after the group's reset pulse (measured: the standup's
# handler takes no drop closure for about 8 frames after the pulse, and one
# 12 frames after it sinks the ball).
function Watch-Letter([string]$L, [switch]$Pulse, [string]$Sink) {
    $sw = Get-EbcSwitch $LetterOf[$L]
    $resetPattern = '^\d+ sol {0} 1$' -f (Get-EbcSolenoid $standups[$LetterOf[$L]])
    $seen = Get-EbcEventCount
    $before = Get-Score
    $pats = @(); $timer = @(); $start = -1; $reset = -1; $pulseAt = -1; $sinkAt = -1; $pulseScore = $null; $pulseSounds = ''
    $spinSw = Get-EbcSwitch 'Spinner'
    for ($k = 0; $k -lt $WatchFrames; $k++) {
        if ($k -eq 0) { Set-EbcSwitch -Number $sw -Closed $true }
        if ($k -eq 4) { Set-EbcSwitch -Number $sw -Closed $false }
        if ($Pulse -and $start -ge 0 -and $k -eq $start + $PulseIntoPreview) {
            $pulseAt = $k; $pulseBefore = Get-Total; $pulseSeen = Get-EbcEventCount; Set-EbcSwitch -Number $spinSw -Closed $true
        }
        if ($pulseAt -ge 0 -and $k -eq $pulseAt + 4) { Set-EbcSwitch -Number $spinSw -Closed $false }
        if ($pulseAt -ge 0 -and $k -eq $pulseAt + 30) { $pulseScore = (Get-Total) - $pulseBefore; $pulseSounds = (@(Get-Commands $pulseSeen) -join ' ') }
        if ($Sink -and $sinkAt -lt 0 -and $start -ge 0 -and $reset -ge 0 -and $k -eq $reset + $SinkAfterReset) { $sinkAt = $k; $atSink = Get-Total; Set-EbcSwitch -Number (Get-EbcSwitch $Sink) -Closed $true }
        if ($sinkAt -ge 0 -and $k -eq $sinkAt + 4) { Set-EbcSwitch -Number (Get-EbcSwitch $Sink) -Closed $false }
        Step-EbcFrames -Frames 1
        $pats += Get-Pattern $SpinLamps
        $timer += Read-EbcByte $PreviewTimer
        if ($start -lt 0 -and $timer[-1] -ne 0) { $start = $k }
        if ($reset -lt 0 -and @(Get-EbcEvents -Since $seen | Where-Object { $_ -match $resetPattern }).Count) { $reset = $k }
    }
    Wait-Settled
    $letterScore = if ($sinkAt -ge 0) { $atSink - $before } else { (Get-Score) - $before - $(if ($null -ne $pulseScore) { $pulseScore } else { 0 }) }
    [PSCustomObject]@{ Letter = $L; Score = $letterScore; Pats = $pats; Timer = $timer; Start = $start; PulseAt = $pulseAt; PulseScore = $pulseScore; PulseSounds = $pulseSounds; SinkAt = $sinkAt }
}
# Lit runs of the preview: frames from the preview start to each run's first
# lit frame, and its length.
function Get-LitRuns($w) {
    $runs = [Collections.Generic.List[object]]::new(); $run = -1
    for ($k = $w.Start; $k -lt $w.Pats.Count; $k++) {
        $lit = $w.Pats[$k] -ne '...'
        if ($lit -and $run -lt 0) { $run = $k }
        if (-not $lit -and $run -ge 0) { $runs.Add([PSCustomObject]@{ From = $run - $w.Start; Len = $k - $run }); $run = -1 }
    }
    if ($run -ge 0) { $runs.Add([PSCustomObject]@{ From = $run - $w.Start; Len = $w.Pats.Count - $run }) }
    $runs.ToArray()
}
function Format-Runs($w) { (@(Get-LitRuns $w | ForEach-Object { "$($_.From)+$($_.Len)" }) -join ' ') }
# Frames from the preview start to its last lit frame.
function Get-PreviewFrames($w) { $r = @(Get-LitRuns $w); if (-not $r.Count) { 0 } else { $r[-1].From + $r[-1].Len } }
function Get-PreviewValues($w) { @($w.Pats[$w.Start..($w.Pats.Count - 1)] | Where-Object { $_ -ne '...' } | Select-Object -Unique | ForEach-Object { ConvertTo-Spin $_ }) }

$script:Shown = [ordered]@{}      # activation -> value shown
$script:Collected = @()           # active pulses: value, multiplier, score, sound
$script:Letters = @()             # letter hits: letter, multiplier, score, advanced
function Add-Collect([int]$Value, $p) { $script:Collected += [PSCustomObject]@{ Value = $Value; M = (Get-Multiplier); Score = $p.Score; Sound = $p.Sounds } }
function Get-Value { [int](ConvertTo-Spin (Get-Pattern $SpinLamps)) }
# The spinner value as the game holds it, read from DELUXE_SPINNER_VALUE_MASK
# (10FE bits 20/40/80 = the 1,000/3,000/5,000 lamps, symbols.inc) only to
# record whether a letter advanced it; every expectation reads the lamps.
function Get-HeldValue { $m = Read-EbcByte 0x10FE; $v = 0; if ($m -band 0x20) { $v += 100 }; if ($m -band 0x40) { $v += 300 }; if ($m -band 0x80) { $v += 500 }; $v }
function Add-Letter([string]$L, [int]$Score, [int]$Before) { $script:Letters += [PSCustomObject]@{ Letter = $L; M = (Get-Multiplier); Score = $Score; Before = $Before; After = (Get-HeldValue) } }
function Invoke-LetterRecorded([string]$L) { $b = Get-HeldValue; $d = Invoke-Letter $L; Add-Letter $L $d $b; Step-EbcFrames -Frames $WatchFrames }

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $StartRegister -Value $StartSetting | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

# ---- Ball 1, rack 1, at 1x ----
$unlitOrbitInactive = Invoke-Pulse                                  # orbit inactive
Invoke-Sink 'Drop Target 1,2,9,10'                                  # ball 1: orbit active
Invoke-OrbitCollect | Out-Null                                      # spinner inactive
$unlitSpinnerInactive = Invoke-Pulse
Invoke-Sink 'Drop Target 3,11'                                      # ball 3: spinner active
$script:Shown['100'] = Get-SpinShown
$seq100 = Invoke-Pulses $GapsAt100                                  # collecting, refresh, stop
Add-Collect 100 $seq100.Pulses[0]
Wait-SpinnerStopped
$unlitStopped = Invoke-Pulse                                        # orbit inactive again
Invoke-Sink 'Drop Target 4,5,12,13'                                 # ball 4: orbit active
$b = Get-HeldValue
$p1 = Watch-Letter 'I' -Pulse                                       # 100 -> 300, preview with an unlit pulse
Add-Letter 'I' $p1.Score $b
Invoke-OrbitCollect | Out-Null                                      # spinner inactive
Invoke-Sink 'Drop Target 1,2,9,10'                                  # ball 2: spinner active
$script:Shown['300'] = Get-SpinShown
$seq300 = Invoke-Pulses @(0) -Sink 'Drop Target 6,14' -SinkAt $SinkAfterPulse   # ball 6 before the spinner stops
Add-Collect 300 $seq300.Pulses[0]
Wait-SpinnerStopped
$arrowsAfterStop = Get-ArrowsLit
$orbitAfterStop = Invoke-OrbitCollect                               # the orbit is still active: spinner inactive
$b = Get-HeldValue
$p2 = Watch-Letter 'H' -Sink 'Drop Target 4,5,12,13'                # 300 -> 400 preview; ball 5 activates the spinner
Add-Letter 'H' $p2.Score $b
$script:Shown['400'] = Get-SpinShown
$p = Invoke-Pulse; Add-Collect 400 $p
Wait-SpinnerStopped
Invoke-Sink 'Drop Target 7,15'                                      # ball 7: orbit active
$b = Get-HeldValue
$p3 = Watch-Letter 'G'                                              # 400 -> 500 preview
Add-Letter 'G' $p3.Score $b
Invoke-OrbitCollect | Out-Null                                      # spinner inactive
Invoke-EightBall                                                    # the 8-ball: spinner active, new rack
$script:Shown['500'] = Get-SpinShown
$p = Invoke-Pulse; Add-Collect 500 $p
Wait-SpinnerStopped

# ---- Rack 2 ----
Invoke-Sink 'Drop Target 6,14'                                      # orbit active
Invoke-LetterRecorded 'E'                                           # 500 -> 600
Invoke-EbcScoredHit 'Drop Target 6,14' | Out-Null                   # ball already sunk: lowers the group only
Invoke-LetterRecorded 'E'                                           # already lit this round
Invoke-OrbitCollect | Out-Null                                      # spinner inactive
Invoke-Sink 'Drop Target 7,15'                                      # spinner active
$script:Shown['600'] = Get-SpinShown
$p = Invoke-Pulse; Add-Collect 600 $p
Wait-SpinnerStopped
$ballBBefore = 0; for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; if (Get-EbcLamp -Number $BallB) { $ballBBefore++ } }
Invoke-LetterRecorded 'T'                                           # 600 -> 800, completes E-I-G-H-T
$ballBAfter = 0; for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; if (Get-EbcLamp -Number $BallB) { $ballBAfter++ } }
Invoke-Sink 'Drop Target 1,2,9,10'                                  # orbit active
Invoke-OrbitCollect | Out-Null                                      # spinner inactive
Invoke-Sink 'Drop Target 3,11'                                      # spinner active
$script:Shown['800'] = Get-SpinShown
$p = Invoke-Pulse; Add-Collect 800 $p
Wait-SpinnerStopped

# ---- 2x ----
Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null
Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null
$b = Get-HeldValue
$p4 = Watch-Letter 'G' -Pulse                                       # round 2: 800 -> 900, preview at 2x with an unlit pulse
Add-Letter 'G' $p4.Score $b
Invoke-Sink 'Drop Target 4,5,12,13'                                 # orbit active
Invoke-LetterRecorded 'I'                                           # a new letter at 900
Invoke-OrbitCollect | Out-Null                                      # spinner inactive
$unlit2x = Invoke-Pulse
Invoke-Sink 'Drop Target 1,2,9,10'                                  # spinner active
$script:Shown['900'] = Get-SpinShown
$seq2x = Invoke-Pulses @(0, $RefreshGap, $RefreshGap)
Add-Collect 900 $seq2x.Pulses[0]
Wait-SpinnerStopped

# ---- 3x ----
Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null
Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null
Invoke-LetterRecorded 'H'                                           # round 2, group 28 down
Invoke-Sink 'Drop Target 4,5,12,13'                                 # orbit active
Invoke-OrbitCollect | Out-Null                                      # spinner inactive
$unlit3x = Invoke-Pulse
Invoke-EightBall                                                    # spinner active
$seq3x = Invoke-Pulses @(0, $RefreshGap, $RefreshGap)
Add-Collect 900 $seq3x.Pulses[0]

$Letters = $script:Letters
$Collected = $script:Collected
# The collecting timer's end after the 100 sequence's last lit pulse, in
# frames from that pulse's closure (read only, reported with the stop item).
$lastLit = @($seq100.Pulses | Where-Object { $_.Score -eq 100 })[-1].At
$stopFrames = -1; for ($k = $lastLit; $k -lt $seq100.Timer.Count; $k++) { if ($seq100.Timer[$k] -eq 0) { $stopFrames = $k - $lastLit + 1; break } }
Write-Host ("spinner collecting ended {0} frames after the last lit pulse (DELUXE_SPINNER_COLLECTING_TICKS 78 at 2 ticks per frame); previews lit runs (from the letter's closure, +frames): I [{1}], G [{2}], G at 2x [{3}]" -f $stopFrames, (Format-Runs $p1), (Format-Runs $p3), (Format-Runs $p4))

Test-EbcItem -Name 'Spinner values and lamps advance through the weighted binary states (printed 1,000 -> 3,000 -> 4,000 -> 5,000 -> 6,000 -> 8,000 -> 9,000, scoring 100 -> 300 -> 400 -> 500 -> 600 -> 800 -> 900), and the visible lamp combinations include both 8K and 9K' -Doc "$Doc; $Spin" -Body {
    # The value each activation shows (one new letter between activations),
    # and the first pulse's score at that value.
    $seen = @($script:Shown.Keys | ForEach-Object { $v = [int]$_; $c = @($Collected | Where-Object { $_.Value -eq $v })[0]; "shown $($script:Shown[$_]), first pulse $($c.Score) at $($c.M)x" })
    $want = @(for ($i = 0; $i -lt 7; $i++) { $m = @($Collected | Where-Object { $_.Value -eq $Award[$i] })[0].M; "shown $($Printed[$i]), first pulse $($Award[$i] * $m) at ${m}x" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'spinner lamps at each activation and the first active pulse'
}
Test-EbcItem -Name 'Active spins receive 2x/3x' -Doc "$Doc; $Spin" -Body {
    $seen = @($seq2x.Pulses | ForEach-Object { "2x: $($_.Score)" }) + @($seq3x.Pulses | ForEach-Object { "3x: $($_.Score)" })
    $want = @(1..3 | ForEach-Object { "2x: $(900 * 2)" }) + @(1..3 | ForEach-Object { "3x: $(900 * 3)" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'active pulses at 900 (first, then two continuing)'
}
Test-EbcItem -Name 'An unlit spin remains 10' -Doc "$Doc; $Spin" -Body {
    $seen = @("orbit inactive: $($unlitOrbitInactive.Score)", "spinner inactive: $($unlitSpinnerInactive.Score)", "after spinner collecting ended: $($unlitStopped.Score)", "during the preview: $($p1.PulseScore)", "during the preview at 2x: $($p4.PulseScore)", "spinner inactive at 2x: $($unlit2x.Score)", "spinner inactive at 3x: $($unlit3x.Score)")
    $want = @("orbit inactive: $Unlit", "spinner inactive: $Unlit", "after spinner collecting ended: $Unlit", "during the preview: $Unlit", "during the preview at 2x: $Unlit", "spinner inactive at 2x: $Unlit", "spinner inactive at 3x: $Unlit")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'unlit spinner pulses'
}
Test-EbcItem -Name 'The score / original-sound tiers are 10 -> 100 sound, 100 -> 1K sound, 300/400 -> 3K sound, and 500/600/800/900 -> 5K sound' -Doc "$Doc; $Spin" -Body {
    $seen = @("unlit 10: [$($unlitOrbitInactive.Sounds)]", "unlit 10 during the preview: [$($p1.PulseSounds)]") + @($Collected | ForEach-Object { "$($_.Value) at $($_.M)x: [$($_.Sound)]" })
    $want = @(('unlit 10: [{0:X2}]' -f $Sound100), ('unlit 10 during the preview: [{0:X2}]' -f $Sound100)) + @($Collected | ForEach-Object { "$($_.Value) at $($_.M)x: [{0:X2}]" -f $TierSound[$_.Value] })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'first sound command of each pulse (speech excluded)'
}
Test-EbcItem -Name 'Activating spinner collect or sinking a pool ball does not advance its accumulated value' -Doc "$Doc; $Spin" -Body {
    # The previews show each letter's new value; the next activation (after
    # one or more sinks) shows that same value.
    $seen = @("I preview [$((Get-PreviewValues $p1) -join ', ')], then shown $($script:Shown['300'])", "H preview cancelled by the activating sink, then shown $($script:Shown['400'])", "G preview [$((Get-PreviewValues $p3) -join ', ')], then shown $($script:Shown['500'])", "G preview at 2x [$((Get-PreviewValues $p4) -join ', ')], then shown $($script:Shown['900'])")
    $want = @("I preview [3000], then shown 3000", "H preview cancelled by the activating sink, then shown 4000", "G preview [5000], then shown 5000", "G preview at 2x [9000], then shown 9000")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'value previewed against the value the next activation shows'
}
Test-EbcItem -Name 'Every dedicated E-I-G-H-T target hit awards 250 at 1x, 500 at 2x, or 750 at 3x' -Doc "$Doc; $Rules" -Body {
    $seen = @($Letters | ForEach-Object { "$($_.Letter) at $($_.M)x: $($_.Score)" })
    $want = @($Letters | ForEach-Object { "$($_.Letter) at $($_.M)x: $($LetterAward[$_.M])" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'letter hits'
}
Test-EbcItem -Name 'Each target advances the spinner exactly once per letter round; an already-lit letter still scores but does not advance it' -Doc "$Doc; $Spin" -Body {
    # Value held before and after each hit (DELUXE_SPINNER_VALUE_MASK, read
    # only); the activations above show the same values on the lamps. Round
    # 1 is I, H, G, E, (E again), T; round 2 is G, I, H. "It remains at 900
    # after reaching the top state" ("Spinner").
    $seen = @($Letters | ForEach-Object { "$($_.Letter): $($_.Before) -> $($_.After)" })
    $want = @('I: 100 -> 300', 'H: 300 -> 400', 'G: 400 -> 500', 'E: 500 -> 600', 'E: 600 -> 600', 'T: 600 -> 800', 'G: 800 -> 900', 'I: 900 -> 900', 'H: 900 -> 900')
    Assert-EbcEqual -Expected $want -Actual $seen -What 'spinner value around each letter hit (the second E is already lit)'
}
Test-EbcItem -Name 'Completing E-I-G-H-T awards a BALL letter and rearms the five letters' -Doc "$Doc; $Spin; $Rules" -Body {
    # The B of B-A-L-L lights at the completing T; the next G (a letter of
    # round 1) advances the spinner again.
    $g2 = @($Letters | Where-Object { $_.Letter -eq 'G' })[1]
    $seen = "Ball B lit on $ballBBefore/$LampSampleFrames frames before T and $ballBAfter/$LampSampleFrames after; next G advances $($g2.Before) -> $($g2.After)"
    $want = "Ball B lit on 0/$LampSampleFrames frames before T and $LampSampleFrames/$LampSampleFrames after; next G advances 800 -> 900"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'E-I-G-H-T completion'
}
Test-EbcItem -Name "With spinner collect inactive, each value advance blinks the new lamp combination for about three seconds and then hides it (timing window: $PreviewMin-$PreviewMax frames)" -Doc "$Doc; $Spin" -Body {
    $seen = @($p1, $p3, $p4 | ForEach-Object { $f = Get-PreviewFrames $_; "$($_.Letter) preview: shows [$((Get-PreviewValues $_) -join ', ')], " + $(if ($f -ge $PreviewMin -and $f -le $PreviewMax) { 'in window' } else { "$f frames" }) + ", dark at the end $($_.Pats[-1] -eq '...')" })
    $want = @(@(3000, 5000, 9000) | ForEach-Object -Begin { $l = @('I', 'G', 'G'); $i = 0 } -Process { "$($l[$i++]) preview: shows [$_], in window, dark at the end True" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'frames from the letter''s closure to the last lit spinner lamp'
}
Test-EbcItem -Name 'The preview''s first visible pulse is a complete blink phase rather than a brief flicker' -Doc "$Doc; $Spin" -Body {
    # Every lit run but the last is as long as the first; the first is no
    # shorter than any other.
    $seen = @($p1, $p3, $p4 | ForEach-Object { $r = @(Get-LitRuns $_); $max = ($r | Measure-Object -Property Len -Maximum).Maximum; "$($_.Letter): first lit run $($r[0].Len) of $($r.Count) runs, longest $max" })
    $want = @($p1, $p3, $p4 | ForEach-Object { $r = @(Get-LitRuns $_); $max = ($r | Measure-Object -Property Len -Maximum).Maximum; "$($_.Letter): first lit run $max of $($r.Count) runs, longest $max" })
    Assert-EbcEqual -Expected $want -Actual $seen -What "preview lit runs (I [$(Format-Runs $p1)], G [$(Format-Runs $p3)], G [$(Format-Runs $p4)])"
    Assert-EbcTrue ((@(Get-LitRuns $p1)).Count -ge 2) 'the I preview has fewer than two lit runs'
}
Test-EbcItem -Name 'During the preview, spinner pulses still score only the ordinary unlit 10 points, do not use the playfield multiplier, and do not activate or restart the preview' -Doc "$Doc; $Spin" -Body {
    $seen = @($p1, $p4 | ForEach-Object {
        $t = $_.Timer; $a = $_.PulseAt
        "$($_.Letter) at $(if ($_ -eq $p4) { 2 } else { 1 })x: pulse $($_.PulseScore), timer keeps falling $(($t[$a + 6] -lt $t[$a - 1]) -and ($t[$a - 1] -gt 0)), dark at the end $($_.Pats[-1] -eq '...')" })
    $want = @("I at 1x: pulse $Unlit, timer keeps falling True, dark at the end True", "G at 2x: pulse $Unlit, timer keeps falling True, dark at the end True")
    Assert-EbcEqual -Expected $want -Actual $seen -What "a pulse $PulseIntoPreview frames into the preview (DELUXE_SPINNER_PREVIEW_TIMER read only)"
}
Test-EbcItem -Name 'Activating spinner during a preview cancels the timer and the current value becomes steady immediately' -Doc "$Doc; $Spin" -Body {
    # The H preview: the activating sink closes $SinkAfterReset frames after
    # the group's reset. "Immediately": the timer reads 0 at the end of the
    # sink's closure frame, and the lamps are steady from the next frame on
    # (the lamp outputs lag RAM by a frame or two; orbits.tests.ps1). Control:
    # the I preview, never activated, still blinks over the same frames.
    $a = $p2.SinkAt
    $after = @($p2.Pats[($a + 1)..($p2.Pats.Count - 1)] | Select-Object -Unique)
    $ctrl = @($p1.Pats[($a + 1)..(Get-PreviewFrames $p1)] | Select-Object -Unique).Count
    $seen = "preview running before the sink $($p2.Timer[$a - 1] -gt 0); timer at the end of the sink's frame $($p2.Timer[$a]); lamps from the next frame on [$(@($after | ForEach-Object { ConvertTo-Spin $_ }) -join ', ')]; control preview blinks over those frames $($ctrl -gt 1)"
    $want = "preview running before the sink True; timer at the end of the sink's frame 0; lamps from the next frame on [4000]; control preview blinks over those frames True"
    Assert-EbcEqual -Expected $want -Actual $seen -What "spinner activation $a frames after the H closure (lamps on the sink's frame: $(ConvertTo-Spin $p2.Pats[$a]); the preview is dark until frame 34 of every letter hit)"
}
Test-EbcItem -Name 'The first active-spinner pulse enters spinner collecting and scores the displayed value while immediately making the orbit location inactive; a new pool ball sunk before the spinner stops lights the orbit collect' -Doc "$Doc; $Spin; $Collect" -Body {
    $lit = [Array]::IndexOf([bool[]]$seq300.Arrows, $true)
    $seen = "first pulse at 300: $($seq300.Pulses[0].Score); spinner collecting after it $($seq300.Timer[1] -gt 0); sink $SinkAfterPulse frames later lights the orbit arrows $($lit -ge 0) while still collecting $($lit -ge 0 -and $seq300.Timer[$lit] -gt 0)"
    $want = "first pulse at 300: 300; spinner collecting after it True; sink $SinkAfterPulse frames later lights the orbit arrows True while still collecting True"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'first pulse at 300, then a sink (DELUXE_SPINNER_COLLECTING_TIMER read only)'
}
Test-EbcItem -Name 'Every continuing spinner pulse retains its lit value and multiplier and refreshes the stop timer' -Doc "$Doc; $Spin" -Body {
    # Five pulses $RefreshGap frames apart span $(4 * $RefreshGap) frames,
    # more than the longest stop ($StopMax), so each must refresh it.
    $seen = @($seq100.Pulses[0..4] | ForEach-Object { "1x pulse at +$($_.At): $($_.Score)" }) + @($seq2x.Pulses | ForEach-Object { "2x pulse at +$($_.At): $($_.Score)" }) + @($seq3x.Pulses | ForEach-Object { "3x pulse at +$($_.At): $($_.Score)" })
    $want = @(0..4 | ForEach-Object { "1x pulse at +$($_ * $RefreshGap): 100" }) + @(0..2 | ForEach-Object { "2x pulse at +$($_ * $RefreshGap): 1800" }) + @(0..2 | ForEach-Object { "3x pulse at +$($_ * $RefreshGap): 2700" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'continuing pulses'
}
Test-EbcItem -Name "Roughly two seconds with no pulse ends spinner scoring (timing window: $StopMin-$StopMax frames)" -Doc "$Doc; $Spin" -Body {
    # A pulse $($StopMin - 1) frames after the last is inside the window, so
    # still lit; one $($StopMax + 6) frames after that is past it.
    $seen = @($seq100.Pulses[5..6] | ForEach-Object { "pulse $($_.At - $seq100.At[[Array]::IndexOf($seq100.At, $_.At) - 1]) frames after the previous: $($_.Score)" })
    $want = @("pulse $($StopMin - 1) frames after the previous: 100", "pulse $($StopMax + 6) frames after the previous: $Unlit")
    Assert-EbcEqual -Expected $want -Actual $seen -What "pulses after a pause (collecting ended $stopFrames frames after the last lit pulse)"
}
Test-EbcItem -Name 'The stop ends only spinner scoring without clearing or moving the orbit state' -Doc "$Doc; $Spin; $Collect" -Body {
    # After the 300 collect's sink activated the orbit and collecting ended:
    # the arrows still lit, and the left rollover collects the orbit value
    # (an inactive orbit would score 500, "Left orbit").
    $seen = "arrows lit after the stop $arrowsAfterStop; left rollover scores more than the unlit 500 $($orbitAfterStop -gt 500)"
    Assert-EbcEqual -Expected 'arrows lit after the stop True; left rollover scores more than the unlit 500 True' -Actual $seen -What "orbit after spinner collecting ended (left rollover scored $orbitAfterStop)"
}
Complete-EbcTests
