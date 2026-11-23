param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe completed-rack bonus: the 120K/240K inserts from the fourth rack,
# six racks at 1x/2x/3x/5x plus the partial-rack balls, and the credit display
# during the bonus. All by play: one player completes six racks on ball 1 of
# a five-ball game (balls per game set through service mode), then drains at
# a different bonus multiplier on each of balls 1-4.
#
# A rack is balls 1-7 sunk through their drop groups (a down group is raised
# with its E-I-G-H-T standup, GameNames.psd1 StandupDropGroups), then the
# 8-ball at the saucer. Each 8-ball collection also collects the lit saucer
# multiplier (measured: ball 1 reaches 5x by the third rack); on a new ball
# the first, second and third saucer hits give 2x, 3x and 5x (measured,
# saucer.tests.ps1). The lit multiplier is read from the BONUS MULTIPLIER
# 2X/3X/5X lamps (GameNames.psd1 Lamps), dark for 1x.
#
# The bonus plays $37 with every 1,500-point sunk-ball step and $38 with every
# 1,000-point E-I-G-H-T step (src/8bc-deluxe/asm/modules/
# 10_game_state_and_drop_reset.asm $C7FC, $C90C). The completed-rack portion
# is the score change from the drain to the frame before the first $38 (or to
# the end of the bonus when no $38 is played); the rack phase is the frames
# from the first $37 to that point.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Pool = 'src/8bc-deluxe/gamerules.md "Pool-ball bonus"'
$Manual = 'OPS manual p. 1-9 "Balls per game; register 23"'

# "Required gameplay verification": with six completed racks the completed-
# rack portion is 72,000 at 1x, 144,000 at 2x, 216,000 at 3x, or 360,000 at
# 5x, plus 1,500 times the multiplier for each sunk ball in the partial rack.
# ("Pool-ball bonus": each rack is 8 * 1,500 = 12,000, and 6 * 12,000 = 72,000.)
$Racks = 6
$SixRacks = @{ 1 = 72000; 2 = 144000; 3 = 216000; 5 = 360000 }
$PartialBallValue = 1500
# "Complete at least four 8-ball racks ... verify both 120K and 240K inserts
# blink together beginning with the fourth rack."
$BlinkFrom = 4
# "the credit display shows `06` for six completed racks".
$RackCountShown = '06'
$SoundRackStep = 0x37
$SoundLetterStep = 0x38
$BallsRegister = 23
$BallsPerGame = 5
$LampSampleFrames = 64

$RackLamps = [ordered]@{ '120K' = (Get-EbcLampNumber 'Bonus 120,000'); '240K' = (Get-EbcLampNumber 'Bonus 240,000') }
$MultiplierLamps = [ordered]@{ '2' = (Get-EbcLampNumber 'Bonus Multiplier 2X'); '3' = (Get-EbcLampNumber 'Bonus Multiplier 3X'); '5' = (Get-EbcLampNumber 'Bonus Multiplier 5X') }
$GroupOf = @{ 1 = 'Drop Target 1,2,9,10'; 2 = 'Drop Target 1,2,9,10'; 3 = 'Drop Target 3,11'; 4 = 'Drop Target 4,5,12,13'
              5 = 'Drop Target 4,5,12,13'; 6 = 'Drop Target 6,14'; 7 = 'Drop Target 7,15' }
$LatchOf = @{ 'Drop Target 1,2,9,10' = 0x01; 'Drop Target 3,11' = 0x04; 'Drop Target 4,5,12,13' = 0x08; 'Drop Target 6,14' = 0x20; 'Drop Target 7,15' = 0x40 }
$standups = (Get-EbcNames).StandupDropGroups
$ResetBy = @{}; foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }

function Get-SunkCount { $s = Get-EbcSunkBalls; @(0..6 | Where-Object { $s -band (1 -shl $_) }).Count }
# Sinks the lowest unsunk ball, raising its group first when it is down.
function Invoke-NewSink {
    $sunk = Get-EbcSunkBalls
    $next = @(1..7 | Where-Object { -not ($sunk -band (1 -shl ($_ - 1))) })[0]
    $g = $GroupOf[$next]
    if ((Read-EbcByte (Get-EbcRamAddress 'DROP_TARGET_SWITCH_CLOSURE_LATCHES')) -band $LatchOf[$g]) { Invoke-EbcScoredHit $ResetBy[$g] -AfterSolenoid $g | Out-Null }
    Invoke-EbcScoredHit $g | Out-Null
    if ((Get-EbcSunkBalls) -eq $sunk) { throw "$g sank no new ball" }
}
function Invoke-Rack {
    while ((Get-EbcSunkBalls) -ne 0x7F) { Invoke-NewSink }
    Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
    if ((Get-EbcSunkBalls) -ne 0) { throw 'the 8-ball did not start a new rack' }
    Step-EbcFrames -Frames 30
}
function Invoke-Saucer { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null; Step-EbcFrames -Frames 30 }
function Get-LitMultiplier { $lit = @($MultiplierLamps.Keys | Where-Object { Get-EbcLamp -Number $MultiplierLamps[$_] }); if ($lit.Count -eq 0) { 1 } elseif ($lit.Count -eq 1) { [int]$lit[0] } else { $lit -join '+' } }
# The 120K/240K inserts over $LampSampleFrames frames.
function Get-RackInserts {
    $s = [ordered]@{}; foreach ($n in $RackLamps.Keys) { $s[$n] = '' }
    for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; foreach ($n in $RackLamps.Keys) { $s[$n] += $(if (Get-EbcLamp -Number $RackLamps[$n]) { '#' } else { '.' }) } }
    $blinking = @($RackLamps.Keys | Where-Object { $s[$_].Contains('#') -and $s[$_].Contains('.') })
    if (-not $blinking.Count) { return 'steady' }
    if ($blinking.Count -eq 2 -and $s['120K'] -eq $s['240K']) { return '120K+240K blinking in phase' }
    ($RackLamps.Keys | ForEach-Object { "$_ $($s[$_])" }) -join ', '
}
# Drains and records every frame until the next serve: the score, the credit
# display, the status display, the credits, and the sound commands.
function Measure-Bonus {
    $p = [int](Get-EbcCurrentPlayer)
    $addr = Get-EbcRamAddress "ScoreBuffer$p"
    $read = { $t = Get-EbcScoreBufferText $addr; if ($t -eq '') { [long]0 } else { [long]$t } }
    $r = [PSCustomObject]@{ Multiplier = (Get-LitMultiplier); Partial = (Get-SunkCount); Before = (& $read); CreditsBefore = (Get-EbcCredits)
                            CreditShownBefore = (Get-EbcDisplayText (Get-EbcNames).Displays.Credits); Frames = @{}; Commands = @(); First37 = -1; RackEnd = -1; End = -1 }
    $seen = Get-EbcEventCount
    $sol = Get-EbcSolenoid 'Outhole'
    Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $true
    for ($k = 0; ; $k++) {
        if ($k -gt 6000) { throw 'no serve within 6000 frames of the drain' }
        Step-EbcFrames -Frames 1
        $r.Frames[(Get-EbcFrame)] = [PSCustomObject]@{ Score = (& $read); Credit = (Get-EbcDisplayText (Get-EbcNames).Displays.Credits); Status = (Get-EbcDisplayText (Get-EbcNames).Displays.Status); Credits = (Get-EbcCredits) }
        if (@(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $sol 1$" }).Count) { break }
    }
    Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $false
    $ev = @(Get-EbcEvents -Since $seen | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $x = $_ -split ' '; [PSCustomObject]@{ F = [int]$x[0]; B = [int]$x[3] } })
    $r.Commands = @(for ($i = 0; $i -lt $ev.Count; $i++) {
        $ev[$i]
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    })
    $s37 = @($r.Commands | Where-Object { $_.B -eq $SoundRackStep })
    if (-not $s37.Count) { throw 'the bonus played no $37' }
    $r.First37 = $s37[0].F
    $steps = @($r.Commands | Where-Object { $_.F -ge $r.First37 -and $_.B -in @($SoundRackStep, $SoundLetterStep) })
    $after = @($r.Commands | Where-Object { $_.F -ge $steps[-1].F -and $_.B -notin @($SoundRackStep, $SoundLetterStep) } | Select-Object -First 1)
    if (-not $after.Count) { throw 'no command after the last bonus step' }
    $r.End = $after[0].F
    $s38 = @($steps | Where-Object { $_.B -eq $SoundLetterStep })
    $r.RackEnd = if ($s38.Count) { $s38[0].F - 1 } else { $r.End }
    $r | Add-Member -NotePropertyName RackTotal -NotePropertyValue ($r.Frames[$r.RackEnd].Score - $r.Before)
    $r
}
function Format-Drain($d) { "{0}x, {1} partial-rack balls: rack portion {2}" -f $d.Multiplier, $d.Partial, $d.RackTotal }

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $BallsRegister -Value $BallsPerGame | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit -Count 3 | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

# ---- Ball 1: six racks, then two balls of the seventh ----
$inserts = @()
for ($k = 1; $k -le $Racks; $k++) { Invoke-Rack; $inserts += "rack ${k}: $(Get-RackInserts)" }
Invoke-NewSink; Invoke-NewSink
Step-EbcFrames -Frames 60
$drains = @()
$drains += Measure-Bonus
# ---- Balls 2-4: 1x, 2x and 3x, one more partial-rack ball each ----
foreach ($hits in 0, 1, 2) {
    Step-EbcFrames -Frames 120
    Invoke-NewSink
    for ($h = 0; $h -lt $hits; $h++) { Invoke-Saucer }
    Step-EbcFrames -Frames 60
    $drains += Measure-Bonus
}

Test-EbcItem -Name 'Both 120K and 240K inserts blink together beginning with the fourth completed rack' -Doc "$Doc; $Pool" -Body {
    $want = @(1..$Racks | ForEach-Object { "rack ${_}: $(if ($_ -ge $BlinkFrom) { '120K+240K blinking in phase' } else { 'steady' })" })
    Assert-EbcEqual -Expected $want -Actual $inserts -What "120K/240K inserts over $LampSampleFrames frames after each rack"
}
Test-EbcItem -Name 'Six completed racks give 72,000/144,000/216,000/360,000 at 1x/2x/3x/5x, plus 1,500 times the multiplier for each partial-rack ball' -Doc "$Doc; $Pool" -Body {
    $seen = @($drains | ForEach-Object { Format-Drain $_ } | Sort-Object)
    $want = @($drains | ForEach-Object { "{0}x, {1} partial-rack balls: rack portion {2}" -f $_.Multiplier, $_.Partial, ($SixRacks[[int]$_.Multiplier] + $_.Multiplier * $PartialBallValue * $_.Partial) } | Sort-Object)
    $mults = @($drains | ForEach-Object { "$($_.Multiplier)x" } | Sort-Object) -join ' '
    Assert-EbcEqual -Expected '1x 2x 3x 5x' -Actual $mults -What 'multipliers lit at the four drains'
    Assert-EbcEqual -Expected $want -Actual $seen -What 'completed-rack portion at each drain'
}
# The 5x drain: five rack passes, from the first $37 to the frame before the
# B-A-L-L phase (the status display changes on the frame before the first $38).
$five = @($drains | Where-Object { $_.Multiplier -eq 5 })[0]
$rackFrames = @($five.Frames.Keys | Where-Object { $_ -ge $five.First37 -and $_ -lt $five.RackEnd } | Sort-Object)
$shownDuring = @($rackFrames | ForEach-Object { $five.Frames[$_].Credit } | Select-Object -Unique)
$statusDuring = @($rackFrames | ForEach-Object { $five.Frames[$_].Status } | Select-Object -Unique)
Write-Output ("INFO {0}/rack-bonus :: 5x rack phase ({1} frames): credit display [{2}], status display [{3}]" -f $Tree, $rackFrames.Count, ($shownDuring -join ', '), ($statusDuring -join ', '))
Test-EbcItem -Name 'During the rack bonus the credit display shows 06 for six completed racks and stays stable through every multiplier pass' -Doc "$Doc; $Pool" -Body {
    Assert-EbcEqual -Expected @($RackCountShown) -Actual $shownDuring -What ("credit display (GameNames Displays.Credits) on every frame from the first `$37 to the B-A-L-L phase, 5x drain (status display showed [{0}])" -f ($statusDuring -join ', '))
}
Test-EbcItem -Name 'After the B-A-L-L bonus the credit display restores the exact prior credit count, and credits are unchanged' -Doc "$Doc; $Pool" -Body {
    $seen = @($drains | ForEach-Object { $d = $_; $last = ($d.Frames.Keys | Sort-Object)[-1]
        $creditsSeen = @($d.Frames.Values | ForEach-Object { $_.Credits } | Select-Object -Unique) -join ','
        "{0}x: shown after the bonus '{1}', credits during the drain [{2}]" -f $d.Multiplier, $d.Frames[$last].Credit, $creditsSeen })
    $want = @($drains | ForEach-Object { "{0}x: shown after the bonus '{1}', credits during the drain [{2}]" -f $_.Multiplier, $_.CreditShownBefore, $_.CreditsBefore })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'credit display at the serve after each bonus, and the credit RAM through it'
}
Complete-EbcTests
