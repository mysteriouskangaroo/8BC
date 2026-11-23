param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM automatic solenoid test (function 92): it pulses page 1-18
# tests 01-12 in order, then holds continuous output 13 (K1), reached from
# keypad mode by keying the function number.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/originals/ghidra/HARDWARE_MAP.md "Solenoid self-test outputs and page 1-18 identification"'
$Manual = 'OPS manual p. 1-4 "Solenoids (Function 92)" and p. 1-5 test functions'
# Manual p. 1-5: function 92 is the solenoids test; p. 1-3/1-4: keypad entry
# shows the keyed number on the match/credit display.
$Function = '92'
$ExpectedTestNumber = '92'
# HARDWARE_MAP.md / page 1-18: tests 01-12 are momentary coils, test 13 is the
# continuous K1 Relay (Flipper Enable) output.
$Tests = @(
    'Drop Target 1,2,9,10', 'Drop Target 3,11', 'Drop Target 4,5,12,13', 'Drop Target 6,14',
    'Drop Target 7,15', 'Saucer', 'Right Thumper Bumper', 'Left Thumper Bumper',
    'Right Slingshot', 'Left Slingshot', 'Outhole', 'Knocker', 'K1 Relay (Flipper Enable)')
$Continuous = 'K1 Relay (Flipper Enable)'
# Frames recorded: one full cycle of 13 tests is about 940 frames (measured).
$RecordFrames = 1500

$byNumber = @{}; foreach ($t in $Tests) { $byNumber[(Get-EbcSolenoid $t)] = $t }

Start-EbcGame
Enter-EbcServiceMode | Out-Null
$seen = Get-EbcEventCount
foreach ($c in $Function.ToCharArray()) { Invoke-EbcKey ([string]$c) }
Invoke-EbcKey 'Enter'
Step-EbcFrames -Frames $RecordFrames
$events = @(Get-EbcEvents -Since $seen)

# Each output's on/off events, in order, as name and frame.
$pulses = @(); $open = @{}
foreach ($e in $events) {
    if ($e -match '^(\d+) sol (\d+) ([01])$') {
        $f = [int]$Matches[1]; $n = [int]$Matches[2]
        if ($Matches[3] -eq '1') { $open[$n] = $f }
        elseif ($open.ContainsKey($n)) { $pulses += [PSCustomObject]@{ Name = $(if ($byNumber.ContainsKey($n)) { $byNumber[$n] } else { "solenoid $n" }); On = $open[$n]; Frames = $f - $open[$n] }; $open.Remove($n) }
    }
}
$firstCycle = @($pulses | Select-Object -First $Tests.Count)

Test-EbcItem -Name 'Keying 92 in keypad mode runs the solenoid test showing 92' -Doc $Manual -Body {
    # Only the display events after the first pulse, so the keyed digits do not count.
    $from = $firstCycle[0].On
    $shown = @($events | Where-Object { $_ -match "^(\d+) disp $((Get-EbcNames).Displays.Status) " -and [int]$Matches[1] -gt $from } | ForEach-Object { ($_ -split ' ', 4)[3] -replace '[ ,]', '' } | Where-Object { $_ -ne '' } | Select-Object -Unique)
    Assert-EbcTrue ($shown -contains $ExpectedTestNumber) "match/credit display showed '$($shown -join '/')', expected '$ExpectedTestNumber' among them"
}
Test-EbcItem -Name 'The automatic test fires page 1-18 tests 01-12 in order, then 13' -Doc $Doc -Body {
    Assert-EbcEqual -Expected $Tests -Actual @($firstCycle | ForEach-Object { $_.Name }) -What 'outputs switched on, in order, in the first cycle'
}
Test-EbcItem -Name 'Test 13 is a continuous output, held longer than any momentary pulse' -Doc $Doc -Body {
    $k1 = @($firstCycle | Where-Object { $_.Name -eq $Continuous })
    $momentary = @($firstCycle | Where-Object { $_.Name -ne $Continuous } | ForEach-Object { $_.Frames } | Measure-Object -Maximum).Maximum
    Assert-EbcEqual -Expected 1 -Actual $k1.Count -What 'K1 on/off periods in the first cycle'
    Assert-EbcTrue ($k1[0].Frames -gt $momentary) "K1 held $($k1[0].Frames) frames, the longest momentary pulse $momentary"
}
Complete-EbcTests
