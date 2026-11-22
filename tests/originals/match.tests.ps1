param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM match: over 12 fixed one-player games, each ended at a
# different frame, the match number shown at game end is the MatchDigit byte,
# and a credit is awarded exactly when that digit equals the score's tens
# digit. Each game's match digit and outcome are printed as INFO lines.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Manual = 'OPS manual p. 1-9 "Match Feature; Register 29" and p. 1-2'
# Manual p. 1-5/1-9: register 29 "Match option", 1 = ON. A fresh NVRAM already
# runs the match (measured: 168B stays FF after storing 1), so the setting is
# made explicit through the service menu.
$MatchRegister = 29
$MatchOn = 1
# Manual p. 1-9: if the match number equals the tens digit of a player's
# score, a free game (one credit) is awarded.
$CreditsForMatch = 1
$CreditsForNoMatch = 0
$Games = 12
# Frames after game over by which the match animation has stopped and any
# award has posted (measured: the number settles about 200 frames after).
$SettleFrames = 400
# The schedule: Rebound (10 points) once on balls 1 and 2, then 2 + 2 * (g mod 5)
# times on ball 3, so scores end in 40, 60, 80, 100, 120; ball 3 drains
# 1 + 37 * g frames after its last hit, so each game ends at a different frame.
function Get-Ball3Hits([int]$g) { 2 + 2 * ($g % 5) }
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
    $end = $null
    for ($ball = 1; $ball -le 3; $ball++) {
        Step-EbcFrames -Frames 120
        $hits = if ($ball -eq 3) { Get-Ball3Hits $g } else { 1 }
        for ($h = 0; $h -lt $hits; $h++) { Invoke-EbcScoredHit 'Rebound' | Out-Null }
        if ($ball -eq 3) { Step-EbcFrames -Frames (Get-EndDelay $g) }
        $credits = Get-EbcCredits
        $outcome = Invoke-EbcDrain
    }
    $end = Get-EbcFrame
    $score = [long](Get-EbcScoreBufferText (Get-EbcRamAddress 'ScoreBuffer1'))
    Step-EbcFrames -Frames $SettleFrames
    $r = [PSCustomObject]@{
        Game = $g + 1; Outcome = $outcome; EndFrame = $end; Score = $score; Tens = [int](($score / 10) % 10)
        Digit = ((Read-EbcByte $MatchAt) -band $MatchMask) -shr 4
        Shown = Get-EbcDisplayText (Get-EbcNames).Displays.Status
        Award = (Get-EbcCredits) - $credits
    }
    $script:Results += $r
    Write-Output ("INFO {0}/match :: game {1}: ended frame {2}, score {3} (tens {4}), match digit {5} (display '{6}'), credits +{7}, {8}" -f $Tree, $r.Game, $r.EndFrame, $r.Score, $r.Tens, $r.Digit, $r.Shown, $r.Award, $(if ($r.Digit -eq $r.Tens) { 'match' } else { 'no match' }))
}
$R = $script:Results

Test-EbcItem -Name 'Each fixed game ends in game over at a different frame' -Doc $Manual -Body {
    Assert-EbcEqual -Expected @(1..$Games | ForEach-Object { 'GameOver' }) -Actual @($R | ForEach-Object { $_.Outcome }) -What 'outcome of each third-ball drain'
    Assert-EbcEqual -Expected $Games -Actual @($R | ForEach-Object { $_.EndFrame } | Select-Object -Unique).Count -What 'distinct game-over frames'
}
Test-EbcItem -Name 'The match number shown at game end is the MatchDigit byte' -Doc "$Manual; tools/GameNames.psd1 Ram.MatchDigit" -Body {
    Assert-EbcEqual -Expected @($R | ForEach-Object { '{0}0' -f $_.Digit }) -Actual @($R | ForEach-Object { $_.Shown }) -What 'match/credit display after each game (MatchDigit followed by 0)'
}
Test-EbcItem -Name 'A credit is awarded exactly when the match digit equals the score tens digit' -Doc $Manual -Body {
    $expected = @($R | ForEach-Object { if ($_.Digit -eq $_.Tens) { $CreditsForMatch } else { $CreditsForNoMatch } })
    Assert-EbcEqual -Expected $expected -Actual @($R | ForEach-Object { $_.Award }) -What ('credits added by each game (match digits ' + (($R | ForEach-Object { $_.Digit }) -join ',') + '; tens digits ' + (($R | ForEach-Object { $_.Tens }) -join ',') + ')')
}
Test-EbcItem -Name 'The fixed games include both a match and a non-match' -Doc 'test schedule' -Body {
    $matched = @($R | Where-Object { $_.Digit -eq $_.Tens }).Count
    Assert-EbcTrue ($matched -ge 1 -and $matched -lt $Games) "$matched of $Games games matched; the schedule must exercise both outcomes"
}
Complete-EbcTests
