[CmdletBinding()]
param()

# Local-only negative control: builds the canonical CPU from source, inverts
# C000 in a temporary ROM set, and requires detection of the checksum-failure
# loop. Sound inputs are local files under src/roms. Run in its own pwsh process.

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $repositoryRoot 'tools/LibPinmameBoot.ps1')
$libraryPath = & (Join-Path $repositoryRoot 'tools/Get-LibPinmame.ps1')

& (Join-Path $repositoryRoot 'src/originals/asm/build.ps1') -SkipPackaging

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
            $source = if ($name -eq 'u3_cpu.128') { 'src/originals/build/u3_cpu.rebuilt.128' } else { "src/roms/$name" }
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path $repositoryRoot $source))
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
