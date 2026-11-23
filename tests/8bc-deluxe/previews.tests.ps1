param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe lamp previews: a newly sunk ball that activates the spinner during
# the right-orbit value preview cancels that preview and shows the spinner's
# accumulated value; an E-I-G-H-T spinner preview started during the orbit
# preview leaves both retained values and the collect state intact. By play
# on one player's first ball.
#
# The orbit value is read from the orbit-value arrows and the spinner value
# from the spinner value lamps (GameNames.psd1 Lamps): the printed legends of
# the lit lamps add up to the value (orbits.tests.ps1; gamerules.md "Spinner":
# the three lamps are a binary counter 1,000 -> 3,000 -> 4,000 -> ...).
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Right = 'src/8bc-deluxe/gamerules.md "Right orbit"'
$Spin = 'src/8bc-deluxe/gamerules.md "Spinner"'
$Collect = 'src/8bc-deluxe/gamerules.md "Deluxe collect feature"'

# "Right orbit": activation lights the printed 10,000; the right collect
# advances it by 20,000. Scores are the printed value / 10.
$FirstOrbit = 10000
$RightStep = 20000
# "Spinner": the collect begins at the printed 1,000 each ball, and each new
# E-I-G-H-T letter advances it one step: 1,000 -> 3,000 -> 4,000.
$SpinnerSteps = @(1000, 3000, 4000, 5000, 6000, 8000, 9000)
$SpinnerUnlit = 10
$Fps = (Get-EbcNames).FramesPerSecond
$SpinnerStopFrames = $Fps * 3
# Frames read after the activating sink and after the E-I-G-H-T hit: past
# any preview (about three seconds plus 20%).
$WatchFrames = [int]($Fps * 3 * 1.2) + 60
# The orbit preview timer (src/8bc-deluxe/asm/symbols.inc
# DELUXE_ORBIT_PREVIEW_TIMER, 1115), read only: to confirm a preview is
# running when the next step starts, and that activation zeroes it.
$PreviewTimer = 0x1115
# The activating sink starts this many frames into the orbit preview: at its
# start, so an uncancelled preview outlasts the sink's animation.
$IntoPreview = 0
# The E-I-G-H-T hit starts this far in, past the chase's last arrow, which
# the lamp outputs still show for a few frames (orbits.tests.ps1).
$IntoPreviewEight = 20

$ArrowValues = @(10000, 20000, 30000, 40000)
$ArrowLamps = @($ArrowValues | ForEach-Object { Get-EbcLampNumber ('Rollover Lanes {0:N0}' -f $_) })
$SpinValues = @(1000, 3000, 5000)
$SpinLamps = @($SpinValues | ForEach-Object { Get-EbcLampNumber ('Spinner {0:N0}' -f $_) })
function Get-Pattern($Lamps) { (@($Lamps | ForEach-Object { if (Get-EbcLamp -Number $_) { '#' } else { '.' } }) -join '') }
function ConvertTo-Value([string]$Pattern, $Values) { $v = 0; for ($k = 0; $k -lt $Values.Count; $k++) { if ($Pattern[$k] -eq '#') { $v += $Values[$k] } }; $v }
function Get-OrbitShown { ConvertTo-Value (Get-Pattern $ArrowLamps) $ArrowValues }
function Get-SpinnerShown { ConvertTo-Value (Get-Pattern $SpinLamps) $SpinValues }

# Closes $Switch and reads both lamp sets every frame for $Frames frames.
function Watch-Hit([string]$Switch, [int]$Frames = $WatchFrames) {
    $timer = Read-EbcByte $PreviewTimer
    $n = Get-EbcSwitch $Switch
    $orbit = @(); $spin = @(); $timers = @()
    for ($k = 0; $k -lt $Frames; $k++) {
        if ($k -eq 0) { Set-EbcSwitch -Number $n -Closed $true }
        if ($k -eq 4) { Set-EbcSwitch -Number $n -Closed $false }
        Step-EbcFrames -Frames 1
        $orbit += Get-Pattern $ArrowLamps
        $spin += Get-Pattern $SpinLamps
        $timers += Read-EbcByte $PreviewTimer
    }
    [PSCustomObject]@{ TimerAtHit = $timer; Orbit = $orbit; Spin = $spin; Timer = $timers }
}
# Starts the right-orbit preview: the collect, read until $IntoPreview frames
# after the preview timer starts. Returns the score change.
function Start-OrbitPreview([int]$Into = $IntoPreview) {
    $p = [int](Get-EbcCurrentPlayer)
    $addr = Get-EbcRamAddress "ScoreBuffer$p"
    $before = Get-EbcScoreBufferText $addr
    Invoke-EbcSwitchHit 'Right Rollover Button'
    for ($k = 0; (Read-EbcByte $PreviewTimer) -eq 0; $k++) { if ($k -gt 600) { throw 'no orbit preview within 600 frames of the right collect' }; Step-EbcFrames -Frames 1 }
    if ($Into -gt 0) { Step-EbcFrames -Frames $Into }
    [long](Get-EbcScoreBufferText $addr) - [long]$(if ($before) { $before } else { 0 })
}

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

# ---- 1: a newly sunk ball activates the spinner during the orbit preview ----
Invoke-EbcScoredHit 'Drop Target 1,2,9,10' | Out-Null            # ball 1: orbit active
Step-EbcFrames -Frames 30
$orbitAtFirst = Get-OrbitShown
Invoke-EbcScoredHit 'Drop Target "I"' -AfterSolenoid 'Drop Target 1,2,9,10' | Out-Null   # new letter I: spinner 1,000 -> 3,000
Step-EbcFrames -Frames $WatchFrames                               # its spinner preview ends
$score1 = Start-OrbitPreview                                      # right collect of 10,000 -> 30,000, preview running
$w1 = Watch-Hit 'Drop Target 1,2,9,10'                            # ball 2: spinner active
$on = [Array]::FindIndex([string[]]$w1.Spin, [Predicate[string]] { param($x) $x -ne '...' })
$pulse1 = Invoke-EbcScoredHit 'Spinner'                           # orbit inactive + spinner collecting
Write-Host ("spinner lamps lit {0} frames after the sink's closure; orbit preview timer {1} ticks at the sink" -f ($on + 1), $w1.TimerAtHit)

Test-EbcItem -Name 'A newly sunk ball that activates the spinner during the right-orbit preview cancels that preview immediately and shows the spinner''s accumulated value' -Doc "$Doc; $Right; $Spin" -Body {
    Assert-EbcTrue ($on -ge 0) 'the spinner lamps never lit after the sink'
    $orbitAfter = @($w1.Orbit[$on..($w1.Orbit.Count - 1)] | Select-Object -Unique)
    $spinAfter = @($w1.Spin[$on..($w1.Spin.Count - 1)] | Select-Object -Unique | ForEach-Object { ConvertTo-Value $_ $SpinValues })
    $seen = "orbit preview running at the sink $($w1.TimerAtHit -gt 0); preview timer at activation $($w1.Timer[$on]); spinner shown from frame $on on: [$($spinAfter -join ', ')]; arrows from then on: [$($orbitAfter -join ', ')]; first pulse $pulse1"
    $want = "orbit preview running at the sink True; preview timer at activation 0; spinner shown from frame $on on: [$($SpinnerSteps[1])]; arrows from then on: [....]; first pulse $($SpinnerSteps[1] / 10)"
    Assert-EbcEqual -Expected $want -Actual $seen -What "spinner activation during the orbit preview (orbit activation showed $orbitAtFirst, right collect scored $score1)"
}

# ---- 2: an E-I-G-H-T spinner preview during the orbit preview ----
Step-EbcFrames -Frames $SpinnerStopFrames                         # spinner collecting ends
Invoke-EbcScoredHit 'Drop Target 3,11' | Out-Null                 # ball 3: orbit active
Step-EbcFrames -Frames 30
$orbitShown = Get-OrbitShown
$score2 = Start-OrbitPreview $IntoPreviewEight                                      # right collect: preview of the advanced value
$w2 = Watch-Hit 'Drop Target "G"'                                 # new letter G: spinner 3,000 -> 4,000 preview
$spinUnlit = Invoke-EbcScoredHit 'Spinner'                        # still spinner inactive
Invoke-EbcScoredHit 'Drop Target 4,5,12,13' | Out-Null            # ball 4: spinner active
Step-EbcFrames -Frames 30
$spinShown = Get-SpinnerShown
$spinPulse = Invoke-EbcScoredHit 'Spinner'                        # orbit inactive + spinner collecting
Step-EbcFrames -Frames $SpinnerStopFrames
Invoke-EbcScoredHit 'Drop Target 6,14' | Out-Null                 # ball 6: orbit active
Step-EbcFrames -Frames 30
$orbitAgain = Get-OrbitShown
$seen = Get-EbcEventCount
$orbitCollect = Invoke-EbcScoredHit 'Left Rollover Button'

Test-EbcItem -Name 'An E-I-G-H-T spinner preview during the orbit preview leaves both retained values and the collect state intact' -Doc "$Doc; $Right; $Spin; $Collect" -Body {
    $newOrbit = $orbitShown + $RightStep
    $newSpin = $SpinnerSteps[2]
    $orbitPats = @($w2.Orbit | Where-Object { $_ -ne '....' } | Select-Object -Unique | ForEach-Object { ConvertTo-Value $_ $ArrowValues })
    $spinPats = @($w2.Spin | Where-Object { $_ -ne '...' } | Select-Object -Unique | ForEach-Object { ConvertTo-Value $_ $SpinValues })
    $seen = @(
        "orbit preview running at the E-I-G-H-T hit $($w2.TimerAtHit -gt 0)",
        "during both previews the arrows show [$($orbitPats -join ', ')] and the spinner lamps [$($spinPats -join ', ')]; both dark at the end $($w2.Orbit[-1] -eq '....' -and $w2.Spin[-1] -eq '...')",
        "then spinner inactive: pulse $spinUnlit",
        "spinner activation shows $spinShown, first pulse $spinPulse",
        "next orbit activation shows $orbitAgain, collect $orbitCollect")
    $want = @(
        'orbit preview running at the E-I-G-H-T hit True',
        "during both previews the arrows show [$newOrbit] and the spinner lamps [$newSpin]; both dark at the end True",
        "then spinner inactive: pulse $SpinnerUnlit",
        "spinner activation shows $newSpin, first pulse $($newSpin / 10)",
        "next orbit activation shows $newOrbit, collect $($newOrbit / 10)")
    Assert-EbcEqual -Expected $want -Actual $seen -What "overlapping previews (orbit $orbitShown before the right collect, which scored $score2)"
}
# ---- Control: the same orbit preview with no activating sink ----
# From spinner inactive (the left collect above): activate the spinner with
# ball 7, take its first pulse, then re-arm group 28 with "H" and sink ball 5
# to activate the orbit; start the right-orbit preview and hit the Rebound,
# which sinks no ball, instead of a drop group.
Invoke-EbcScoredHit 'Drop Target 7,15' | Out-Null                 # ball 7: spinner active
Invoke-EbcScoredHit 'Spinner' | Out-Null                          # orbit inactive
Step-EbcFrames -Frames $SpinnerStopFrames
Invoke-EbcScoredHit 'Drop Target "H"' -AfterSolenoid 'Drop Target 4,5,12,13' | Out-Null
Step-EbcFrames -Frames $WatchFrames                               # any spinner preview ends
Invoke-EbcScoredHit 'Drop Target 4,5,12,13' | Out-Null            # ball 5: orbit active
Step-EbcFrames -Frames 30
Start-OrbitPreview | Out-Null
$w0 = Watch-Hit 'Rebound'
Test-EbcItem -Name 'Control: without the activating sink, the same orbit preview still lights the arrows after the activation frame' -Doc "$Doc; $Right" -Body {
    # The cancel item above reads the arrows from frame $on on; an uncancelled
    # preview is visible there, so a missing cancel would fail it.
    $lit = @($w0.Orbit[$on..($w0.Orbit.Count - 1)] | Where-Object { $_ -ne '....' }).Count
    Assert-EbcTrue ($w0.TimerAtHit -gt 0 -and $lit -gt 0) "preview running at the Rebound $($w0.TimerAtHit -gt 0); arrows lit on $lit frames from frame $on on"
}
Complete-EbcTests
