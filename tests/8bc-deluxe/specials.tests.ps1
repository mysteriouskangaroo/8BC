param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe specials: the additional points every special collection awards at
# 1x, 2x and 3x, with the original special award, sound and knocker once, by
# play over one player's three balls.
#
# Routes collected, one per multiplier: the E-I-G-H-T Special (the second
# E-I-G-H-T completion, OPS manual p. 1-11) at 1x, the roll-up lanes (orbit)
# Special at 2x, and an outlane Special at 3x (lit only by CHAMP completion 5,
# which keeps 3x). Measured: after the orbit Special was collected on ball 1,
# a later ball at the recalled 100,000 collected no Special, so one ball
# carries the orbit route. The 120K/240K Special is not collected (Task 8c
# report).
#
# "Additional score" is the collecting switch event's score change minus the
# same shot's change with no special lit, at the same multiplier and on the
# same ball: the orbit collect at 100,000 once its special is collected (the
# 10A0 latch keeps it unlit for the rest of the ball, gamerules.md "Left
# orbit"), the outlane hit before completion 5, and the completing letter of
# the first E-I-G-H-T completion (an Extra Ball, not a Special).
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
# credit; the knocker pulses once; the Special sound $6F ("Specials" trace,
# C1D6) is sent once.
$AwardRegister = 25; $AwardReplay = 3
$CreditsPerSpecial = 1
$KnocksPerSpecial = 1
$SpecialSound = 0x6F
$SoundsPerSpecial = 1
# Register 51 = 0: the roll-up lanes special flashes at 100K; register 48 = 1
# recalls the roll-up values from ball to ball (manual p. 1-5, p. 1-12).
$OrbitSpecialRegister = 51; $OrbitSpecialAt100K = 0
$RecallRegister = 48; $RecallOn = 1
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
function Invoke-Measured([string]$Switch) {
    $credits = Get-EbcCredits; $seen = Get-EbcEventCount
    $d = Invoke-EbcScoredHit $Switch
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

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $AwardRegister -Value $AwardReplay | Out-Null
Set-EbcAdjustment -Number $OrbitSpecialRegister -Value $OrbitSpecialAt100K | Out-Null
Set-EbcAdjustment -Number $RecallRegister -Value $RecallOn | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

# ---- Ball 1 (1x): two E-I-G-H-T completions; the first awards an Extra
# Ball, the second a Special (OPS manual p. 1-11) ----
$letters = @('Drop Target "E"', 'Drop Target "I"', 'Drop Target "G"', 'Drop Target "H"', 'Drop Target "T"')
$first = $null; $second = $null
foreach ($round in 1, 2) { foreach ($l in $letters) { $m = Invoke-EightLetter $l; if ($l -eq $letters[-1]) { if ($round -eq 1) { $first = $m } else { $second = $m } } } }
$r = @([PSCustomObject]@{ Route = 'E-I-G-H-T'; Special = $second; Base = $first })
# ---- Ball 1 (2x): right collects take the orbit to 100,000 ----
for ($k = 0; $k -lt 5; $k++) { Invoke-ToActiveOrbit; Invoke-EbcScoredHit 'Right Rollover Button' | Out-Null; Step-EbcFrames -Frames 300 }
Invoke-Completions 2
$r += Invoke-OrbitSpecial
# ---- Next ball (3x): an outlane special ----
Invoke-Drain
Invoke-Completions 4
$outBase = Invoke-Measured 'Left Outlane'
Invoke-Completions 1                                              # completion 5: both outlane specials
$outSpecial = Invoke-Measured 'Left Outlane'
$r += [PSCustomObject]@{ Route = 'outlane'; Special = $outSpecial; Base = $outBase }

foreach ($x in $r) { Write-Host ("{0} at {1}x: special {2} (credits +{3}, knocks {4}, 6F {5}); without {6} (credits +{7}, knocks {8}, 6F {9})" -f $x.Route, $x.Special.M, $x.Special.Score, $x.Special.Credits, $x.Special.Knocks, $x.Special.Sixf, $x.Base.Score, $x.Base.Credits, $x.Base.Knocks, $x.Base.Sixf) }

Test-EbcItem -Name 'Collecting each available special at 1x, 2x, and 3x adds respectively 25,000, 50,000, and 75,000' -Doc "$Doc; $Specials" -Body {
    $seen = @($r | ForEach-Object { "$($_.Route) special at $($_.Special.M)x: additional $($_.Special.Score - $_.Base.Score)" })
    $want = @($r | ForEach-Object { "$($_.Route) special at $($_.Special.M)x: additional $($Additional[$_.Special.M])" })
    Assert-EbcEqual -Expected $want -Actual $seen -What ('score change with the special minus without (' + (($r | ForEach-Object { "$($_.Route) $($_.Special.Score) - $($_.Base.Score)" }) -join '; ') + ')')
    Assert-EbcEqual -Expected @('1x', '2x', '3x') -Actual @($r | ForEach-Object { "$($_.Special.M)x" }) -What 'multipliers covered'
}
Test-EbcItem -Name 'The original special award and knocker behavior still occur exactly once' -Doc "$Doc; $Specials; $Manual" -Body {
    $seen = @($r | ForEach-Object { "$($_.Route) at $($_.Special.M)x: credits +$($_.Special.Credits), knocks $($_.Special.Knocks), `$6F $($_.Special.Sixf); without the special: credits +$($_.Base.Credits), knocks $($_.Base.Knocks), `$6F $($_.Base.Sixf)" })
    $want = @($r | ForEach-Object { "$($_.Route) at $($_.Special.M)x: credits +$CreditsPerSpecial, knocks $KnocksPerSpecial, `$6F $SoundsPerSpecial; without the special: credits +0, knocks 0, `$6F 0" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'replay credit, knocker pulses and Special sounds per collecting hit'
}
Complete-EbcTests
