param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Exercise the real service keypad and switch dispatch; RAM is read only.
# Clause: Verify the first active-spinner pulse
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force
$Doc = 'src/8bc-deluxe/gamerules.md "Spinner", register 52'
$Register = 0x168E
$Timer = 0x1117
$Active = 0x10FC
function Get-Setting {
    $b = Read-EbcRam -Address $Register -Count 2
    (($b[0] -shr 4) -bor ($b[1] -band 0xF0))
}
function Get-Timer {
    $b = Read-EbcRam -Address $Timer -Count 2
    (([int]$b[0] -shl 8) -bor [int]$b[1])
}
function Get-Total {
    $text = Get-EbcScoreBufferText (Get-EbcRamAddress 'ScoreBuffer1')
    $total = if ($text) { [long]$text } else { [long]0 }
    $weight = 1
    foreach ($n in (Read-EbcRam -Address 0x94 -Count 6)) {
        $total += $n * $weight; $weight *= 10
    }
    $total
}
function Invoke-Spin {
    $before = Get-Total
    Set-EbcSwitch -Number (Get-EbcSwitch 'Spinner') -Closed $true
    Step-EbcFrames -Frames 4
    Set-EbcSwitch -Number (Get-EbcSwitch 'Spinner') -Closed $false
    Step-EbcFrames -Frames 4
    (Get-Total) - $before
}

Start-EbcGame
Test-EbcItem -Name 'Unset register 52 reads zero' -Doc $Doc -Body {
    Assert-EbcEqual -Expected 0 -Actual (Get-Setting) -What 'fresh battery-backed adjustment'
}
foreach ($setting in @(0, 1, 12, 30, 60)) {
    Test-EbcItem -Name "Register 52 = $setting sets the spinner window, refreshes it, and survives service restart" -Doc $Doc -Body {
        Enter-EbcServiceMode | Out-Null
        Set-EbcAdjustment -Number 52 -Value $setting | Out-Null
        Exit-EbcServiceMode | Out-Null
        Assert-EbcEqual -Expected $setting -Actual (Get-Setting) -What 'setting after service Cancel'
        # Select it again: Player 1 must display the retained value, including 0.
        Enter-EbcServiceMode | Out-Null
        Invoke-EbcKey '5'; Invoke-EbcKey '2'; Invoke-EbcKey 'Enter'
        Step-EbcFrames -Frames 60
        Assert-EbcEqual -Expected '52' -Actual (Get-EbcStatusText) -What 'selected register number'
        Assert-EbcEqual -Expected $setting -Actual ([int](Get-EbcDisplayText (Get-EbcNames).Displays.Player1)) -What 'register readback'
        Exit-EbcServiceMode | Out-Null

        Add-EbcCredit | Out-Null
        Start-EbcPlay | Out-Null
        Step-EbcFrames -Frames 120
        Invoke-EbcScoredHit 'Drop Target 1,2,9,10' | Out-Null
        Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
        Invoke-EbcScoredHit 'Drop Target 3,11' | Out-Null
        $seconds = if ($setting -eq 0) { 12 } else { $setting }
        $ticks = $seconds * 120
        Assert-EbcEqual -Expected 100 -Actual (Invoke-Spin) -What 'first active spinner award'
        $remaining = Get-Timer
        Assert-EbcTrue -Condition ($remaining -le $ticks -and $remaining -ge $ticks - 16) -What "first pulse loads $ticks ticks (read $remaining)"
        # Wait half the remaining window and refresh it through another pulse.
        Step-EbcFrames -Frames ([int][Math]::Floor($remaining / 4))
        Assert-EbcEqual -Expected 100 -Actual (Invoke-Spin) -What 'continuing lit award'
        $remaining = Get-Timer
        Assert-EbcTrue -Condition ($remaining -le $ticks -and $remaining -ge $ticks - 16) -What "continuing pulse reloads $ticks ticks (read $remaining)"
        Step-EbcFrames -Frames ([int][Math]::Floor($remaining / 2) - 1)
        Assert-EbcEqual -Expected 1 -Actual (Read-EbcByte $Active) -What 'active immediately before expiry'
        Step-EbcFrames -Frames 2
        Assert-EbcEqual -Expected 0 -Actual (Read-EbcByte $Active) -What 'inactive immediately after expiry'
        Assert-EbcEqual -Expected 0 -Actual (Get-Timer) -What 'expired countdown'
        Assert-EbcEqual -Expected 10 -Actual (Invoke-Spin) -What 'ordinary award after expiry'
        Complete-EbcGame | Out-Null
        Step-EbcFrames -Frames 600
        Assert-EbcEqual -Expected $setting -Actual (Get-Setting) -What 'setting survives game end'
    }
}
Test-EbcItem -Name 'Register 52 rejects 61 and keeps 60; nearby original adjustments still work' -Doc $Doc -Body {
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number 52 -Value 60 | Out-Null
    Invoke-EbcKey '6'; Invoke-EbcKey '1'
    Assert-EbcEqual -Expected 61 -Actual ([int](Get-EbcDisplayText (Get-EbcNames).Displays.Player2)) -What 'entered out-of-range value'
    Invoke-EbcKey 'Enter'
    Step-EbcFrames -Frames 60
    Assert-EbcEqual -Expected 60 -Actual (Get-Setting) -What 'value after rejected 61'
    Set-EbcAdjustment -Number 51 -Value 7 | Out-Null
    Set-EbcAdjustment -Number 50 -Value 1 | Out-Null
    Set-EbcAdjustment -Number 23 -Value 3 | Out-Null
    Set-EbcAdjustment -Number 52 -Value 0 | Out-Null
    Exit-EbcServiceMode | Out-Null
    Assert-EbcEqual -Expected 0 -Actual (Get-Setting) -What 'zero retains the default selection'
}
Complete-EbcTests
