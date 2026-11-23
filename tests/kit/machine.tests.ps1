# Tests for tools/LibPinmameMachine.ps1, the lockstep libpinmame machine.
# Usage: pwsh tests/kit/machine.tests.ps1 -Tree originals -VpmZip src/originals/build/game-tests/eballchp.zip
# Boots a private copy of the tree's packaged eballchp.zip; never writes src/*/roms/.
# -ChildMode/-OutFile are internal: the script re-invokes itself in a new pwsh
# for the tests that need a second, independent boot.

param(
    [string]$Tree,
    [string]$VpmZip,
    [string]$ObserveTo,
    [ValidateSet('', 'Deterministic', 'ThrowWhilePaused', 'UnhandledWhilePaused', 'HangGuard', 'SlowStartup')][string]$ChildMode = '',
    [string]$OutFile
)
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force
$ErrorActionPreference = 'Stop'
$VpmZip = (Resolve-Path -LiteralPath $VpmZip).Path
$Doc = 'tools/LibPinmameMachine.ps1 header'

# A test file that throws at top level while paused, with no Stop of its own,
# relies on the machine's ProcessExit handler (registered in Start). A second
# ProcessExit handler, registered after Start's so it runs after it, records
# whether the emulator was still running by then.
if ($ChildMode -eq 'UnhandledWhilePaused') {
    Start-EbcGame -AttractFrames 0 -EmptyOuthole
    Step-EbcFrames -Frames 10
    Add-Type -TypeDefinition @'
public static class EbcExitProbe {
    public static void Register(string path) {
        System.AppDomain.CurrentDomain.ProcessExit += delegate {
            string state = "no EightBallChampMachine type";
            foreach (var a in System.AppDomain.CurrentDomain.GetAssemblies()) {
                var t = a.GetType("EightBallChampMachine");
                if (t != null) { state = "running=" + t.GetProperty("IsRunning").GetValue(null); break; }
            }
            System.IO.File.WriteAllText(path, state);
        };
    }
}
'@
    [EbcExitProbe]::Register($OutFile)
    throw 'deliberate top-level exception while the emulator is paused'
}

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

# Scratch for the children's output files; each process's VPM folder is its
# own (Start-EbcGame), deleted on the way out.
$work = Join-Path $(if ($env:EBC_PRIVATE_DIR) { $env:EBC_PRIVATE_DIR } else { [IO.Path]::GetTempPath() }) ('machine-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    try {
        if ($ChildMode -eq 'Deterministic') {
            Start-EbcGame -AttractFrames 0 -EmptyOuthole
            Invoke-StandardRun | Out-Null
            Set-Content -LiteralPath $OutFile -Value (Get-EbcEvents) -Encoding utf8
            Stop-EbcGame
            exit 0
        }
        if ($ChildMode -eq 'ThrowWhilePaused') {
            Start-EbcGame -AttractFrames 0 -EmptyOuthole
            Step-EbcFrames -Frames 10
            throw 'deliberate exception while the emulator is paused'
        }
        if ($ChildMode -eq 'SlowStartup') {
            # The game thread is held 300 ms in the run-state callback, as a
            # busy machine may preempt it there; the 20 s guard stands in for
            # the 600 s one so a machine that never reaches frame 0 fails fast.
            [EightBallChampMachine]::RunStateDelayMs = 300
            [EightBallChampMachine]::HangGuardSeconds = 20
            Start-EbcGame -AttractFrames 0 -EmptyOuthole
            Step-EbcFrames -Frames 10
            Set-Content -LiteralPath $OutFile -Value ('frame=' + (Get-EbcFrame)) -Encoding utf8
            Stop-EbcGame
            exit 0
        }
        if ($ChildMode -eq 'HangGuard') {
            # A 2 s guard stands in for the 600 s one: after it expires with no
            # resume, the machine must refuse calls, naming the frame.
            Start-EbcGame -AttractFrames 0 -EmptyOuthole
            Step-EbcFrames -Frames 10
            [EightBallChampMachine]::HangGuardSeconds = 2
            Step-EbcFrames -Frames 1
            Start-Sleep -Seconds 4
            $msg = 'no exception'
            try { Read-EbcRam -Address 0x1000 -Count 1 | Out-Null } catch { $msg = $_.Exception.Message }
            Set-Content -LiteralPath $OutFile -Value $msg -Encoding utf8
            Stop-EbcGame
            exit 0
        }

        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        Start-EbcGame -AttractFrames 0 -EmptyOuthole
        $run = Invoke-StandardRun
        $clock.Stop()
        Write-Output ("INFO {0}/machine :: 1,500 frames (1,000 single steps + 500) in {1:N2} s wall" -f $Tree, $clock.Elapsed.TotalSeconds)

        Test-EbcItem -Name 'Advance is exact' -Doc $Doc -Body {
            Assert-EbcEqual -Expected 1500 -Actual (Get-EbcFrame) -What 'Frame after 1,000 x Advance(1) + Advance(500)'
        }

        Test-EbcItem -Name 'Paused means frozen' -Doc $Doc -Body {
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
            Assert-EbcEqual -Expected 0 -Actual $diff -What 'U4 bytes changed during 200 ms paused at Frame 1500'
            Assert-EbcTrue ($moved -gt 0) "$moved bytes of `$0000-`$17FF changed over Advance(1), expected > 0"
        }

        $events = @(Get-EbcEvents)
        Test-EbcItem -Name 'Deterministic' -Doc $Doc -Body {
            $childOut = Join-Path $work 'deterministic-events.txt'
            $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -PassThru -NoNewWindow -ArgumentList @(
                '-NoProfile', '-File', $PSCommandPath, '-Tree', $Tree, '-VpmZip', $VpmZip, '-ChildMode', 'Deterministic', '-OutFile', $childOut)
            if (-not $proc.WaitForExit(660000)) { $proc.Kill(); throw 'child run hung past 660 s' }
            if ($proc.ExitCode -ne 0) { throw "child exited $($proc.ExitCode)" }
            $childEvents = @(Get-Content -LiteralPath $childOut -Encoding utf8)
            $firstDiff = -1
            for ($k = 0; $k -lt [Math]::Max($events.Count, $childEvents.Count); $k++) {
                if ($k -ge $events.Count -or $k -ge $childEvents.Count -or $events[$k] -ne $childEvents[$k]) { $firstDiff = $k; break }
            }
            Assert-EbcTrue ($firstDiff -lt 0 -and $events.Count -gt 0) ("{0} vs {1} events; first difference at index {2}: '{3}' vs '{4}'" -f $events.Count, $childEvents.Count, $firstDiff, $(if ($firstDiff -ge 0 -and $firstDiff -lt $events.Count) { $events[$firstDiff] }), $(if ($firstDiff -ge 0 -and $firstDiff -lt $childEvents.Count) { $childEvents[$firstDiff] }))
        }

        Test-EbcItem -Name 'Event stamps match Frame' -Doc $Doc -Body {
            Assert-EbcTrue ($null -eq $run.BadStamp) "$($run.BadStamp)"
        }

        # The switch scan first writes $102C at frame 325 (after the RAM test);
        # with switch 8 open it writes $00 there. The power-on $FF already has
        # bit $80 set, so an earlier frame (such as 300) proves nothing.
        Test-EbcItem -Name 'Switch reaches the ROM' -Doc $Doc -Body {
            Assert-EbcEqual -Expected '80' -Actual ('{0:X2}' -f $run.Switch102CAt400) -What '$102C at frame 400 (switch 08 = strobe 0, return 7)'
        }

        Test-EbcItem -Name 'RAM write is seen' -Doc $Doc -Seeded -Body {
            $okFF = $run.UnusedStayedFF -and (Read-EbcRam -Address $UnusedU4 -Count 1)[0] -eq 0xFF   # Frame 1501
            Write-EbcRam -Address $UnusedU4 -Bytes ([byte[]]@(0x5A))
            Step-EbcFrames -Frames 1
            $back = (Read-EbcRam -Address $UnusedU4 -Count 1)[0]
            Assert-EbcTrue $okFF '$17FE was not FF on every frame 330-1500'
            Assert-EbcEqual -Expected '5A' -Actual ('{0:X2}' -f $back) -What '$17FE read back after 1 frame'
        }

        Test-EbcItem -Name 'Wait returns the Frame it stops at' -Doc $Doc -Body {
            $from = Get-EbcFrame
            $hit = Wait-EbcEvent -Prefix 'disp ' -MaxFrames 600
            $now = Get-EbcFrame
            Assert-EbcTrue ($hit -eq $now -and $now -gt $from) "Wait-EbcEvent 'disp ' from Frame $from returned $hit, machine at Frame $now"
        }

        Test-EbcItem -Name 'Second start throws' -Doc $Doc -Body {
            $msg = ''
            try { Start-EbcGame -AttractFrames 0 -EmptyOuthole } catch { $msg = $_.Exception.Message }
            Assert-EbcTrue ($msg -like '*one boot per process*') "second Start message: '$msg'"
        }
    }
    finally {
        if ($ChildMode -eq 'ThrowWhilePaused') {
            # Only the machine's own stop, not Stop-EbcGame below, may have run yet.
            if ('EightBallChampMachine' -as [type]) { Stop-EbcMachine }
        }
        elseif ($ChildMode -eq '') { Stop-EbcGame }
    }

    if ($ChildMode -eq '') {
        Test-EbcItem -Name 'Exception while paused still exits' -Doc $Doc -Body {
            $clock = [System.Diagnostics.Stopwatch]::StartNew()
            $throwOut = Join-Path $work 'throw-child-state.txt'
            $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -PassThru -NoNewWindow -RedirectStandardError (Join-Path $work 'throw-child.err') -RedirectStandardOutput (Join-Path $work 'throw-child.out') -ArgumentList @(
                '-NoProfile', '-File', $PSCommandPath, '-Tree', $Tree, '-VpmZip', $VpmZip, '-ChildMode', 'ThrowWhilePaused', '-OutFile', $throwOut)
            if (-not $proc.WaitForExit(60000)) { $proc.Kill(); throw 'child still running after 60 s' }
            $state = if (Test-Path -LiteralPath $throwOut) { (Get-Content -LiteralPath $throwOut -Raw).Trim() } else { 'no state file' }
            Assert-EbcTrue ($proc.ExitCode -ne 0 -and $state -eq 'running=False') ("child exited {0} after {1:N1} s; emulator after cleanup: {2}" -f $proc.ExitCode, $clock.Elapsed.TotalSeconds, $state)
        }

        Test-EbcItem -Name 'Unhandled exception while paused exits and stops the emulator' -Doc $Doc -Body {
            $clock = [System.Diagnostics.Stopwatch]::StartNew()
            $probeOut = Join-Path $work 'unhandled-child-state.txt'
            $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -PassThru -NoNewWindow -RedirectStandardError (Join-Path $work 'unhandled-child.err') -RedirectStandardOutput (Join-Path $work 'unhandled-child.out') -ArgumentList @(
                '-NoProfile', '-File', $PSCommandPath, '-Tree', $Tree, '-VpmZip', $VpmZip, '-ChildMode', 'UnhandledWhilePaused', '-OutFile', $probeOut)
            if (-not $proc.WaitForExit(60000)) { $proc.Kill(); throw 'child still running after 60 s' }
            $state = if (Test-Path -LiteralPath $probeOut) { (Get-Content -LiteralPath $probeOut -Raw).Trim() } else { 'no state file' }
            Assert-EbcTrue ($proc.ExitCode -ne 0 -and $state -eq 'running=False') ("child exited {0} after {1:N1} s; emulator at process exit: {2}" -f $proc.ExitCode, $clock.Elapsed.TotalSeconds, $state)
        }

        # libpinmame raises the run state (MACHINE_INIT, src/wpc/core.c) inside
        # cpu_pre_run, before cpu_run resets the time-fence offset
        # (src/cpuexec.c); a fence set in that window freezes emulated time at 0.
        Test-EbcItem -Name 'Start survives a slow start-up' -Doc $Doc -Body {
            $slowOut = Join-Path $work 'slow-startup.txt'
            $slowErr = Join-Path $work 'slow-startup.err'
            $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -PassThru -NoNewWindow -RedirectStandardError $slowErr -RedirectStandardOutput (Join-Path $work 'slow-startup.out') -ArgumentList @(
                '-NoProfile', '-File', $PSCommandPath, '-Tree', $Tree, '-VpmZip', $VpmZip, '-ChildMode', 'SlowStartup', '-OutFile', $slowOut)
            if (-not $proc.WaitForExit(60000)) { $proc.Kill(); throw 'child still running after 60 s' }
            $got = if (Test-Path -LiteralPath $slowOut) { (Get-Content -LiteralPath $slowOut -Raw).Trim() } else {
                $why = (@(Get-Content -LiteralPath $slowErr -ErrorAction SilentlyContinue | Where-Object { $_ -match '\w' } | Select-Object -Last 3) -join ' ').Trim()
                "no output; child exited $($proc.ExitCode): $why" }
            Assert-EbcEqual -Expected 'frame=10' -Actual $got -What 'Frame after Start and Advance(10), run-state callback held 300 ms'
        }

        Test-EbcItem -Name 'Hang guard faults the machine' -Doc $Doc -Body {
            $hangOut = Join-Path $work 'hang-guard.txt'
            $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -PassThru -NoNewWindow -ArgumentList @(
                '-NoProfile', '-File', $PSCommandPath, '-Tree', $Tree, '-VpmZip', $VpmZip, '-ChildMode', 'HangGuard', '-OutFile', $hangOut)
            if (-not $proc.WaitForExit(60000)) { $proc.Kill(); throw 'child still running after 60 s' }
            $hangMsg = if (Test-Path -LiteralPath $hangOut) { (Get-Content -LiteralPath $hangOut -Raw).Trim() } else { "no output; child exited $($proc.ExitCode)" }
            Assert-EbcTrue ($hangMsg -like '*hang guard*frame 11*') "after the 2 s guard expired at Frame 11, ReadRam said: '$hangMsg'"
        }
    }
}
finally {
    # The throwing child reports whether its cleanup stopped the emulator: on
    # macOS the process exits even with the emulation thread still paused, so
    # the exit code alone cannot show a Stop that failed to release it.
    if ($ChildMode -eq 'ThrowWhilePaused' -and $OutFile) {
        Set-Content -LiteralPath $OutFile -Value ("running=" + [EightBallChampMachine]::IsRunning) -Encoding utf8
        Stop-EbcGame
    }
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Complete-EbcTests
