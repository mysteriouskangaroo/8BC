# Tests for tools/LibPinmameMachine.ps1, the lockstep libpinmame machine.
# Usage: pwsh tests/kit/machine.tests.ps1 -Tree originals [-VpmZip <path>]
# Boots a private copy of the tree's packaged eballchp.zip; never writes src/*/roms/.
# -ChildMode/-OutFile are internal: the script re-invokes itself in a new pwsh
# for the tests that need a second, independent boot.

param(
    [Parameter(Mandatory = $true)][string]$Tree,
    [string]$VpmZip,
    [ValidateSet('', 'Deterministic', 'ThrowWhilePaused', 'HangGuard')][string]$ChildMode = '',
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $VpmZip) { $VpmZip = Join-Path $repo 'VisualPinballX/VPinMAME/roms/eballchp.zip' }
$VpmZip = (Resolve-Path -LiteralPath $VpmZip).Path

# Temporary result printer, until the helper module provides one.
$script:failed = 0
function Write-Result([string]$Name, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) { Write-Output "PASS kit/machine :: $Name" }
    else { $script:failed++; Write-Output "FAIL kit/machine :: $Name :: $Detail" }
}

$machineScript = Join-Path $repo 'tools/LibPinmameMachine.ps1'
if (-not (Test-Path -LiteralPath $machineScript)) {
    Write-Result 'setup' $false 'tools/LibPinmameMachine.ps1 does not exist'
    exit 1
}
. $machineScript
$library = & (Join-Path $repo 'tools/Get-LibPinmame.ps1')

# U4 byte for the RAM-write test. No U4 byte stays $FF through 1,500 frames:
# U4 powers on all $FF and the startup RAM test writes every byte of
# $1000-$17FF between frames 124 and 324. $17FE reads $FF on every frame
# 330-1500 of the standard run (measured with this machine at commit 99f349a)
# and no ROM operand names it (the stack is LDS #$FF, internal RAM). The test
# writes it at frame 1500, after the RAM test.
$UnusedU4 = 0x17FE

# The standard run, identical in parent and Deterministic child: close switch 8
# (outhole) at frame 0, step 1,000 single frames, then 500 at once. Returns
# $102C at frame 400, whether $UnusedU4 read $FF on every stepped frame from
# 330 on, and the first event a single step added with a stamp other than the
# new Frame (events must be stamped with the first Frame they are visible at).
function Invoke-StandardRun {
    Set-EbcSwitch -Number 8 -Closed $true
    $at400 = -1; $unusedStayedFF = $true; $badStamp = $null
    $seen = [EightBallChampMachine]::EventCount
    for ($k = 0; $k -lt 1000; $k++) {
        Step-EbcFrames -Frames 1
        $f = [EightBallChampMachine]::Frame
        foreach ($e in (Get-EbcEvents -Since $seen)) {
            if ($null -eq $badStamp -and [int]($e -split ' ', 2)[0] -ne $f) { $badStamp = "'$e' visible first at Frame $f" }
        }
        $seen = [EightBallChampMachine]::EventCount
        if ($f -eq 400) { $at400 = (Read-EbcRam -Address 0x102C -Count 1)[0] }
        if ($f -ge 330 -and (Read-EbcRam -Address $UnusedU4 -Count 1)[0] -ne 0xFF) { $unusedStayedFF = $false }
    }
    Step-EbcFrames -Frames 500
    if ((Read-EbcRam -Address $UnusedU4 -Count 1)[0] -ne 0xFF) { $unusedStayedFF = $false }
    [PSCustomObject]@{ Switch102CAt400 = $at400; UnusedStayedFF = $unusedStayedFF; BadStamp = $badStamp }
}

# Private VPM folder holding a copy of the zip (build/ is gitignored); every
# process, parent or child, deletes its own folder on the way out.
$vpm = Join-Path $repo ("src/$Tree/build/game-tests-scratch/" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path (Join-Path $vpm 'roms') -Force | Out-Null
    Copy-Item -LiteralPath $VpmZip -Destination (Join-Path $vpm 'roms/eballchp.zip')
    try {
        if ($ChildMode -eq 'Deterministic') {
            Start-EbcMachine -LibraryPath $library -VpmPath $vpm
            Invoke-StandardRun | Out-Null
            Set-Content -LiteralPath $OutFile -Value (Get-EbcEvents) -Encoding utf8
            exit 0
        }
        if ($ChildMode -eq 'ThrowWhilePaused') {
            Start-EbcMachine -LibraryPath $library -VpmPath $vpm
            Step-EbcFrames -Frames 10
            throw 'deliberate exception while the emulator is paused'
        }
        if ($ChildMode -eq 'HangGuard') {
            # A 2 s guard stands in for the 600 s one: after it expires with no
            # resume, the machine must refuse calls, naming the frame.
            Start-EbcMachine -LibraryPath $library -VpmPath $vpm
            Step-EbcFrames -Frames 10
            [EightBallChampMachine]::HangGuardSeconds = 2
            Step-EbcFrames -Frames 1
            Start-Sleep -Seconds 4
            $msg = 'no exception'
            try { Read-EbcRam -Address 0x1000 -Count 1 | Out-Null } catch { $msg = $_.Exception.Message }
            Set-Content -LiteralPath $OutFile -Value $msg -Encoding utf8
            exit 0
        }

        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        Start-EbcMachine -LibraryPath $library -VpmPath $vpm
        $run = Invoke-StandardRun
        $clock.Stop()
        Write-Output ("INFO kit/machine :: 1,500 frames (1,000 single steps + 500) in {0:N2} s wall" -f $clock.Elapsed.TotalSeconds)

        $frame = [EightBallChampMachine]::Frame
        Write-Result 'Advance is exact' ($frame -eq 1500) "Frame is $frame after 1,000 x Advance(1) + Advance(500), expected 1500"

        $before = Read-EbcRam -Address 0x1000 -Count 0x800
        Start-Sleep -Milliseconds 200
        $after = Read-EbcRam -Address 0x1000 -Count 0x800
        $diff = 0; for ($k = 0; $k -lt 0x800; $k++) { if ($before[$k] -ne $after[$k]) { $diff++ } }
        # Control: 21-34 bytes of $0000-$17FF change on every frame near 1500
        # (measured), so a frozen comparison is not vacuous.
        $ram0 = Read-EbcRam -Address 0x0000 -Count 0x1800
        Step-EbcFrames -Frames 1
        $ram1 = Read-EbcRam -Address 0x0000 -Count 0x1800
        $moved = 0; for ($k = 0; $k -lt 0x1800; $k++) { if ($ram0[$k] -ne $ram1[$k]) { $moved++ } }
        Write-Result 'Paused means frozen' ($diff -eq 0 -and $moved -gt 0) "$diff U4 bytes changed during 200 ms paused at Frame 1500; $moved bytes of `$0000-`$17FF changed over Advance(1) (expected > 0)"

        $events = @(Get-EbcEvents)
        $childOut = Join-Path $vpm 'deterministic-events.txt'
        $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -PassThru -NoNewWindow -ArgumentList @(
            '-NoProfile', '-File', $PSCommandPath, '-Tree', $Tree, '-VpmZip', $VpmZip, '-ChildMode', 'Deterministic', '-OutFile', $childOut)
        if (-not $proc.WaitForExit(660000)) { $proc.Kill(); Write-Result 'Deterministic' $false 'child run hung past 660 s' }
        elseif ($proc.ExitCode -ne 0) { Write-Result 'Deterministic' $false "child exited $($proc.ExitCode)" }
        else {
            $childEvents = @(Get-Content -LiteralPath $childOut -Encoding utf8)
            $firstDiff = -1
            for ($k = 0; $k -lt [Math]::Max($events.Count, $childEvents.Count); $k++) {
                if ($k -ge $events.Count -or $k -ge $childEvents.Count -or $events[$k] -ne $childEvents[$k]) { $firstDiff = $k; break }
            }
            Write-Result 'Deterministic' ($firstDiff -lt 0 -and $events.Count -gt 0) ("{0} vs {1} events; first difference at index {2}: '{3}' vs '{4}'" -f $events.Count, $childEvents.Count, $firstDiff, $(if ($firstDiff -ge 0 -and $firstDiff -lt $events.Count) { $events[$firstDiff] }), $(if ($firstDiff -ge 0 -and $firstDiff -lt $childEvents.Count) { $childEvents[$firstDiff] }))
        }

        # The switch scan first writes $102C at frame 325 (after the RAM test);
        # with switch 8 open it writes $00 there. The power-on $FF already has
        # bit $80 set, so an earlier frame (such as 300) proves nothing.
        Write-Result 'Event stamps match Frame' ($null -eq $run.BadStamp) "$($run.BadStamp)"

        Write-Result 'Switch reaches the ROM' ($run.Switch102CAt400 -eq 0x80) ("`$102C at frame 400 is {0:X2}, expected 80 (switch 08 = strobe 0, return 7)" -f $run.Switch102CAt400)

        $okFF = $run.UnusedStayedFF -and (Read-EbcRam -Address $UnusedU4 -Count 1)[0] -eq 0xFF   # Frame 1501
        Write-EbcRam -Address $UnusedU4 -Bytes ([byte[]]@(0x5A))
        Step-EbcFrames -Frames 1
        $back = (Read-EbcRam -Address $UnusedU4 -Count 1)[0]
        Write-Result 'RAM write is seen' ($okFF -and $back -eq 0x5A) ("`$17FE FF on every frame 330-1500: $okFF; read back {0:X2} after 1 frame, expected 5A" -f $back)

        $from = [EightBallChampMachine]::Frame
        $hit = Wait-EbcEvent -Prefix 'disp ' -MaxFrames 600
        $now = [EightBallChampMachine]::Frame
        Write-Result 'Wait returns the Frame it stops at' ($hit -eq $now -and $now -gt $from) "Wait-EbcEvent 'disp ' from Frame $from returned $hit, machine at Frame $now"

        $msg = ''
        try { Start-EbcMachine -LibraryPath $library -VpmPath $vpm } catch { $msg = $_.Exception.Message }
        Write-Result 'Second start throws' ($msg -like '*one boot per process*') "second Start message: '$msg'"
    }
    finally {
        if ('EightBallChampMachine' -as [type]) { Stop-EbcMachine }
    }

    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $throwOut = Join-Path $vpm 'throw-child-state.txt'
    $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -PassThru -NoNewWindow -RedirectStandardError (Join-Path $vpm 'throw-child.err') -RedirectStandardOutput (Join-Path $vpm 'throw-child.out') -ArgumentList @(
        '-NoProfile', '-File', $PSCommandPath, '-Tree', $Tree, '-VpmZip', $VpmZip, '-ChildMode', 'ThrowWhilePaused', '-OutFile', $throwOut)
    if (-not $proc.WaitForExit(60000)) { $proc.Kill(); Write-Result 'Exception while paused still exits' $false 'child still running after 60 s' }
    else {
        $state = if (Test-Path -LiteralPath $throwOut) { (Get-Content -LiteralPath $throwOut -Raw).Trim() } else { 'no state file' }
        Write-Result 'Exception while paused still exits' ($proc.ExitCode -ne 0 -and $state -eq 'running=False') ("child exited {0} after {1:N1} s; emulator after cleanup: {2}" -f $proc.ExitCode, $clock.Elapsed.TotalSeconds, $state)
    }

    $hangOut = Join-Path $vpm 'hang-guard.txt'
    $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -PassThru -NoNewWindow -ArgumentList @(
        '-NoProfile', '-File', $PSCommandPath, '-Tree', $Tree, '-VpmZip', $VpmZip, '-ChildMode', 'HangGuard', '-OutFile', $hangOut)
    if (-not $proc.WaitForExit(60000)) { $proc.Kill(); Write-Result 'Hang guard faults the machine' $false 'child still running after 60 s' }
    else {
        $hangMsg = if (Test-Path -LiteralPath $hangOut) { (Get-Content -LiteralPath $hangOut -Raw).Trim() } else { "no output; child exited $($proc.ExitCode)" }
        Write-Result 'Hang guard faults the machine' ($hangMsg -like '*hang guard*frame 11*') "after the 2 s guard expired at Frame 11, ReadRam said: '$hangMsg'"
    }
}
finally {
    # The throwing child reports whether its cleanup stopped the emulator: on
    # macOS the process exits even with the emulation thread still paused, so
    # the exit code alone cannot show a Stop that failed to release it.
    if ($ChildMode -eq 'ThrowWhilePaused' -and $OutFile) {
        Set-Content -LiteralPath $OutFile -Value ("running=" + [EightBallChampMachine]::IsRunning) -Encoding utf8
    }
    Remove-Item -LiteralPath $vpm -Recurse -Force -ErrorAction SilentlyContinue
}
if ($script:failed -gt 0) { exit 1 }
exit 0
