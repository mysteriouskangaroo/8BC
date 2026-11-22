# Dot-source this file to get Invoke-EightBallChampBootTest, which boots an
# eballchp ROM set in libpinmame, headless and unthrottled, and reports whether
# the CPU got past the startup checksum and drove the displays. It runs on the
# lockstep machine in LibPinmameMachine.ps1, which owns the emulator, the
# callbacks and the frame convention.
# Requires PowerShell 7; Windows PowerShell 5.1 can still run the builds.

if ($PSVersionTable.PSEdition -ne 'Core') {
    throw 'The libpinmame boot test requires PowerShell 7 (pwsh); Windows PowerShell 5.1 can still run the builds.'
}

. (Join-Path $PSScriptRoot 'LibPinmameMachine.ps1')

function Invoke-EightBallChampBootTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LibraryPath,
        # Folder holding roms/eballchp.zip; its nvram/, cfg/ and hi/ are cleared first.
        [Parameter(Mandatory = $true)][string]$VpmPath,
        [ValidateRange(600, 36000)][int]$Frames = 1500
    )
    $machine = [EightBallChampMachine]
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $why = New-Object System.Collections.Generic.List[string]
    $samples = New-Object System.Collections.Generic.List[string]
    $stack = ''
    $lastFrame = -1
    $events = @()
    $written = -1
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        Start-EbcMachine -LibraryPath $LibraryPath -VpmPath $VpmPath
        # Ball resting in the outhole (switch 8), closed from the first frame.
        $machine::SetSwitch(8, $true)
        $at = 0
        foreach ($sampleFrame in 60, 300, ($Frames - 1)) {
            $machine::Advance($sampleFrame - $machine::Frame)
            $u4 = $machine::ReadRam(0x1000, 0x800)
            $written = 0
            foreach ($b in $u4) { if ($b -ne 0xFF) { $written++ } }
            $stack = -join ($machine::ReadRam(0x00FC, 4) | ForEach-Object { $_.ToString('x2') })
            $lastFrame = $machine::Frame
            $samples.Add("$($machine::Frame) ram stack=$stack u4written=$written")
        }
        # Snapshot before Stop releases the paused thread: later events are not part of the run.
        $events = @($machine::EventsSince(0))
    }
    catch { $why.Add("machine error: $($_.Exception.Message)") }
    finally { try { Stop-EbcMachine } catch { $why.Add("stop error: $($_.Exception.Message)") } }

    $events = $events + $samples
    $counts = @{ disp = 0; lamp = 0; sol = 0; snd = 0 }
    foreach ($e in $events) { $kind = $e.Split(' ')[1]; if ($counts.ContainsKey($kind)) { $counts[$kind]++ } }
    $digest = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($events -join "`n"))) | ForEach-Object { $_.ToString('x2') })
    if ($counts.disp -eq 0) { $why.Add('no display events') }
    if ($stack -eq 'c000e3e0') { $why.Add('stack 00FC-00FF = C000 E3E0 (checksum-failure loop)') }
    if ($written -le 0) { $why.Add('U4 RAM 1000-17FF never written (all FF)') }
    $pass = $why.Count -eq 0
    [PSCustomObject]@{
        Pass           = $pass
        Reason         = if ($pass) { 'ok' } else { $why -join '; ' }
        Frames         = $lastFrame + 1
        WallSeconds    = [math]::Round($watch.Elapsed.TotalSeconds, 2)
        DisplayEvents  = $counts.disp
        LampEvents     = $counts.lamp
        SolenoidEvents = $counts.sol
        SoundEvents    = $counts.snd
        Stack00FC      = $stack
        U4WrittenBytes = $written
        Digest         = $digest
        Logs           = $machine::Logs
    }
}
