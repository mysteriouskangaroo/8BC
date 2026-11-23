[CmdletBinding()]
param()

# Negative control for the libpinmame boot test: boots the immutable original
# ROM set with the C000 checksum byte inverted, in a temporary folder, and
# passes only if the boot test reports FAIL with the CPU in the E3E0
# checksum-failure loop. Proves the boot test cannot pass a stuck ROM. Reads
# src/originals/roms/ and never writes there. Run in its own pwsh process
# (libpinmame allows one boot per process).

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $repositoryRoot 'tools/LibPinmameBoot.ps1')
$libraryPath = & (Join-Path $repositoryRoot 'tools/Get-LibPinmame.ps1')

$workDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('ebc-negative-control-' + [System.IO.Path]::GetRandomFileName())
$romSetDirectory = Join-Path $workDirectory 'roms'
New-Item -ItemType Directory -Path $romSetDirectory -Force | Out-Null
try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::Open(
        (Join-Path $romSetDirectory 'eballchp.zip'), [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in 'u3_cpu.128', 'u3_snd.532', 'u4_snd.532', 'u5_snd.532') {
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path $repositoryRoot "src/originals/roms/$name"))
            if ($name -eq 'u3_cpu.128') { $bytes[0] = $bytes[0] -bxor 0xFF }
            $stream = $archive.CreateEntry($name).Open()
            try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
        }
    }
    finally { $archive.Dispose() }

    $result = Invoke-EightBallChampBootTest -LibraryPath $libraryPath -VpmPath $workDirectory
    "Corrupted-checksum ROM: Pass=$($result.Pass); stack 00FC-00FF=$($result.Stack00FC); display events=$($result.DisplayEvents); $($result.Reason)"
    if ($result.Pass -or $result.Stack00FC -ne 'c000e3e0') {
        'Negative control: FAIL (the boot test did not detect the checksum-failure loop)'
        exit 1
    }
    'Negative control: PASS'
}
finally {
    Remove-Item -LiteralPath $workDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
