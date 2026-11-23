param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe collect feature: the orbit inactive -> orbit active -> spinner
# inactive -> spinner active -> orbit inactive cycle, one newly sunk ball per
# activation, no queued activations, and the collected 8-ball as an
# activation event, all by play on one ball.
#
# The location is read from what a shot scores, using the doc's values: an
# inactive orbit scores 500 and an active one its orbit value (at least the
# printed 10,000, 1,000 displayed); an inactive spinner scores 10 and an
# active one its lit value (at least the printed 1,000, 100 displayed).
# Exact orbit and spinner values are checked in orbits and spinner.tests.ps1.
# Clauses of gamerules.md "Required gameplay verification" checked here
# (tools/tests/Test-DeluxeCoverage.ps1):
# Clause: Verify collecting the lit 8-ball activates
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Deluxe collect feature"; "Required gameplay verification"'
$Orbit = 'src/8bc-deluxe/gamerules.md "Left orbit", "Right orbit"'
$Spin = 'src/8bc-deluxe/gamerules.md "Spinner"'
# "Left orbit"/"Right orbit": an inactive rollover awards 500.
$OrbitInactive = 500
# "Deluxe collect feature" item 2: activating promotes the 5,000 baseline to
# the printed 10,000 value: 10,000 / 10 = 1,000 or more while active.
$OrbitActiveMin = 10000 / 10
# "Spinner": an unlit spinner scores 10; the collect begins at 100 (printed
# 1,000) and only rises.
$SpinnerInactive = 10
$SpinnerActiveMin = 1000 / 10
# "Spinner": about two seconds with no pulse ends spinner collecting. Waited
# after a first pulse before the spinner is read again: FramesPerSecond x 3,
# well past 2 seconds + 20%.
$StopWaitFrames = (Get-EbcNames).FramesPerSecond * 3

# Pool balls by drop group in this file's sink order (drop-targets.tests.ps1:
# group 25 sinks ball 1 then 2, group 28 ball 4 then 5). A group's second
# ball needs its E-I-G-H-T standup hit first (GameNames.psd1
# StandupDropGroups).
$ResetBy = @{}
$standups = (Get-EbcNames).StandupDropGroups
foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }

$script:Deltas = @()
function Get-OrbitState([string]$Side) {
    $d = Invoke-EbcScoredHit "$Side Rollover Button"
    $script:Deltas += "$Side orbit $d"
    if ($d -eq $OrbitInactive) { 'orbit inactive' } elseif ($d -ge $OrbitActiveMin) { 'orbit active' } else { "orbit scored $d" }
}
# Reads the spinner with one pulse. An active first pulse starts spinner
# collecting, so the file waits for it to stop before the next read.
function Get-SpinnerState {
    $d = Invoke-EbcScoredHit 'Spinner'
    $script:Deltas += "spinner $d"
    if ($d -eq $SpinnerInactive) { 'spinner inactive' }
    elseif ($d -ge $SpinnerActiveMin) { Step-EbcFrames -Frames $StopWaitFrames; 'spinner active' }
    else { "spinner scored $d" }
}
# A newly sunk ball; throws unless 10C3 gains a bit.
function Invoke-Sink([string]$Group, [switch]$Rearm) {
    if ($Rearm) { Invoke-EbcScoredHit $ResetBy[$Group] -AfterSolenoid $Group | Out-Null }
    $before = Get-EbcSunkBalls
    Invoke-EbcScoredHit $Group | Out-Null
    if ((Get-EbcSunkBalls) -eq $before) { throw ('{0} sank no new ball (10C3 {1:X2})' -f $Group, $before) }
    $script:Deltas += "sink $Group"
    'sink'
}
function Invoke-Saucer { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null; $script:Deltas += 'saucer'; 'saucer' }
function Assert-Sequence([string[]]$Expected, [string[]]$Actual) {
    $scores = $script:Deltas -join '; '; $script:Deltas = @()
    Assert-EbcEqual -Expected $Expected -Actual $Actual -What "states read in order (scores: $scores)"
}

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'A new game begins at orbit inactive and the first newly sunk ball activates that same location' -Doc "$Doc; $Orbit; $Spin" -Body {
    $seen = @(Get-OrbitState 'Left'; Get-SpinnerState; Invoke-Sink 'Drop Target 1,2,9,10'; Get-SpinnerState; Get-OrbitState 'Left')
    Assert-Sequence @('orbit inactive', 'spinner inactive', 'sink', 'spinner inactive', 'orbit active') $seen
}
Test-EbcItem -Name 'The cycle is orbit inactive -> orbit active -> spinner inactive -> spinner active -> orbit inactive, with a distinct newly sunk ball for each activation' -Doc "$Doc; $Orbit; $Spin" -Body {
    # The left collect above moved the feature to spinner inactive.
    $seen = @(
        Get-SpinnerState; Get-OrbitState 'Right'            # spinner inactive; no orbit
        Invoke-Sink 'Drop Target 3,11'; Get-SpinnerState    # spinner active, first pulse
        Get-SpinnerState; Get-OrbitState 'Left'             # orbit inactive, waits for a sink
        Invoke-Sink 'Drop Target 4,5,12,13'; Get-OrbitState 'Right'  # repeating orbit stage
        Get-SpinnerState)
    Assert-Sequence @('spinner inactive', 'orbit inactive', 'sink', 'spinner active', 'spinner inactive', 'orbit inactive', 'sink', 'orbit active', 'spinner inactive') $seen
}
Test-EbcItem -Name 'Extra newly sunk balls while spinner is active neither move it nor queue the next activation' -Doc "$Doc; $Orbit; $Spin" -Body {
    # At spinner inactive (the right collect above).
    $seen = @(Invoke-Sink 'Drop Target 6,14'; Invoke-Sink 'Drop Target 7,15'; Get-OrbitState 'Left'; Get-SpinnerState; Get-OrbitState 'Left'; Get-SpinnerState)
    Assert-Sequence @('sink', 'sink', 'orbit inactive', 'spinner active', 'orbit inactive', 'spinner inactive') $seen
}
Test-EbcItem -Name 'An ordinary saucer hit does not activate the collect' -Doc "$Doc; $Orbit; $Spin" -Body {
    # At orbit inactive (the first spinner pulse above); balls 1-7 are not all
    # sunk, so the saucer is not collecting the 8-ball.
    Assert-EbcTrue ((Get-EbcSunkBalls) -ne 0x7F) ('10C3 {0:X2}: the 8-ball would be lit' -f (Get-EbcSunkBalls))
    $seen = @(Invoke-Saucer; Get-SpinnerState; Get-OrbitState 'Left'; Get-OrbitState 'Right')
    Assert-Sequence @('saucer', 'spinner inactive', 'orbit inactive', 'orbit inactive') $seen
}
Test-EbcItem -Name 'Extra newly sunk balls while an orbit is active neither move it nor queue the next activation' -Doc "$Doc; $Orbit; $Spin" -Body {
    $seen = @(Invoke-Sink 'Drop Target 1,2,9,10' -Rearm; Invoke-Sink 'Drop Target 4,5,12,13' -Rearm; Get-SpinnerState; Get-OrbitState 'Left'; Get-SpinnerState)
    Assert-Sequence @('sink', 'sink', 'spinner inactive', 'orbit active', 'spinner inactive') $seen
}
Test-EbcItem -Name 'Collecting the lit 8-ball activates an inactive location' -Doc "$Doc; $Orbit; $Spin" -Body {
    # Balls 1-7 are sunk and the feature is at spinner inactive.
    Assert-EbcEqual -Expected '7F' -Actual ('{0:X2}' -f (Get-EbcSunkBalls)) -What '10C3 before the 8-ball'
    $seen = @(Invoke-Saucer; Get-SpinnerState; Get-OrbitState 'Left')
    Assert-EbcEqual -Expected '00' -Actual ('{0:X2}' -f (Get-EbcSunkBalls)) -What '10C3 after the 8-ball (new rack)'
    Assert-Sequence @('saucer', 'spinner active', 'orbit inactive') $seen
}
Test-EbcItem -Name 'Collecting the lit 8-ball while a location is active does nothing and is never queued' -Doc "$Doc; $Orbit; $Spin" -Body {
    # Orbit inactive; a new rack: the first sink activates the orbit, the
    # other six and the 8-ball arrive while it is active.
    $seen = @(
        Invoke-Sink 'Drop Target 1,2,9,10'; Invoke-Sink 'Drop Target 1,2,9,10' -Rearm; Invoke-Sink 'Drop Target 3,11'
        Invoke-Sink 'Drop Target 4,5,12,13'; Invoke-Sink 'Drop Target 4,5,12,13' -Rearm; Invoke-Sink 'Drop Target 6,14'; Invoke-Sink 'Drop Target 7,15')
    Assert-EbcEqual -Expected '7F' -Actual ('{0:X2}' -f (Get-EbcSunkBalls)) -What '10C3 before the second 8-ball'
    $seen += @(Invoke-Saucer; Get-SpinnerState; Get-OrbitState 'Right'; Get-SpinnerState; Get-OrbitState 'Left')
    Assert-Sequence (@('sink') * 7 + @('saucer', 'spinner inactive', 'orbit active', 'spinner inactive', 'orbit inactive')) $seen
}
Complete-EbcTests
