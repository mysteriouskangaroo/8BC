param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Separate-process multiplayer check for the persistent per-player H/A/M target
# array. libpinmame intentionally permits only one machine boot per process.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "CHAMP H-A-M skill shot"'
$Trace = 'src/8bc-deluxe/ghidra/GAME_RULE_TRACES.md "Ball-start H-A-M skill shot"'
$TargetAddress = Get-EbcRamAddress 'DELUXE_CHAMP_SKILL_ACTIVE_TARGET'
$TargetsAddress = Get-EbcRamAddress 'DELUXE_PLAYER_CHAMP_SKILL_TARGETS'
$Target = @{ H = 0x02; A = 0x04; M = 0x08 }
$Lane = @{ A = '"A" Top Lane'; M = '"M" Top Lane' }

function Wait-SkillTarget([byte]$Wanted, [int]$MaxFrames = 500) {
    for ($frames = 0; $frames -le $MaxFrames; $frames++) {
        if ((Read-EbcByte $TargetAddress) -eq $Wanted) { return $frames }
        Step-EbcFrames -Frames 1
    }
    throw ('skill target did not reach {0:X2} in {1} frames' -f $Wanted, $MaxFrames)
}

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number 23 -Value 5 | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit -Count 2 | Out-Null
Start-EbcPlay -Players 2 | Out-Null

# Player 1 freezes at A. Player 2 must start at its independent H, and Player
# 1 must resume A on the following round.
Wait-SkillTarget $Target.A | Out-Null
Invoke-EbcScoredHit $Lane.M | Out-Null # miss, remembers A for Player 1
$p1Remembered = Read-EbcByte ($TargetsAddress + 0)
Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'serve Player 2 ball 1'
$p2Target = Read-EbcByte $TargetAddress
Invoke-EbcScoredHit $Lane.A | Out-Null # miss H, end Player 2 opportunity
$p2Remembered = Read-EbcByte ($TargetsAddress + 1)
Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'serve Player 1 ball 2'
$p1ReturnTarget = Read-EbcByte $TargetAddress

Test-EbcItem -Name 'Remembered H/A/M skill targets are isolated between players' -Doc "$Doc; $Trace" -Body {
    $seen = "P1 saved $p1Remembered; P2 starts $p2Target and saves $p2Remembered; P1 returns $p1ReturnTarget"
    $want = "P1 saved $($Target.A); P2 starts $($Target.H) and saves $($Target.H); P1 returns $($Target.A)"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'per-player target memory'
}

Complete-EbcTests
