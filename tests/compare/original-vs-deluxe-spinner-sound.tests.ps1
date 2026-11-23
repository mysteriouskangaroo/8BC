param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# The spinner's sound command for each award tier on the original ROM and on
# Deluxe. gamerules.md "Spinner": "Spinner sounds follow the highest lit value
# lamp, matching the original sound tiers: unlit 10 uses the original 100
# sound; 100 uses the original 1,000 sound; printed 3,000 and 4,000 use the
# 3,000 sound; and printed 5,000, 6,000, 8,000, and 9,000 use the 5,000 sound."
# Original means as the original ROM sends it. Each tree records one spin per
# tier, named by the original award: the original's 100, 1,000, 3,000 and
# 5,000 spins (register 49 = 0 starts it at 100; each C-H-A-M-P completion
# raises the lamp, tests/originals/spinner.tests.ps1), and Deluxe's unlit 10
# and active 100, 300 and 500 spins (reached as in
# tests/8bc-deluxe/spinner.tests.ps1). Scores differ by design and are not
# compared.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Spinner"; "Required gameplay verification"'
# OPS manual p. 1-5: register 49 "Spinner start at", 0 = 100 points.
$StartRegister = 49

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
# One spin: records the sound commands of the next 30 frames under $Tier.
function Add-Spin([string]$Tier) {
    $seen = Get-EbcEventCount
    Invoke-EbcSwitchHit 'Spinner'
    Step-EbcFrames -Frames 30
    Add-EbcObservation ("{0} sound: [{1}]" -f $Tier, (@(Get-Commands $seen) -join ' '))
    Step-EbcFrames -Frames 150
}
function Wait-SpinnerStopped { Step-EbcFrames -Frames 300 }
function Invoke-Hit([string]$Switch, [string]$After) { if ($After) { Invoke-EbcScoredHit $Switch -AfterSolenoid $After | Out-Null } else { Invoke-EbcScoredHit $Switch | Out-Null }; Step-EbcFrames -Frames 30 }

Invoke-EbcComparedScenario -Name 'The spinner sends the original ROM''s 100, 1,000, 3,000 and 5,000 sound for each award tier' -Doc $Doc -Trees @('originals', '8bc-deluxe') -Scenario {
    Start-EbcGame
    if ($Tree -eq 'originals') {
        Enter-EbcServiceMode | Out-Null
        Set-EbcAdjustment -Number $StartRegister -Value 0 | Out-Null
        Exit-EbcServiceMode | Out-Null
    }
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    if ($Tree -eq 'originals') {
        Add-Spin '100'
        foreach ($tier in '1K', '3K', '5K') { Complete-EbcChamp | Out-Null; Add-Spin $tier }
        return
    }
    Add-Spin '100'                                                  # unlit 10
    Invoke-Hit 'Drop Target 1,2,9,10'                               # ball 1: orbit active
    Invoke-Hit 'Left Rollover Button'                               # spinner inactive
    Invoke-Hit 'Drop Target 3,11'                                   # ball 3: spinner active at 100
    Add-Spin '1K'
    Wait-SpinnerStopped
    Invoke-Hit 'Drop Target 4,5,12,13'                              # ball 4: orbit active
    Invoke-Hit 'Drop Target "I"' 'Drop Target 1,2,9,10'             # 100 -> 300
    Invoke-Hit 'Left Rollover Button'                               # spinner inactive
    Invoke-Hit 'Drop Target 1,2,9,10'                               # ball 2: spinner active at 300
    Add-Spin '3K'
    Wait-SpinnerStopped
    Invoke-Hit 'Drop Target "G"' 'Drop Target 3,11'                 # 300 -> 400
    Invoke-Hit 'Drop Target "H"' 'Drop Target 4,5,12,13'            # 400 -> 500
    Invoke-Hit 'Drop Target 4,5,12,13'                              # ball 5: orbit active
    Invoke-Hit 'Left Rollover Button'                               # spinner inactive
    Invoke-Hit 'Drop Target 6,14'                                   # ball 6: spinner active at 500
    Add-Spin '5K'
}
Complete-EbcTests
