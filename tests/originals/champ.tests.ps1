param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM C-H-A-M-P: each completion advances CHAMP_COMPLETION_STATE
# (10C0) 00 -> 10 -> 20 -> 60 -> E0; each lane scores 3,000 with the
# multiplier active before its own completion; scoring follows 10C0, not the
# blinking lamp shadow 1041.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/originals/ghidra/GAME_RULE_TRACES.md "Playfield Scores Double and Triple"'
$Rebound = 'src/originals/ghidra/GAME_RULE_TRACES.md "Switch 07: Rebound"'
# "Playfield Scores Double and Triple": the 10C0 table and the lane award.
$States = @('10', '20', '60', 'E0')
$LaneAward = 3000
# Multiplier active while each completion's lanes score: 1x, 2x, 3x, 3x.
$LaneMultiplier = @(1, 2, 3, 3)
# "Switch 07: Rebound": 10 points per multiplier copy.
$ReboundAward = 10
$ShadowAddress = Get-EbcRamAddress 'CHAMP_MULTIPLIER_LAMP_SHADOW'

function Assert-Completion([int]$n) {
    $deltas = @(Complete-EbcChamp)
    $m = $LaneMultiplier[$n - 1]
    Assert-EbcEqual -Expected @(1..5 | ForEach-Object { $LaneAward * $m }) -Actual $deltas -What "C, H, A, M, P lane scores in completion $n (${m}x)"
    Assert-EbcEqual -Expected $States[$n - 1] -Actual ('{0:X2}' -f (Get-EbcChampState)) -What "10C0 after completion $n"
}

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'Completion 1: lanes score 3,000 and 10C0 becomes 10 (double)' -Doc $Doc -Body {
    Assert-EbcEqual -Expected '00' -Actual ('{0:X2}' -f (Get-EbcChampState)) -What '10C0 on a new ball'
    Assert-Completion 1
}
Test-EbcItem -Name 'At double, scoring follows 10C0 while lamp shadow 1041 blinks' -Doc $Doc -Body {
    # 1041 blinks the Double lamp (bit 10 clear = lit) on a 16-frame cycle
    # (measured), while 10C0 holds 10. Rebound closed at each of the 16
    # phases must score 2 x 10 every time, with the lamp seen lit and unlit.
    $deltas = @(); $shadow = @()
    for ($phase = 0; $phase -lt 16; $phase++) {
        while ((Get-EbcFrame) % 16 -ne $phase) { Step-EbcFrames -Frames 1 }
        $shadow += '{0:X2}' -f ((Read-EbcByte $ShadowAddress) -band 0x10)
        $deltas += Invoke-EbcScoredHit 'Rebound'
    }
    Assert-EbcTrue (($shadow -contains '00') -and ($shadow -contains '10')) "1041 bit 10 at the 16 closures was only $(($shadow | Sort-Object -Unique) -join ', '); the check needs both"
    Assert-EbcEqual -Expected @(1..16 | ForEach-Object { 2 * $ReboundAward }) -Actual $deltas -What "Rebound scores at 1041 bit 10 = $($shadow -join ' ') ($Rebound)"
    Assert-EbcEqual -Expected '10' -Actual ('{0:X2}' -f (Get-EbcChampState)) -What '10C0 after the Rebound hits'
}
Test-EbcItem -Name 'Completion 2: lanes score 6,000 and 10C0 becomes 20 (triple)' -Doc $Doc -Body { Assert-Completion 2 }
Test-EbcItem -Name 'Completion 3: lanes score 9,000 and 10C0 becomes 60' -Doc $Doc -Body { Assert-Completion 3 }
Test-EbcItem -Name 'Completion 4: lanes score 9,000 and 10C0 becomes E0' -Doc $Doc -Body { Assert-Completion 4 }
Complete-EbcTests
