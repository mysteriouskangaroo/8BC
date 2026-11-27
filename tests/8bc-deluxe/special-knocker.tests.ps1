param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Use operator settings, coins, CHAMP completions and the outlane Special.
# Observe solenoid events through the full pulse, not just an award flag.
# Clause: Collect each available special
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force
$Doc = 'src/8bc-deluxe/gamerules.md "Specials"'
$Knocker = Get-EbcSolenoid 'Knocker'
function Measure-Hit([string]$Switch, [string]$After) {
    $before = Get-EbcCredits
    $seen = Get-EbcEventCount
    $score = if ($After) { Invoke-EbcScoredHit $Switch -AfterSolenoid $After } else { Invoke-EbcScoredHit $Switch }
    Step-EbcFrames -Frames 60
    $events = @(Get-EbcEvents -Since $seen)
    [PSCustomObject]@{
        Score = $score
        Before = $before
        After = Get-EbcCredits
        KnockOn = @($events | Where-Object { $_ -match "^\d+ sol $Knocker 1$" }).Count
        KnockOff = @($events | Where-Object { $_ -match "^\d+ sol $Knocker 0$" }).Count
        SpecialSounds = @($events | Where-Object { $_ -match '^\d+ snd \d+ 111$' }).Count
    }
}
Start-EbcGame
foreach ($case in @(
    @{ Name='replay at maximum credits'; Option=3; Fill=$true; Before=3; After=3 },
    @{ Name='replay reaching maximum credits'; Option=3; Fill=$false; Before=2; After=3 },
    @{ Name='no operator award at maximum credits'; Option=0; Fill=$true; Before=3; After=3 },
    @{ Name='points award at maximum credits'; Option=1; Fill=$true; Before=3; After=3 },
    @{ Name='Extra Ball award at maximum credits'; Option=2; Fill=$true; Before=3; After=3 }
)) {
    Test-EbcItem -Name "Special knocks exactly once: $($case.Name)" -Doc $Doc -Body {
        Enter-EbcServiceMode | Out-Null
        Set-EbcAdjustment -Number 16 -Value 3 | Out-Null # Maximum credits.
        Set-EbcAdjustment -Number 25 -Value $case.Option | Out-Null
        Exit-EbcServiceMode | Out-Null
        Add-EbcCredit -Count 3 | Out-Null
        Start-EbcPlay | Out-Null
        Step-EbcFrames -Frames 120
        if ($case.Fill) { Add-EbcCredit | Out-Null }
        foreach ($completion in 1..5) { Complete-EbcChamp -RearmWith 'Center Rollover Button' | Out-Null }
        $award = Measure-Hit 'Left Outlane'
        $ordinary = Measure-Hit 'Left Outlane'
        # Finish before assertions, so a failed case cannot contaminate the
        # next service session. The replay/Extra Ball choices remain operative.
        Complete-EbcGame | Out-Null
        Step-EbcFrames -Frames 600
        Assert-EbcEqual -Expected $case.Before -Actual $award.Before -What 'credits before Special'
        Assert-EbcEqual -Expected $case.After -Actual $award.After -What 'credits after Special'
        Assert-EbcEqual -Expected 1 -Actual $award.KnockOn -What 'Special knocker pulse starts'
        Assert-EbcEqual -Expected 1 -Actual $award.KnockOff -What 'Special knocker pulse ends'
        Assert-EbcEqual -Expected 0 -Actual $ordinary.KnockOn -What 'ordinary outlane hit does not knock'
        Assert-EbcEqual -Expected 1 -Actual $award.SpecialSounds -What 'Special sound is unchanged'
        Assert-EbcEqual -Expected 0 -Actual $ordinary.SpecialSounds -What 'ordinary outlane has no Special sound'
        Assert-EbcEqual -Expected $case.After -Actual $ordinary.After -What 'ordinary outlane preserves credits'
        if ($case.Option -eq 0 -or $case.Option -eq 3) {
            Assert-EbcEqual -Expected 75000 -Actual ($award.Score - $ordinary.Score) -What 'unchanged 3x Deluxe Special points'
        }
    }
}
Test-EbcItem -Name 'The direct-entry 120K rack Special also knocks once at maximum credits' -Doc $Doc -Body {
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number 16 -Value 3 | Out-Null
    Set-EbcAdjustment -Number 25 -Value 3 | Out-Null
    Set-EbcAdjustment -Number 44 -Value 1 | Out-Null
    Exit-EbcServiceMode | Out-Null
    Add-EbcCredit -Count 3 | Out-Null
    Start-EbcPlay | Out-Null
    Step-EbcFrames -Frames 120
    Add-EbcCredit | Out-Null
    foreach ($shot in @(
        @('Drop Target 1,2,9,10',''),
        @('Drop Target 1,2,9,10','Drop Target "I"'),
        @('Drop Target 3,11',''),
        @('Drop Target 4,5,12,13',''),
        @('Drop Target 4,5,12,13','Drop Target "H"'),
        @('Drop Target 6,14',''),
        @('Drop Target 7,15','')
    )) {
        if ($shot[1]) { Invoke-EbcScoredHit $shot[1] -AfterSolenoid $shot[0] | Out-Null }
        Invoke-EbcScoredHit $shot[0] | Out-Null
    }
    Assert-EbcEqual -Expected 0x7F -Actual (Get-EbcSunkBalls) -What 'all seven balls sunk'
    $award = Measure-Hit 'Saucer' 'Saucer'
    Assert-EbcEqual -Expected 3 -Actual $award.Before -What 'credits before rack Special'
    Assert-EbcEqual -Expected 3 -Actual $award.After -What 'credits remain capped'
    Assert-EbcEqual -Expected 1 -Actual $award.KnockOn -What 'rack Special pulse starts'
    Assert-EbcEqual -Expected 1 -Actual $award.KnockOff -What 'rack Special pulse ends'
    Assert-EbcEqual -Expected 0 -Actual $award.SpecialSounds -What 'direct-entry Special sound remains unchanged'
}
Complete-EbcTests
