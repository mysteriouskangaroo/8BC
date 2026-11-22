# Helpers for the Eight Ball Champ game tests (tests/**/*.tests.ps1), on the
# lockstep machine in tools/LibPinmameMachine.ps1 and the name table in
# tools/GameNames.psd1. A test file begins with
#   param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
#   Import-Module <repo>/tools/GameTest.psm1
# prints one line per test through Test-EbcItem,
#   PASS|FAIL <tree>/<file> :: <test name>[ [seeded]][ :: <detail>]
# and ends with Complete-EbcTests, which exits 1 when any test failed.
# Every count here is in frames; wall-clock limits are hang guards only.

$ErrorActionPreference = 'Stop'
$script:Repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'LibPinmameMachine.ps1')
$script:MachineWriteRam = ${function:Write-EbcRam}
$script:Names = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'GameNames.psd1')
if (-not ('EbcPrivateDirCleanup' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
public static class EbcPrivateDirCleanup {
    public static void Register(string dir) {
        AppDomain.CurrentDomain.ProcessExit += delegate {
            try { if (Directory.Exists(dir)) Directory.Delete(dir, true); } catch { }
        };
    }
}
'@
}

$script:Passed = 0
$script:Failed = 0
$script:CurrentDoc = ''
$script:Label = $null
$script:Tree = ''
$script:PrivateDir = $null
$script:Observations = [Collections.Generic.List[string]]::new()
$script:ObserveTo = ''
# RAM-write bookkeeping for the seeded label: every Write-EbcRam call counts;
# a call outside a test item seeds the state of every later item.
$script:RamWrites = 0
$script:InItem = $false
$script:SeededState = $false
# A compare child runs only the scenario its parent names.
$script:ChildScenario = $env:EBC_SCENARIO

# ---------------------------------------------------------------- results

function Get-CallerValue([System.Management.Automation.PSCmdlet]$Cmdlet, [string]$Name) {
    $Cmdlet.SessionState.PSVariable.GetValue($Name)
}

# "<tree>/<file>" for the calling test file ("<file>" when it has no tree).
function Get-ResultLabel([System.Management.Automation.PSCmdlet]$Cmdlet) {
    if ($null -ne $script:Label) { return $script:Label }
    # Test bodies run in the test file's scope; make its errors terminating so
    # Test-EbcItem catches them as failures.
    $Cmdlet.SessionState.PSVariable.Set('ErrorActionPreference', 'Stop')
    $path = $Cmdlet.MyInvocation.PSCommandPath
    $file = if ($path) { (Split-Path -Leaf $path) -replace '\.tests\.ps1$', '' -replace '\.ps1$', '' } else { 'interactive' }
    $tree = Get-CallerValue $Cmdlet 'Tree'
    if ($tree) { $script:Tree = $tree }
    $script:Label = if ($script:Tree) { "$($script:Tree)/$file" } else { $file }
    $script:Label
}

function Format-EbcValue($Value) {
    if ($null -eq $Value) { return '(null)' }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) { return '[' + ((@($Value) | ForEach-Object { Format-EbcValue $_ }) -join ', ') + ']' }
    "$Value"
}

# Runs one test: prints PASS, or FAIL with the exception text, and records a
# failure for Complete-EbcTests. -Seeded marks a test that wrote RAM to reach
# its state; the label is printed whether it passes or fails. An item that
# called Write-EbcRam, or follows a Write-EbcRam call made outside any item,
# FAILs unless it is -Seeded.
function Test-EbcItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Doc,
        [switch]$Seeded,
        [Parameter(Mandatory = $true)][scriptblock]$Body
    )
    $label = Get-ResultLabel $PSCmdlet
    if ($script:ObserveTo) { return }   # a compare child prints no results
    $tag = if ($Seeded) { ' [seeded]' } else { '' }
    $script:CurrentDoc = $Doc
    $writesBefore = $script:RamWrites
    $script:InItem = $true
    $msg = $null
    try { & $Body | Out-Null }
    catch { $msg = ($_.Exception.Message -replace '\s*\r?\n\s*', ' ').Trim() }
    finally { $script:InItem = $false; $script:CurrentDoc = '' }
    if (-not $Seeded -and ($script:SeededState -or $script:RamWrites -gt $writesBefore)) {
        $rule = 'wrote RAM without -Seeded (Write-EbcRam ' + $(if ($script:RamWrites -gt $writesBefore) { 'in this item' } else { 'before this item, outside any item' }) + ')'
        $msg = if ($msg) { "$rule; $msg" } else { $rule }
    }
    if ($null -eq $msg) {
        $script:Passed++
        Write-Output "PASS $label :: $Name$tag"
    }
    else {
        $script:Failed++
        Write-Output "FAIL $label :: $Name$tag :: $msg"
    }
}

function Assert-EbcEqual {
    param([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()]$Expected,
          [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()]$Actual,
          [Parameter(Mandatory = $true)][string]$What)
    $e = Format-EbcValue $Expected; $a = Format-EbcValue $Actual
    if ($e -cne $a) { throw "${What}: expected $e, actual $a ($($script:CurrentDoc))" }
}

function Assert-EbcTrue {
    param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][AllowEmptyString()][string]$What)
    if (-not $Condition) { throw "$What ($($script:CurrentDoc))" }
}

# Stops the machine, deletes this process's private folder, and exits 1 when
# any test failed (or none ran).
function Complete-EbcTests {
    [CmdletBinding()] param()
    $label = Get-ResultLabel $PSCmdlet
    Stop-EbcGame
    if ($script:ObserveTo) {
        [Console]::Error.WriteLine("compare child: no scenario named '$($script:ChildScenario)' in $label")
        exit 1
    }
    if ($script:Passed + $script:Failed -eq 0) {
        Write-Output "FAIL $label :: (file) :: no test ran"
        exit 1
    }
    if ($script:Failed -gt 0) { exit 1 }
    exit 0
}

# ---------------------------------------------------------------- machine

function New-EbcPrivateDir {
    $root = if ($env:EBC_PRIVATE_DIR) { $env:EBC_PRIVATE_DIR } else { [IO.Path]::GetTempPath() }
    $dir = Join-Path $root ('ebc-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $dir
}

# Copies the tree's packaged zip to a private VPM folder and boots it.
# -Tree and -VpmZip default to the calling file's $Tree and $VpmZip. Switch 8
# (Outhole) closes at frame 0, the ball resting in the outhole, unless
# -EmptyOuthole; the machine then runs -AttractFrames frames (coin, credit and
# self-test respond by frame 1500; names.tests.ps1).
function Start-EbcGame {
    [CmdletBinding()]
    param([string]$Tree, [string]$VpmZip, [ValidateRange(0, 100000)][int]$AttractFrames = 1500, [switch]$EmptyOuthole)
    if (-not $Tree) { $Tree = Get-CallerValue $PSCmdlet 'Tree' }
    if (-not $VpmZip) { $VpmZip = Get-CallerValue $PSCmdlet 'VpmZip' }
    if (-not $VpmZip -and $Tree) { $VpmZip = Join-Path $script:Repo "src/$Tree/build/game-tests/eballchp.zip" }
    if (-not $VpmZip -or -not (Test-Path -LiteralPath $VpmZip -PathType Leaf)) { throw "Start-EbcGame: no zip at '$VpmZip' (run tools/Invoke-GameTests.ps1, or pass -VpmZip)." }
    if ($Tree) { $script:Tree = $Tree }
    $null = Get-ResultLabel $PSCmdlet
    $dir = New-EbcPrivateDir
    try {
        New-Item -ItemType Directory -Path (Join-Path $dir 'roms') | Out-Null
        Copy-Item -LiteralPath $VpmZip -Destination (Join-Path $dir 'roms/eballchp.zip')
        $library = & (Join-Path $script:Repo 'tools/Get-LibPinmame.ps1')
        Start-EbcMachine -LibraryPath $library -VpmPath $dir
    }
    catch { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue; throw }
    $script:PrivateDir = $dir
    # A file that throws before Complete-EbcTests still removes its folder
    # (the runner also deletes each process's folder).
    # PowerShell.Exiting does not fire for a -File script ended by a throw, so
    # this uses .NET ProcessExit, after the machine's own Stop handler
    # (registered first, in Start).
    [EbcPrivateDirCleanup]::Register($dir)
    if (-not $EmptyOuthole) { Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $true }
    if ($AttractFrames -gt 0) { Step-EbcFrames -Frames $AttractFrames }
}

# Stops the machine and deletes the private folder (safe to call twice).
function Stop-EbcGame {
    if ('EightBallChampMachine' -as [type]) { try { Stop-EbcMachine } catch { [Console]::Error.WriteLine("Stop: $($_.Exception.Message)") } }
    if ($script:PrivateDir) { Remove-Item -LiteralPath $script:PrivateDir -Recurse -Force -ErrorAction SilentlyContinue; $script:PrivateDir = $null }
}

function Get-EbcFrame { [EightBallChampMachine]::Frame }
function Get-EbcEventCount { [EightBallChampMachine]::EventCount }

# ---------------------------------------------------------------- names

function Get-EbcNames { $script:Names }
function Get-EbcName([string]$Table, [string]$Name) {
    $t = $script:Names[$Table]
    if ($null -eq $t -or -not $t.ContainsKey($Name)) { throw "GameNames.psd1 $Table has no entry '$Name'." }
    $t[$Name]
}
function Get-EbcSwitch([Parameter(Mandatory = $true)][string]$Name) { Get-EbcName 'Switches' $Name }
function Get-EbcSolenoid([Parameter(Mandatory = $true)][string]$Name) { Get-EbcName 'Solenoids' $Name }
function Get-EbcLampNumber([Parameter(Mandatory = $true)][string]$Name) { Get-EbcName 'Lamps' $Name }
function Get-EbcRamAddress([Parameter(Mandatory = $true)][string]$Name) { Get-EbcName 'Ram' $Name }
function Get-EbcServiceKey([Parameter(Mandatory = $true)][string]$Name) { Get-EbcName 'ServiceKeys' $Name }

# ---------------------------------------------------------------- switches

# A switch name from GameNames.psd1 Switches, or a libpinmame switch number.
function Resolve-EbcSwitch($Switch) {
    if ($Switch -is [int]) { return $Switch }
    $n = 0
    if ([int]::TryParse([string]$Switch, [ref]$n)) { return $n }
    Get-EbcSwitch ([string]$Switch)
}

# Closes the switch for -CloseFrames, then opens it for -OpenFrames, -Count
# times. 4 and 8 frames are well above the 1-frame closure and gap the ROM
# accepts (GameNames.psd1 SwitchMinCloseFrames/SwitchMinOpenFrames).
function Invoke-EbcSwitchHit {
    param([Parameter(Mandatory = $true, Position = 0)]$Name,
          [ValidateRange(1, 1000)][int]$Count = 1,
          [ValidateRange(1, 1000)][int]$CloseFrames = 4,
          [ValidateRange(1, 1000)][int]$OpenFrames = 8)
    $n = Resolve-EbcSwitch $Name
    for ($k = 0; $k -lt $Count; $k++) {
        Set-EbcSwitch -Number $n -Closed $true; Step-EbcFrames -Frames $CloseFrames
        Set-EbcSwitch -Number $n -Closed $false; Step-EbcFrames -Frames $OpenFrames
    }
}

# ---------------------------------------------------------------- reads

function Read-EbcByte([int]$Address) { (Read-EbcRam -Address $Address -Count 1)[0] }
function ConvertFrom-EbcDigitByte([byte]$b) { $d = $b -shr 4; if ($d -gt 9) { $null } else { $d } }

# Text of a display, without commas and spaces.
function Get-EbcDisplayText([Parameter(Mandatory = $true)][int]$Index) { ((Get-EbcDisplay -Index $Index) -replace '[ ,]', '') }

# Seven digit bytes, ones first, digit in the high nibble, F = blank.
function Get-EbcScoreBufferText([int]$Address) {
    $b = Read-EbcRam -Address $Address -Count 7
    $s = ''; for ($k = 6; $k -ge 0; $k--) { $d = ConvertFrom-EbcDigitByte $b[$k]; $s += $(if ($null -eq $d) { ' ' } else { [string]$d }) }
    $s.Trim()
}

# The player's score from its RAM display buffer, cross-checked against the
# player's display; throws when they disagree (a blank, blinking display
# disagrees too, so read scores during play).
function Get-EbcScore {
    param([Parameter(Mandatory = $true)][ValidateRange(1, 4)][int]$Player)
    $buf = Get-EbcScoreBufferText (Get-EbcRamAddress "ScoreBuffer$Player")
    $shown = Get-EbcDisplayText $script:Names.Displays["Player$Player"]
    if ($buf -ne $shown) { throw "Player $Player score: RAM buffer '$buf' but display shows '$shown' at frame $(Get-EbcFrame)." }
    if ($buf -eq '') { return 0 }
    [long]$buf
}

# Credits: two digit bytes, ones first (GameNames.psd1 Ram.Credits).
function Get-EbcCredits {
    $b = Read-EbcRam -Address (Get-EbcRamAddress 'Credits') -Count 2
    $t = ConvertFrom-EbcDigitByte $b[1]; $o = ConvertFrom-EbcDigitByte $b[0]
    10 * [int]$t + [int]$o
}
function Get-EbcMasked([string]$Name) {
    $mask = $script:Names.RamMasks[$Name]
    $v = (Read-EbcByte (Get-EbcRamAddress $Name)) -band $mask
    while ($mask -and -not ($mask -band 1)) { $mask = $mask -shr 1; $v = $v -shr 1 }
    $v
}
function Get-EbcBallInPlay { Get-EbcMasked 'BallInPlay' }
function Get-EbcPlayerCount { Get-EbcMasked 'PlayerCount' }
function Get-EbcCurrentPlayer { Read-EbcByte (Get-EbcRamAddress 'CurrentPlayer') }
function Test-EbcGameOver { (Get-EbcMasked 'GameOver') -ne 0 }
# CHAMP completion state (10C0), the authoritative double/triple state.
function Get-EbcChampState { Read-EbcByte (Get-EbcRamAddress 'CHAMP_COMPLETION_STATE') }
# Sunk pool balls 1-7 (10C3).
function Get-EbcSunkBalls { Read-EbcByte (Get-EbcRamAddress 'SUNK_POOL_BALLS_1_TO_7') }

# ---------------------------------------------------------------- game flow

# Drops -Count coins in Coin I (Left); returns the credits afterwards.
function Add-EbcCredit {
    param([ValidateRange(1, 99)][int]$Count = 1)
    Invoke-EbcSwitchHit 'Coin I (Left)' -Count $Count
    Step-EbcFrames -Frames 60
    Get-EbcCredits
}

# Steps until the Outhole solenoid fires (an event at or after event index
# -Since), then opens switch 8: the ball has left the outhole. Returns the
# frame of the serve; throws after -MaxFrames.
function Wait-EbcBallServed {
    param([int]$Since = -1, [ValidateRange(1, 100000)][int]$MaxFrames = 3000)
    $sol = Get-EbcSolenoid 'Outhole'
    $pattern = "^\d+ sol $sol 1$"
    $f = -1
    if ($Since -ge 0) {
        $hit = @(Get-EbcEvents -Since $Since | Where-Object { $_ -match $pattern } | Select-Object -First 1)
        if ($hit.Count) { $f = [int]($hit[0] -split ' ')[0] }
    }
    if ($f -lt 0) { $f = Wait-EbcEvent -Prefix "sol $sol 1" -MaxFrames $MaxFrames }
    Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $false
    $f
}

# Starts a game: presses Credit and waits for the first serve, then adds each
# further player with Credit. The ROM ignores Credit for a while after the
# serve (measured: a press at the serve frame is lost, one about 70 frames
# later is taken), so each extra player is pressed for, 60 frames apart, until
# the player count rises (at most 10 presses each). Returns the serve frame and
# the Credit presses used, so tests can assert the exact count.
function Start-EbcPlay {
    param([ValidateRange(1, 4)][int]$Players = 1)
    $seen = Get-EbcEventCount
    Invoke-EbcSwitchHit 'Credit'
    $serve = Wait-EbcBallServed -Since $seen
    $presses = 1
    for ($p = 2; $p -le $Players; $p++) {
        $added = $false
        for ($try = 0; $try -lt 10 -and -not $added; $try++) {
            Invoke-EbcSwitchHit 'Credit'; $presses++
            for ($w = 0; $w -lt 48; $w++) { if ((Get-EbcPlayerCount) -ge $p) { $added = $true; break }; Step-EbcFrames -Frames 1 }
        }
        if (-not $added) { throw "Start-EbcPlay: player count $(Get-EbcPlayerCount) after 10 Credit presses for player $p (credits $(Get-EbcCredits))." }
    }
    [PSCustomObject]@{ ServeFrame = $serve; CreditPresses = $presses }
}

# The ball drains: closes switch 8, then steps until the next serve (the
# bonus count runs first) or game over. Returns 'Served' (switch 8 open again)
# or 'GameOver'. A ball whose score has not posted is served again (measured:
# a hit in the first 60-100 frames after a serve posts its score later, and a
# drain before that re-serves the same ball).
function Invoke-EbcDrain {
    param([ValidateRange(1, 100000)][int]$MaxFrames = 6000)
    $sol = Get-EbcSolenoid 'Outhole'
    $seen = Get-EbcEventCount
    $start = Get-EbcFrame
    Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $true
    for ($k = 0; $k -lt $MaxFrames; $k++) {
        Step-EbcFrames -Frames 1
        if (@(Get-EbcEvents -Since $seen | Where-Object { $_ -match "^\d+ sol $sol 1$" }).Count) {
            Set-EbcSwitch -Number (Get-EbcSwitch 'Outhole') -Closed $false
            return 'Served'
        }
        if (Test-EbcGameOver) { return 'GameOver' }
    }
    throw "Invoke-EbcDrain: no serve and no game over within $MaxFrames frames of frame $start."
}

# Plays out the game: on each ball, lets the ball travel 30 frames from the
# serve (measured: Rebound closed on the serve frame never scores, one frame
# later it does), hits -Switch, waits (up to 600 frames) for the current
# player's score to change so the ball counts, and drains, until game over.
# Returns the number of balls drained.
function Complete-EbcGame {
    param($Switch = 'Rebound', [ValidateRange(1, 100)][int]$MaxBalls = 40)
    for ($balls = 1; $balls -le $MaxBalls; $balls++) {
        Step-EbcFrames -Frames 30
        $addr = Get-EbcRamAddress ("ScoreBuffer{0}" -f (Get-EbcCurrentPlayer))
        $before = Get-EbcScoreBufferText $addr
        Invoke-EbcSwitchHit $Switch
        $w = 0
        while ((Get-EbcScoreBufferText $addr) -eq $before) {
            if (++$w -gt 600) { throw "Complete-EbcGame: ball $balls, '$Switch' did not change the score '$before' within 600 frames." }
            Step-EbcFrames -Frames 1
        }
        if ((Invoke-EbcDrain) -eq 'GameOver') { return $balls }
    }
    throw "Complete-EbcGame: no game over after $MaxBalls balls."
}

# ---------------------------------------------------------------- service mode

# Presses the self-test switch (4 frames) and steps until $Until holds, up to
# 400 frames per press and -MaxPresses presses. The ROM can miss a press,
# deterministically by press frame (names.tests.ps1: one press at frame 2100
# misses every run). Returns the number of presses used, or -1.
function Invoke-EbcSelfTestPress {
    param([Parameter(Mandatory = $true)][scriptblock]$Until, [ValidateRange(1, 20)][int]$MaxPresses = 5)
    for ($try = 1; $try -le $MaxPresses; $try++) {
        Set-EbcSwitch -Number $script:Names.SelfTestSwitch -Closed $true; Step-EbcFrames -Frames 4
        Set-EbcSwitch -Number $script:Names.SelfTestSwitch -Closed $false
        for ($w = 0; $w -lt 400; $w++) { if (& $Until) { return $try }; Step-EbcFrames -Frames 1 }
    }
    -1
}

function Get-EbcStatusText { Get-EbcDisplayText $script:Names.Displays.Status }

# Enters keypad mode (manual p. 1-3: one self-test press with no keypad
# switch closed shows 00 on the match/credit display). Returns the presses used.
function Enter-EbcServiceMode {
    $p = Invoke-EbcSelfTestPress -Until { (Get-EbcStatusText) -eq '00' }
    if ($p -lt 0) { throw "Enter-EbcServiceMode: status display shows '$(Get-EbcStatusText)' after 5 self-test presses, expected '00'." }
    $p
}

function Invoke-EbcKey([Parameter(Mandatory = $true)][string]$Key) {
    $name = switch ($Key) {
        '0' { 'Zero' } '1' { 'One' } '2' { 'Two' } '3' { 'Three' } '4' { 'Four' }
        '5' { 'Five' } '6' { 'Six' } '7' { 'Seven' } '8' { 'Eight' } '9' { 'Nine' } default { $Key } }
    Invoke-EbcSwitchHit (Get-EbcServiceKey $name)
}

# Keypad entry (manual p. 1-3/1-4, measured in tests/kit/service.tests.ps1):
# the register number's digits then Enter show the number on the match/credit
# display and the value on Player 1; the value's digits (shown on Player 2)
# then Enter store it, and Player 1 shows it. Throws when a display disagrees.
# Returns the number of key presses.
function Set-EbcAdjustment {
    param([Parameter(Mandatory = $true)][ValidateRange(1, 99)][int]$Number,
          [Parameter(Mandatory = $true)][ValidateRange(0, 9999999)][long]$Value)
    $presses = 0
    $digits = '{0:D2}' -f $Number
    foreach ($c in $digits.ToCharArray()) { Invoke-EbcKey ([string]$c); $presses++ }
    Invoke-EbcKey 'Enter'; $presses++
    Step-EbcFrames -Frames 60
    $status = Get-EbcStatusText
    if ($status -ne $digits) { throw "Set-EbcAdjustment: status display '$status' after keying register $digits, expected '$digits'." }
    foreach ($c in ([string]$Value).ToCharArray()) { Invoke-EbcKey ([string]$c); $presses++ }
    Invoke-EbcKey 'Enter'; $presses++
    Step-EbcFrames -Frames 60
    $p1 = Get-EbcDisplayText $script:Names.Displays.Player1
    if ($p1 -eq '' -or [long]$p1 -ne $Value) { throw "Set-EbcAdjustment: register $digits shows '$p1' on Player 1 after entering $Value." }
    $presses
}

# Leaves service mode with Cancel: presses until the match/credit display
# stays blank for 60 frames (at most 5 presses), then runs to 300 frames after
# that press. Cancel restarts the ROM at E50D (PIA initialization); a coin is
# lost until about 212-232 frames after the press (measured). Returns the
# presses used.
function Exit-EbcServiceMode {
    for ($try = 1; $try -le 5; $try++) {
        $pressed = Get-EbcFrame
        Invoke-EbcSwitchHit (Get-EbcServiceKey 'Cancel')
        $blank = 0
        for ($w = 0; $w -lt 300 -and $blank -lt 60; $w++) {
            Step-EbcFrames -Frames 1
            if ((Get-EbcStatusText) -eq '') { $blank++ } else { $blank = 0 }
        }
        if ($blank -ge 60) {
            $left = $pressed + 300 - (Get-EbcFrame)
            if ($left -gt 0) { Step-EbcFrames -Frames $left }
            return $try
        }
    }
    throw "Exit-EbcServiceMode: status display still shows '$(Get-EbcStatusText)' after 5 Cancel presses."
}

# Leaves the solenoid test (92). Cancel is read only between pulses, and the
# test clears the strobe-0 events after each pulse's delay (ED6A-ED6D), so a
# press during the delay is lost. Presses Cancel (held 4 frames) until 200
# frames pass with no momentary pulse; returns the presses used, or -1.
function Exit-EbcSolenoidTest {
    for ($try = 1; $try -le 5; $try++) {
        $n = Get-EbcServiceKey 'Cancel'
        Set-EbcSwitch -Number $n -Closed $true; Step-EbcFrames -Frames 4; Set-EbcSwitch -Number $n -Closed $false
        $seen = Get-EbcEventCount
        Step-EbcFrames -Frames 200
        if (@(Get-EbcEvents -Since $seen | Where-Object { $_ -match '^\d+ sol ([1-9]|1[0-5]) 1$' }).Count -eq 0) { return $try }
    }
    -1
}

# ---------------------------------------------------------------- comparison

function Add-EbcObservation([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text) { $script:Observations.Add($Text) }

# Runs this test file twice as child processes, once per tree, each running
# only this scenario with -ObserveTo <json>; then compares the two observation
# lists (after -Normalize, which maps each line through $_) and prints one
# result line. In a child, runs the scenario (it calls Start-EbcGame when it
# needs a machine), writes the list and exits.
function Invoke-EbcComparedScenario {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Doc,
        [Parameter(Mandatory = $true)][ValidateCount(2, 2)][string[]]$Trees,
        [Parameter(Mandatory = $true)][scriptblock]$Scenario,
        [scriptblock]$Normalize = { $_ },
        # The scenario writes RAM to reach its state (see Test-EbcItem).
        [switch]$Seeded,
        [ValidateRange(10, 3600)][int]$TimeoutSeconds = 900
    )
    $observeTo = Get-CallerValue $PSCmdlet 'ObserveTo'
    if ($observeTo) {
        $script:ObserveTo = $observeTo
        if ($script:ChildScenario -ne $Name) { return }
        $script:Observations.Clear()
        $script:InItem = $true
        try { & $Scenario | Out-Null }
        catch { [Console]::Error.WriteLine("scenario '$Name' threw: $($_.Exception.Message)"); Stop-EbcGame; exit 1 }
        $wrote = $script:SeededState -or $script:RamWrites -gt 0
        ConvertTo-Json -InputObject ([PSCustomObject]@{ Observations = @($script:Observations); WroteRam = $wrote }) | Set-Content -LiteralPath $observeTo -Encoding utf8
        Stop-EbcGame
        exit 0
    }

    $label = Get-ResultLabel $PSCmdlet
    $tag = if ($Seeded) { ' [seeded]' } else { '' }
    $script:CurrentDoc = $Doc
    $script_ = $PSCmdlet.MyInvocation.PSCommandPath
    $work = New-EbcPrivateDir
    try {
        # Only zips the runner built and checked in this run (EBC_BUILT_TREES)
        # may boot; otherwise a stale src/<tree>/build/game-tests zip could.
        $builtTrees = @(([string]$env:EBC_BUILT_TREES) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $notBuilt = @($Trees | Where-Object { $_ -notin $builtTrees })
        if ($notBuilt.Count) { throw "tree $($notBuilt -join ', ') not built in this run (EBC_BUILT_TREES '$($env:EBC_BUILT_TREES)'); run the file through tools/Invoke-GameTests.ps1 with both trees selected" }
        $lists = @()
        $wroteRam = @()
        foreach ($t in $Trees) {
            $json = Join-Path $work ("{0}-{1}.json" -f $lists.Count, $t)
            $childDir = Join-Path $work ("child-{0}" -f $lists.Count)
            New-Item -ItemType Directory -Path $childDir | Out-Null
            $psi = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
            foreach ($a in @('-NoProfile', '-File', $script_, '-Tree', $t, '-VpmZip', (Join-Path $script:Repo "src/$t/build/game-tests/eballchp.zip"), '-ObserveTo', $json)) { $psi.ArgumentList.Add($a) }
            $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
            $psi.Environment['EBC_SCENARIO'] = $Name
            $psi.Environment['EBC_PRIVATE_DIR'] = $childDir
            $psi.Environment['NO_COLOR'] = '1'
            $p = [Diagnostics.Process]::Start($psi)
            $outTask = $p.StandardOutput.ReadToEndAsync(); $errTask = $p.StandardError.ReadToEndAsync()
            if (-not $p.WaitForExit($TimeoutSeconds * 1000)) { $p.Kill($true); throw "child for $t timed out after $TimeoutSeconds s" }
            $p.WaitForExit()
            $err = ($errTask.Result -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 3) -join ' / '
            if ($p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $json)) { throw "child for $t exited $($p.ExitCode) without observations: $err" }
            $obs = Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
            if ($obs.WroteRam) { $wroteRam += $t }
            $lists += , @(@($obs.Observations) | ForEach-Object -Process $Normalize | ForEach-Object { "$_" })
        }
        if ($wroteRam.Count -and -not $Seeded) { throw "scenario wrote RAM without -Seeded (Write-EbcRam in the $($wroteRam -join ' and ') child)" }
        $a = $lists[0]; $b = $lists[1]
        for ($k = 0; $k -lt [Math]::Max($a.Count, $b.Count); $k++) {
            $x = if ($k -lt $a.Count) { "'$($a[$k])'" } else { '(none)' }
            $y = if ($k -lt $b.Count) { "'$($b[$k])'" } else { '(none)' }
            if ($x -cne $y) { throw "observation $($k + 1) differs: $($Trees[0]) $x, $($Trees[1]) $y ($($a.Count) vs $($b.Count) observations) ($Doc)" }
        }
        if ($a.Count -eq 0) { throw "no observations ($Doc)" }
        $script:Passed++
        Write-Output "PASS $label :: $Name$tag"
    }
    catch {
        $script:Failed++
        Write-Output ("FAIL $label :: $Name$tag :: " + (($_.Exception.Message -replace '\s*\r?\n\s*', ' ').Trim()))
    }
    finally {
        $script:CurrentDoc = ''
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# The machine's Write-EbcRam, counted for the seeded label (see Test-EbcItem).
function Write-EbcRam {
    param([Parameter(Mandatory = $true)][int]$Address, [Parameter(Mandatory = $true)][byte[]]$Bytes)
    $script:RamWrites++
    if (-not $script:InItem) { $script:SeededState = $true }
    & $script:MachineWriteRam -Address $Address -Bytes $Bytes
}

Export-ModuleMember -Function @(
    'Test-EbcItem', 'Assert-EbcEqual', 'Assert-EbcTrue', 'Complete-EbcTests',
    'Start-EbcGame', 'Stop-EbcGame', 'Get-EbcFrame', 'Get-EbcEventCount',
    'Get-EbcNames', 'Get-EbcSwitch', 'Get-EbcSolenoid', 'Get-EbcLampNumber', 'Get-EbcRamAddress', 'Get-EbcServiceKey',
    'Invoke-EbcSwitchHit', 'Read-EbcByte', 'Get-EbcDisplayText', 'Get-EbcScoreBufferText',
    'Get-EbcScore', 'Get-EbcCredits', 'Get-EbcBallInPlay', 'Get-EbcPlayerCount', 'Get-EbcCurrentPlayer', 'Test-EbcGameOver',
    'Get-EbcChampState', 'Get-EbcSunkBalls',
    'Add-EbcCredit', 'Start-EbcPlay', 'Wait-EbcBallServed', 'Invoke-EbcDrain', 'Complete-EbcGame',
    'Invoke-EbcSelfTestPress', 'Get-EbcStatusText', 'Enter-EbcServiceMode', 'Invoke-EbcKey', 'Set-EbcAdjustment', 'Exit-EbcServiceMode', 'Exit-EbcSolenoidTest',
    'Add-EbcObservation', 'Invoke-EbcComparedScenario',
    # From tools/LibPinmameMachine.ps1
    'Start-EbcMachine', 'Stop-EbcMachine', 'Step-EbcFrames', 'Wait-EbcEvent', 'Set-EbcSwitch', 'Read-EbcRam', 'Write-EbcRam',
    'Get-EbcDisplay', 'Get-EbcLamp', 'Get-EbcEvents')
