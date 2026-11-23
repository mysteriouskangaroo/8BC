param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# The C-H-A-M-P letter lamps for each letter state, played identically on the
# original ROM and on Deluxe: C, H, A, M, the center rollover, then P (which
# completes the word), recording the five letter lamps after each step. The
# two observation lists must match exactly.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

# gamerules.md "Deluxe collect feature": "All five C-H-A-M-P lamps continuously
# show their normal collected-letter state"; "Required gameplay verification":
# they "retain the normal collected-letter display". Normal means as the
# original ROM shows it. The center rollover before P rearms Deluxe's C/P
# latch ("CHAMP"; a second new C or P waits for a qualifying shot) and only
# scores in the original, so both trees reach the same letters. Scores differ
# by design, so only the lamps are compared.
$Doc = 'src/8bc-deluxe/gamerules.md "Deluxe collect feature"; "Required gameplay verification"'
$Letters = @('C', 'H', 'A', 'M', 'P')
# 'C'-'P' ROLLOVER (GameNames.psd1 Lamps, from the manual's lamp table).
$Lamps = @($Letters | ForEach-Object { Get-EbcLampNumber """$_"" Rollover" })
$SampleFrames = 32

# '<step>: <letter>=<frames lit of 32> ...'
function Add-Letters([string]$What) {
    $lit = @(0, 0, 0, 0, 0)
    for ($k = 0; $k -lt $SampleFrames; $k++) { Step-EbcFrames -Frames 1; for ($i = 0; $i -lt 5; $i++) { if (Get-EbcLamp -Number $Lamps[$i]) { $lit[$i]++ } } }
    Add-EbcObservation ("{0}: {1}" -f $What, ((0..4 | ForEach-Object { "$($Letters[$_])=$($lit[$_])" }) -join ' '))
}

Invoke-EbcComparedScenario -Name 'The C-H-A-M-P letter lamps show each letter state as in the original ROM' -Doc $Doc -Trees @('originals', '8bc-deluxe') -Scenario {
    Start-EbcGame
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    Add-Letters 'ball 1 served'
    foreach ($l in 'C', 'H', 'A', 'M') {
        Invoke-EbcScoredHit ('"{0}" {1}' -f $l, $(if ($l -eq 'C') { 'Return Lane' } else { 'Top Lane' })) | Out-Null
        Add-Letters "$l lane"
    }
    Invoke-EbcScoredHit 'Center Rollover Button' | Out-Null
    Add-Letters 'center rollover'
    Invoke-EbcScoredHit '"P" Return Lane' | Out-Null
    Add-Letters 'P lane (word complete)'
}
Complete-EbcTests
