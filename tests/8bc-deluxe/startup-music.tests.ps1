param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# A rapid Start used to send the one and only background-music command while
# the Squawk & Talk boot phrase was still active. Verify the Deluxe boot guard
# delays that first request and emits it exactly once.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Startup speech"; src/8bc-deluxe/ghidra/GAME_RULE_TRACES.md "Startup-safe first-ball background music"'
$Music = 0x11
$BallStart = 0x18
$BootPhrase3Ball = 0x69
$GuardFrames = 180       # 360 periodic ticks, measured at two ticks/frame
$GuardTolerance = 12

function Get-SoundEvents([int]$Since, [int]$Command, [int]$AtOrAfterFrame = 0) {
    @(Get-EbcEvents -Since $Since | Where-Object {
        $f = $_ -split ' '
        $f.Count -ge 4 -and [int]$f[0] -ge $AtOrAfterFrame -and
            $f[1] -eq 'snd' -and [int]$f[3] -eq $Command
    })
}
function Get-EventFrame([string]$Event) { [int](($Event -split ' ')[0]) }

# Stop on the first complete boot phrase, then coin and start immediately.
# This avoids the normal 1500-frame attract wait, which is well beyond the
# collision window and could never reproduce the real-machine report.
Start-EbcGame -AttractFrames 0
$bootSeen = Get-EbcEventCount
$phraseFrame = -1
for ($wait = 0; $wait -lt 1500 -and $phraseFrame -lt 0; $wait++) {
    Step-EbcFrames -Frames 1
    $phrase = Get-SoundEvents $bootSeen $BootPhrase3Ball | Select-Object -First 1
    if ($phrase) { $phraseFrame = Get-EventFrame $phrase }
}
if ($phraseFrame -lt 0) { throw 'no 3-ball boot phrase within 1500 frames' }
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames ($GuardFrames + 120)
$firstStarts = Get-SoundEvents 0 $BallStart ($phraseFrame + 1)
$firstStartFrame = Get-EventFrame ($firstStarts | Select-Object -First 1)
$firstMusic = Get-SoundEvents 0 $Music $firstStartFrame
$firstMusicFrame = Get-EventFrame ($firstMusic | Select-Object -First 1)

Test-EbcItem -Name 'Rapid Start defers first-ball background music until the boot-speech guard expires, then sends it once' -Doc $Doc -Body {
    Assert-EbcEqual -Expected 1 -Actual $firstMusic.Count -What "background-music commands after rapid Start ($($firstMusic -join '; '))"
    Assert-EbcEqual -Expected 1 -Actual $firstStarts.Count -What "ball-start commands after rapid Start ($($firstStarts -join '; '))"
    $delta = $firstMusicFrame - $firstStartFrame
    Assert-EbcTrue ($delta -ge ($GuardFrames - $GuardTolerance) -and $delta -le ($GuardFrames + $GuardTolerance)) "music frame $firstMusicFrame is $delta frames after rapid ball-start frame $firstStartFrame; expected $GuardFrames +/- $GuardTolerance"
    Assert-EbcTrue ($firstMusicFrame -gt $firstStartFrame) "music frame $firstMusicFrame follows first-ball start command $($firstStarts[0])"
}

Complete-EbcTests
