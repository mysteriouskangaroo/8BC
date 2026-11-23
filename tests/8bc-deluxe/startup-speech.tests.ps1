param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe startup speech: "Super" followed by the original "Eight Ball, 3 Ball"
# or "Eight Ball, 5 Ball" announcement in one continuous flow, and nothing
# when speech is off. The balls-per-game and speech settings are changed
# through the service-mode keypad.
#
# A process boots libpinmame once, so only the first announcement follows a
# power-on boot. The others follow the restart that Cancel causes when it
# leaves service mode (GameTest.psm1 Exit-EbcServiceMode: it restarts the ROM
# at E50D); measured, that restart replays the announcement after the same
# delay.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Startup speech"; "Required gameplay verification"'
$Manual = 'OPS manual p. 1-5 register table, p. 1-9 "Balls per game; register 23", p. 1-10 "Alternate sound boards; register 50"'
$SoundMap = 'src/8bc-deluxe/ghidra/HARDWARE_MAP.md "Squawk & Talk command transport and response map"'
# Speech commands are 41-80 in the response map; anything else is a sound
# effect or the high-nibble half of a command (libpinmame reports both).
$SpeechLow = 0x41
$SpeechHigh = 0x80
# "Super": gamerules.md names the word; the Deluxe ROM sends it as
# SQUAWK_TALK_SUPER_COMMAND (src/8bc-deluxe/asm/symbols.inc), 6F, at
# DELUXE_PREPEND_STARTUP_SUPER (35_deluxe_rules.asm, reached from C46D).
$Super = 0x6F
# The response map gives 67-6B as "the 8 ball followed by ball 1 through
# ball 5", so the 3-ball phrase is 67 + 2 and the 5-ball phrase 67 + 4.
$EightBallFirst = 0x67
$Phrase = @{ 3 = $EightBallFirst + 2; 5 = $EightBallFirst + 4 }
# Brief: "one continuous flow" is a gap of no more than 30 frames between the
# two commands; "without a cut-off command" means no further speech command
# within the same window after the phrase.
$GapFrames = 30
# Manual p. 1-5/1-9: register 23 is balls per game (1-5); p. 1-10: register
# 50 = 1 talks to the Squawk & Talk board, 0 only to Cheap Squeak (speech off).
$BallsRegister = 23
$SpeechRegister = 50
# Frames watched after a boot or restart (measured: the announcement comes
# about 300 frames after either; C462 loads a 0258-tick delay, 600 ticks at
# 120 a second).
$WatchFrames = 1500

# Speech commands sent since event index $Since, as 'frame:XX'.
function Get-Speech([int]$Since) {
    @(Get-EbcEvents -Since $Since | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object {
        $f = $_ -split ' '; $v = [int]$f[3]
        if ($v -ge $SpeechLow -and $v -le $SpeechHigh) { '{0}:{1:X2}' -f $f[0], $v }
    })
}
function Get-Frame([string]$s) { [int]($s -split ':')[0] }
function Get-Command([string]$s) { ($s -split ':')[1] }
# Asserts that the first speech command is Super, the next is the phrase for
# $Balls balls within $GapFrames frames, and no speech follows within
# $GapFrames frames of the phrase.
function Assert-Announcement([string[]]$Speech, [int]$Balls) {
    $want = @(('{0:X2}' -f $Super), ('{0:X2}' -f $Phrase[$Balls]))
    $got = @($Speech | Select-Object -First 2 | ForEach-Object { Get-Command $_ })
    Assert-EbcEqual -Expected $want -Actual $got -What "first two speech commands (all: $($Speech -join ' '))"
    $gap = (Get-Frame $Speech[1]) - (Get-Frame $Speech[0])
    Assert-EbcTrue ($gap -le $GapFrames) "gap from Super to the $Balls-ball phrase is $gap frames, window $GapFrames"
    if ($Speech.Count -gt 2) {
        $next = (Get-Frame $Speech[2]) - (Get-Frame $Speech[1])
        Assert-EbcTrue ($next -gt $GapFrames) "speech command $($Speech[2]) follows the phrase after $next frames, window $GapFrames"
    }
}
function Get-BallsSetting { (Read-EbcByte (Get-EbcRamAddress 'BallsPerGame')) -shr 4 }
# Sets one register through the keypad, leaves service mode (the ROM
# restarts) and returns the speech commands of the following $WatchFrames.
function Set-AndRestart([int]$Register, [int]$Value) {
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number $Register -Value $Value | Out-Null
    $seen = Get-EbcEventCount
    Exit-EbcServiceMode | Out-Null
    Step-EbcFrames -Frames $WatchFrames
    Get-Speech $seen
}

Start-EbcGame -AttractFrames $WatchFrames

Test-EbcItem -Name 'Cold boot, 3 balls: "Super" then "Eight Ball, 3 Ball" in one continuous flow (timing window: gap <= 30 frames)' -Doc "$Doc; $SoundMap" -Body {
    # OPS manual p. 1-3: a fresh NVRAM sets 3 balls per game.
    Assert-EbcEqual -Expected 3 -Actual (Get-BallsSetting) -What 'balls per game on a fresh NVRAM'
    Assert-Announcement (Get-Speech 0) 3
}
Test-EbcItem -Name '5 balls set through service mode: "Super" then "Eight Ball, 5 Ball" in one continuous flow (timing window: gap <= 30 frames)' -Doc "$Doc; $Manual; $SoundMap" -Body {
    $speech = Set-AndRestart $BallsRegister 5
    Assert-EbcEqual -Expected 5 -Actual (Get-BallsSetting) -What 'balls per game after register 23 = 5'
    Assert-Announcement $speech 5
}
Test-EbcItem -Name '3 balls set through service mode: "Super" then "Eight Ball, 3 Ball" in one continuous flow (timing window: gap <= 30 frames)' -Doc "$Doc; $Manual; $SoundMap" -Body {
    $speech = Set-AndRestart $BallsRegister 3
    Assert-EbcEqual -Expected 3 -Actual (Get-BallsSetting) -What 'balls per game after register 23 = 3'
    Assert-Announcement $speech 3
}
Test-EbcItem -Name 'Speech off (register 50 = 0) suppresses "Super" and the ball-count phrase' -Doc "$Doc; $Manual; $SoundMap" -Body {
    $speech = Set-AndRestart $SpeechRegister 0
    $announced = @($speech | Where-Object { (Get-Command $_) -in @(('{0:X2}' -f $Super), ('{0:X2}' -f $Phrase[3]), ('{0:X2}' -f $Phrase[5])) })
    Assert-EbcEqual -Expected @() -Actual $announced -What "Super or ball-count commands in the $WatchFrames frames after the restart (all speech: $($speech -join ' '))"
}
Complete-EbcTests
