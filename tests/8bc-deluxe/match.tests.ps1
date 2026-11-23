param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe match: over 12 fixed one-player games, each ended at a different
# frame and each with a nonzero ones digit, the match number shown at game
# end is the MatchDigit byte followed by 0, and a credit is awarded exactly
# when that digit equals the score's tens digit (tests/originals/match
# .tests.ps1 is the original-ROM version). Each game's score, digits and
# outcome are printed as INFO lines.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Scale = 'src/8bc-deluxe/gamerules.md "Deluxe score scale"'
$Manual = 'OPS manual p. 1-9 "Match Feature; Register 29"'
# "Verify Match retains the factory tens-digit behavior ... even when the
# score's ones digit is nonzero"; "Deluxe score scale": "The manual defines
# Match against the tens digit, and the ROM continues to do so. Activating the
# ones digit does not change Match probability or presentation." Manual
# p. 1-9: register 29 = 1 turns Match on; a match number equal to the tens
# digit of a player's score awards a free game (one credit).
$MatchRegister = 29
$MatchOn = 1
$CreditsForMatch = 1
$CreditsForNoMatch = 0
$Games = 12
# Frames after game over by which the match animation has stopped and any
# award has posted (tests/originals/match.tests.ps1).
$SettleFrames = 400
# The schedule. A Rebound scores 1 and an unlit spin 10 (gamerules.md
# "Required gameplay verification", "Spinner"; a new ball starts at orbit
# inactive, so the spinner is unlit). Balls 1 and 2: one Rebound each. Ball 3:
# 2 * (g mod 5) spins, then 1 + (g mod 3) Rebounds. So game g scores
# 20 * (g mod 5) + 3 + (g mod 3): tens digit 0, 2, 4, 6 or 8, ones digit 3, 4
# or 5. (A first schedule with tens digits 0-9 drew no match in 12 games;
# this one draws two, so both outcomes are exercised.) Ball 3 drains
# 1 + 37 * g frames after its last hit.
function Get-Spins([int]$g) { 2 * ($g % 5) }
function Get-Rebounds([int]$g) { 1 + ($g % 3) }
function Get-EndDelay([int]$g) { 1 + 37 * $g }

$MatchAt = Get-EbcRamAddress 'MatchDigit'
$MatchMask = (Get-EbcNames).RamMasks.MatchDigit

Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $MatchRegister -Value $MatchOn | Out-Null
Exit-EbcServiceMode | Out-Null

$script:Results = @()
for ($g = 0; $g -lt $Games; $g++) {
    Add-EbcCredit | Out-Null
    Start-EbcPlay | Out-Null
    for ($ball = 1; $ball -le 3; $ball++) {
        Step-EbcFrames -Frames 120
        if ($ball -eq 3) {
            for ($h = 0; $h -lt (Get-Spins $g); $h++) { Invoke-EbcScoredHit 'Spinner' | Out-Null }
            for ($h = 0; $h -lt (Get-Rebounds $g); $h++) { Invoke-EbcScoredHit 'Rebound' | Out-Null }
            Step-EbcFrames -Frames (Get-EndDelay $g)
        }
        else { Invoke-EbcScoredHit 'Rebound' | Out-Null }
        $credits = Get-EbcCredits
        $outcome = Invoke-EbcDrain
    }
    $end = Get-EbcFrame
    $score = [long](Get-EbcScoreBufferText (Get-EbcRamAddress 'ScoreBuffer1'))
    Step-EbcFrames -Frames $SettleFrames
    $r = [PSCustomObject]@{
        Game = $g + 1; Outcome = $outcome; EndFrame = $end; Score = $score; Ones = [int]($score % 10); Tens = [int]([Math]::Floor($score / 10) % 10)
        Digit = ((Read-EbcByte $MatchAt) -band $MatchMask) -shr 4
        Shown = Get-EbcDisplayText (Get-EbcNames).Displays.Status
        Award = (Get-EbcCredits) - $credits
    }
    $script:Results += $r
    Write-Output ("INFO {0}/match :: game {1}: ended frame {2}, score {3} (tens {4}, ones {5}), match digit {6} (display '{7}'), credits +{8}, {9}" -f $Tree, $r.Game, $r.EndFrame, $r.Score, $r.Tens, $r.Ones, $r.Digit, $r.Shown, $r.Award, $(if ($r.Digit -eq $r.Tens) { 'match' } else { 'no match' }))
}
$R = $script:Results

Test-EbcItem -Name 'Each fixed game ends in game over at a different frame, with the scheduled score' -Doc 'test schedule' -Body {
    Assert-EbcEqual -Expected @(1..$Games | ForEach-Object { 'GameOver' }) -Actual @($R | ForEach-Object { $_.Outcome }) -What 'outcome of each third-ball drain'
    Assert-EbcEqual -Expected $Games -Actual @($R | ForEach-Object { $_.EndFrame } | Select-Object -Unique).Count -What 'distinct game-over frames'
    Assert-EbcEqual -Expected @(0..($Games - 1) | ForEach-Object { 10 * (Get-Spins $_) + 2 + (Get-Rebounds $_) }) -Actual @($R | ForEach-Object { $_.Score }) -What 'final scores'
}
Test-EbcItem -Name 'Every game''s score has a nonzero ones digit' -Doc "$Doc; $Scale" -Body {
    Assert-EbcEqual -Expected @() -Actual @($R | Where-Object { $_.Ones -eq 0 } | ForEach-Object { "game $($_.Game) score $($_.Score)" }) -What ('games ending in 0 (ones digits ' + (($R | ForEach-Object { $_.Ones }) -join ',') + ')')
}
Test-EbcItem -Name 'Match presentation is unchanged: the match number shown at game end is the MatchDigit byte followed by 0' -Doc "$Scale; $Manual; tools/GameNames.psd1 Ram.MatchDigit" -Body {
    Assert-EbcEqual -Expected @($R | ForEach-Object { '{0}0' -f $_.Digit }) -Actual @($R | ForEach-Object { $_.Shown }) -What 'match/credit display after each game (MatchDigit followed by 0)'
}
Test-EbcItem -Name 'Match retains the factory tens-digit behavior even when the score''s ones digit is nonzero: a credit is awarded exactly when the match digit equals the score tens digit' -Doc "$Doc; $Scale; $Manual" -Body {
    $expected = @($R | ForEach-Object { if ($_.Digit -eq $_.Tens) { $CreditsForMatch } else { $CreditsForNoMatch } })
    Assert-EbcEqual -Expected $expected -Actual @($R | ForEach-Object { $_.Award }) -What ('credits added by each game (match digits ' + (($R | ForEach-Object { $_.Digit }) -join ',') + '; tens digits ' + (($R | ForEach-Object { $_.Tens }) -join ',') + '; ones digits ' + (($R | ForEach-Object { $_.Ones }) -join ',') + ')')
}
Test-EbcItem -Name 'The fixed games include both a match and a non-match' -Doc 'test schedule' -Body {
    $matched = @($R | Where-Object { $_.Digit -eq $_.Tens }).Count
    Assert-EbcTrue ($matched -ge 1 -and $matched -lt $Games) "$matched of $Games games matched; the schedule must exercise both outcomes"
}
Complete-EbcTests
