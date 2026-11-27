param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Keep the spinner window open across multiple collect cycles. All setup uses
# the service keypad and physical switch events; RAM is observed only.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force
$Doc = 'src/8bc-deluxe/gamerules.md "Deluxe collect feature" and "Spinner"'
function Get-Location { (Read-EbcByte 0x10FB) -band 7 }
function Invoke-Spin {
    Invoke-EbcSwitchHit 'Spinner'
    Step-EbcFrames -Frames 8
}
function Invoke-NewSink {
    $groups = @{ 1='Drop Target 1,2,9,10'; 2='Drop Target 1,2,9,10'; 3='Drop Target 3,11';
        4='Drop Target 4,5,12,13'; 5='Drop Target 4,5,12,13'; 6='Drop Target 6,14'; 7='Drop Target 7,15' }
    $latches = @{ 1=1; 2=1; 3=4; 4=8; 5=8; 6=32; 7=64 }
    $sunk = Get-EbcSunkBalls
    if ($sunk -eq 0x7F) {
        Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
    } else {
        $ball = @(1..7 | Where-Object { -not ($sunk -band (1 -shl ($_ - 1))) })[0]
        $group = $groups[$ball]
        if ((Read-EbcByte 0x10C5) -band $latches[$ball]) {
            $reset = @((Get-EbcNames).StandupDropGroups.Keys | Where-Object { (Get-EbcNames).StandupDropGroups[$_] -eq $group })[0]
            Invoke-EbcScoredHit $reset -AfterSolenoid $group | Out-Null
        }
        Invoke-EbcScoredHit $group | Out-Null
    }
}
function Prepare-NextSpinner {
    if ((Get-Location) -eq 1) { Invoke-NewSink }
    if ((Get-Location) -eq 5) { Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null }
    if ((Get-Location) -eq 2) { Invoke-NewSink }
    Assert-EbcEqual -Expected 6 -Actual (Get-Location) -What 'next spinner qualified'
}
function Assert-OrbitLit {
    $lit = $false
    foreach ($frame in 1..32) {
        Step-EbcFrames -Frames 1
        foreach ($value in @(10000,20000,30000,40000)) {
            if (Get-EbcLamp -Number (Get-EbcLampNumber ('Rollover Lanes {0:N0}' -f $value))) { $lit = $true }
        }
    }
    Assert-EbcTrue $lit 'active orbit value lamps'
}
function Assert-SaucerDark {
    $lit = @{}
    foreach ($frame in 1..32) {
        Step-EbcFrames -Frames 1
        foreach ($name in @('2X','3X','5X','100,000')) {
            if (Get-EbcLamp -Number (Get-EbcLampNumber "Saucer $name")) { $lit[$name] = $true }
        }
    }
    Assert-EbcEqual -Expected 0 -Actual $lit.Count -What 'waiting saucer award stays dark'
}
Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number 52 -Value 60 | Out-Null
Exit-EbcServiceMode | Out-Null
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'A newly qualified spinner consumes its collect even while the previous spinner window is still running' -Doc $Doc -Body {
    Invoke-EbcScoredHit 'Drop Target 1,2,9,10' | Out-Null
    Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
    Invoke-EbcScoredHit 'Drop Target 3,11' | Out-Null
    Assert-EbcEqual -Expected 6 -Actual (Get-Location) -What 'first qualified spinner'
    Invoke-Spin
    Assert-EbcEqual -Expected 1 -Actual (Get-Location) -What 'first spinner collection releases orbit'
    Invoke-EbcScoredHit 'Drop Target 4,5,12,13' | Out-Null
    Assert-EbcEqual -Expected 5 -Actual (Get-Location) -What 'first orbit reactivation'
    Assert-OrbitLit
    Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
    Invoke-EbcScoredHit 'Drop Target 6,14' | Out-Null
    Assert-EbcEqual -Expected 1 -Actual (Read-EbcByte 0x10FC) -What 'earlier spinner window remains open'
    Assert-EbcEqual -Expected 6 -Actual (Get-Location) -What 'newly qualified spinner during old window'
    Invoke-Spin
    Assert-EbcEqual -Expected 1 -Actual (Get-Location) -What 'second spinner collection releases orbit'
    Invoke-EbcScoredHit 'Drop Target 7,15' | Out-Null
    Assert-EbcEqual -Expected 5 -Actual (Get-Location) -What 'second orbit reactivation'
    Assert-OrbitLit
    Invoke-Spin
    Assert-EbcEqual -Expected 5 -Actual (Get-Location) -What 'continuing spinner pulse preserves active orbit'
    Assert-OrbitLit
}
Test-EbcItem -Name 'New spinner collects relight 7x, 8x and 10x during a still-running prior scoring window' -Doc $Doc -Body {
    # Collect 2x, 3x, 5x. The first 100K is armed; prepare a qualified
    # spinner before collecting it, so the next transition is its first pulse.
    foreach ($step in 1..3) { Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null }
    foreach ($stage in @(7,8,10)) {
        Prepare-NextSpinner
        Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
        Assert-EbcEqual -Expected 6 -Actual (Get-Location) -What 'qualified spinner not yet hit'
        Assert-EbcEqual -Expected 1 -Actual (Read-EbcByte 0x10FC) -What 'prior scoring window remains open'
        Assert-EbcEqual -Expected 0x40 -Actual ((Read-EbcByte 0x10FB) -band 0x40) -What 'saucer waiting for collection'
        Assert-SaucerDark
        Invoke-Spin
        Assert-EbcEqual -Expected 1 -Actual (Get-Location) -What "spinner collect releases orbit for ${stage}x"
        $mask = @{ 7=0x0D; 8=0x0E; 10=0x0F }[$stage]
        Assert-EbcEqual -Expected $mask -Actual ((Read-EbcByte 0x10C1) -band 0x0F) -What "${stage}x plus 100K flash mask"
        Assert-EbcEqual -Expected 0 -Actual ((Read-EbcByte 0x10FB) -band 0x40) -What 'saucer flashing is enabled'
        $expected = @{ 7=@('2X','5X','100,000'); 8=@('3X','5X','100,000'); 10=@('2X','3X','5X','100,000') }[$stage]
        $seen = @{}
        foreach ($frame in 1..32) {
            Step-EbcFrames -Frames 1
            foreach ($name in @('2X','3X','5X','100,000')) {
                if (Get-EbcLamp -Number (Get-EbcLampNumber "Saucer $name")) { $seen[$name]=$true }
            }
        }
        Assert-EbcEqual -Expected @($expected | Sort-Object) -Actual @($seen.Keys | Sort-Object) -What "${stage}x plus 100K lamp outputs"
    }
}
Test-EbcItem -Name 'Continuing spins after collecting a saucer award never relight it during the same spinner window' -Doc $Doc -Body {
    Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer' | Out-Null
    Assert-EbcEqual -Expected 10 -Actual (Read-EbcByte 0x1149) -What '10x was collected'
    foreach ($gap in @(0,60,120)) {
        if ($gap) { Step-EbcFrames -Frames $gap }
        Invoke-Spin
        Assert-EbcEqual -Expected 1 -Actual (Read-EbcByte 0x10FC) -What 'scoring window is still running'
        Assert-EbcEqual -Expected 1 -Actual (Get-Location) -What 'continuing pulse preserves orbit location'
        Assert-EbcEqual -Expected 0x40 -Actual ((Read-EbcByte 0x10FB) -band 0x40) -What 'continuing pulse does not reauthorize saucer'
        Assert-EbcEqual -Expected 8 -Actual ((Read-EbcByte 0x10C1) -band 15) -What 'dormant 100K state is unchanged'
        Assert-SaucerDark
    }
    Invoke-NewSink
    Assert-EbcEqual -Expected 5 -Actual (Get-Location) -What 'next new ball activates orbit'
    Invoke-Spin
    Assert-EbcEqual -Expected 5 -Actual (Get-Location) -What 'continuing pulse preserves active orbit'
    Assert-EbcEqual -Expected 0x40 -Actual ((Read-EbcByte 0x10FB) -band 0x40) -What 'continuing pulse with active orbit does not rearm saucer'
    Assert-SaucerDark
    Assert-OrbitLit
}
Complete-EbcTests
