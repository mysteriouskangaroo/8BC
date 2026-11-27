param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# A new qualification is consumed only by its first spinner pulse. Neither
# activation nor further pulses during that scoring window authorize awards.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force
$Doc = 'src/8bc-deluxe/gamerules.md "Hole / saucer"'
function Get-Location { (Read-EbcByte 0x10FB) -band 7 }
function Assert-Waiting {
    Assert-EbcEqual -Expected 0x40 -Actual ((Read-EbcByte 0x10FB) -band 0x40) -What 'saucer remains waiting'
    Assert-EbcEqual -Expected 8 -Actual ((Read-EbcByte 0x10C1) -band 15) -What 'dormant terminal flash state'
    $lit = 0
    foreach ($frame in 1..32) {
        Step-EbcFrames -Frames 1
        foreach ($name in @('2X','3X','5X','100,000')) {
            if (Get-EbcLamp -Number (Get-EbcLampNumber "Saucer $name")) { $lit++ }
        }
    }
    Assert-EbcEqual -Expected 0 -Actual $lit -What 'no saucer next-award lamps'
}
Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number 52 -Value 60 | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120
Test-EbcItem -Name 'Spinner activation alone stays dark; first pulse relights 7x; continuing pulses do not rearm it' -Doc $Doc -Body {
    foreach ($step in 1..3) { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null }
    Invoke-EbcScoredHit 'Drop Target 1,2,9,10' | Out-Null
    Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
    Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
    Assert-Waiting
    Invoke-EbcScoredHit 'Drop Target 3,11' | Out-Null
    Assert-EbcEqual -Expected 6 -Actual (Get-Location) -What 'spinner qualified but never hit'
    Assert-EbcEqual -Expected 0 -Actual (Read-EbcByte 0x10FC) -What 'no scoring window before first pulse'
    Assert-Waiting
    Invoke-EbcSwitchHit 'Spinner'
    Step-EbcFrames -Frames 8
    Assert-EbcEqual -Expected 1 -Actual (Get-Location) -What 'first pulse releases orbit'
    Assert-EbcEqual -Expected 13 -Actual ((Read-EbcByte 0x10C1) -band 15) -What 'first pulse relights 7x plus 100K'
    Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
    Assert-EbcEqual -Expected 7 -Actual (Read-EbcByte 0x1149) -What '7x was collected'
    foreach ($gap in @(0,60,120)) {
        if ($gap) { Step-EbcFrames -Frames $gap }
        Invoke-EbcSwitchHit 'Spinner'
        Step-EbcFrames -Frames 8
        Assert-EbcEqual -Expected 1 -Actual (Read-EbcByte 0x10FC) -What 'spinner scoring window still open'
        Assert-EbcEqual -Expected 1 -Actual (Get-Location) -What 'continuing pulse preserves orbit location'
        Assert-Waiting
    }
}
Complete-EbcTests
