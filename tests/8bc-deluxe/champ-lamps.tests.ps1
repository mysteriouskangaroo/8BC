param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe CHAMP: the completion milestones 1-6, the thumper upgrades and their
# reset at a drain, the outlane specials lit without entering the Special
# path, and the five letter lamps through orbit collects with the C/P
# anti-shatz latch, all by play on one player's first two balls.
#
# Units. gamerules.md "CHAMP" and its verification clauses write these values
# as manual/playfield values: the completing lane's "normal 9K" at 3x is the
# 3,000-point CHAMP lane, which "Required gameplay verification" scores as 300
# displayed (so 900 at 3x). This file therefore converts every CHAMP value
# with the doc's divide-by-ten rule ("Deluxe score scale"): thumper 3K/6K/9K
# -> 300/600/900, stock 1K -> 100, 30K -> 3,000, 90K -> 9,000, 9K -> 900,
# 99K -> 9,900. The reading is listed for a user ruling in the Task 8b report.
# Clauses of gamerules.md "Required gameplay verification" checked here
# (tools/tests/Test-DeluxeCoverage.ps1):
# Clause: Verify CHAMP completions 1-5
# Clause: Verify lighting the outlane specials
# Clause: Verify the upgraded left and right thumpers
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Champ = 'src/8bc-deluxe/gamerules.md "CHAMP"'
$Collect = 'src/8bc-deluxe/gamerules.md "Deluxe collect feature"'
$Scale = 'src/8bc-deluxe/gamerules.md "Deluxe score scale"'

# Upgraded thumpers: 3K/6K/9K at 1x/2x/3x, each / 10.
$Thumper = @{ 1 = 3000 / 10; 2 = 6000 / 10; 3 = 9000 / 10 }
# Stock thumper: 1K -> 1,000 / 10 at 1x.
$Stock = 1000 / 10
# Completion 5 and later: 30K base through the multiplier: 90K at 3x;
# with the completing lane's 9K (3,000 x 3) the switch event moves 99K.
$Milestone = 30000 / 10
$Lane = 3000 / 10
$Full3x = (90000 + 9000) / 10
# The playfield multiplier after each completion: CHAMP_COMPLETION_STATE 10C0
# bit 10 = double, bit 20 = triple (GAME_RULE_TRACES.md "Playfield Scores
# Double and Triple"). Completion 5 "retains 3x".
$StateAfter = @{ 1 = '1x'; 2 = '2x'; 3 = '2x'; 4 = '3x' }
# "Specials": a collected special plays $6F and the knocker; lighting one must
# do neither.
$SpecialSound = 0x6F
# "CHAMP does not change spinner value": the spinner collect begins at the
# printed 1,000 each ball ("Spinner"), shown by its 1,000 lamp alone.
$SpinnerStart = 1000

$Letters = @('C', 'H', 'A', 'M', 'P')
$LetterLamp = @{}; foreach ($l in $Letters) { $LetterLamp[$l] = Get-EbcLampNumber """$l"" Rollover" }
$LaneOf = @{ C = '"C" Return Lane'; H = '"H" Top Lane'; A = '"A" Top Lane'; M = '"M" Top Lane'; P = '"P" Return Lane' }
$OutlaneLamps = @((Get-EbcLampNumber 'Left Outlane'), (Get-EbcLampNumber 'Right Outlane'))
$SpinLamps = @('Spinner 1,000', 'Spinner 3,000', 'Spinner 5,000' | ForEach-Object { Get-EbcLampNumber $_ })
$Knocker = Get-EbcSolenoid 'Knocker'
$Fps = (Get-EbcNames).FramesPerSecond
$SpinnerStopFrames = $Fps * 3
$LampSampleFrames = 32
$WatchFrames = 420

function Get-Commands([int]$Since) {
    # Sound commands, each once (libpinmame also reports byte >> 4), speech
    # prompts 41-80 excluded except where counted separately.
    $ev = @(Get-EbcEvents -Since $Since | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $f = $_ -split ' '; [PSCustomObject]@{ F = [int]$f[0]; B = [int]$f[3] } })
    for ($i = 0; $i -lt $ev.Count; $i++) {
        $ev[$i]
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    }
}
function Get-Multiplier { $c = Get-EbcChampState; if ($c -band 0x20) { '3x' } elseif ($c -band 0x10) { '2x' } else { '1x' } }
function Get-Pulses([int]$Since, [int]$Solenoid) { @(Get-EbcEvents -Since $Since | Where-Object { $_ -match "^\d+ sol $Solenoid 1$" }).Count }
# A thumper hit: score, non-speech sound commands, its own coil's pulses.
function Invoke-Thumper([string]$Side) {
    $name = "$Side Thumper Bumper"
    $seen = Get-EbcEventCount
    $d = Invoke-EbcScoredHit $name
    $snd = (@(Get-Commands $seen | Where-Object { $_.B -lt 0x41 -or $_.B -gt 0x80 } | ForEach-Object { '{0:X2}' -f $_.B }) -join ' ')
    [PSCustomObject]@{ Side = $Side; Score = $d; Sounds = $snd; Pulses = (Get-Pulses $seen (Get-EbcSolenoid $name)) }
}
function Format-Thumper($t) { "$($t.Side) thumper $($t.Score), sounds [$($t.Sounds)], coil pulses $($t.Pulses)" }
function Get-OutlaneLit { $n = 0; for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; foreach ($l in $OutlaneLamps) { if (Get-EbcLamp -Number $l) { $n++; break } } }; $n -gt 0 }
# A completion: the five lanes in order (C-H-A-M-P), the center rollover
# rearming the C/P latch before P. Returns the P lane's score change (the
# completing switch event), with sounds, knocks and credits around it.
function Invoke-Completion {
    $credits = Get-EbcCredits
    $seen = Get-EbcEventCount
    $lanes = @(Complete-EbcChamp -RearmWith 'Center Rollover Button')
    [PSCustomObject]@{
        Completing = $lanes[-1]; Lanes = $lanes; State = Get-Multiplier
        Special6F = @(Get-Commands $seen | Where-Object { $_.B -eq $SpecialSound }).Count
        Knocks = Get-Pulses $seen $Knocker; Credits = (Get-EbcCredits) - $credits
    }
}
# The letter lamps lit. The normal display lights the letters still to be
# collected and darkens collected ones, as the original ROM does
# (tests/compare/original-vs-deluxe-champ-lamps.tests.ps1).
function Get-LetterLamps { (@($Letters | Where-Object { Get-EbcLamp -Number $LetterLamp[$_] }) -join '') }
# The letters collected in CHAMP_LANE_STATE (1040 bits 0-4 set, HARDWARE_MAP.md
# "C-H-A-M-P lamp shadows"), the authoritative state.
function Get-LetterState { $b = Read-EbcByte (Get-EbcRamAddress 'CHAMP_LANE_STATE'); (@(for ($k = 0; $k -lt 5; $k++) { if ($b -band (1 -shl $k)) { $Letters[$k] } }) -join '') }
# Closes $Switch and records the letter lamps every frame for $WatchFrames
# frames; returns the distinct patterns seen.
function Watch-Letters([string]$Switch) {
    $n = Get-EbcSwitch $Switch
    $pats = [Collections.Generic.List[string]]::new()
    for ($k = 0; $k -lt $WatchFrames; $k++) {
        if ($k -eq 0) { Set-EbcSwitch -Number $n -Closed $true }
        if ($k -eq 4) { Set-EbcSwitch -Number $n -Closed $false }
        Step-EbcFrames -Frames 1
        $p = Get-LetterLamps; if (-not $pats.Contains($p)) { $pats.Add($p) }
    }
    Step-EbcFrames -Frames 150
    @($pats)
}
function Format-Pats($p) { '[' + (@($p | ForEach-Object { if ($_ -eq '') { '-' } else { $_ } }) -join ', ') + ']' }

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

# ---- Ball 1: milestones ----
$stockHits = @((Invoke-Thumper 'Right'), (Invoke-Thumper 'Left'))
$comp = @{}; $thump = @{}; $outlanes = @{}
$outlanes[0] = Get-OutlaneLit
foreach ($n in 1..4) {
    $comp[$n] = Invoke-Completion
    $outlanes[$n] = Get-OutlaneLit
    $thump[$n] = @((Invoke-Thumper 'Right'), (Invoke-Thumper 'Left'))
}
$comp[5] = Invoke-Completion
$outlanes[5] = Get-OutlaneLit
$comp[6] = Invoke-Completion

Test-EbcItem -Name 'CHAMP completions 1-4 give right thumper 3K, 2x playfield, left thumper 3K, 3x playfield' -Doc "$Doc; $Champ; $Scale" -Body {
    # Thumper values at the multiplier then in force. The doc gives the stock
    # 1K's multiplier behavior nowhere, so the still-stock left thumper is
    # checked only at 1x (completion 1).
    $seen = @(1..4 | ForEach-Object { "completion ${_}: state $($comp[$_].State); right thumper $($thump[$_][0].Score)" + $(if ($_ -ne 2) { ", left thumper $($thump[$_][1].Score)" }) })
    $want = @(
        "completion 1: state $($StateAfter[1]); right thumper $($Thumper[1]), left thumper $($Stock * 1)",
        "completion 2: state $($StateAfter[2]); right thumper $($Thumper[2])",
        "completion 3: state $($StateAfter[3]); right thumper $($Thumper[2]), left thumper $($Thumper[2])",
        "completion 4: state $($StateAfter[4]); right thumper $($Thumper[3]), left thumper $($Thumper[3])")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'state and thumper scores after each completion'
}
Test-EbcItem -Name 'Completion 5 lights both outlane specials and awards 30K; at 3x the milestone is 90K and the completing switch event moves 99K' -Doc "$Doc; $Champ; $Scale" -Body {
    $seen = "outlanes lit before completion 5: $($outlanes[4]); after: $($outlanes[5]); state $($comp[5].State); completing P lane event $($comp[5].Completing)"
    $want = "outlanes lit before completion 5: False; after: True; state $($StateAfter[4]); completing P lane event $Full3x"
    Assert-EbcEqual -Expected $want -Actual $seen -What "completion 5 (90K = $Milestone x 3, lane $Lane x 3)"
}
Test-EbcItem -Name 'Each later completion awards another 30K through the multiplier (99K switch event at 3x)' -Doc "$Doc; $Champ; $Scale" -Body {
    Assert-EbcEqual -Expected "state $($StateAfter[4]); completing P lane event $Full3x" -Actual "state $($comp[6].State); completing P lane event $($comp[6].Completing)" -What 'completion 6'
}
Test-EbcItem -Name 'A completion after the fifth awards another 30K base through the playfield multiplier, apart from the completing lane''s own score' -Doc "$Doc; $Champ; $Scale" -Body {
    # The completing P lane's own score is a CHAMP lane's normal score; the M
    # lane of the same completion is one, at the same multiplier.
    $mScore = $comp[6].Lanes[3]
    Assert-EbcEqual -Expected "lane $($Lane * 3); milestone $($Milestone * 3)" -Actual "lane $mScore; milestone $($comp[6].Completing - $mScore)" -What "completion 6 at $($comp[6].State): the M lane's score, and the P lane event minus it"
}
Test-EbcItem -Name 'Lighting the outlane specials on completion 5 enters no Special path: no Special points, sound, knocker or award' -Doc "$Doc; $Champ" -Body {
    # Special points would show as a score above the 99K event above.
    $seen = "completion 5: event $($comp[5].Completing), `$6F $($comp[5].Special6F), knocks $($comp[5].Knocks), credits +$($comp[5].Credits)"
    Assert-EbcEqual -Expected "completion 5: event $Full3x, `$6F 0, knocks 0, credits +0" -Actual $seen -What 'Special-path effects of completion 5'
}

# ---- Ball 1: letter lamps through orbit collects, and the C/P latch ----
# The collect is at orbit inactive (no ball sunk yet this ball).
$laneScores = @()
foreach ($l in 'H', 'A') { $laneScores += Invoke-EbcScoredHit $LaneOf[$l] }
$state1 = Get-LetterState
$p1Sink = Watch-Letters 'Drop Target 1,2,9,10'                    # orbit active
$p1Collect = Watch-Letters 'Left Rollover Button'                 # -> spinner inactive
Invoke-EbcScoredHit 'Drop Target 3,11' | Out-Null                 # spinner active
Invoke-EbcScoredHit 'Spinner' | Out-Null                          # orbit inactive
Step-EbcFrames -Frames $SpinnerStopFrames
foreach ($l in 'M', 'C') { $laneScores += Invoke-EbcScoredHit $LaneOf[$l] }
$lockedP = Invoke-EbcScoredHit $LaneOf['P']                       # C was just awarded: P is locked
$state2 = Get-LetterState
$p2Sink = Watch-Letters 'Drop Target 4,5,12,13'                   # orbit active
$p2Collect = Watch-Letters 'Right Rollover Button'                # rearms C/P; -> spinner inactive
$compAfter = Invoke-EbcScoredHit $LaneOf['P']                     # completes the word
$stateAfter = Get-LetterState
# CHAMP left the spinner value alone: activate it and read its lamps.
Invoke-EbcScoredHit 'Drop Target 6,14' | Out-Null                 # spinner active
Step-EbcFrames -Frames 30
$spinPattern = (@($SpinLamps | ForEach-Object { if (Get-EbcLamp -Number $_) { '#' } else { '.' } }) -join '')

Test-EbcItem -Name 'All five C-H-A-M-P letter lamps hold the collected-letter display through orbit activation and collection, with no H/A/M blackout or roll' -Doc "$Doc; $Collect; $Champ" -Body {
    $seen = @(
        "letters $state1 collected: orbit activation shows $(Format-Pats $p1Sink), left collect $(Format-Pats $p1Collect)",
        "letters $state2 collected: orbit activation shows $(Format-Pats $p2Sink), right collect $(Format-Pats $p2Collect)")
    # Lit on every frame: the letters not yet collected.
    $want = @(
        "letters HA collected: orbit activation shows [CMP], left collect [CMP]",
        "letters CHAM collected: orbit activation shows [P], right collect [P]")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'letter lamps lit on every frame of each hit'
}
Test-EbcItem -Name 'CHAMP lane scoring and the C/P anti-shatz latch are unchanged around orbit collects' -Doc "$Doc; $Champ" -Body {
    # At 3x each new lane scores 3,000 x 3; a locked P still scores its lane
    # points without lighting P; the orbit collect (a qualifying shot)
    # rearms it, and P then completes the word (another 99K event).
    $seen = "lanes H A M C: [$($laneScores -join ', ')]; locked P: $lockedP, letters $state2; P after the right collect: $compAfter, letters '$stateAfter'"
    $want = "lanes H A M C: [$((@($Lane * 3) * 4) -join ', ')]; locked P: $($Lane * 3), letters CHAM; P after the right collect: $Full3x, letters ''"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'lane scores and letters'
}
Test-EbcItem -Name 'CHAMP completion does not change the spinner value' -Doc "$Doc; $Champ" -Body {
    # Seven completions this ball; the spinner shows its start value.
    Assert-EbcEqual -Expected '#..' -Actual $spinPattern -What "spinner lamps 1,000/3,000/5,000 at activation (start value $SpinnerStart)"
}

# ---- Ball 2: thumpers back to stock ----
Invoke-EbcDrain | Out-Null
Step-EbcFrames -Frames 120
$ball2 = @((Invoke-Thumper 'Right'), (Invoke-Thumper 'Left'))
$state3 = Get-Multiplier
Test-EbcItem -Name 'The upgraded thumpers score 3K/6K/9K at 1x/2x/3x, return to the stock 1K after a drain, and keep their sound and coil pulse' -Doc "$Doc; $Champ; $Scale" -Body {
    $seen = @($stockHits | ForEach-Object { 'ball 1 stock: ' + (Format-Thumper $_) }) +
            @("1x: right $($thump[1][0].Score)", "2x: right $($thump[2][0].Score), left $($thump[3][1].Score)", "3x: right $($thump[4][0].Score), left $($thump[4][1].Score)") +
            @(1..4 | ForEach-Object { $n = $_; $thump[$n] | ForEach-Object { "completion ${n} $($_.Side): sounds [$($_.Sounds)], coil pulses $($_.Pulses)" } }) +
            @($ball2 | ForEach-Object { "ball 2 ($state3): " + (Format-Thumper $_) })
    $want = @($stockHits | ForEach-Object { "ball 1 stock: $($_.Side) thumper $Stock, sounds [$($stockHits[0].Sounds)], coil pulses 1" }) +
            @("1x: right $($Thumper[1])", "2x: right $($Thumper[2]), left $($Thumper[2])", "3x: right $($Thumper[3]), left $($Thumper[3])") +
            @(1..4 | ForEach-Object { $n = $_; $thump[$n] | ForEach-Object { "completion ${n} $($_.Side): sounds [$($stockHits[0].Sounds)], coil pulses 1" } }) +
            @($ball2 | ForEach-Object { "ball 2 (1x): $($_.Side) thumper $Stock, sounds [$($stockHits[0].Sounds)], coil pulses 1" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'thumper hits'
}
Complete-EbcTests
