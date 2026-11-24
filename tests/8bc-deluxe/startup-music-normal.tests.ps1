param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Once the boot-speech guard has expired, the first ball uses the same
# immediate background-music path as every later ball.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Startup speech"; src/8bc-deluxe/ghidra/GAME_RULE_TRACES.md "Startup-safe first-ball background music"'
$Music = 0x11
$BallStart = 0x18

function Get-SoundEvents([int]$Command, [int]$AtOrAfterFrame) {
    @(Get-EbcEvents | Where-Object {
        $f = $_ -split ' '
        $f.Count -ge 4 -and [int]$f[0] -ge $AtOrAfterFrame -and
            $f[1] -eq 'snd' -and [int]$f[3] -eq $Command
    })
}
function Get-EventFrame([string]$Event) { [int](($Event -split ' ')[0]) }

# The normal attract wait is far beyond the three-second guard, so the timer is
# already zero and C562 takes the immediate path.
Start-EbcGame -AttractFrames 1500
Add-EbcCredit | Out-Null
$guardBeforeStart = Read-EbcRam -Address 0x114C -Count 3
$searchFrame = Get-EbcFrame
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 30
$starts = Get-SoundEvents $BallStart $searchFrame
$startFrame = Get-EventFrame ($starts | Select-Object -First 1)
$music = Get-SoundEvents $Music $startFrame
$musicFrame = Get-EventFrame ($music | Select-Object -First 1)
$guardAfterStart = Read-EbcRam -Address 0x114C -Count 3

Test-EbcItem -Name 'A normal Start after the boot guard retains the original immediate background-music command' -Doc $Doc -Body {
    Assert-EbcEqual -Expected 1 -Actual $starts.Count -What "ball-start commands ($($starts -join '; '))"
    Assert-EbcEqual -Expected 1 -Actual $music.Count -What "background-music commands ($($music -join '; '))"
    Assert-EbcEqual -Expected @(0, 0, 2) -Actual @($guardBeforeStart) -What 'expired guard and boot-armed state immediately before normal Start'
    Assert-EbcEqual -Expected @(0, 0, 0) -Actual @($guardAfterStart) -What 'guard and consumed one-shot state after normal Start'
    # C4F6 sends $18 before the canonical reset/serve setup. Reaching C562 and
    # sending $11 immediately there is measured 86 frames later; only a gap
    # beyond this window would indicate that the Deluxe guard delayed it.
    $gap = $musicFrame - $startFrame
    Assert-EbcTrue ($gap -ge 80 -and $gap -le 92) "music follows the ball-start command by $gap frames; canonical immediate-C562 window is 80-92"
}

Complete-EbcTests
