param([string]$Tree, [string]$VpmZip, [string]$ObserveTo, [int]$Games = 300)
# Deluxe match frequency (long tier: runs only with Invoke-GameTests.ps1
# -Long): over 300 one-player games, each with a nonzero ones digit and
# ending at a different frame, the share of games that award a match credit
# lies between 6% and 14%. -Games exists only to time a shorter run; the
# runner always uses the default.
# Clauses of gamerules.md "Required gameplay verification" checked here
# (tools/tests/Test-DeluxeCoverage.ps1):
# Clause: Verify Match retains the factory
Import-Module (Join-Path $PSScriptRoot '../../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Scale = 'src/8bc-deluxe/gamerules.md "Deluxe score scale"'
$Manual = 'OPS manual p. 1-9 "Match Feature; Register 29"'
# "Verify Match retains the factory tens-digit behavior and approximately 10%
# award probability even when the score's ones digit is nonzero." The brief's
# window for "approximately 10%" over 300 games is 6% to 14% (10% +/- 4%).
$DefaultGames = 300
$Rate = 0.10
$RateLow = $Rate - 0.04
$RateHigh = $Rate + 0.04
# Manual p. 1-9: register 29 = 1 turns Match on.
$MatchRegister = 29
$MatchOn = 1
# Frames after game over by which any match award has posted
# (tests/originals/match.tests.ps1).
$SettleFrames = 400
# The schedule (as in tests/8bc-deluxe/match.tests.ps1): a Rebound scores 1
# and an unlit spin 10. Balls 1 and 2: one Rebound each. Ball 3: (g mod 10)
# spins, then 1 + (g mod 3) Rebounds, so game g scores
# 10 * (g mod 10) + 3 + (g mod 3): every tens digit, ones digit 3, 4 or 5.
# Ball 3 drains 1 + (37 * g mod 1009) frames after its last hit, so games end
# at spread-out frames of the free-running counter the match number comes
# from (GameNames.psd1 Ram.MatchDigit).
function Get-Spins([int]$g) { $g % 10 }
function Get-Rebounds([int]$g) { 1 + ($g % 3) }
function Get-EndDelay([int]$g) { 1 + ((37 * $g) % 1009) }

$clock = [Diagnostics.Stopwatch]::StartNew()
Start-EbcGame
Enter-EbcServiceMode | Out-Null
Set-EbcAdjustment -Number $MatchRegister -Value $MatchOn | Out-Null
Exit-EbcServiceMode | Out-Null

$R = [Collections.Generic.List[object]]::new()
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
    $R.Add([PSCustomObject]@{ Game = $g + 1; Outcome = $outcome; EndFrame = $end; Score = $score; Award = (Get-EbcCredits) - $credits })
}
$awarded = @($R | Where-Object { $_.Award -gt 0 }).Count
$awardRate = $awarded / [Math]::Max(1, $R.Count)
Write-Output ("INFO {0}/match-frequency :: {1} games in {2:N1} s ({3:N2} s per game); {4} awarded a match credit ({5:P1}); tens digits of the awards [{6}]" -f $Tree, $R.Count, $clock.Elapsed.TotalSeconds, ($clock.Elapsed.TotalSeconds / [Math]::Max(1, $R.Count)), $awarded, $awardRate, ((@($R | Where-Object { $_.Award -gt 0 } | ForEach-Object { [int]([Math]::Floor($_.Score / 10) % 10) }) | Sort-Object) -join ','))

Test-EbcItem -Name 'All 300 games end in game over at distinct frames, each with the scheduled score and a nonzero ones digit' -Doc 'test schedule' -Body {
    Assert-EbcEqual -Expected $DefaultGames -Actual $R.Count -What 'games played'
    Assert-EbcEqual -Expected @() -Actual @($R | Where-Object { $_.Outcome -ne 'GameOver' } | ForEach-Object { "game $($_.Game)" }) -What 'games whose third drain did not end the game'
    Assert-EbcEqual -Expected $R.Count -Actual @($R | ForEach-Object { $_.EndFrame } | Select-Object -Unique).Count -What 'distinct game-over frames'
    Assert-EbcEqual -Expected @($R | ForEach-Object { $g = $_.Game - 1; 10 * (Get-Spins $g) + 2 + (Get-Rebounds $g) }) -Actual @($R | ForEach-Object { $_.Score }) -What 'final scores'
    Assert-EbcEqual -Expected @() -Actual @($R | Where-Object { $_.Score % 10 -eq 0 } | ForEach-Object { "game $($_.Game)" }) -What 'games ending in 0'
}
Test-EbcItem -Name 'Over 300 games with a nonzero ones digit the match award rate is approximately 10% (window: 6% to 14%)' -Doc "$Doc; $Scale; $Manual" -Body {
    Assert-EbcTrue ($awardRate -ge $RateLow -and $awardRate -le $RateHigh) ("{0} of {1} games awarded a match credit ({2:P1}); expected {3:P0} to {4:P0}" -f $awarded, $R.Count, $awardRate, $RateLow, $RateHigh)
}
Complete-EbcTests
