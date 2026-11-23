param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Deluxe saucer: the 2x -> 3x -> 5x steps, the first 100,000, the relit
# 7x+100,000 / 8x+100,000 / 10x+100,000 / 100,000 awards and their lamps, the
# collect transitions that relight them, and dark saucer hits, all by play
# on one player's first ball.
#
# A collect transition is either an active orbit collect (orbit active ->
# spinner inactive) or the first active-spinner pulse (spinner active ->
# orbit inactive) (gamerules.md "Deluxe collect feature"; collect-cycle
# .tests.ps1). Each is reached by sinking a new ball to activate the current
# location first. The next-award lamps are the SAUCER 2X/3X/5X/100K inserts
# (GameNames.psd1 Lamps), read over $LampSampleFrames frames.
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force

$Doc = 'src/8bc-deluxe/gamerules.md "Required gameplay verification"'
$Hole = 'src/8bc-deluxe/gamerules.md "Hole / saucer"'
$Rules = 'src/8bc-deluxe/gamerules.md "Existing rules established in the original ROM"'

# "Hole / saucer": the 100,000 playfield award is scaled to 10,000 displayed.
$Award100K = 100000 / 10
# "The inserts represent 7x as 2x+5x, 8x as 3x+5x, and 10x as 2x+3x+5x, with
# the complete combination and 100,000 blinking in phase."
$Combo = @{ 2 = @('2X'); 3 = @('3X'); 5 = @('5X'); 100 = @('100,000'); 7 = @('2X', '5X', '100,000'); 8 = @('3X', '5X', '100,000'); 10 = @('2X', '3X', '5X', '100,000') }
# HARDWARE_MAP.md response map: 7B / 7C / 7D are the 2X / 3X / 5X
# multiplier announcements. A dark saucer hit makes none of them.
$Announce = @{ 2 = 0x7B; 3 = 0x7C; 5 = 0x7D }
# "Deluxe RAM $1149 then extends the actual bonus multiplier" ("Existing
# rules"); read only, as the earned end-of-ball multiplier.
$EarnedAt = 0x1149
$LampSampleFrames = 32

$Inserts = [ordered]@{}; foreach ($n in '2X', '3X', '5X', '100,000') { $Inserts[$n] = Get-EbcLampNumber "Saucer $n" }
$GroupOf = @{ 1 = 'Drop Target 1,2,9,10'; 2 = 'Drop Target 1,2,9,10'; 3 = 'Drop Target 3,11'; 4 = 'Drop Target 4,5,12,13'
              5 = 'Drop Target 4,5,12,13'; 6 = 'Drop Target 6,14'; 7 = 'Drop Target 7,15' }
$LatchOf = @{ 'Drop Target 1,2,9,10' = 0x01; 'Drop Target 3,11' = 0x04; 'Drop Target 4,5,12,13' = 0x08; 'Drop Target 6,14' = 0x20; 'Drop Target 7,15' = 0x40 }
$standups = (Get-EbcNames).StandupDropGroups
$ResetBy = @{}; foreach ($s in $standups.Keys) { $ResetBy[$standups[$s]] = $s }

function Get-Commands([int]$Since) {
    $ev = @(Get-EbcEvents -Since $Since | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { $f = $_ -split ' '; [PSCustomObject]@{ F = [int]$f[0]; B = [int]$f[3] } })
    for ($i = 0; $i -lt $ev.Count; $i++) {
        $ev[$i].B
        if ($i + 1 -lt $ev.Count -and $ev[$i + 1].F -eq $ev[$i].F -and $ev[$i + 1].B -eq ($ev[$i].B -shr 4)) { $i++ }
    }
}
# The next-award inserts: '<lit names> blinking in phase', 'dark', or the
# per-lamp frame strings when they are not one in-phase blink.
function Get-Inserts {
    $s = [ordered]@{}; foreach ($n in $Inserts.Keys) { $s[$n] = '' }
    for ($k = 0; $k -lt $LampSampleFrames; $k++) { Step-EbcFrames -Frames 1; foreach ($n in $Inserts.Keys) { $s[$n] += $(if (Get-EbcLamp -Number $Inserts[$n]) { '#' } else { '.' }) } }
    $lit = @($Inserts.Keys | Where-Object { $s[$_].Contains('#') })
    if (-not $lit.Count) { return 'dark' }
    $pats = @($lit | ForEach-Object { $s[$_] } | Select-Object -Unique)
    if ($pats.Count -eq 1 -and $pats[0].Contains('.')) { return "$($lit -join '+') blinking in phase" }
    ($Inserts.Keys | ForEach-Object { "$_ $($s[$_])" }) -join ', '
}
function Want-Inserts([int]$m) { if ($m -eq 0) { 'dark' } else { "$($Combo[$m] -join '+') blinking in phase" } }
function Get-Earned { [int](Read-EbcByte $EarnedAt) }
function Get-Location { (Read-EbcByte 0x10FB) -band 0x07 }   # DELUXE_COLLECT_STATE, read only to choose the next shot
# A newly sunk ball 1-7 (re-arming its group first when it is down).
function Invoke-NewSink {
    $sunk = Get-EbcSunkBalls
    $next = @(1..7 | Where-Object { -not ($sunk -band (1 -shl ($_ - 1))) })
    if (-not $next.Count) { throw 'balls 1-7 are sunk: the next sink is the 8-ball at the saucer' }
    $g = $GroupOf[$next[0]]
    if ((Read-EbcByte (Get-EbcRamAddress 'DROP_TARGET_SWITCH_CLOSURE_LATCHES')) -band $LatchOf[$g]) { Invoke-EbcScoredHit $ResetBy[$g] -AfterSolenoid $g | Out-Null }
    Invoke-EbcScoredHit $g | Out-Null
    if ((Get-EbcSunkBalls) -eq $sunk) { throw "$g sank no new ball" }
    Step-EbcFrames -Frames 30
}
# Collect states (src/8bc-deluxe/asm/symbols.inc): 4 = active, low bits
# 1/3 = orbit, 2 = spinner.
function Invoke-OrbitTransition {
    if ((Get-Location) -band 0x04) { if (((Get-Location) -band 3) -eq 2) { throw 'the spinner is active, not the orbit' } } else {
        if (((Get-Location) -band 3) -eq 2) { throw 'the spinner is the current location' }
        Invoke-NewSink }
    Invoke-EbcScoredHit 'Left Rollover Button' | Out-Null
    Step-EbcFrames -Frames 30
    'orbit collect'
}
function Invoke-SpinnerTransition {
    if (((Get-Location) -band 3) -ne 2) { throw 'the orbit is the current location' }
    if (-not ((Get-Location) -band 0x04)) { Invoke-NewSink }
    Invoke-EbcScoredHit 'Spinner' | Out-Null
    Step-EbcFrames -Frames 300                                   # spinner collecting ends
    'first spinner pulse'
}
function Invoke-Transition { if (((Get-Location) -band 3) -eq 2) { Invoke-SpinnerTransition } else { Invoke-OrbitTransition } }
# A saucer hit: score, the 7B-7D announcements, then the inserts and the
# earned multiplier.
function Invoke-Saucer {
    $seen = Get-EbcEventCount
    $d = Invoke-EbcScoredHit 'Saucer' -AfterSolenoid 'Saucer'
    Step-EbcFrames -Frames 30
    $ann = @(Get-Commands $seen | Where-Object { $_ -ge 0x7B -and $_ -le 0x7D } | ForEach-Object { '{0:X2}' -f $_ })
    [PSCustomObject]@{ Score = $d; Announce = ($ann -join ' '); Inserts = (Get-Inserts); Earned = (Get-Earned) }
}

function Show([string]$What) { [PSCustomObject]@{ What = $What; Inserts = (Get-Inserts); Earned = (Get-Earned) } }

Start-EbcGame
Add-EbcCredit | Out-Null
Start-EbcPlay | Out-Null
Step-EbcFrames -Frames 120

# ---- 2x, 3x, 5x, each with a collect transition before its hit ----
$steps = @()
$steps += Show 'new ball'
$steps += Show ("after an {0}" -f (Invoke-Transition))
$h2 = Invoke-Saucer
$steps += Show ("after a {0}" -f (Invoke-Transition))
$h3 = Invoke-Saucer
$steps += Show ("after an {0}" -f (Invoke-Transition))
$locAt5x = Get-Location
$h5 = Invoke-Saucer                                              # 5x: the first 100,000 lights at once
$lit100 = Show ("after a {0} with 100,000 lit" -f (Invoke-Transition))
$c1 = Invoke-Saucer                                              # the first 100,000
$d1 = Invoke-Saucer                                              # dark
# ---- 7x + 100,000 ----
$t7 = Show ("after an {0}" -f (Invoke-Transition))
$t7b = Show ("after a further {0}" -f (Invoke-Transition))
$c7 = Invoke-Saucer
$d2 = Invoke-Saucer
# ---- 8x + 100,000 ----
$t8 = Show ("after an {0}" -f (Invoke-Transition))
if ((Get-EbcSunkBalls) -ne 0x7F) { throw "expected balls 1-7 sunk before the 8-ball (10C3 $('{0:X2}' -f (Get-EbcSunkBalls)))" }
$c8 = Invoke-Saucer                                              # the 8-ball collection collects 8x + 100,000
$d3 = Invoke-Saucer
# ---- 10x + 100,000 ----
$t10 = Show ("after a {0}" -f (Invoke-Transition))
$t10b = Show ("after a further {0}" -f (Invoke-Transition))
$c10 = Invoke-Saucer
$d4 = Invoke-Saucer
# ---- 100,000 alone, twice ----
$t100 = Show ("after a {0}" -f (Invoke-Transition))
$t100b = Show ("after a further {0}" -f (Invoke-Transition))
$c100 = Invoke-Saucer
$d5 = Invoke-Saucer
$t100c = Show ("after a {0}" -f (Invoke-Transition))
$c100b = Invoke-Saucer

Test-EbcItem -Name 'The saucer displays and collects 2x, then 3x, then 5x without any collect transition changing or skipping those steps' -Doc "$Doc; $Hole" -Body {
    $seen = @($steps | ForEach-Object { "$($_.What): $($_.Inserts), earned $($_.Earned)x" }) + @($h2, $h3 | ForEach-Object { "hit: announcements [$($_.Announce)], inserts $($_.Inserts), earned $($_.Earned)x" })
    $want = @("new ball: $(Want-Inserts 2), earned 1x", "$($steps[1].What): $(Want-Inserts 2), earned 1x", "$($steps[2].What): $(Want-Inserts 3), earned 2x", "$($steps[3].What): $(Want-Inserts 5), earned 3x",
              ("hit: announcements [{0:X2}], inserts $(Want-Inserts 3), earned 2x" -f $Announce[2]), ("hit: announcements [{0:X2}], inserts $(Want-Inserts 5), earned 3x" -f $Announce[3]))
    Assert-EbcEqual -Expected $want -Actual $seen -What 'saucer inserts around the 2x and 3x hits'
}
Test-EbcItem -Name 'Collecting 5x immediately lights the first 100,000 regardless of the current collect state' -Doc "$Doc; $Hole" -Body {
    # The 5x hit comes right after an orbit collect, at spinner inactive,
    # with no transition since the 3x hit's own.
    $seen = "collect state before the hit $locAt5x; announcements [$($h5.Announce)], inserts $($h5.Inserts), earned $($h5.Earned)x"
    $want = ("collect state before the hit $locAt5x; announcements [{0:X2}], inserts $(Want-Inserts 100), earned 5x" -f $Announce[5])
    Assert-EbcEqual -Expected $want -Actual $seen -What 'the 5x hit'
}
Test-EbcItem -Name 'While 100,000 is already lit, another active collect changes nothing' -Doc "$Doc; $Hole" -Body {
    $seen = @("$($lit100.What): $($lit100.Inserts), earned $($lit100.Earned)x") + @($t7b, $t10b, $t100b | ForEach-Object { "$($_.What): $($_.Inserts), earned $($_.Earned)x" })
    $want = @("$($lit100.What): $(Want-Inserts 100), earned 5x", "$($t7b.What): $(Want-Inserts 7), earned 5x", "$($t10b.What): $(Want-Inserts 10), earned 8x", "$($t100b.What): $(Want-Inserts 100), earned 10x")
    Assert-EbcEqual -Expected $want -Actual $seen -What 'inserts after a transition while an award is lit'
}
Test-EbcItem -Name 'Collecting 100,000 awards 10,000 at 1x and every next-award lamp turns off' -Doc "$Doc; $Hole" -Body {
    $seen = "score $($c1.Score), announcements [$($c1.Announce)], inserts $($c1.Inserts), earned $($c1.Earned)x"
    Assert-EbcEqual -Expected "score $Award100K, announcements [], inserts dark, earned 5x" -Actual $seen -What 'the first 100,000'
}
Test-EbcItem -Name 'The first qualifying transition blinks 7x+100,000 (2x+5x+100,000 lamps) while bonus remains 5x; its collection earns 7x and darkens the combination' -Doc "$Doc; $Hole" -Body {
    $seen = "$($t7.What): $($t7.Inserts), earned $($t7.Earned)x; collected: score $($c7.Score), inserts $($c7.Inserts), earned $($c7.Earned)x"
    $want = "$($t7.What): $(Want-Inserts 7), earned 5x; collected: score $Award100K, inserts dark, earned 7x"
    Assert-EbcEqual -Expected $want -Actual $seen -What '7x + 100,000'
}
Test-EbcItem -Name 'The next transition blinks 8x+100,000 (3x+5x+100,000), and the following one blinks 10x+100,000 (2x+3x+5x+100,000); collecting that award earns 10x and darkens it' -Doc "$Doc; $Hole" -Body {
    # The 8x award is collected by the 8-ball's saucer hit, which also
    # scores the rack, so only its lamps and multiplier are compared.
    $seen = @("$($t8.What): $($t8.Inserts), earned $($t8.Earned)x", "collected by the 8-ball: inserts $($c8.Inserts), earned $($c8.Earned)x",
              "$($t10.What): $($t10.Inserts), earned $($t10.Earned)x", "collected: score $($c10.Score), inserts $($c10.Inserts), earned $($c10.Earned)x")
    $want = @("$($t8.What): $(Want-Inserts 8), earned 7x", 'collected by the 8-ball: inserts dark, earned 8x',
              "$($t10.What): $(Want-Inserts 10), earned 8x", "collected: score $Award100K, inserts dark, earned 10x")
    Assert-EbcEqual -Expected $want -Actual $seen -What '8x and 10x + 100,000'
}
Test-EbcItem -Name 'After 10x, every later transition blinks only 100,000 and every collection darkens it again' -Doc "$Doc; $Hole" -Body {
    $seen = @("$($t100.What): $($t100.Inserts)", "collected: score $($c100.Score), inserts $($c100.Inserts), earned $($c100.Earned)x",
              "$($t100c.What): $($t100c.Inserts)", "collected: score $($c100b.Score), inserts $($c100b.Inserts), earned $($c100b.Earned)x")
    $want = @("$($t100.What): $(Want-Inserts 100)", "collected: score $Award100K, inserts dark, earned 10x", "$($t100c.What): $(Want-Inserts 100)", "collected: score $Award100K, inserts dark, earned 10x")
    Assert-EbcEqual -Expected $want -Actual $seen -What '100,000 after 10x'
}
Test-EbcItem -Name 'Either active orbit -> spinner inactive or the first active-spinner pulse -> orbit inactive can relight it' -Doc "$Doc; $Hole" -Body {
    $seen = @($t7, $t8, $t10, $t100, $t100c | ForEach-Object { "$($_.What): lit $($_.Inserts -ne 'dark')" } | Select-Object -Unique)
    $want = @('after an orbit collect: lit True', 'after a first spinner pulse: lit True')
    Assert-EbcEqual -Expected $want -Actual $seen -What 'transitions that relit an award'
}
Test-EbcItem -Name 'At every stage a dark saucer hit gives no 5x announcement, scores only its ordinary value, and does not advance' -Doc "$Doc; $Hole" -Body {
    # The ordinary value is what the 2x step hit scored (the original D07A
    # step path awards the saucer's own value before advancing).
    $prev = @($c1, $c7, $c8, $c10, $c100)
    $seen = @(0..4 | ForEach-Object { $d = @($d1, $d2, $d3, $d4, $d5)[$_]; "dark hit after earning $($prev[$_].Earned)x: score $($d.Score), announcements [$($d.Announce)], inserts $($d.Inserts), earned $($d.Earned)x" })
    $want = @(0..4 | ForEach-Object { "dark hit after earning $($prev[$_].Earned)x: score $($h2.Score), announcements [], inserts dark, earned $($prev[$_].Earned)x" })
    Assert-EbcEqual -Expected $want -Actual $seen -What 'dark saucer hits'
}
Complete-EbcTests
