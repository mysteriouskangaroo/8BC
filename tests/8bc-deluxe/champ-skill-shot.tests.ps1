param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Ball-start H/A/M skill shot, entirely by timed lamp observation, switch play,
# drains, and a real B-A-L-L Extra Ball award. The target is per-player state;
# the live blink is output-only and must never alter CHAMP_LANE_STATE.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "CHAMP H-A-M skill shot"'
$Trace = 'src/8bc-deluxe/ghidra/GAME_RULE_TRACES.md "Ball-start H-A-M skill shot"'
$Manual = 'OPS manual p. 1-18 switches 18-20 and lamp chart H/A/M Top Lane'
$TargetAddress = Get-EbcRamAddress 'DELUXE_CHAMP_SKILL_ACTIVE_TARGET'
$TargetsAddress = Get-EbcRamAddress 'DELUXE_PLAYER_CHAMP_SKILL_TARGETS'
$StackAddress = Get-EbcRamAddress 'DELUXE_STACKED_EXTRA_BALLS'
$CompletionCountAddress = 0x10FD
$Target = @{ H = 0x02; A = 0x04; M = 0x08 }
$Lane = @{ H = '"H" Top Lane'; A = '"A" Top Lane'; M = '"M" Top Lane' }
$LetterForTarget = @{ 0x02 = 'H'; 0x04 = 'A'; 0x08 = 'M' }
$Letters = @('C', 'H', 'A', 'M', 'P')
$LetterLamp = @{}; foreach ($l in $Letters) { $LetterLamp[$l] = Get-EbcLampNumber "`"$l`" Rollover" }
$Fps = (Get-EbcNames).FramesPerSecond

$LetterOf = [ordered]@{
    E = 'Drop Target "E"'
    I = 'Drop Target "I"'
    G = 'Drop Target "G"'
    H = 'Drop Target "H"'
    T = 'Drop Target "T"'
}
$Standups = (Get-EbcNames).StandupDropGroups

function Get-LetterState {
    $b = Read-EbcByte (Get-EbcRamAddress 'CHAMP_LANE_STATE')
    (@(for ($k = 0; $k -lt 5; $k++) { if ($b -band (1 -shl $k)) { $Letters[$k] } }) -join '')
}

function Get-LetterLamps {
    (@($Letters | Where-Object { Get-EbcLamp -Number $LetterLamp[$_] }) -join '')
}

function Wait-SkillTarget([byte]$Wanted, [int]$MaxFrames = 500) {
    for ($frames = 0; $frames -le $MaxFrames; $frames++) {
        if ((Read-EbcByte $TargetAddress) -eq $Wanted) { return $frames }
        Step-EbcFrames -Frames 1
    }
    throw ('skill target did not reach {0:X2} in {1} frames' -f $Wanted, $MaxFrames)
}

function Invoke-EightLetter([string]$Letter) {
    $standup = $LetterOf[$Letter]
    $group = $Standups[$standup]
    Invoke-EbcScoredHit $group | Out-Null
    Invoke-EbcScoredHit $standup -AfterSolenoid $group | Out-Null
}

function Complete-EightWord {
    foreach ($letter in $LetterOf.Keys) { Invoke-EightLetter $letter }
}

function Get-SoundCommands([int]$Since) {
    @(Get-EbcEvents -Since $Since | Where-Object { $_ -match '^\d+ snd \d+ \d+$' } | ForEach-Object { [int](($_ -split ' ')[3]) })
}

function Invoke-WatchedSkill([string]$Switch, [int]$Frames = 300) {
    $player = [int](Get-EbcCurrentPlayer)
    $before = Get-EbcScore -Player $player
    $seen = Get-EbcEventCount
    $number = Get-EbcSwitch $Switch
    $patterns = [Collections.Generic.HashSet[string]]::new()
    for ($k = 0; $k -lt $Frames; $k++) {
        if ($k -eq 0) { Set-EbcSwitch -Number $number -Closed $true }
        if ($k -eq 4) { Set-EbcSwitch -Number $number -Closed $false }
        Step-EbcFrames -Frames 1
        $null = $patterns.Add((Get-LetterLamps))
    }
    Set-EbcSwitch -Number $number -Closed $false
    [PSCustomObject]@{
        Score = (Get-EbcScore -Player $player) - $before
        Sounds = @(Get-SoundCommands $seen)
        LampPatterns = @($patterns)
        FinalLamps = Get-LetterLamps
    }
}

function Set-SkillTestAdjustments {
    Enter-EbcServiceMode | Out-Null
    Set-EbcAdjustment -Number 23 -Value 5 | Out-Null # five balls
    Set-EbcAdjustment -Number 43 -Value 1 | Out-Null # Extra Ball on B/odd count
    Set-EbcAdjustment -Number 46 -Value 1 | Out-Null # recall partial CHAMP letters
    Exit-EbcServiceMode | Out-Null
}

Start-EbcGame
Set-SkillTestAdjustments
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null

# New game starts on H. Observe one complete A dwell so startup/serve latency
# cannot shorten the measured interval, and sample its physical lamp overlay.
$initialTarget = Read-EbcByte $TargetAddress
$toA = Wait-SkillTarget $Target.A
$aStart = Get-EbcFrame
$aLampStates = [Collections.Generic.HashSet[bool]]::new()
$otherLampPatterns = [Collections.Generic.HashSet[string]]::new()
while ((Read-EbcByte $TargetAddress) -eq $Target.A) {
    $null = $aLampStates.Add([bool](Get-EbcLamp -Number $LetterLamp.A))
    $null = $otherLampPatterns.Add(('{0}{1}' -f [int][bool](Get-EbcLamp -Number $LetterLamp.H), [int][bool](Get-EbcLamp -Number $LetterLamp.M)))
    Step-EbcFrames -Frames 1
    if ((Get-EbcFrame) - $aStart -gt ($Fps * 3)) { throw 'A skill target did not advance to M' }
}
$aDwellFrames = (Get-EbcFrame) - $aStart
$afterA = Read-EbcByte $TargetAddress

# M is now blinking. H is a miss: the skill shot ends and H follows the normal
# lane path. The remembered target remains M for this player's next ball.
$missScore = Invoke-EbcScoredHit $Lane.H
$missActive = Read-EbcByte $TargetAddress
$missLetters = Get-LetterState
$rememberedAfterMiss = Read-EbcByte $TargetsAddress

Test-EbcItem -Name 'The ball-start skill target cycles H to A to M with a two-second dwell and only the selected H/A/M lamp blinks' -Doc "$Doc; $Trace; $Manual" -Body {
    Assert-EbcEqual -Expected $Target.H -Actual $initialTarget -What 'new-game target'
    Assert-EbcEqual -Expected $Target.M -Actual $afterA -What 'target after one complete A dwell'
    Assert-EbcTrue ([math]::Abs($aDwellFrames - ($Fps * 2)) -le 3) "A dwell was $aDwellFrames frames, expected $($Fps * 2)"
    Assert-EbcEqual -Expected 2 -Actual $aLampStates.Count -What 'A lamp visible states during its dwell'
    Assert-EbcEqual -Expected 1 -Actual $otherLampPatterns.Count -What 'non-target H/M lamp patterns during A dwell'
}

Test-EbcItem -Name 'The first wrong H/A/M rollover ends the skill shot and follows the normal CHAMP letter path' -Doc "$Doc; $Trace" -Body {
    Assert-EbcEqual -Expected 300 -Actual $missScore -What 'missed H lane score at 1x'
    Assert-EbcEqual -Expected 0 -Actual $missActive -What 'active target after miss'
    Assert-EbcEqual -Expected 'H' -Actual $missLetters -What 'letters after missed H rollover'
    Assert-EbcEqual -Expected $Target.M -Actual $rememberedAfterMiss -What 'remembered target after miss'
}

# Ball 2 resumes M. C does not end an H/A/M skill shot; A misses and records
# normally, leaving three recalled letters C/H/A for the next ball.
Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'serve ball 2'
$ball2Target = Read-EbcByte $TargetAddress
$cScore = Invoke-EbcScoredHit '"C" Return Lane'
$afterCActive = Read-EbcByte $TargetAddress
$ball2MissLetter = if ($afterCActive -eq $Target.A) { 'M' } else { 'A' }
$topLaneMissScore = Invoke-EbcScoredHit $Lane[$ball2MissLetter]
$ball2Letters = Get-LetterState
$expectedBall2Letters = if ($ball2MissLetter -eq 'A') { 'CHA' } else { 'CHM' }
Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'serve ball 3'
$ball3Target = Read-EbcByte $TargetAddress
$ball3SkillLetter = $LetterForTarget[[int]$ball3Target]
$beforeSkillLetters = Get-LetterState
$beforeSkillBits = (Read-EbcByte (Get-EbcRamAddress 'CHAMP_LANE_STATE')) -band 0x1F
$expectedRestoredLamps = (@($Letters | Where-Object { -not $beforeSkillLetters.Contains($_) }) -join '')
$skillWatch = Invoke-WatchedSkill $Lane[$ball3SkillLetter]
$skillScore = $skillWatch.Score
$skillSounds = $skillWatch.Sounds
$afterSkillBits = (Read-EbcByte (Get-EbcRamAddress 'CHAMP_LANE_STATE')) -band 0x1F
$afterSkillLetters = Get-LetterState
$skillCompletions = Read-EbcByte $CompletionCountAddress
$rightThumper = Invoke-EbcScoredHit 'Right Thumper Bumper'

Test-EbcItem -Name 'A matching target awards one CHAMP completion while preserving the exact recalled partial-letter state' -Doc "$Doc; $Trace" -Body {
    Assert-EbcEqual -Expected $Target.M -Actual $ball2Target -What 'remembered target at ball 2 start'
    Assert-EbcTrue ($afterCActive -in @($Target.H, $Target.A, $Target.M)) 'C lane ended or corrupted the active H/A/M target'
    Assert-EbcEqual -Expected 300 -Actual $cScore -What 'C lane score while skill shot remains active'
    Assert-EbcEqual -Expected 300 -Actual $topLaneMissScore -What "missed $ball2MissLetter lane score"
    Assert-EbcEqual -Expected $expectedBall2Letters -Actual $ball2Letters -What 'three partial letters before drain'
    Assert-EbcEqual -Expected $afterCActive -Actual $ball3Target -What 'remembered target at ball 3 start'
    Assert-EbcEqual -Expected $beforeSkillBits -Actual $afterSkillBits -What 'authoritative partial CHAMP bits across the skill-shot hit'
    Assert-EbcEqual -Expected $beforeSkillLetters -Actual $afterSkillLetters -What 'partial CHAMP letters across the skill-shot hit'
    Assert-EbcEqual -Expected 300 -Actual $skillScore -What "matching $ball3SkillLetter lane score"
    Assert-EbcEqual -Expected 1 -Actual $skillCompletions -What 'CHAMP completion count after skill shot'
    Assert-EbcEqual -Expected 300 -Actual $rightThumper -What 'right thumper after the first CHAMP completion'
}

Test-EbcItem -Name 'Collecting the skill shot plays CHAMP complete before Called Ball, flashes all five green inserts, then restores the partial letters' -Doc "$Doc; $Trace" -Body {
    Assert-EbcEqual -Expected 1 -Actual @($skillSounds | Where-Object { $_ -eq 0x34 }).Count -What 'C-H-A-M-P complete sound command on the skill-shot award'
    Assert-EbcEqual -Expected 0 -Actual @($skillSounds | Where-Object { $_ -ge 0x51 -and $_ -le 0x5F }).Count -What 'Called Ball speech during the skill-shot celebration'
    Assert-EbcTrue ($skillWatch.LampPatterns -contains 'CHAMP') "all-five-on CHAMP pattern was not observed: [$($skillWatch.LampPatterns -join ', ')]"
    Assert-EbcTrue ($skillWatch.LampPatterns -contains '') "all-five-off CHAMP pattern was not observed: [$($skillWatch.LampPatterns -join ', ')]"
    Assert-EbcEqual -Expected $expectedRestoredLamps -Actual $skillWatch.FinalLamps -What 'green CHAMP inserts after the celebration'
}

# Earn B/count 1 by real E-I-G-H-T target play. It awards one Extra Ball; the
# served Extra Ball must rearm the skill shot at the same remembered M target.
Complete-EightWord
$pendingBeforeDrain = Read-EbcByte $StackAddress
$ballBeforeExtra = Get-EbcBallInPlay
Assert-EbcEqual -Expected 'Served' -Actual (Invoke-EbcDrain) -What 'serve stacked Extra Ball'
$ballAfterExtra = Get-EbcBallInPlay
$extraBallTarget = Read-EbcByte $TargetAddress
$pendingAfterDrain = Read-EbcByte $StackAddress

Test-EbcItem -Name 'Every served Extra Ball rearms the skill shot at the player''s remembered target' -Doc "$Doc; $Trace" -Body {
    $seen = "ball $ballBeforeExtra->$ballAfterExtra, pending $pendingBeforeDrain->$pendingAfterDrain, target $extraBallTarget"
    $want = "ball 3->3, pending 1->0, target $ball3Target"
    Assert-EbcEqual -Expected $want -Actual $seen -What 'Extra Ball skill-shot rearm'
}

Complete-EbcTests
