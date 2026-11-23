param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe drain-bonus timing against the preceding Deluxe ROM: the partial-rack
# and B-A-L-L/E-I-G-H-T countdown phases take about 75% of their frames at
# 7d9c960 (the commit before "speedier bonus count", 934986c), with identical
# totals, multiplier passes, sounds and lamp steps. All by play on one
# player's first ball: one completed rack and three balls of the next, one
# completed E-I-G-H-T word and two letters of the next, at 3x.
#
# Phases, defined by sound commands, the same way for both ROMs. The bonus
# plays $37 with every 1,500-point sunk-ball step and $38 with every
# 1,000-point E-I-G-H-T step (src/8bc-deluxe/asm/modules/
# 10_game_state_and_drop_reset.asm $C7FC and $C90C, unchanged by 934986c).
#   partial-rack phase: from the frame of the first $37 to the frame of the
#     first $38;
#   B-A-L-L/E-I-G-H-T phase: from the frame of the first $38 to the frame of
#     the first later command that is not $38 (the end-of-bonus command).
# Each phase's frames are that difference.
#
# The reference was measured once and is written below, not rebuilt on each
# run: 7d9c960's src/8bc-deluxe/asm/build.ps1, built in a detached worktree
# with DASM 2.20.14.1 (the macOS binary at the script's Windows path),
# packaged eballchp.zip (u3_cpu.128 SHA-1
# CEA618D529E4A55FF61A5250CB6E6F77E92890BA; it differs from the 934986c image
# only in the four delay selectors at $C8A0, $C912, $D937, $DA14 and the
# checksum byte at $C000), and this file was run against that zip with
# -VpmZip. Its INFO line gave the values in $Reference.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Pool = 'src/8bc-deluxe/gamerules.md "Pool-ball bonus"'
$BallDoc = 'src/8bc-deluxe/gamerules.md "B-A-L-L and E-I-G-H-T bonus"'

# "Pool-ball bonus": each completed rack is worth 8 * 1,500 = 12,000, and each
# ball sunk in the unfinished rack adds another 1,500 Deluxe points.
$PartialBallValue = 1500
$RackValue = 8 * 1500
# "B-A-L-L and E-I-G-H-T bonus": each completed B-A-L-L letter is worth five
# scaled 1,000-point E-I-G-H-T units, or 5,000; each E-I-G-H-T letter toward
# the next B-A-L-L letter adds another 1,000.
$PartialLetterValue = 1000
$BallLetterValue = 5 * 1000
# "Required gameplay verification": both visible countdown phases finish in
# approximately 75% of their prior time; the brief's window is 75% +/- 5%.
$TimeRatio = 0.75
$TimeTolerance = 0.05
$SoundRackStep = 0x37
$SoundLetterStep = 0x38

# Measured at 7d9c960 (see the header). Frames per phase, the two bonus
# portions, the step-sound counts, the command sequence and the lamp steps.
$Reference = [PSCustomObject]@{
    RackFrames = 242; BallFrames = 133; RackTotal = 49500; BallTotal = 21000; Count37 = 33; Count38 = 21
    Sounds = ((@('37') * 33) + (@('38') * 21) + @('18')) -join ' '
    # Per lamp in $StepLamps order (120K, 240K, B, A, L, L): '#' lit.
    Lamps = '#.#... ..#... #.#... ..#... #.#... ..#... ...... ..#... ...... ..#... ......'
}

# This file's play: one completed rack (Racks), three balls of the next
# (PartialBalls), one completed E-I-G-H-T word (BallLetters), two letters of
# the next (PartialLetters), and the saucer's 3x (Multiplier).
$Racks = 1; $PartialBalls = 3; $BallLetters = 1; $PartialLetters = 2; $Multiplier = 3

# Lamps of the two bonus phases: BONUS 120,000 / 240,000 and B-A-L-L
# (GameNames.psd1 Lamps), and the earned 2X/3X/5X bonus multiplier.
$StepLamps = @('Bonus 120,000', 'Bonus 240,000', 'Ball "B"', 'Ball "A"', 'Ball "L" 1', 'Ball "L" 2') | ForEach-Object { Get-EbcLampNumber $_ }
$MultiplierLamps = [ordered]@{ '2' = (Get-EbcLampNumber 'Bonus Multiplier 2X'); '3' = (Get-EbcLampNumber 'Bonus Multiplier 3X'); '5' = (Get-EbcLampNumber 'Bonus Multiplier 5X') }

$standups = (Get-EbcNames).StandupDropGroups
$LetterOf = @{ E = 'Drop Target "E"'; I = 'Drop Target "I"'; G = 'Drop Target "G"'; H = 'Drop Target "H"'; T = 'Drop Target "T"' }
# A letter: its drop group goes down (sinking that group's next ball, if
# any), then its standup scores the letter and raises the group (GameNames
# .psd1 StandupDropGroups).
function Invoke-Letter([string]$L) {
    $g = $standups[$LetterOf[$L]]
    Invoke-EbcScoredHit $g | Out-Null
    Invoke-EbcScoredHit $LetterOf[$L] -AfterSolenoid $g | Out-Null
}
function Get-StepLamps { -join @($StepLamps | ForEach-Object { if (Get-EbcLamp -Number $_) { '#' } else { '.' } }) }
function Get-LitMultiplier { $lit = @($MultiplierLamps.Keys | Where-Object { Get-EbcLamp -Number $MultiplierLamps[$_] }); if ($lit.Count -eq 0) { 1 } else { $lit -join '+' } }

# Drains and records every frame until the next serve: the score, and the
# sound commands (one per command: libpinmame also reports each byte shifted
# right four on the same frame, GameNames.psd1 Sounds).
function Measure-Bonus {
    $p = [int](Get-EbcCurrentPlayer)
    $addr = Get-EbcRamAddress "ScoreBuffer$p"
    $read = { $t = Get-EbcScoreBufferText $addr; if ($t -eq '') { [long]0 } else { [long]$t } }
    $before = & $read
    $seen = Get-EbcEventCount
    $sol = Get-EbcSolenoid 'Outhole'
    $score = @{}; $lamps = @{}
    Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $true
    for ($k = 0; ; $k++) {
        if ($k -gt 6000) { throw 'no serve within 6000 frames of the drain' }
        Step-EbcFrames -Frames 1
        $f = Get-EbcFrame
        $score[$f] = & $read; $lamps[$f] = Get-StepLamps
        if (@(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $sol 1$" }).Count) { break }
    }
    Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $false
    $ev = @(Get-EbcEvents -Since $seen | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $x = $_ -split ' '; [PSCustomObject]@{ F = [int]$x[0]; B = [int]$x[3] } })
    $cmds = @(for ($i = 0; $i -lt $ev.Count; $i++) {
        $ev[$i]
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    })
    $r37 = @($cmds | Where-Object { $_.B -eq $SoundRackStep }); $r38 = @($cmds | Where-Object { $_.B -eq $SoundLetterStep })
    if (-not $r37.Count -or -not $r38.Count) { throw "the bonus played $($r37.Count) `$37 and $($r38.Count) `$38 commands" }
    $first37 = $r37[0].F; $first38 = $r38[0].F; $last38 = $r38[-1].F
    $end = @($cmds | Where-Object { $_.F -ge $last38 -and $_.B -ne $SoundLetterStep } | Select-Object -First 1)
    if (-not $end.Count) { throw 'no command after the last $38' }
    $endF = $end[0].F
    $bonusCmds = @($cmds | Where-Object { $_.F -ge $first37 -and $_.F -le $endF })
    $lampSteps = [Collections.Generic.List[string]]::new()
    for ($f = $first37; $f -le $endF; $f++) { if ($lampSteps.Count -eq 0 -or $lampSteps[-1] -ne $lamps[$f]) { $lampSteps.Add($lamps[$f]) } }
    $rackTotal = $score[$first38 - 1] - $before
    [PSCustomObject]@{
        RackFrames = $first38 - $first37; BallFrames = $endF - $first38
        RackTotal = $rackTotal; BallTotal = $score[$endF] - $before - $rackTotal
        Count37 = $r37.Count; Count38 = $r38.Count
        Sounds = (@($bonusCmds | ForEach-Object { '{0:X2}' -f $_.B }) -join ' ')
        Lamps = ($lampSteps -join ' ')
    }
}

Start-EbcGame
Add-EbcCredit -Count 2 | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

# E sinks ball 6 and activates the orbit collect; the orbit collect is a
# collect transition, and the saucer then awards 2x (saucer.tests.ps1).
Invoke-Letter 'E'
Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
# The rest of the word (one B-A-L-L letter), two letters of the next word,
# and ball 5: balls 1-7 are sunk.
foreach ($L in 'I', 'G', 'H', 'T', 'E', 'I') { Invoke-Letter $L }
Invoke-EbcScoredHit 'Drop Target 4,5,12,13' | Out-Null
if ((Get-EbcSunkBalls) -ne 0x7F) { throw ('balls 1-7 not all sunk before the 8-ball (10C3 {0:X2})' -f (Get-EbcSunkBalls)) }
# The 8-ball completes the rack (and collects the lit 3x), then three balls
# of the new rack.
Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
Step-EbcFrames -Frames 30
foreach ($g in 'Drop Target 1,2,9,10', 'Drop Target 3,11', 'Drop Target 6,14') { Invoke-EbcScoredHit $g | Out-Null }
Step-EbcFrames -Frames 60
$litMultiplier = Get-LitMultiplier
$m = Measure-Bonus
Write-Output ("INFO {0}/bonus-timing :: measured: rack {1} frames, B-A-L-L {2} frames, rack total {3}, B-A-L-L total {4}, `$37 x{5}, `$38 x{6}; sounds [{7}]; lamps [{8}]" -f $Tree, $m.RackFrames, $m.BallFrames, $m.RackTotal, $m.BallTotal, $m.Count37, $m.Count38, $m.Sounds, $m.Lamps)

function Assert-Reference { if ($null -eq $Reference) { throw 'no 7d9c960 reference recorded in this file' } }
function Test-Ratio([string]$What, [int]$Now, [int]$Was) {
    $ratio = $Now / $Was
    Assert-EbcTrue ([Math]::Abs($ratio - $TimeRatio) -le $TimeTolerance + 1e-9) ("{0}: {1} frames, 7d9c960 {2} frames, ratio {3:N3}; expected {4:N2} +/- {5:N2}" -f $What, $Now, $Was, $ratio, $TimeRatio, $TimeTolerance)
}
Test-EbcItem -Name 'The partial-rack countdown phase finishes in approximately 75% of its 7d9c960 time (timing window: 75% +/- 5% of the reference frames)' -Doc "$Doc; $Pool" -Body {
    Assert-Reference
    Test-Ratio 'partial-rack phase (first $37 to first $38)' $m.RackFrames $Reference.RackFrames
}
Test-EbcItem -Name 'The B-A-L-L/E-I-G-H-T countdown phase finishes in approximately 75% of its 7d9c960 time (timing window: 75% +/- 5% of the reference frames)' -Doc "$Doc; $BallDoc" -Body {
    Assert-Reference
    Test-Ratio 'B-A-L-L/E-I-G-H-T phase (first $38 to the end-of-bonus command)' $m.BallFrames $Reference.BallFrames
}
Test-EbcItem -Name 'Both phases award identical totals: the doc''s arithmetic through the multiplier, as at 7d9c960' -Doc "$Doc; $Pool; $BallDoc" -Body {
    Assert-Reference
    $rack = $Multiplier * ($Racks * $RackValue + $PartialBalls * $PartialBallValue)
    $ball = $Multiplier * ($BallLetters * $BallLetterValue + $PartialLetters * $PartialLetterValue)
    Assert-EbcEqual -Expected "lit multiplier $Multiplier; rack $rack, B-A-L-L $ball; 7d9c960 rack $rack, B-A-L-L $ball" -Actual "lit multiplier $litMultiplier; rack $($m.RackTotal), B-A-L-L $($m.BallTotal); 7d9c960 rack $($Reference.RackTotal), B-A-L-L $($Reference.BallTotal)" -What "bonus portions ($Racks rack + $PartialBalls balls, $BallLetters B-A-L-L letter + $PartialLetters letters, ${Multiplier}x)"
}
Test-EbcItem -Name 'Every multiplier pass is retained: one step sound per 1,500 or 1,000 unit in each pass, as at 7d9c960' -Doc "$Doc; $Pool; $BallDoc" -Body {
    Assert-Reference
    $s37 = $Multiplier * (8 * $Racks + $PartialBalls); $s38 = $Multiplier * (5 * $BallLetters + $PartialLetters)
    Assert-EbcEqual -Expected "`$37 x$s37, `$38 x$s38; 7d9c960 `$37 x$s37, `$38 x$s38" -Actual "`$37 x$($m.Count37), `$38 x$($m.Count38); 7d9c960 `$37 x$($Reference.Count37), `$38 x$($Reference.Count38)" -What 'step sounds'
}
Test-EbcItem -Name 'Every sound and lamp step is unchanged from 7d9c960' -Doc "$Doc; $BallDoc" -Body {
    Assert-Reference
    Assert-EbcEqual -Expected "sounds [$($Reference.Sounds)]; lamps [$($Reference.Lamps)]" -Actual "sounds [$($m.Sounds)]; lamps [$($m.Lamps)]" -What 'bonus command sequence and the 120K/240K/B-A-L-L lamp steps'
}
Complete-EbcTests
