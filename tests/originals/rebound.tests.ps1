param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM Rebound (switch 07): 10 points through the playfield
# multiplier, with sound 0x22. Double and triple are reached by completing
# C-H-A-M-P through its lane switches.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/originals/ghidra/GAME_RULE_TRACES.md "Switch 07: Rebound"'
$Champ = 'src/originals/ghidra/GAME_RULE_TRACES.md "Playfield Scores Double and Triple"'
# "Switch 07: Rebound": CA95 queues 0x22, CA1B adds 10 per multiplier copy.
$ReboundSound = 0x22
$Expected = @{ 1 = 10; 2 = 20; 3 = 30 }
# "Playfield Scores Double and Triple": 10C0 is 10 for double, 20 for triple.
$StateFor = @{ 1 = '00'; 2 = '10'; 3 = '20' }

# Hits Rebound; returns its score change and the sound bytes sent meanwhile.
function Invoke-Rebound {
    $seen = Get-EbcEventCount
    $delta = Invoke-EbcScoredHit 'Rebound'
    $sounds = @(Get-EbcEvents -Since $seen | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { [int]($_ -split ' ')[3] })
    [PSCustomObject]@{ Delta = $delta; Sounds = $sounds }
}

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

foreach ($m in 1, 2, 3) {
    Test-EbcItem -Name "Rebound scores $($Expected[$m]) at ${m}x and sends sound 0x22" -Doc $Doc -Body {
        if ($m -gt 1) { Complete-EbcChamp | Out-Null }
        Assert-EbcEqual -Expected $StateFor[$m] -Actual ('{0:X2}' -f (Get-EbcChampState)) -What "CHAMP completion state for ${m}x ($Champ)"
        $r = Invoke-Rebound
        Assert-EbcEqual -Expected $Expected[$m] -Actual $r.Delta -What "Rebound score at ${m}x"
        Assert-EbcEqual -Expected 1 -Actual @($r.Sounds | Where-Object { $_ -eq $ReboundSound }).Count -What ("sound 0x22 commands among {0}" -f (($r.Sounds | ForEach-Object { '{0:X2}' -f $_ }) -join ' '))
    }
}
Complete-EbcTests
