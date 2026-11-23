param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM tilt (switch 15): the tilted ball scores no bonus when it
# drains and the next ball is served; an untilted drain on the next ball
# scores its bonus, showing the bonus was there to lose. All by play.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Manual = 'OPS manual p. 1-2 "General Game Operation" (tilt)'
$Bonus = 'OPS manual p. 1-11 "8 Ball Feature"; src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM" (C765)'
# Manual p. 1-2: tilting results in loss of the ball, the flippers go dead and
# bonus points are not scored; play resumes when the next ball is served.
$TiltedBonus = 0
$FlipperRelay = Get-EbcSolenoid 'K1 Relay (Flipper Enable)'
# Manual p. 1-11: each lit Bonus Rack ball scores 15,000 at the drain
# (gamerules.md: C765 awards 1,500 Deluxe = 15,000 original per sunk ball),
# at the 1x bonus of a ball with no saucer hit.
$BonusPerSunkBall = 15000

function Get-SunkCount { $b = Get-EbcSunkBalls; $n = 0; for ($k = 0; $k -lt 7; $k++) { if ($b -band (1 -shl $k)) { $n++ } }; $n }

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'The Tilt switch ends the ball with no bonus' -Doc $Manual -Body {
    Invoke-EbcScoredHit 'Drop Target 1,2,9,10' | Out-Null
    Assert-EbcEqual -Expected 1 -Actual (Get-SunkCount) -What 'sunk balls before the tilt (a bonus to lose)'
    $before = Get-EbcScore -Player 1
    $seen = Get-EbcEventCount
    Invoke-EbcSwitchHit 'Tilt'
    Step-EbcFrames -Frames 60
    $relayOff = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $FlipperRelay 0$" }).Count
    Assert-EbcEqual -Expected 1 -Actual $relayOff -What 'K1 flipper relay switched off by the tilt (flippers dead)'
    Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'drain after the tilt'
    Assert-EbcEqual -Expected $TiltedBonus -Actual ((Get-EbcScore -Player 1) - $before) -What 'score added from the tilt to the next serve'
}
# Lets the next ball travel before it is scored (GameTest.psm1 Invoke-EbcDrain).
Step-EbcFrames -Frames 120
Test-EbcItem -Name 'The next ball is served after the tilt' -Doc $Manual -Body {
    Assert-EbcEqual -Expected 2 -Actual (Get-EbcBallInPlay) -What 'ball in play after the tilted ball drains'
    Assert-EbcEqual -Expected $false -Actual (Test-EbcGameOver) -What 'game over'
    # Play is normal again: a scoring switch scores.
    Assert-EbcTrue ((Invoke-EbcScoredHit 'Rebound') -gt 0) 'Rebound did not score on the ball after the tilt'
}
Test-EbcItem -Name 'An untilted drain scores 15,000 per sunk ball' -Doc $Bonus -Body {
    Invoke-EbcScoredHit 'Drop Target 3,11' | Out-Null
    $sunk = Get-SunkCount
    $before = Get-EbcScore -Player 1
    Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'drain of ball 2'
    Assert-EbcEqual -Expected ($sunk * $BonusPerSunkBall) -Actual ((Get-EbcScore -Player 1) - $before) -What "bonus for $sunk sunk balls"
}
Complete-EbcTests
