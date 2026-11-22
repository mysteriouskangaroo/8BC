param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM pool-ball drop targets: a first sink scores 500 and records the
# ball in 10C3; a hit on an already-sunk ball scores 5,000 and leaves 10C3
# alone; both go through the CHAMP playfield multiplier, reached by play.
#
# src/8bc-deluxe/gamerules.md "Existing rules established in the original
# ROM" gives the first sink as 2,500; GAME_RULE_TRACES.md gives 500. The
# controller ruled that this file asserts the GAME_RULE_TRACES values; the
# conflict goes to the user.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/originals/ghidra/GAME_RULE_TRACES.md "Pool-ball drop targets: first sink and later 5,000"'
$Champ = 'src/originals/ghidra/GAME_RULE_TRACES.md "Playfield Scores Double and Triple"'
# "Pool-ball drop targets": C9C4 adds 500, C9EF adds 5,000, each times the
# playfield multiplier.
$FirstSink = 500
$AlreadySunk = 5000
# The drop-target table: switch -> sunk-ball bit(s), paired switches record
# their first ball, then their second.
$ExpectedSinks = @('25:01', '27:04', '28:08', '30:20', '25:02', '28:10', '31:40')

# A drop group re-arms (its 10C5 latch clears) only when the E-I-G-H-T target
# behind it is hit with the group down: CDAA ties E/I/G/H/T (33-37) to groups
# 30/25/27/28/31, and CD4C pulses that group's reset (C6C9-C6FC).
$ResetBy = @{
    'Drop Target 1,2,9,10'  = 'Drop Target "I"'
    'Drop Target 3,11'      = 'Drop Target "G"'
    'Drop Target 4,5,12,13' = 'Drop Target "H"'
    'Drop Target 6,14'      = 'Drop Target "E"'
}
$script:Sinks = @()

# Hits a drop target; returns the score change and 10C3 before and after,
# and records any newly set 10C3 bits as '<switch>:<bits>'.
function Invoke-Drop([string]$Name) {
    $before = Get-EbcSunkBalls
    $delta = Invoke-EbcScoredHit $Name
    $after = Get-EbcSunkBalls
    $new = $after -band -bnot $before
    if ($new) { $script:Sinks += '{0}:{1:X2}' -f (Get-EbcSwitch $Name), $new }
    [PSCustomObject]@{ Delta = $delta; Before = $before; After = $after }
}
# Re-arms a drop group by play: hits its E-I-G-H-T target and waits for the
# group's reset pulse.
function Reset-Drop([string]$Name) { Invoke-EbcScoredHit $ResetBy[$Name] -AfterSolenoid $Name | Out-Null }

function Assert-Multiplier([int]$m) {
    $state = @{ 1 = '00'; 2 = '10'; 3 = '20' }[$m]
    Assert-EbcEqual -Expected $state -Actual ('{0:X2}' -f (Get-EbcChampState)) -What "CHAMP completion state for ${m}x ($Champ)"
}
function Assert-FirstSink([string]$Name, [int]$m) {
    $r = Invoke-Drop $Name
    Assert-EbcEqual -Expected ($FirstSink * $m) -Actual $r.Delta -What "first sink on '$Name' at ${m}x"
    Assert-EbcTrue ($r.After -ne $r.Before) ('10C3 {0:X2} unchanged by the first sink on {1}' -f $r.Before, $Name)
}
function Assert-AlreadySunk([string]$Name, [int]$m) {
    Reset-Drop $Name
    $r = Invoke-Drop $Name
    Assert-EbcEqual -Expected ($AlreadySunk * $m) -Actual $r.Delta -What "already-sunk hit on '$Name' at ${m}x"
    Assert-EbcEqual -Expected ('{0:X2}' -f $r.Before) -Actual ('{0:X2}' -f $r.After) -What "10C3 after the already-sunk hit on '$Name'"
}

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

Test-EbcItem -Name 'A first sink scores 500 at 1x' -Doc $Doc -Body {
    Assert-Multiplier 1
    Assert-FirstSink 'Drop Target 1,2,9,10' 1
    Assert-FirstSink 'Drop Target 3,11' 1
}
Test-EbcItem -Name 'An already-sunk ball scores 5,000 at 1x and leaves 10C3 unchanged' -Doc $Doc -Body {
    Assert-AlreadySunk 'Drop Target 3,11' 1
}
Test-EbcItem -Name 'A first sink scores 500 x 2 at 2x' -Doc $Doc -Body {
    Complete-EbcChamp | Out-Null
    Assert-Multiplier 2
    Assert-FirstSink 'Drop Target 4,5,12,13' 2
}
Test-EbcItem -Name 'An already-sunk ball scores 5,000 x 2 at 2x and leaves 10C3 unchanged' -Doc $Doc -Body {
    Assert-AlreadySunk 'Drop Target 3,11' 2
}
Test-EbcItem -Name 'A first sink scores 500 x 3 at 3x' -Doc $Doc -Body {
    Complete-EbcChamp | Out-Null
    Assert-Multiplier 3
    Assert-FirstSink 'Drop Target 6,14' 3
}
Test-EbcItem -Name 'An already-sunk ball scores 5,000 x 3 at 3x and leaves 10C3 unchanged' -Doc $Doc -Body {
    Assert-AlreadySunk 'Drop Target 6,14' 3
}
Test-EbcItem -Name 'Each ball sets its 10C3 bit on its first sink' -Doc $Doc -Body {
    Reset-Drop 'Drop Target 1,2,9,10'; Invoke-Drop 'Drop Target 1,2,9,10' | Out-Null
    Reset-Drop 'Drop Target 4,5,12,13'; Invoke-Drop 'Drop Target 4,5,12,13' | Out-Null
    Invoke-Drop 'Drop Target 7,15' | Out-Null
    Assert-EbcEqual -Expected $ExpectedSinks -Actual $script:Sinks -What 'switch:new 10C3 bits, in sink order'
    Assert-EbcEqual -Expected '7F' -Actual ('{0:X2}' -f (Get-EbcSunkBalls)) -What '10C3 after all seven balls'
}
Complete-EbcTests
