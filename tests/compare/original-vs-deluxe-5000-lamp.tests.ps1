param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# The 5,000 drop-target lamp effect of an already-sunk ball, played
# identically on the original ROM and on Deluxe: sink ball 3 with Drop Target
# 3,11, reset that target with its E-I-G-H-T standup ("G"), hit it again, and
# record lamp 5,000 Drop Target 3 frame by frame after each step. The two
# observation lists must match exactly.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

# gamerules.md "Called ball score": an already-sunk ball "retains its separate
# normal 5,000 playfield-value path"; "Required gameplay verification": it
# "retains the physical 5,000 lamp effect". GAME_RULE_TRACES.md "Pool-ball
# drop targets": D034 updates that lamp effect through 10BF and 103F. Retained
# means the lamp behaves as in the original ROM. Scores differ by design
# (Deluxe scale and first-sink value), so only the lamp is compared.
$Doc = 'src/8bc-deluxe/gamerules.md "Called ball score"; "Required gameplay verification"'
# 5,000 DROP TARGET 3 (GameNames.psd1 Lamps, from the manual's lamp table).
$Lamp = Get-EbcLampNumber '5,000 Drop Target 3'
# Frames recorded after each step (four 16-frame blink cycles).
$SampleFrames = 64

# '<step>: L<lamp> <one character per frame, # lit, . dark>'
function Add-Lamp([string]$What) {
    $s = ''
    for ($k = 0; $k -lt $SampleFrames; $k++) { Step-EbcFrames -Frames 1; $s += $(if (Get-EbcLamp -Number $Lamp) { '#' } else { '.' }) }
    Add-EbcObservation ("{0}: L{1} {2}" -f $What, $Lamp, $s)
}

Invoke-EbcComparedScenario -Name 'An already-sunk ball''s 5,000 drop-target lamp behaves as in the original ROM' -Doc $Doc -Trees @('originals', '8bc-deluxe') -Scenario {
    Start-EbcGame
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    Add-Lamp 'ball 1 served'
    Invoke-EbcScoredHit 'Drop Target 3,11' | Out-Null
    Add-Lamp 'ball 3 first sink'
    Invoke-EbcScoredHit 'Drop Target "G"' -AfterSolenoid 'Drop Target 3,11' | Out-Null
    Add-Lamp 'Drop Target 3,11 reset by "G"'
    Invoke-EbcScoredHit 'Drop Target 3,11' | Out-Null
    Add-Lamp 'already-sunk hit on Drop Target 3,11'
    Step-EbcFrames -Frames 600
    Add-Lamp '600 frames later'
}
Complete-EbcTests
