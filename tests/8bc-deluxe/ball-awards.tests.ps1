param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Repeating B-A-L-L awards, entirely by switch play and drains:
# register 43 = 1 (B) awards Extra Ball on odd counts; register 43 = 0 (A)
# awards it on even counts; every count from 2 onward independently awards a
# Special. The Special is made observable as one credit, one knocker pulse,
# and one $6F command by register 25 = replay.
#
# Clause: With register 43 set to B
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Rules = 'src/8bc-deluxe/gamerules.md "B-A-L-L and E-I-G-H-T bonus"'
$Trace = 'src/8bc-deluxe/ghidra/GAME_RULE_TRACES.md "Repeating B-A-L-L Extra Ball and Special awards"'
$Manual = 'OPS manual p. 1-5 register 43 and p. 1-11 "E-I-G-H-T Feature"'

$XBallRegister = 43
$XBallAtB = 1
$XBallAtA = 0
$SpecialModeRegister = 25
$SpecialAwardsReplay = 3
$SpecialAwardsExtraBall = 2
$BallsPerGameRegister = 23
$BallsPerGame = 5
$ActiveBallLetters = 0x1104
$StackedExtraBalls = 0x1150
$SpecialSound = 0x6F
$Knocker = Get-EbcSolenoid 'Knocker'

$LetterOf = [ordered]@{
    E = 'Drop Target "E"'
    I = 'Drop Target "I"'
    G = 'Drop Target "G"'
    H = 'Drop Target "H"'
    T = 'Drop Target "T"'
}
$standups = (Get-EbcNames).StandupDropGroups

function Get-Commands([int]$Since) {
    $ev = @(Get-EbcEvents -Since $Since |
        Where-Object { ($_ -split ' ')[1] -eq 'snd' } |
        ForEach-Object {
            $f = $_ -split ' '
            [PSCustomObject]@{ F = [int]$f[0]; B = [int]$f[3] }
        })
    for ($i = 0; $i -lt $ev.Count; $i++) {
        $ev[$i].B
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and
            $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    }
}

function Invoke-EightLetter([string]$Letter) {
    $standup = $LetterOf[$Letter]
    $group = $standups[$standup]
    Invoke-EbcScoredHit $group | Out-Null
    Invoke-EbcScoredHit $standup -AfterSolenoid $group | Out-Null
}

function Complete-EightWord {
    foreach ($letter in $LetterOf.Keys) { Invoke-EightLetter $letter }
}

function Start-AwardGame([int]$XBallSetting, [int]$Players = 1, [int]$SpecialSetting = $SpecialAwardsReplay) {
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number $XBallRegister -Value $XBallSetting | Out-Null
    Set-EbcAdjustment -Number $SpecialModeRegister -Value $SpecialSetting | Out-Null
    Set-EbcAdjustment -Number $BallsPerGameRegister -Value $BallsPerGame | Out-Null
    Exit-EbcServiceMode | Out-Null
    Add-EbcCredit | Out-Null
    Start-EbcPlay -Players $Players | Out-Null
    Step-EbcFrames -Frames 120
}

function Invoke-MeasuredCompletion([int]$ExpectedCount) {
    $credits = Get-EbcCredits
    $seen = Get-EbcEventCount
    $ballBefore = [int](Get-EbcBallInPlay)
    Complete-EightWord
    Step-EbcFrames -Frames 60
    $count = Read-EbcByte $ActiveBallLetters
    if ($count -ne $ExpectedCount) {
        throw "B-A-L-L count is $count after completion $ExpectedCount"
    }
    $specialCredits = (Get-EbcCredits) - $credits
    $knocks = @(Get-EbcEvents -Since $seen |
        Where-Object { $_ -match "^\d+ sol $Knocker 1$" }).Count
    $sixf = @(Get-Commands $seen | Where-Object { $_ -eq $SpecialSound }).Count
    $drain = Invoke-EbcDrain
    if ($drain -ne 'Served') { throw "game ended after B-A-L-L count $ExpectedCount" }
    Step-EbcFrames -Frames 120
    [PSCustomObject]@{
        Count = $count
        BallBefore = $ballBefore
        BallAfter = [int](Get-EbcBallInPlay)
        Credits = $specialCredits
        Knocks = $knocks
        Sixf = $sixf
    }
}

function Format-Result($r) {
    "count $($r.Count): ball $($r.BallBefore)->$($r.BallAfter), credits +$($r.Credits), knocks $($r.Knocks), `$6F $($r.Sixf)"
}

function Invoke-StackedExtraBallDrains([int]$ExtraBalls) {
    $result = @()
    foreach ($drainNumber in 1..($ExtraBalls + 1)) {
        if ($drainNumber -gt 1) {
            Invoke-EbcScoredHit 'Rebound' | Out-Null
            Step-EbcFrames -Frames 60
        }
        $outcome = Invoke-EbcDrain
        if ($outcome -ne 'Served') { throw "stacked Extra Ball drain $drainNumber ended the game" }
        Step-EbcFrames -Frames 120
        $result += '{0}: player {1}, ball {2}, pending {3}' -f $drainNumber,
            (Get-EbcCurrentPlayer), (Get-EbcBallInPlay), (Read-EbcByte $StackedExtraBalls)
    }
    $result
}

Start-EbcGame

# Register 43 = 1: B/odd Extra Balls. Counts 3 and 5 also prove that Extra
# Ball and Special can both be collected on one completing target event.
Start-AwardGame $XBallAtB
$b = @(for ($count = 1; $count -le 5; $count++) {
    Invoke-MeasuredCompletion $count
})

Test-EbcItem -Name 'Register 43 B mode awards Extra Ball on B-A-L-L counts 1, 3 and 5 only' -Doc "$Doc; $Rules; $Trace; $Manual" -Body {
    $seen = @($b | ForEach-Object { "register 43 count $($_.Count): ball $($_.BallBefore)->$($_.BallAfter)" })
    $want = @(
        'register 43 count 1: ball 1->1',
        'register 43 count 2: ball 1->2',
        'register 43 count 3: ball 2->2',
        'register 43 count 4: ball 2->3',
        'register 43 count 5: ball 3->3'
    )
    Assert-EbcEqual -Expected $want -Actual $seen -What 'ball number after each drain in B/odd mode'
}

Test-EbcItem -Name 'B mode awards a Special on A/count 2 and every later count, including the odd Extra Ball counts' -Doc "$Doc; $Rules; $Trace; $Manual" -Body {
    $seen = @($b | ForEach-Object { Format-Result $_ })
    $want = @(
        'count 1: ball 1->1, credits +0, knocks 0, $6F 0',
        'count 2: ball 1->2, credits +1, knocks 1, $6F 1',
        'count 3: ball 2->2, credits +1, knocks 1, $6F 1',
        'count 4: ball 2->3, credits +1, knocks 1, $6F 1',
        'count 5: ball 3->3, credits +1, knocks 1, $6F 1'
    )
    Assert-EbcEqual -Expected $want -Actual $seen -What 'independent Special effects in B/odd mode'
}

Complete-EbcGame | Out-Null
Step-EbcFrames -Frames 300

# Register 43 = 0: the complementary A/even Extra Ball parity. Counts 2 and 4
# must collect both awards, while count 3 remains a Special without Extra Ball.
Start-AwardGame $XBallAtA
$a = @(for ($count = 1; $count -le 4; $count++) {
    Invoke-MeasuredCompletion $count
})

Test-EbcItem -Name 'Register 43 A mode awards Extra Ball on B-A-L-L counts 2 and 4 only' -Doc "$Doc; $Rules; $Trace; $Manual" -Body {
    $seen = @($a | ForEach-Object { "register 43 count $($_.Count): ball $($_.BallBefore)->$($_.BallAfter)" })
    $want = @(
        'register 43 count 1: ball 1->2',
        'register 43 count 2: ball 2->2',
        'register 43 count 3: ball 2->3',
        'register 43 count 4: ball 3->3'
    )
    Assert-EbcEqual -Expected $want -Actual $seen -What 'ball number after each drain in A/even mode'
}

Test-EbcItem -Name 'A mode still awards a Special on count 2 and every later count, so even counts award both' -Doc "$Doc; $Rules; $Trace; $Manual" -Body {
    $seen = @($a | ForEach-Object { Format-Result $_ })
    $want = @(
        'count 1: ball 1->2, credits +0, knocks 0, $6F 0',
        'count 2: ball 2->2, credits +1, knocks 1, $6F 1',
        'count 3: ball 2->3, credits +1, knocks 1, $6F 1',
        'count 4: ball 3->3, credits +1, knocks 1, $6F 1'
    )
    Assert-EbcEqual -Expected $want -Actual $seen -What 'independent Special effects in A/even mode'
}

Complete-EbcGame | Out-Null
Step-EbcFrames -Frames 300

# Collect B, the second B, and the third B before draining. This proves the
# common Extra Ball path retains all three awards instead of collapsing them
# into the canonical one-bit flag. Scoring once on each served ball prevents
# the stock no-score re-serve behavior from masking a consumed Extra Ball.
Start-AwardGame $XBallAtB 2
foreach ($count in 1..5) {
    Complete-EightWord
    Step-EbcFrames -Frames 60
    Assert-EbcEqual -Expected $count -Actual (Read-EbcByte $ActiveBallLetters) -What "B-A-L-L count before stacked drain $count"
}
$stackBefore = Read-EbcByte $StackedExtraBalls
$stackDrains = @(Invoke-StackedExtraBallDrains 3)

Test-EbcItem -Name 'Three Extra Balls collected on one ball are played in sequence before the multiplayer turn advances' -Doc "$Doc; $Rules; $Trace" -Body {
    Assert-EbcEqual -Expected 3 -Actual $stackBefore -What 'shared pending Extra Ball count after B-A-L-L counts 1 through 5'
    $want = @(
        '1: player 1, ball 1, pending 2',
        '2: player 1, ball 1, pending 1',
        '3: player 1, ball 1, pending 0',
        '4: player 2, ball 1, pending 0'
    )
    Assert-EbcEqual -Expected $want -Actual $stackDrains -What 'stacked Extra Ball drain sequence'
}

Complete-EbcGame | Out-Null
Step-EbcFrames -Frames 300

# Register 25 = 2 converts each Special into an Extra Ball. In A mode count 2
# awards both its parity Extra Ball and a Special Extra Ball, then count 3 adds
# another Special Extra Ball. This exercises the configured-Special path before
# it converges with B-A-L-L at the common C239 Extra Ball request.
Start-AwardGame $XBallAtA 2 $SpecialAwardsExtraBall
foreach ($count in 1..3) {
    Complete-EightWord
    Step-EbcFrames -Frames 60
    Assert-EbcEqual -Expected $count -Actual (Read-EbcByte $ActiveBallLetters) -What "B-A-L-L count before Special Extra Ball stack $count"
}
$specialStackBefore = Read-EbcByte $StackedExtraBalls
$specialStackDrains = @(Invoke-StackedExtraBallDrains 3)

Test-EbcItem -Name 'Operator-configured Special Extra Balls share the stack, including a completion that awards two at once' -Doc "$Doc; $Rules; $Trace; $Manual" -Body {
    Assert-EbcEqual -Expected 3 -Actual $specialStackBefore -What 'shared count after one parity and two Special Extra Ball awards'
    $want = @(
        '1: player 1, ball 1, pending 2',
        '2: player 1, ball 1, pending 1',
        '3: player 1, ball 1, pending 0',
        '4: player 2, ball 1, pending 0'
    )
    Assert-EbcEqual -Expected $want -Actual $specialStackDrains -What 'Special Extra Ball stack drain sequence'
}

Complete-EbcTests
