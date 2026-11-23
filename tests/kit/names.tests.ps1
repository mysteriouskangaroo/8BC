# Tests for tools/GameNames.psd1, the switch, solenoid, lamp, sound and RAM
# name table the game tests use. Each test checks a table entry by play.
# Usage: pwsh tests/kit/names.tests.ps1 -Tree originals -VpmZip src/originals/build/game-tests/eballchp.zip
# Boots a private copy of the tree's packaged eballchp.zip; never writes src/*/roms/.

param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force
$ErrorActionPreference = 'Stop'
$N = Get-EbcNames

# ---- Expected values, copied from the documents they cite. ----

# HARDWARE_MAP.md "Page 1-18 switch assembly identification": all 37 numbers.
$ExpectedSwitches = [ordered]@{
    'Right Thumper Bumper' = 1; 'Left Thumper Bumper' = 2; 'Right Slingshot' = 3; 'Left Slingshot' = 4
    'Saucer' = 5; 'Credit' = 6; 'Rebound' = 7; 'Outhole' = 8
    'Coin III (Right)' = 9; 'Coin I (Left)' = 10; 'Coin II (Middle)' = 11; 'Left Rollover Button' = 12
    'Right Rollover Button' = 13; 'Not Used 14' = 14; 'Tilt' = 15; 'Slam' = 16
    '"C" Return Lane' = 17; '"H" Top Lane' = 18; '"A" Top Lane' = 19; '"M" Top Lane' = 20
    '"P" Return Lane' = 21; 'Not Used 22' = 22; 'Left Outlane' = 23; 'Right Outlane' = 24
    'Drop Target 1,2,9,10' = 25; 'Lane Change (Cabinet)' = 26; 'Drop Target 3,11' = 27; 'Drop Target 4,5,12,13' = 28
    'Center Rollover Button' = 29; 'Drop Target 6,14' = 30; 'Drop Target 7,15' = 31; 'Spinner' = 32
    'Drop Target "E"' = 33; 'Drop Target "I"' = 34; 'Drop Target "G"' = 35; 'Drop Target "H"' = 36; 'Drop Target "T"' = 37
}
# HARDWARE_MAP.md "Solenoid self-test outputs": tests 01-12 in page 1-18 order,
# with the U14 driver output M<n> of each.
$ExpectedSolenoidTests = @(
    @('Drop Target 1,2,9,10', 0), @('Drop Target 3,11', 1), @('Drop Target 4,5,12,13', 2), @('Drop Target 6,14', 3),
    @('Drop Target 7,15', 4), @('Saucer', 7), @('Right Thumper Bumper', 8), @('Left Thumper Bumper', 9),
    @('Right Slingshot', 10), @('Left Slingshot', 11), @('Outhole', 13), @('Knocker', 14))
# GAME_RULE_TRACES.md "Switch 07: Rebound": CA95 queues sound command 0x22.
$ExpectedReboundSound = 0x22
# HARDWARE_MAP.md "U4 RAM: dedicated player-score display buffers".
$ExpectedScoreBuffers = @(0x1046, 0x104D, 0x1054, 0x105B)
# HARDWARE_MAP.md "Solenoid self-test outputs": test 13 is K1, driven by the
# continuous output BF rather than U14.
$ExpectedK1Name = 'K1 Relay (Flipper Enable)'
# Factory settings (fresh NVRAM): Coin I gives 1 credit (F079 -> F08F with the
# Coin I setting at 1676, read FF FF from a fresh NVRAM; measured).
$ExpectedCreditsPerCoinI = 1
# The service entry shows test 00 on the status display (EBA3/EBB1 show 008D,
# which entry leaves at 00); the solenoid test is 92 (service table at EB70: 5C -> ED40).
$ExpectedFirstServiceTest = '00'
$ExpectedSolenoidTestNumber = '92'
# GAME_RULE_TRACES.md "Playfield Scores Double and Triple": each CHAMP lane
# (CAD4) awards 3,000. src/8bc-deluxe/gamerules.md: Deluxe divides playfield
# awards by ten, so the lane shows 300 there.
$ExpectedLaneCScore = if ($Tree -eq '8bc-deluxe') { '300' } else { '3000' }
# Self-test and Cancel presses this test's fixed schedule needs (measured;
# each press lands on a frame where the ROM accepts it, see
# Invoke-EbcSelfTestPress). The miss frames depend on the ROM image: on the
# originals and loop-score-change the press at frame 2100 misses (probe10:
# 1015 never set) and the next one enters; on 8bc-deluxe the first press
# enters and the press toward test 90 misses once (measured in Task 4).
$ExpectedServiceEntryPresses = if ($Tree -eq '8bc-deluxe') { 1 } else { 2 }
$ExpectedDiagnosticPresses = if ($Tree -eq '8bc-deluxe') { @(1, 2) } else { @(1, 1) }   # to reach 94, then 90
$ExpectedSolenoidCancelPresses = 3
# OPS manual lamp driver locations (PDF p. 61): BONUS 120,000 is J13-13 and
# BONUS 240,000 is J13-5, both phase B. pinmame src/wpc/by6803.c header:
# J13-13 = 29, J13-05 = 45, phase B = x + 48.
$ExpectedBonusLamps = [ordered]@{ 'Bonus 120,000' = 29 + 48; 'Bonus 240,000' = 45 + 48 }
# Same table: B, A, L, L of B-A-L-L are J10-18, J10-4, J10-11 and J10-19,
# phase B; by6803.c: J10-18 = 35, J10-04 = 4, J10-11 = 20, J10-19 = 36.
$ExpectedBallLamps = [ordered]@{ 'Ball "B"' = 35 + 48; 'Ball "A"' = 4 + 48; 'Ball "L" 1' = 20 + 48; 'Ball "L" 2' = 36 + 48 }
# Same table, second page (PDF p. 62): "5,000 DROP TARGET 3" is J13-10, phase
# A; by6803.c: J13-10 = 46, phase A unchanged.
$ExpectedDropTarget3Lamp = 46
# Same table, first page: DROP TARGET 1-7 and 9-15, all phase A, on the
# pins below; by6803.c converts each pin (phase A unchanged).
$ByPin = @{ 'J10-18' = 35; 'J10-4' = 4; 'J10-11' = 20; 'J10-19' = 36; 'J10-5' = 5; 'J10-12' = 21; 'J10-14' = 37
            'J10-10' = 22; 'J10-13' = 38; 'J11-8' = 7; 'J11-16' = 23; 'J11-6' = 39; 'J11-12' = 8; 'J11-11' = 24 }
$ExpectedNumberedLamps = [ordered]@{
    'Drop Target 1' = $ByPin['J10-18']; 'Drop Target 2' = $ByPin['J10-4']; 'Drop Target 3' = $ByPin['J10-11']
    'Drop Target 4' = $ByPin['J10-19']; 'Drop Target 5' = $ByPin['J10-5']; 'Drop Target 6' = $ByPin['J10-12']
    'Drop Target 7' = $ByPin['J10-14']; 'Drop Target 9' = $ByPin['J10-10']; 'Drop Target 10' = $ByPin['J10-13']
    'Drop Target 11' = $ByPin['J11-8']; 'Drop Target 12' = $ByPin['J11-16']; 'Drop Target 13' = $ByPin['J11-6']
    'Drop Target 14' = $ByPin['J11-12']; 'Drop Target 15' = $ByPin['J11-11'] }
# Zero-cross service ticks per second (E0FB: 1C20 = 7,200 per minute).
$TicksPerSecond = 120

# Same table: ROLLOVER LANES 10,000/20,000/30,000/40,000/SPECIAL on J12-4,
# J13-1, J13-8, J13-6, J13-2, all phase B; by6803.c: 43, 12, 28, 44, 13,
# phase B = x + 48.
$ExpectedOrbitLamps = [ordered]@{
    'Rollover Lanes 10,000' = 43 + 48; 'Rollover Lanes 20,000' = 12 + 48; 'Rollover Lanes 30,000' = 28 + 48
    'Rollover Lanes 40,000' = 44 + 48; 'Rollover Lanes Special' = 13 + 48 }
# Same table, second page: SPINNER 1,000/3,000/5,000 on J10-17, J10-3, J10-9,
# phase B; by6803.c: 34, 3, 19.
$ExpectedSpinnerLamps = [ordered]@{ 'Spinner 1,000' = 34 + 48; 'Spinner 3,000' = 3 + 48; 'Spinner 5,000' = 19 + 48 }
# Same table, first page: 'C'/'H'/'A'/'M'/'P' ROLLOVER on J10-1, J10-7,
# J10-16, J10-2, J10-8 and LEFT/RIGHT OUTLANE on J10-14/J10-6, phase B;
# by6803.c: 1, 17, 33, 2, 18, 37, 6.
$ExpectedChampLamps = [ordered]@{ '"C" Rollover' = 1 + 48; '"H" Rollover' = 17 + 48; '"A" Rollover' = 33 + 48; '"M" Rollover' = 2 + 48
                                  '"P" Rollover' = 18 + 48; 'Left Outlane' = 37 + 48; 'Right Outlane' = 6 + 48 }
# Same table: SAUCER 2X/3X/5X on J12-13, J12-7, J12-2 and 2X/3X/5X on J12-8,
# J12-3, J12-11, phase B; by6803.c: 9, 25, 41, 26, 42, 11. SAUCER 100K: wire
# code 73 is BONUS 4's line J11-14/J12-12 (by6803.c 10), not the printed
# J12-14 (GameNames.psd1 Lamps comment).
$ExpectedSaucerLamps = [ordered]@{ 'Saucer 2X' = 9 + 48; 'Saucer 3X' = 25 + 48; 'Saucer 5X' = 41 + 48; 'Saucer 100,000' = 10 + 48
                                   'Bonus Multiplier 2X' = 26 + 48; 'Bonus Multiplier 3X' = 42 + 48; 'Bonus Multiplier 5X' = 11 + 48 }

# ---- Pure table checks (no emulator). ----

$badSw = @(); foreach ($k in $ExpectedSwitches.Keys) { if ($N.Switches[$k] -ne $ExpectedSwitches[$k]) { $badSw += "$k=$($N.Switches[$k]) (expected $($ExpectedSwitches[$k]))" } }
Test-EbcItem -Name 'Switch numbers are page 1-18' -Doc 'HARDWARE_MAP.md page 1-18 switch table' -Body { Assert-EbcTrue ($badSw.Count -eq 0 -and $N.Switches.Count -eq 37) ("{0} entries; wrong: {1}" -f $N.Switches.Count, ($badSw -join '; ')) }
$badBuf = @(); for ($p = 1; $p -le 4; $p++) { if ($N.Ram["ScoreBuffer$p"] -ne $ExpectedScoreBuffers[$p - 1]) { $badBuf += "ScoreBuffer$p" } }
Test-EbcItem -Name 'Score buffers are HARDWARE_MAP addresses' -Doc 'HARDWARE_MAP.md score-display buffers' -Body { Assert-EbcTrue ($badBuf.Count -eq 0) ("wrong: " + ($badBuf -join ', ')) }
$badLamp = @(); foreach ($k in $ExpectedBonusLamps.Keys) { if ($N.Lamps[$k] -ne $ExpectedBonusLamps[$k]) { $badLamp += "$k=$($N.Lamps[$k]) (expected $($ExpectedBonusLamps[$k]))" } }
Test-EbcItem -Name 'Bonus lamps are J13-13 and J13-5 phase B' -Doc 'OPS manual lamp driver locations; pinmame by6803.c connector table' -Body { Assert-EbcTrue ($badLamp.Count -eq 0) ("wrong: " + ($badLamp -join '; ')) }
Test-EbcItem -Name 'B-A-L-L lamps are J10-18, J10-4, J10-11 and J10-19 phase B' -Doc 'OPS manual lamp driver locations; pinmame by6803.c connector table' -Body { Assert-EbcEqual -Expected @($ExpectedBallLamps.Values) -Actual @($ExpectedBallLamps.Keys | ForEach-Object { $N.Lamps[$_] }) -What "Lamps entries $($ExpectedBallLamps.Keys -join ', ')" }
Test-EbcItem -Name '5,000 drop target 3 lamp is J13-10 phase A' -Doc 'OPS manual lamp driver locations; pinmame by6803.c connector table' -Body { Assert-EbcEqual -Expected $ExpectedDropTarget3Lamp -Actual $N.Lamps['5,000 Drop Target 3'] -What 'Lamps entry 5,000 Drop Target 3' }
$badNum = @(); foreach ($k in $ExpectedNumberedLamps.Keys) { if ($N.Lamps[$k] -ne $ExpectedNumberedLamps[$k]) { $badNum += "$k=$($N.Lamps[$k]) (expected $($ExpectedNumberedLamps[$k]))" } }
Test-EbcItem -Name 'Numbered drop-target lamps are the manual''s J10/J11 phase A pins' -Doc 'OPS manual lamp driver locations; pinmame by6803.c connector table' -Body { Assert-EbcTrue ($badNum.Count -eq 0) ("wrong: " + ($badNum -join '; ')) }
$badOrbit = @(); foreach ($k in $ExpectedOrbitLamps.Keys) { if ($N.Lamps[$k] -ne $ExpectedOrbitLamps[$k]) { $badOrbit += "$k=$($N.Lamps[$k]) (expected $($ExpectedOrbitLamps[$k]))" } }
Test-EbcItem -Name 'Orbit-value lamps are the manual''s rollover lane pins, phase B' -Doc 'OPS manual lamp driver locations; pinmame by6803.c connector table' -Body { Assert-EbcTrue ($badOrbit.Count -eq 0) ("wrong: " + ($badOrbit -join '; ')) }
$badSpin = @(); foreach ($k in $ExpectedSpinnerLamps.Keys) { if ($N.Lamps[$k] -ne $ExpectedSpinnerLamps[$k]) { $badSpin += "$k=$($N.Lamps[$k]) (expected $($ExpectedSpinnerLamps[$k]))" } }
Test-EbcItem -Name 'Spinner value lamps are J10-17, J10-3 and J10-9 phase B' -Doc 'OPS manual lamp driver locations; pinmame by6803.c connector table' -Body { Assert-EbcTrue ($badSpin.Count -eq 0) ("wrong: " + ($badSpin -join '; ')) }
$badChamp = @(); foreach ($k in $ExpectedChampLamps.Keys) { if ($N.Lamps[$k] -ne $ExpectedChampLamps[$k]) { $badChamp += "$k=$($N.Lamps[$k]) (expected $($ExpectedChampLamps[$k]))" } }
Test-EbcItem -Name 'C-H-A-M-P and outlane lamps are J10 phase B pins' -Doc 'OPS manual lamp driver locations; pinmame by6803.c connector table' -Body { Assert-EbcTrue ($badChamp.Count -eq 0) ("wrong: " + ($badChamp -join '; ')) }
$badSaucer = @(); foreach ($k in $ExpectedSaucerLamps.Keys) { if ($N.Lamps[$k] -ne $ExpectedSaucerLamps[$k]) { $badSaucer += "$k=$($N.Lamps[$k]) (expected $($ExpectedSaucerLamps[$k]))" } }
Test-EbcItem -Name 'Saucer and bonus multiplier lamps are J12 phase B pins' -Doc 'OPS manual lamp driver locations; pinmame by6803.c connector table' -Body { Assert-EbcTrue ($badSaucer.Count -eq 0) ("wrong: " + ($badSaucer -join '; ')) }
Test-EbcItem -Name 'Rebound sound is 0x22' -Doc 'GAME_RULE_TRACES.md Switch 07: Rebound' -Body { Assert-EbcEqual -Expected $ExpectedReboundSound -Actual $N.Sounds.Rebound -What 'Sounds.Rebound' }

# ---- Play checks (one boot). ----

$AttractFrames = 1500   # coin, credit and self-test all respond by frame 1500 (measured)
function RamByte([int]$a) { (Read-EbcRam -Address $a -Count 1)[0] }
function Hold([int]$n, [int]$frames) { Set-EbcSwitch -Number $n -Closed $true; Step-EbcFrames -Frames $frames; Set-EbcSwitch -Number $n -Closed $false }
function Press([int]$n, [int]$settle) { Hold $n 4; Step-EbcFrames -Frames $settle }
function Digit([byte]$b) { $d = $b -shr 4; if ($d -gt 9) { 0 } else { $d } }
function CreditCount { $b = Read-EbcRam -Address $N.Ram.Credits -Count 2; 10 * (Digit $b[1]) + (Digit $b[0]) }
# Ones-first, displayed digit in the high nibble, F = blank.
function BufferText([int]$addr) {
    $b = Read-EbcRam -Address $addr -Count 7
    $s = ''; for ($k = 6; $k -ge 0; $k--) { $d = $b[$k] -shr 4; $s += $(if ($d -gt 9) { ' ' } else { [string]$d }) }
    $s.Trim()
}
function Shown([int]$index) { Get-EbcDisplayText -Index $index }
function SoundsSince([int]$seen) { @(Get-EbcEvents -Since $seen | Where-Object { ($_ -split ' ')[1] -eq 'snd' } | ForEach-Object { [int]($_ -split ' ')[3] }) }
function Hex($list) { ($list | ForEach-Object { '{0:X2}' -f $_ }) -join ',' }

# Outhole open at boot: the measured press counts below belong to this exact schedule.
Start-EbcGame -EmptyOuthole -AttractFrames $AttractFrames
try {
    & {
        # Frames per second: the zero-cross counter 100C falls once per tick.
        # Summed one frame at a time, so the byte's wraps are counted.
        $ticks = 0; $prev = RamByte 0x100C
        for ($k = 0; $k -lt 600; $k++) { Step-EbcFrames -Frames 1; $now = RamByte 0x100C; $ticks += (($prev - $now) % 256 + 256) % 256; $prev = $now }
        $expectTicks = 600 * $TicksPerSecond / $N.FramesPerSecond
        Test-EbcItem -Name 'Frames per second' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue ($ticks -eq $expectTicks) ("100C fell {0} ticks over 600 frames, expected {1} for {2} frames/s" -f $ticks, $expectTicks, $N.FramesPerSecond) }

        # Self-test switch enters service mode: the status display shows test 00.
        $before = Get-EbcDisplay -Index $N.Displays.Status
        $presses = Invoke-EbcSelfTestPress -Until { (Shown $N.Displays.Status) -eq $ExpectedFirstServiceTest }
        $testNo = Shown $N.Displays.Status
        Test-EbcItem -Name 'Self-test switch enters service mode' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue ($presses -eq $ExpectedServiceEntryPresses -and $testNo -eq $ExpectedFirstServiceTest) ("display {0} '{1}' (was '{2}') after {3} presses (expected {5}), expected '{4}'" -f $N.Displays.Status, $testNo, $before, $presses, $ExpectedFirstServiceTest, $ExpectedServiceEntryPresses) }
        Press $N.ServiceKeys.Cancel 300

        # Solenoid test order is page 1-18: hold Zero and press self-test (94),
        # self-test (90), Enter twice (92), then record 'sol <n> 1' events.
        Set-EbcSwitch -Number $N.ServiceKeys.Zero -Closed $true; Step-EbcFrames -Frames 4
        $p94 = Invoke-EbcSelfTestPress -Until { (Shown $N.Displays.Status) -eq '94' }
        Set-EbcSwitch -Number $N.ServiceKeys.Zero -Closed $false; Step-EbcFrames -Frames 60
        $p90 = Invoke-EbcSelfTestPress -Until { (Shown $N.Displays.Status) -eq '90' }
        Press $N.ServiceKeys.Enter 60
        $seen = [EightBallChampMachine]::EventCount
        Press $N.ServiceKeys.Enter 1000
        # The test number blinks, so look for it among the display events.
        $solTest = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ disp $($N.Displays.Status) " } | ForEach-Object { ($_ -split ' ', 4)[3] -replace '[ ,]', '' } | Where-Object { $_ -ne '' } | Select-Object -Unique) -join '/'
        $order = @(Get-EbcEvents -Since $seen | Where-Object { $_ -match '^\d+ sol \d+ 1$' } | ForEach-Object { [int]($_ -split ' ')[2] })
        $names = @($ExpectedSolenoidTests | ForEach-Object { $_[0] }) + $ExpectedK1Name
        $expectedOrder = @($names | ForEach-Object { $N.Solenoids[$_] })
        $firstCycle = @($order | Select-Object -First $expectedOrder.Count)
        Test-EbcItem -Name 'Solenoid test order is page 1-18' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue (($solTest -split '/') -contains $ExpectedSolenoidTestNumber -and $p94 -eq $ExpectedDiagnosticPresses[0] -and $p90 -eq $ExpectedDiagnosticPresses[1] -and ($firstCycle -join ',') -eq ($expectedOrder -join ',') -and $null -notin $expectedOrder) ("status display showed '{0}' (expected '{1}' among them; reached 94 in {4} and 90 in {5} self-test presses, expected {6} and {7}); pulsed {2}; expected {3}" -f $solTest, $ExpectedSolenoidTestNumber, ($order -join ','), ($expectedOrder -join ','), $p94, $p90, $ExpectedDiagnosticPresses[0], $ExpectedDiagnosticPresses[1]) }
        $badOff = @($ExpectedSolenoidTests | Where-Object { $N.Solenoids[$_[0]] -ne $_[1] + 1 } | ForEach-Object { "$($_[0])=$($N.Solenoids[$_[0]]) (M$($_[1]))" })
        Test-EbcItem -Name 'libpinmame solenoid is M+1' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue ($badOff.Count -eq 0) ("not M+1: " + ($badOff -join '; ')) }
        $cancels = Exit-EbcSolenoidTest
        Test-EbcItem -Name 'Cancel leaves the solenoid test' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue ($cancels -eq $ExpectedSolenoidCancelPresses) ("left after {0} Cancel presses (-1 = never), expected {1}" -f $cancels, $ExpectedSolenoidCancelPresses) }
        Step-EbcFrames -Frames 300

        # Coin adds a credit: closing Coin I (Left) for 4 frames adds the factory coinage.
        $c0 = CreditCount
        Press $N.Switches['Coin I (Left)'] 120
        $c1 = CreditCount
        Test-EbcItem -Name 'Coin adds a credit' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue ($c1 - $c0 -eq $ExpectedCreditsPerCoinI -and (Shown $N.Displays.Credits) -eq ('{0:D2}' -f $c1)) ("Credits {0} -> {1}, expected +{2}; credit display '{3}'" -f $c0, $c1, $ExpectedCreditsPerCoinI, (Shown $N.Displays.Credits)) }

        # Start sets players: Credit with credits > 0 gives one player on ball 1.
        $overAttract = (RamByte $N.Ram.GameOver) -band $N.RamMasks.GameOver
        $seen = [EightBallChampMachine]::EventCount
        Press $N.Switches.Credit 300
        $b8e = RamByte $N.Ram.PlayerCount
        $pc = $b8e -band $N.RamMasks.PlayerCount
        $bip = ((RamByte $N.Ram.BallInPlay) -band $N.RamMasks.BallInPlay) -shr 4
        $cur = RamByte $N.Ram.CurrentPlayer
        $over = (RamByte $N.Ram.GameOver) -band $N.RamMasks.GameOver
        $snd = SoundsSince $seen
        Test-EbcItem -Name 'Start sets players' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue ($pc -eq 1 -and $bip -eq 1 -and $cur -eq 1 -and $overAttract -ne 0 -and $over -eq 0 -and ($snd -contains $N.Sounds.RackTheBalls) -and (Shown $N.Displays.Status) -eq '1') ("PlayerCount {0}, BallInPlay {1}, CurrentPlayer {2}, GameOver bit {3:X2} (attract {7:X2}), status display '{4}', sounds {5}; expected 1, 1, 1, 00 (attract nonzero), '1', with {6:X2} among the sounds" -f $pc, $bip, $cur, $over, (Shown $N.Displays.Status), (Hex $snd), $N.Sounds.RackTheBalls, $overAttract) }

        # Score buffers match display: after a scored switch, ScoreBuffer1 reads as display 1's text.
        Press $N.Switches['"C" Return Lane'] 120
        $buf = BufferText $N.Ram.ScoreBuffer1
        $shown = Shown $N.Displays.Player1
        Test-EbcItem -Name 'Score buffers match display' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue ($buf -eq $ExpectedLaneCScore -and $shown -eq $ExpectedLaneCScore) ("ScoreBuffer1 '{0}', display {1} '{2}', expected '{3}'" -f $buf, $N.Displays.Player1, $shown, $ExpectedLaneCScore) }

        # Rebound queues its sound command.
        $seen = [EightBallChampMachine]::EventCount
        Press $N.Switches.Rebound 30
        $snd = SoundsSince $seen
        Test-EbcItem -Name 'Rebound sound reaches the sound board' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue (@($snd | Where-Object { $_ -eq $ExpectedReboundSound }).Count -eq 1) ("sound events after Rebound: " + (Hex $snd)) }

        # Switch debounce: the shortest closure and gap each register.
        $seen = [EightBallChampMachine]::EventCount
        Hold $N.Switches.Rebound $N.SwitchMinCloseFrames
        Step-EbcFrames -Frames $N.SwitchMinOpenFrames
        Hold $N.Switches.Rebound $N.SwitchMinCloseFrames
        Step-EbcFrames -Frames 30
        $snd = SoundsSince $seen
        $hits = @($snd | Where-Object { $_ -eq $ExpectedReboundSound }).Count
        Test-EbcItem -Name 'Switch debounce' -Doc 'tools/GameNames.psd1' -Body { Assert-EbcTrue ($hits -eq 2) ("Rebound closed {0}, open {1}, closed {0}: {2} x {3:X2}, expected 2; sounds {4}" -f $N.SwitchMinCloseFrames, $N.SwitchMinOpenFrames, $hits, $ExpectedReboundSound, (Hex $snd)) }
    }
}
finally { Stop-EbcGame }
Complete-EbcTests
