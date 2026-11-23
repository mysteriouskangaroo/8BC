param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# Register 48 "Recall roll up values" (OPS manual p. 1-5; p. 1-12: 1 recalls
# the lit roll-up values from ball to ball, 0 turns recall off) on the
# original ROM and on Deluxe. gamerules.md "Required gameplay verification":
# drain/new-ball must respect "existing operator settings for ... orbit
# value". Each tree sets the register through the service menu, takes the
# orbit value to 30,000 on ball 1, drains, and records whether ball 2 shows
# 30,000 on the orbit-value arrows (GameNames.psd1 Lamps).
#   originals: three left rollover hits light 5,000 -> 10,000 -> 20,000 ->
#     30,000 (OPS manual p. 1-11, "Left & Right Roll Up Lane Feature");
#     ball 2's arrows are read directly.
#   8bc-deluxe: a newly sunk ball activates the orbit at 10,000, and one right
#     collect advances it to 30,000 ("Right orbit"), read from the preview
#     that follows the collect's arrow chase; ball 2's arrows are read
#     after its first newly sunk ball activates the orbit (a new ball starts
#     at orbit inactive, with the arrows dark).
# The register 48 = 0 scenario FAILs at this commit: the original resets the
# value (ball 2 shows none) and Deluxe keeps 30,000 (Task 8c report,
# mismatch 3).
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"; OPS manual p. 1-5 and p. 1-12 register 48'
$RecallRegister = 48
$Ball1Value = 30000
$ArrowValues = @(10000, 20000, 30000, 40000)
$ArrowLamps = @($ArrowValues | ForEach-Object { Get-EbcLampNumber ('Rollover Lanes {0:N0}' -f $_) })
function Get-ArrowValue { $v = 0; for ($k = 0; $k -lt 4; $k++) { if (Get-EbcLamp -Number $ArrowLamps[$k]) { $v += $ArrowValues[$k] } }; $v }
function Invoke-Hit([string]$Switch) { Invoke-EbcScoredHit $Switch | Out-Null; Step-EbcFrames -Frames 60 }

function Invoke-Recall([int]$Setting) {
    Start-EbcGame
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number $RecallRegister -Value $Setting | Out-Null
    Exit-EbcServiceMode | Out-Null
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    $shown = 0
    if ($Tree -eq 'originals') { foreach ($k in 1..3) { Invoke-Hit 'Left Rollover Button' }; $shown = Get-ArrowValue }
    else {
        # The right collect's preview blinks the advanced value; it runs while
        # DELUXE_ORBIT_PREVIEW_TIMER (1115, read only) is nonzero. The chase's
        # last arrow still shows for a few frames at its start, so the last lit
        # value is taken (orbits.tests.ps1).
        Invoke-Hit 'Drop Target 1,2,9,10'
        Invoke-EbcSwitchHit 'Right Rollover Button'
        for ($k = 0; $k -lt 400; $k++) { Step-EbcFrames -Frames 1; $v = Get-ArrowValue; if ((Read-EbcByte 0x1115) -ne 0 -and $v -ne 0) { $shown = $v } }
        Step-EbcFrames -Frames 100
    }
    Add-EbcObservation ("register 48 = {0}: ball 1 ends at {1}" -f $Setting, $shown)
    if ((Invoke-EbcDrain) -ne 'Served') { throw 'no second ball' }
    Step-EbcFrames -Frames 150
    if ($Tree -ne 'originals') { Invoke-Hit 'Drop Target 3,11' }
    Add-EbcObservation ("register 48 = {0}: ball 2 shows {1}: {2}" -f $Setting, $Ball1Value, ((Get-ArrowValue) -eq $Ball1Value))
}

Invoke-EbcComparedScenario -Name 'With register 48 = 0 (recall off), the next ball resets the orbit value as on the original ROM' -Doc $Doc -Trees @('originals', '8bc-deluxe') -Scenario { Invoke-Recall 0 }
Invoke-EbcComparedScenario -Name 'With register 48 = 1 (recall on), the next ball keeps the orbit value as on the original ROM' -Doc $Doc -Trees @('originals', '8bc-deluxe') -Scenario { Invoke-Recall 1 }
Complete-EbcTests
