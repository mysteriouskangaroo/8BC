param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM game flow: coinage, a one-player start, four players from four
# Credit presses, the player-then-ball drain order and game over after the
# last player's last ball, on the factory settings of a fresh NVRAM.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Manual = 'OPS manual p. 1-3 (factory settings)'
$Plan = 'docs/superpowers/plans/2026-11-21-game-test-suite.md Task 6 game-flow'
# OPS manual p. 1-3: a fresh NVRAM gives 1 credit per Coin I coin and 3 balls.
$CreditsPerCoin = 1
$BallsPerGame = 3
$Players = 4

# Lets the served ball travel 120 frames (a hit in the first 60-100 frames
# after a serve posts late; GameTest.psm1 Invoke-EbcDrain), scores it with
# Rebound so it counts, records (player, ball) and drains it.
function Invoke-PlayedBall {
    Step-EbcFrames -Frames 120
    $delta = Invoke-EbcScoredHit 'Rebound'
    if ($delta -le 0) { throw "Rebound did not score on player $(Get-EbcCurrentPlayer) ball $(Get-EbcBallInPlay)." }
    $at = '{0}/{1}' -f (Get-EbcCurrentPlayer), (Get-EbcBallInPlay)
    [PSCustomObject]@{ PlayerBall = $at; Outcome = Invoke-EbcDrain }
}

Start-EbcGame
Test-EbcItem -Name 'Coin I adds credits per factory coinage' -Doc $Manual -Body {
    $seen = @(); for ($k = 1; $k -le $Players; $k++) { $seen += Add-EbcCredit -Count 1 }
    Assert-EbcEqual -Expected @(1..$Players | ForEach-Object { $_ * $CreditsPerCoin }) -Actual $seen -What 'credits after each Coin I coin'
}
Test-EbcItem -Name 'Credit starts a 1-player game with ball 1 served' -Doc $Plan -Body {
    $events = Get-EbcEventCount
    Invoke-EbcSwitchHit 'Credit'
    Wait-EbcBallServed -Since $events | Out-Null   # throws unless the Outhole solenoid fires
    Assert-EbcEqual -Expected 1 -Actual (Get-EbcPlayerCount) -What 'players'
    Assert-EbcEqual -Expected 1 -Actual (Get-EbcBallInPlay) -What 'ball in play'
    Assert-EbcEqual -Expected 1 -Actual (Get-EbcCurrentPlayer) -What 'current player'
    Assert-EbcEqual -Expected $false -Actual (Test-EbcGameOver) -What 'game over'
    Assert-EbcEqual -Expected ($Players * $CreditsPerCoin - 1) -Actual (Get-EbcCredits) -What 'credits after the start'
}
Test-EbcItem -Name 'Four Credit presses give 4 players' -Doc $Plan -Body {
    # The start was press 1; presses 2-4 come 120 frames after the serve (the
    # ROM ignores Credit for about 70 frames after it), 60 frames apart.
    Step-EbcFrames -Frames 120
    $counts = @()
    for ($k = 2; $k -le $Players; $k++) { Invoke-EbcSwitchHit 'Credit'; Step-EbcFrames -Frames 48; $counts += Get-EbcPlayerCount }
    Assert-EbcEqual -Expected @(2..$Players) -Actual $counts -What 'players after Credit presses 2-4'
    Assert-EbcEqual -Expected 0 -Actual (Get-EbcCredits) -What 'credits after four players'
    Assert-EbcEqual -Expected 1 -Actual (Get-EbcBallInPlay) -What 'ball in play'
}
Test-EbcItem -Name 'A drain advances player then ball' -Doc $Plan -Body {
    $after = @()
    for ($k = 0; $k -lt $Players; $k++) {
        $r = Invoke-PlayedBall
        if ($r.Outcome -ne 'Served') { throw "drain of $($r.PlayerBall) ended the game" }
        $after += '{0}/{1}' -f (Get-EbcCurrentPlayer), (Get-EbcBallInPlay)
    }
    Assert-EbcEqual -Expected @('2/1', '3/1', '4/1', '1/2') -Actual $after -What 'player/ball after each drain'
}
Test-EbcItem -Name 'Game over after the last ball of the last player' -Doc $Manual -Body {
    # Balls 2 and 3 of every player remain.
    $expected = @(); for ($b = 2; $b -le $BallsPerGame; $b++) { for ($p = 1; $p -le $Players; $p++) { $expected += "$p/$b" } }
    $drained = @(); $outcomes = @()
    for ($k = 0; $k -lt $expected.Count + 2; $k++) {
        $r = Invoke-PlayedBall
        $drained += $r.PlayerBall; $outcomes += $r.Outcome
        if ($r.Outcome -eq 'GameOver') { break }
    }
    Assert-EbcEqual -Expected $expected -Actual $drained -What 'player/ball drained, in order'
    Assert-EbcEqual -Expected (@('Served') * ($expected.Count - 1) + @('GameOver')) -Actual $outcomes -What 'drain outcomes'
    Assert-EbcEqual -Expected $true -Actual (Test-EbcGameOver) -What 'game over'
}
Complete-EbcTests
