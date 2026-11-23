param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# Whether the roll-up lanes (orbit) Special, once collected, can be collected
# again on a later ball of the same game, on the original ROM and on Deluxe.
# gamerules.md "Left orbit": "The original already-collected latch in $10A0
# bit $20 prevents it from being relit after collection during the same
# ball." Both trees set register 25 = 3 (a Special awards a replay credit),
# 51 = 0 (the Special at 100K) and 48 = 1 (recall the roll-up value) through
# the service menu, collect the Special on ball 1, drain, and record the next
# ball's left rollover collect at the recalled 100,000.
#   originals: every left rollover hit collects and advances the value (OPS
#     manual p. 1-11); the hit at 100,000 collects the Special.
#   8bc-deluxe: the collect cycle reaches an active orbit for each collect
#     (tests/8bc-deluxe/specials.tests.ps1).
# Observed per tree: credits and knocker pulses of the Special collect and of
# the next ball's collect. Scores differ by design and are not compared.
# At this commit both trees match: neither relights the Special on the next
# ball, which tests/8bc-deluxe/specials.tests.ps1 reports as a doc/ROM
# mismatch that the original shares.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Left orbit"; OPS manual p. 1-5, p. 1-9, p. 1-12'
$Knocker = Get-EbcSolenoid 'Knocker'
$GroupOf = @{ 1 = 'Drop Target 1,2,9,10'; 2 = 'Drop Target 1,2,9,10'; 3 = 'Drop Target 3,11'; 4 = 'Drop Target 4,5,12,13'
              5 = 'Drop Target 4,5,12,13'; 6 = 'Drop Target 6,14'; 7 = 'Drop Target 7,15' }
$LatchOf = @{ 'Drop Target 1,2,9,10' = 0x01; 'Drop Target 3,11' = 0x04; 'Drop Target 4,5,12,13' = 0x08; 'Drop Target 6,14' = 0x20; 'Drop Target 7,15' = 0x40 }
$standups = (Get-EbcNames).StandupDropGroups
$ResetBy = @{}; foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }

function Invoke-Left {
    $credits = Get-EbcCredits; $seen = Get-EbcEventCount
    Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
    Step-EbcFrames -Frames 60
    [PSCustomObject]@{ Credits = (Get-EbcCredits) - $credits; Knocks = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $Knocker 1$" }).Count }
}
function Invoke-NewSink {
    $sunk = Get-EbcSunkBalls
    $next = @(1..7 | Where-Object { -not ($sunk -band (1 -shl ($_ - 1))) })
    if (-not $next.Count) { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null; Step-EbcFrames -Frames 30; return }
    $g = $GroupOf[$next[0]]
    if ((Read-EbcByte (Get-EbcRamAddress 'DROP_TARGET_SWITCH_CLOSURE_LATCHES')) -band $LatchOf[$g]) { Invoke-EbcScoredHit $ResetBy[$g] -AfterSolenoid $g | Out-Null }
    Invoke-EbcScoredHit $g | Out-Null
    Step-EbcFrames -Frames 30
}
# Deluxe collect states (src/8bc-deluxe/asm/symbols.inc, read only to choose
# the next shot): 4 = active, low bits 2 = spinner, 1/3 = orbit.
function Invoke-ToActiveOrbit {
    for ($k = 0; $k -lt 6; $k++) {
        $loc = (Read-EbcByte 0x10FB) -band 7
        if (($loc -band 4) -and ($loc -band 3) -ne 2) { Step-EbcFrames -Frames 30; return }
        if (($loc -band 3) -eq 2 -and ($loc -band 4)) { Invoke-EbcScoredHit 'Spinner' | Out-Null; Step-EbcFrames -Frames 300; continue }
        Invoke-NewSink
    }
    throw 'no active orbit'
}
# One orbit collect: on Deluxe, reached through the collect cycle.
function Invoke-Collect { if ($Tree -ne 'originals') { Invoke-ToActiveOrbit }; Invoke-Left }

Invoke-EbcComparedScenario -Name 'A collected orbit Special is not collected again on the next ball, as on the original ROM' -Doc $Doc -Trees @('originals', '8bc-deluxe') -Scenario {
    Start-EbcGame
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number 25 -Value 3 | Out-Null
    Set-EbcAdjustment -Number 51 -Value 0 | Out-Null
    Set-EbcAdjustment -Number 48 -Value 1 | Out-Null
    Exit-EbcServiceMode | Out-Null
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    $special = $null
    for ($k = 0; $k -lt 15 -and -not $special; $k++) { $c = Invoke-Collect; if ($c.Knocks) { $special = $c } }
    if (-not $special) { throw 'no orbit Special within 15 collects' }
    Add-EbcObservation ("ball 1 Special collect: credits +{0}, knocks {1}" -f $special.Credits, $special.Knocks)
    if ((Invoke-EbcDrain) -ne 'Served') { throw 'no next ball' }
    Step-EbcFrames -Frames 120
    Invoke-EbcScoredHit 'Rebound' | Out-Null
    $next = Invoke-Collect
    Add-EbcObservation ("next ball collect at the recalled value: credits +{0}, knocks {1}" -f $next.Credits, $next.Knocks)
}
Complete-EbcTests
