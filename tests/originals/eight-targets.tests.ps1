param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Original ROM E-I-G-H-T standups (switches 33-37): a first hit clears the
# target's bit in 1045, a repeated hit clears nothing, and collecting all five
# lights the next B-A-L-L letter and re-arms the targets, all by play.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM"'
$Manual = 'OPS manual p. 1-11 "E-I-G-H-T Feature"'
# gamerules.md: switches 33-37 are E, I, G, H and T, sharing handler CC7C,
# whose active-low collected-letter state is 1045; a hit clears its bit only
# if that letter was not already collected. The five letters are 1045's low
# five bits; 1F there means none collected (armed).
$Letters = @('Drop Target "E"', 'Drop Target "I"', 'Drop Target "G"', 'Drop Target "H"', 'Drop Target "T"')
$LetterMask = 0x1F
$Armed = '1F'
# gamerules.md: all five collected awards the next BALL letter and re-arms
# E-I-G-H-T. Manual p. 1-11: completing E-I-G-H-T the first time lights the
# "B" in B-A-L-L (lamp number from the manual's lamp driver table;
# GameNames.psd1 Lamps).
$LampB = Get-EbcLampNumber 'Ball "B"'
# Frames sampled for a lamp's state (covers the 16-frame blink cycle twice).
$LampSampleFrames = 32

# Each standup counts only while the drop group behind it is down, and its hit
# re-arms that group (GameNames.psd1 StandupDropGroups); sink the group first.
$Groups = (Get-EbcNames).StandupDropGroups
function Get-Letters { '{0:X2}' -f ((Read-EbcByte 0x1045) -band $LetterMask) }
function Invoke-Standup([string]$Name) {
    Invoke-EbcScoredHit $Groups[$Name] | Out-Null
    $before = Get-Letters
    Invoke-EbcScoredHit $Name -AfterSolenoid $Groups[$Name] | Out-Null
    [PSCustomObject]@{ Before = $before; After = Get-Letters }
}
# Bits cleared by a hit, as two hex digits.
function Get-Cleared($r) { '{0:X2}' -f ([Convert]::ToInt32($r.Before, 16) -band -bnot [Convert]::ToInt32($r.After, 16)) }
function Get-LampB {
    $lit = 0
    for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; if (Get-EbcLamp -Number $LampB) { $lit++ } }
    "$lit/$LampSampleFrames"
}

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

$script:First = @{}
Test-EbcItem -Name 'Switches 33-37 clear their bit in 1045 on a first hit only' -Doc $Doc -Body {
    Assert-EbcEqual -Expected $Armed -Actual (Get-Letters) -What '1045 & 1F on the first ball'
    $cleared = @(); $repeat = @()
    # E, I, G and H: first hit, then a repeated hit (T completes the set below).
    foreach ($name in $Letters[0..3]) {
        $c = Get-Cleared (Invoke-Standup $name)
        $script:First[$name] = $c
        $cleared += $c
        $repeat += Get-Cleared (Invoke-Standup $name)
    }
    # Each first hit clears exactly one bit, a different one per switch.
    $single = @($cleared | Where-Object { @(1, 2, 4, 8, 16) -contains [Convert]::ToInt32($_, 16) })
    Assert-EbcEqual -Expected 4 -Actual $single.Count -What "single bits cleared by the first E, I, G, H hits (cleared: $($cleared -join ', '))"
    Assert-EbcEqual -Expected 4 -Actual @($cleared | Select-Object -Unique).Count -What "distinct bits cleared by E, I, G, H (cleared: $($cleared -join ', '))"
    Assert-EbcEqual -Expected @('00', '00', '00', '00') -Actual $repeat -What 'bits cleared by repeated E, I, G, H hits'
}
Test-EbcItem -Name 'All five collected award a B-A-L-L letter and re-arm the targets' -Doc "$Doc; $Manual" -Body {
    Assert-EbcEqual -Expected "0/$LampSampleFrames" -Actual (Get-LampB) -What 'B-A-L-L "B" lamp before T'
    # Before T, only the bit that E, I, G and H left set remains.
    $left = $LetterMask; foreach ($c in $script:First.Values) { $left = $left -band -bnot [Convert]::ToInt32($c, 16) }
    $t = Invoke-Standup $Letters[4]
    Assert-EbcEqual -Expected @(('{0:X2}' -f $left), $Armed) -Actual @($t.Before, $t.After) -What '1045 & 1F before and after the T hit (only T left, then re-armed)'
    Assert-EbcEqual -Expected "$LampSampleFrames/$LampSampleFrames" -Actual (Get-LampB) -What 'B-A-L-L "B" lamp after T'
    # Re-armed: E's first hit of the new round clears its bit again.
    Assert-EbcEqual -Expected $script:First[$Letters[0]] -Actual (Get-Cleared (Invoke-Standup $Letters[0])) -What 'bit cleared by E in the new round'
}
Complete-EbcTests
