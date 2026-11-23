param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# The left orbit collect's sound commands, played identically on the original
# ROM and on Deluxe: sink ball 1 (on Deluxe this activates the opening orbit
# stage; on the original it only scores), then hit the left rollover and
# record the sound commands it sends. The two observation lists must match.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

# gamerules.md "Left orbit": "Its original single collect-sound path is
# unchanged"; "Required gameplay verification": "the active left collect
# retains its original side-specific sound". Original means as the original
# ROM sends it. On the original every left rollover hit collects the orbit
# value (gamerules.md "Existing rules"). Scores differ by design and are not
# compared.
$Doc = 'src/8bc-deluxe/gamerules.md "Left orbit"; "Required gameplay verification"'

# Sound commands since event index $Since, each once (libpinmame also reports
# the byte shifted right four, GameNames.psd1 Sounds), speech prompts 41-80
# (HARDWARE_MAP response map) excluded.
function Get-Commands([int]$Since) {
    $ev = @(Get-EbcEvents -Since $Since | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $f = $_ -split ' '; [PSCustomObject]@{ F = [int]$f[0]; B = [int]$f[3] } })
    for ($i = 0; $i -lt $ev.Count; $i++) {
        if ($ev[$i].B -lt 0x41 -or $ev[$i].B -gt 0x80) { '{0:X2}' -f $ev[$i].B }
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    }
}

Invoke-EbcComparedScenario -Name 'The active left orbit collect sends the original ROM''s left-orbit sound commands' -Doc $Doc -Trees @('originals', '8bc-deluxe') -Scenario {
    Start-EbcGame
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    Invoke-EbcScoredHit 'Drop Target 1,2,9,10' | Out-Null
    Step-EbcFrames -Frames 30
    $seen = Get-EbcEventCount
    Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
    Add-EbcObservation ("left rollover after a first sink: [{0}]" -f (@(Get-Commands $seen) -join ' '))
}
Complete-EbcTests
