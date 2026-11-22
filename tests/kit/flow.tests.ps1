param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Game-flow helpers: coins, a two-player start, scores read from RAM and the
# displays, the CHAMP and sunk-ball state, drains and a played-out game.
# Usage: pwsh tests/kit/flow.tests.ps1 -Tree originals -VpmZip src/originals/build/game-tests/eballchp.zip
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

# These checks hold on every tree; each tree's own scoring values are
# checked in tests/<tree>/.
$Rules = 'src/originals/ghidra/GAME_RULE_TRACES.md'
# OPS manual p. 1-3: a fresh NVRAM sets 1 credit per coin and 3 balls per game.
$CreditsPerCoin = 1
$BallsPerGame = 3
# GAME_RULE_TRACES drop-target table (and src/8bc-deluxe/gamerules.md "New
# pool balls are recorded in $10C3"): switch 27 (Drop Target 3,11) records
# ball 3, 10C3 bit 2. "Playfield Scores Double and Triple": C4F6 clears 10C0
# on each new ball.
$Ball3Bit = 0x04
# Credit presses Start-EbcPlay needs for two players on this schedule
# (measured; the ROM ignores Credit for a while after the serve).
$ExpectedCreditPresses = 3

Start-EbcGame
Test-EbcItem -Name 'Add-EbcCredit adds the factory coinage' -Doc 'OPS manual p. 1-3' -Body {
    Assert-EbcEqual -Expected (2 * $CreditsPerCoin) -Actual (Add-EbcCredit -Count 2) -What 'credits after two Coin I coins'
}
Test-EbcItem -Name 'Start-EbcPlay serves ball 1 to two players' -Doc 'tools/GameNames.psd1 Ram' -Body {
    $start = Start-EbcPlay -Players 2
    Assert-EbcEqual -Expected $ExpectedCreditPresses -Actual $start.CreditPresses -What 'Credit presses for two players'
    Assert-EbcEqual -Expected 2 -Actual (Get-EbcPlayerCount) -What 'players'
    Assert-EbcEqual -Expected 1 -Actual (Get-EbcBallInPlay) -What 'ball in play'
    Assert-EbcEqual -Expected 1 -Actual (Get-EbcCurrentPlayer) -What 'current player'
    Assert-EbcEqual -Expected $false -Actual (Test-EbcGameOver) -What 'game over'
}
Test-EbcItem -Name 'Get-EbcScore reads the lanes from RAM and display' -Doc $Rules -Body {
    $lanes = @('"C" Return Lane', '"H" Top Lane', '"A" Top Lane', '"M" Top Lane', '"P" Return Lane')
    $last = 0
    foreach ($lane in $lanes) {
        Invoke-EbcSwitchHit $lane; Step-EbcFrames -Frames 120
        $now = Get-EbcScore -Player 1   # throws when RAM and display disagree
        Assert-EbcTrue ($now -gt $last) "player 1 score $now after $lane did not rise from $last"
        $last = $now
    }
    Assert-EbcEqual -Expected 0 -Actual (Get-EbcScore -Player 2) -What 'player 2 score'
}
Test-EbcItem -Name 'Get-EbcSunkBalls records a first sink' -Doc $Rules -Body {
    $before = Get-EbcScore -Player 1
    Invoke-EbcSwitchHit 'Drop Target 3,11'
    Step-EbcFrames -Frames 120
    Assert-EbcEqual -Expected ('{0:X2}' -f $Ball3Bit) -Actual ('{0:X2}' -f ((Get-EbcSunkBalls) -band $Ball3Bit)) -What 'sunk-ball bit for ball 3'
    Assert-EbcTrue ((Get-EbcScore -Player 1) -gt $before) "player 1 score did not rise from $before on the first sink"
}
Test-EbcItem -Name 'Invoke-EbcScoredHit returns the settled score change' -Doc $Rules -Body {
    $before = Get-EbcScore -Player 1
    $delta = Invoke-EbcScoredHit 'Rebound'
    Assert-EbcEqual -Expected ((Get-EbcScore -Player 1) - $before) -Actual $delta -What 'returned delta against the score change'
    Assert-EbcTrue ($delta -gt 0) "Rebound delta $delta is not positive"
    $bytes = Read-EbcRam -Address (Get-EbcRamAddress 'PENDING_SCORE_10S') -Count 6
    $pending = -join @($bytes | ForEach-Object { '{0:X2}' -f $_ })
    Assert-EbcEqual -Expected '000000000000' -Actual $pending -What 'pending score 0094-0099 after the hit'
}
Test-EbcItem -Name 'Invoke-EbcScoredHit -AfterSolenoid waits for the pulse' -Doc $Rules -Body {
    $seen = Get-EbcEventCount
    $delta = Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer'
    $kicks = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match ('^\d+ sol {0} 1$' -f (Get-EbcSolenoid 'Saucer')) })
    Assert-EbcEqual -Expected 1 -Actual $kicks.Count -What 'Saucer solenoid pulses during the hit'
    Assert-EbcTrue ($delta -gt 0) "Saucer delta $delta is not positive"
    # A Rebound hit never pulses the Knocker: the wait must give up and say so.
    $msg = try { Invoke-EbcScoredHit 'Rebound' -AfterSolenoid 'Knocker' -MaxFrames 300 | Out-Null; 'no exception' } catch { $_.Exception.Message }
    Assert-EbcTrue ($msg -match "no 'Knocker' pulse within 300 frames") "Knocker wait after Rebound: $msg"
}
Test-EbcItem -Name 'Invoke-EbcDrain passes to player 2' -Doc $Rules -Body {
    Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'drain outcome'
    Assert-EbcEqual -Expected 2 -Actual (Get-EbcCurrentPlayer) -What 'current player'
    Assert-EbcEqual -Expected 1 -Actual (Get-EbcBallInPlay) -What 'ball in play'
    Assert-EbcEqual -Expected '00' -Actual ('{0:X2}' -f (Get-EbcChampState)) -What 'CHAMP completion state on the new ball'
}
Test-EbcItem -Name 'Complete-EbcGame plays out the factory balls' -Doc 'OPS manual p. 1-3' -Body {
    # Player 1 has drained ball 1; 2 x 3 - 1 balls remain.
    Assert-EbcEqual -Expected (2 * $BallsPerGame - 1) -Actual (Complete-EbcGame) -What 'balls drained to game over'
    Assert-EbcEqual -Expected $true -Actual (Test-EbcGameOver) -What 'game over'
}
Complete-EbcTests
