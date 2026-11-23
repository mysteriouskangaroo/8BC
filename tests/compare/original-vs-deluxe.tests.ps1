param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# The original ROM and 8bc-deluxe, compared only where Deluxe does not
# redesign the game: credits after coins; ball, player and serve at a start;
# each drain and the next serve to game over; the coil fired by each switch
# 01-05; the tilt outcome; and the service solenoid order.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

# What is compared. Deluxe rescales every score (gamerules.md "Deluxe score
# scale"), changes the end-of-ball bonus timing and uses the credit display
# during the bonus (gamerules.md "B-A-L-L and E-I-G-H-T bonus" and
# "Pool-ball bonus"), so no observation holds a score, display text or a frame
# count, except the frame at which the second player's credit is taken
# (start scenario). Each observation is a fact named in words: credits from the credit
# bytes (1627-1628), player count, ball in play, current player and the game
# over flag from RAM (GameNames.psd1 Ram), and coils by page 1-18 name from
# solenoid-on events. The tilt item records only whether the score changed
# through the tilted drain, never the score itself. Each scenario's
# observations pass through $Normalize unchanged: there is nothing left to
# normalize.
$Rules = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM" (Deluxe keeps every rule it does not list as changed)'
$Normalize = { $_ }
$Trees = @('originals', '8bc-deluxe')

# Coins dropped one at a time in each chute, on the factory coinage of a
# fresh NVRAM (each scenario boots its own machine).
$Coins = 4
$Chutes = @('Coin I (Left)', 'Coin II (Middle)', 'Coin III (Right)')
# Frames after each coin before the credits are read (as Add-EbcCredit).
$CoinSettleFrames = 60
# Frames watched, one at a time, after the Credit press that adds player 2.
$CreditWatchFrames = 100
# Players started for the play scenarios.
$Players = 2
# Frames a served ball travels before its first hit (a hit in the first
# 60-100 frames after a serve posts late; GameTest.psm1 Invoke-EbcDrain).
$TravelFrames = 120
# Frames watched after each switch 01-05 hit (measured in
# tests/originals/switch-coils.tests.ps1: the saucer kick comes about 34
# frames after its switch, the others within 2).
$WatchFrames = 600
# Solenoid test: function 92 keyed in keypad mode; one cycle of the 13 tests
# takes about 940 frames (tests/originals/service-solenoids.tests.ps1).
$SolenoidFunction = '92'
$SolenoidTests = 13
$RecordFrames = 1500

$byNumber = @{}; foreach ($n in (Get-EbcNames).Solenoids.Keys) { $byNumber[(Get-EbcSolenoid $n)] = $n }
function Get-CoilsSince([int]$Since) {
    @(Get-EbcEvents -Since $Since | Where-Object { $_ -match '^\d+ sol (\d+) 1$' } | ForEach-Object {
        $n = [int](($_ -split ' ')[2]); if ($byNumber.ContainsKey($n)) { $byNumber[$n] } else { "solenoid $n" } })
}
function Get-PlayState { 'players {0}, ball {1}, player {2}, game over {3}' -f (Get-EbcPlayerCount), (Get-EbcBallInPlay), (Get-EbcCurrentPlayer), (Test-EbcGameOver) }
function Start-TwoPlayerGame {
    Start-EbcGame
    Add-EbcCredit -Count $Players | Out-Null
    $seen = Get-EbcEventCount
    Start-EbcPlay -Players $Players | Out-Null
    # Start-EbcPlay returns at the frame the player count rises. The Credit
    # handler (F854, the same bytes F854-F8D0 in both images) raises it at
    # F83D (INC 008E) and then takes the credit at F6E6 (1627), straight-line
    # code in one call; the original's frame boundary falls between the two
    # (measured: the press adding player 2 raises the count at +28 frames and
    # takes the credit at +29 in the original, both at +29 in Deluxe). The
    # frame the credit is taken is compared in the start scenario; here the
    # state, including the final credit count, is read after the travel frames.
    Step-EbcFrames -Frames $TravelFrames
    Add-EbcObservation "start: $(Get-PlayState); credits $(Get-EbcCredits); coils [$((Get-CoilsSince $seen) -join ', ')]"
}

foreach ($chute in $Chutes) {
    Invoke-EbcComparedScenario -Name "Credits after each $chute coin" -Doc $Rules -Trees $Trees -Normalize $Normalize -Scenario {
        Start-EbcGame
        for ($k = 1; $k -le $Coins; $k++) {
            Invoke-EbcSwitchHit $chute
            Step-EbcFrames -Frames $CoinSettleFrames
            Add-EbcObservation "$chute coin ${k}: credits $(Get-EbcCredits)"
        }
    }
}

Invoke-EbcComparedScenario -Name 'Ball, player and serve at a two-player start' -Doc $Rules -Trees $Trees -Normalize $Normalize -Scenario {
    Start-EbcGame
    Add-EbcObservation "attract: game over $(Test-EbcGameOver)"
    Add-EbcCredit -Count $Players | Out-Null
    $seen = Get-EbcEventCount
    Invoke-EbcSwitchHit 'Credit'
    Wait-EbcBallServed -Since $seen | Out-Null
    Add-EbcObservation "first Credit: $(Get-PlayState); credits $(Get-EbcCredits); coils [$((Get-CoilsSince $seen) -join ', ')]"
    $seen = Get-EbcEventCount
    Step-EbcFrames -Frames $TravelFrames
    # The press adding player 2, stepped one frame at a time: the frame after
    # the press at which the credit bytes 1627-1628 change.
    $sw = Get-EbcSwitch 'Credit'; $pressed = Get-EbcFrame; $before = Get-EbcCredits; $taken = 'not taken'
    for ($w = 0; $w -lt $CreditWatchFrames; $w++) {
        Set-EbcSwitch -Number $sw -Closed ($w -lt 4)
        Step-EbcFrames -Frames 1
        if ($taken -eq 'not taken' -and (Get-EbcCredits) -ne $before) { $taken = "+$((Get-EbcFrame) - $pressed) frames" }
    }
    Add-EbcObservation "second Credit: $(Get-PlayState); credits $(Get-EbcCredits), taken at $taken; coils [$((Get-CoilsSince $seen) -join ', ')]"
}

Invoke-EbcComparedScenario -Name 'Each drain serves the next player and ball, to game over' -Doc $Rules -Trees $Trees -Normalize $Normalize -Scenario {
    Start-TwoPlayerGame
    for ($k = 1; $k -le 12; $k++) {
        $at = '{0}/{1}' -f (Get-EbcCurrentPlayer), (Get-EbcBallInPlay)
        Invoke-EbcScoredHit 'Rebound' | Out-Null
        $seen = Get-EbcEventCount
        $outcome = Invoke-EbcDrain
        Add-EbcObservation "drain of ${at}: $outcome; $(Get-PlayState); coils [$((Get-CoilsSince $seen) -join ', ')]"
        if ($outcome -eq 'GameOver') { break }
        Step-EbcFrames -Frames $TravelFrames
    }
}

Invoke-EbcComparedScenario -Name 'Switches 01-05 each fire their coil' -Doc $Rules -Trees $Trees -Normalize $Normalize -Scenario {
    Start-TwoPlayerGame
    foreach ($sw in @('Right Thumper Bumper', 'Left Thumper Bumper', 'Right Slingshot', 'Left Slingshot', 'Saucer')) {
        $seen = Get-EbcEventCount
        Invoke-EbcSwitchHit $sw
        Step-EbcFrames -Frames $WatchFrames
        Add-EbcObservation ('switch {0:D2} {1}: coils [{2}]' -f (Get-EbcSwitch $sw), $sw, ((Get-CoilsSince $seen) -join ', '))
    }
}

Invoke-EbcComparedScenario -Name 'Tilt ends the ball without bonus and play resumes' -Doc $Rules -Trees $Trees -Normalize $Normalize -Scenario {
    Start-TwoPlayerGame
    # A sunk ball gives the tilted ball a bonus to lose (tests/originals/tilt).
    Invoke-EbcScoredHit 'Drop Target 1,2,9,10' | Out-Null
    $seen = Get-EbcEventCount
    Invoke-EbcSwitchHit 'Tilt'
    Step-EbcFrames -Frames 60
    Add-EbcObservation "tilt: coils off [$(@(Get-EbcEvents -Since $seen | Where-Object { $_ -match '^\d+ sol \d+ 0$' } | ForEach-Object { $n = [int](($_ -split ' ')[2]); if ($byNumber.ContainsKey($n)) { $byNumber[$n] } else { "solenoid $n" } }) -join ', ')]"
    $seen = Get-EbcEventCount
    $before = Get-EbcScore -Player 1
    $outcome = Invoke-EbcDrain
    Add-EbcObservation "tilted drain: $outcome; score changed $((Get-EbcScore -Player 1) -ne $before); $(Get-PlayState); coils [$((Get-CoilsSince $seen) -join ', ')]"
    Step-EbcFrames -Frames $TravelFrames
    Add-EbcObservation "next ball: Rebound scores $((Invoke-EbcScoredHit 'Rebound') -gt 0)"
}

Invoke-EbcComparedScenario -Name 'Service solenoid test fires the same outputs in the same order' -Doc $Rules -Trees $Trees -Normalize $Normalize -Scenario {
    Start-EbcGame
    Enter-EbcServiceMode | Out-Null
    $seen = Get-EbcEventCount
    foreach ($c in $SolenoidFunction.ToCharArray()) { Invoke-EbcKey ([string]$c) }
    Invoke-EbcKey 'Enter'
    Step-EbcFrames -Frames $RecordFrames
    $order = @(Get-CoilsSince $seen | Select-Object -First $SolenoidTests)
    Add-EbcObservation "function $SolenoidFunction first cycle: [$($order -join ', ')]"
}
Complete-EbcTests
