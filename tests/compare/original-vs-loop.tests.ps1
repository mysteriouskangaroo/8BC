param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, loop-score-change
# One scripted two-player game, played identically on the original ROM and on
# loop-score-change: coins, start, a fixed list of switch hits covering every
# page 1-18 switch except 05, 12 and 13, then drains to game over. The two
# observation lists must match exactly.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

# SCORING_CHANGES.md: the variation changes only the saucer (05) terminal
# award and the left/right rollover (12, 13) values, and keeps the switch
# dispatch, scoring accumulator, decimal carry and playfield double/triple
# multiplier. So with 05, 12 and 13 never closed, every other switch must
# score, sound and fire coils exactly as in the original.
$Doc = 'src/loop-score-change/notes/SCORING_CHANGES.md (introduction: the retained shared code)'
$Excluded = @(5, 12, 13)

# What each observation holds, after each hit, drain and attract closure:
#   <step>: <switch or action> p1=<score> p2=<score> snd=[<frame offset>:<board> <command>, ...]
#   sol=[<frame offset>:<solenoid>, ...]
# Scores are the RAM display buffers 1046 and 104D (GameNames.psd1 Ram);
# sounds are every libpinmame sound event; solenoids every switch-on event;
# frame offsets count from the step's first frame.

# The hit lists, one per served ball in play order. The first list completes
# C-H-A-M-P twice, so drop targets, standups, the spinner and outlanes score
# at 2x and 3x (10C0, GAME_RULE_TRACES.md "Playfield Scores Double and
# Triple"), and completes E-I-G-H-T twice (measured: the second completion
# fires the Knocker and the drain re-serves player 1's ball 1). Later lists
# score the same switches again at 1x. Each list starts with a scoring hit:
# a ball's display blinks until it scores, which Get-EbcScore rejects. Credit
# (06) is pressed before any coin, with 0 credits, so the game stays
# two-player. Tilt (15) ends one ball. After the lists, each remaining ball
# scores Rebound and drains, to game over; Outhole (08) closes on every drain.
# Switches 16 and 14 are closed in attract after game over: in play, 14 ends
# the game (measured: during ball 1 it blanks the displays and the ROM
# restarts; its entry C025 in the switch table at C011 points at C94C, which
# sends sound 1B and jumps to F34F, ending in SWI).
$Champ = @('"C" Return Lane', '"H" Top Lane', '"A" Top Lane', '"M" Top Lane', '"P" Return Lane')
$Drops = @('Drop Target 1,2,9,10', 'Drop Target 3,11', 'Drop Target 4,5,12,13', 'Drop Target 6,14', 'Drop Target 7,15')
$Standups = @('Drop Target "E"', 'Drop Target "I"', 'Drop Target "G"', 'Drop Target "H"', 'Drop Target "T"')
$Balls = @(
    , (@('Rebound', 'Credit', 'Right Thumper Bumper', 'Left Thumper Bumper', 'Right Slingshot', 'Left Slingshot',
         'Not Used 22', 'Center Rollover Button', 'Spinner', 'Left Outlane', 'Right Outlane') + $Champ +
       $Drops + @('Spinner', 'Rebound', 'Lane Change (Cabinet)') + $Standups + $Champ +
       $Drops + $Standups + @('Spinner', 'Center Rollover Button', 'Right Thumper Bumper', 'Left Outlane'))
    , (@('Rebound', 'Coin I (Left)', 'Coin II (Middle)', 'Coin III (Right)', 'Lane Change (Cabinet)') + $Champ +
       @('Drop Target 3,11', 'Drop Target "G"', 'Spinner', 'Right Outlane'))
    , @('Left Slingshot', 'Drop Target 7,15', 'Spinner', 'Tilt', 'Right Thumper Bumper')
    , @('Rebound', 'Drop Target 1,2,9,10', 'Drop Target "I"', 'Center Rollover Button')
    , @('Rebound', 'Drop Target 6,14', 'Drop Target "E"', 'Left Outlane')
)
# At most this many further balls (Rebound and drain) before game over.
$MaxFurtherBalls = 12
# Frames a served ball travels before its first hit (a hit in the first
# 60-100 frames after a serve posts late; GameTest.psm1 Invoke-EbcDrain).
$TravelFrames = 120
# Switches closed in attract after game over, and the frames recorded after each.
$Attract = @('Slam', 'Not Used 14')
$AttractFrames = 600

$step = 0
function Add-Step([string]$What, [int]$Since, [int]$From) {
    $script:step++
    $snd = @(); $sol = @()
    foreach ($e in @(Get-EbcEvents -Since $Since)) {
        $p = $e -split ' '
        $off = [int]$p[0] - $From
        if ($p[1] -eq 'snd') { $snd += "${off}:$($p[2]) $($p[3])" }
        elseif ($p[1] -eq 'sol' -and $p[3] -eq '1') { $sol += "${off}:$($p[2])" }
    }
    $p1 = Get-EbcScoreBufferText (Get-EbcRamAddress 'ScoreBuffer1')
    $p2 = Get-EbcScoreBufferText (Get-EbcRamAddress 'ScoreBuffer2')
    Add-EbcObservation ("{0}: {1} p1={2} p2={3} snd=[{4}] sol=[{5}]" -f $script:step, $What, $p1, $p2, ($snd -join ', '), ($sol -join ', '))
}

Invoke-EbcComparedScenario -Name 'Two-player game without switches 05, 12 and 13 plays identically' -Doc $Doc -Trees @('originals', 'loop-score-change') -Scenario {
    $all = @($Balls | ForEach-Object { $_ } | ForEach-Object { Get-EbcSwitch $_ }) + @($Attract | ForEach-Object { Get-EbcSwitch $_ }) + @(Get-EbcSwitch 'Outhole')
    $missing = @(1..37 | Where-Object { $_ -notin $Excluded -and $_ -notin $all })
    $used = @($Excluded | Where-Object { $_ -in $all })
    if ($missing.Count -or $used.Count) { throw "switch list: missing $($missing -join ',') ; excluded but used $($used -join ',')" }

    Start-EbcGame
    $seen = Get-EbcEventCount; $from = Get-EbcFrame
    $credits = Add-EbcCredit -Count 2
    Start-EbcPlay -Players 2 | Out-Null
    Add-Step "coins (credits $credits) and start (players $(Get-EbcPlayerCount))" $seen $from
    $lists = @($Balls) + @(1..$MaxFurtherBalls | ForEach-Object { , @('Rebound') })
    $over = $false
    foreach ($hits in $lists) {
        Step-EbcFrames -Frames $TravelFrames
        $at = '{0}/{1}' -f (Get-EbcCurrentPlayer), (Get-EbcBallInPlay)
        foreach ($h in $hits) {
            $seen = Get-EbcEventCount; $from = Get-EbcFrame
            Invoke-EbcScoredHit $h | Out-Null
            Add-Step "$at $h" $seen $from
        }
        $seen = Get-EbcEventCount; $from = Get-EbcFrame
        $outcome = Invoke-EbcDrain
        Add-Step "$at drain -> $outcome" $seen $from
        if ($outcome -eq 'GameOver') { $over = $true; break }
    }
    if (-not $over) { throw "no game over after $MaxFurtherBalls further balls" }
    foreach ($h in $Attract) {
        $seen = Get-EbcEventCount; $from = Get-EbcFrame
        Invoke-EbcSwitchHit $h
        Step-EbcFrames -Frames $AttractFrames
        Add-Step "attract $h" $seen $from
    }
}
Complete-EbcTests
