[CmdletBinding()]
param(
    [switch]$RequireByteIdentical
)

$ErrorActionPreference = 'Stop'

$asmDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$originalsDirectory = Split-Path -Parent $asmDirectory
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $originalsDirectory)
$assembler = Join-Path $repositoryRoot 'dasm-2.20.14.1-win-x64\dasm.exe'
$originalRom = Join-Path $originalsDirectory 'roms\u3_cpu.128'
$buildDirectory = Join-Path $originalsDirectory 'build'
$rebuiltRom = Join-Path $buildDirectory 'u3_cpu.rebuilt.128'
$listing = Join-Path $buildDirectory 'u3_cpu.rebuilt.lst'
$symbols = Join-Path $buildDirectory 'u3_cpu.rebuilt.sym'
$verification = Join-Path $buildDirectory 'verification.txt'
$pinmameRomDirectory = Join-Path $repositoryRoot 'VisualPinballX\VPinMAME\roms'
$pinmameArchive = Join-Path $pinmameRomDirectory 'eballchp.zip'
$packageBackupDirectory = Join-Path $buildDirectory 'visual-pinball-package-backup'
$packageBackup = Join-Path $packageBackupDirectory 'eballchp.pre-build.zip'
$temporaryArchive = Join-Path $buildDirectory 'eballchp.packaging.zip'
$expectedSha1 = '25D310F169B92CE6B348330816DDC3B5710E57DA'
$soundRoms = @(
    (Join-Path $originalsDirectory 'roms\u3_snd.532')
    (Join-Path $originalsDirectory 'roms\u4_snd.532')
    (Join-Path $originalsDirectory 'roms\u5_snd.532')
)

if (-not (Test-Path -LiteralPath $assembler -PathType Leaf)) {
    throw "DASM was not found at $assembler"
}
if (-not (Test-Path -LiteralPath $originalRom -PathType Leaf)) {
    throw "The immutable reference ROM was not found at $originalRom"
}
foreach ($soundRom in $soundRoms) {
    if (-not (Test-Path -LiteralPath $soundRom -PathType Leaf)) {
        throw "An immutable sound ROM was not found at $soundRom"
    }
}

$referenceHash = (Get-FileHash -Algorithm SHA1 -LiteralPath $originalRom).Hash
if ($referenceHash -ne $expectedSha1) {
    throw "Reference ROM SHA-1 is $referenceHash; expected $expectedSha1. Refusing to build."
}

New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null

Push-Location $asmDirectory
try {
    & $assembler 'main.asm' '-f3' "-o$rebuiltRom" "-l$listing" "-s$symbols" '-T1' '-R'
    if ($LASTEXITCODE -ne 0) {
        throw "DASM failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$rebuiltBytes = [System.IO.File]::ReadAllBytes($rebuiltRom)
$originalBytes = [System.IO.File]::ReadAllBytes($originalRom)
if ($rebuiltBytes.Length -ne 16384) {
    throw "Rebuilt ROM is $($rebuiltBytes.Length) bytes; expected 16384."
}

$firstDifferences = [System.Collections.Generic.List[string]]::new()
$differenceCount = 0
for ($index = 0; $index -lt $originalBytes.Length; $index++) {
    if ($originalBytes[$index] -ne $rebuiltBytes[$index]) {
        $differenceCount++
        $address = 0xC000 + $index
        if ($firstDifferences.Count -lt 20) {
            $firstDifferences.Add(('$' + $address.ToString('X4') + ': original $' +
                $originalBytes[$index].ToString('X2') + ', rebuilt $' +
                $rebuiltBytes[$index].ToString('X2')))
        }
    }
}

$vectorNames = @('SCI', 'timer overflow', 'timer output compare', 'timer input capture',
    'external IRQ', 'SWI', 'NMI', 'reset')
$vectorLines = [System.Collections.Generic.List[string]]::new()
for ($vectorIndex = 0; $vectorIndex -lt $vectorNames.Count; $vectorIndex++) {
    $offset = 0x3FF0 + ($vectorIndex * 2)
    $target = (([int]$rebuiltBytes[$offset]) -shl 8) -bor ([int]$rebuiltBytes[$offset + 1])
    if ($target -lt 0xC000 -or $target -gt 0xFFFF) {
        throw "$($vectorNames[$vectorIndex]) vector targets outside ROM: $('$' + $target.ToString('X4'))"
    }
    $vectorLines.Add("$($vectorNames[$vectorIndex]) vector: $('$' + $target.ToString('X4'))")
}

$rebuiltHash = (Get-FileHash -Algorithm SHA1 -LiteralPath $rebuiltRom).Hash
$isByteIdentical = $differenceCount -eq 0

$report = @(
    'Eight Ball Champ canonical build: PASS'
    'Size: 16384 bytes'
    "Reference SHA-1: $referenceHash"
    "Rebuilt SHA-1:   $rebuiltHash"
    "Byte-identical to reference: $isByteIdentical"
    "Byte differences: $differenceCount"
    $vectorLines
)
if ($firstDifferences.Count -ne 0) {
    $report += 'First byte differences:'
    $report += $firstDifferences
}

if ($RequireByteIdentical -and -not $isByteIdentical) {
    $report += 'PinMAME package: not written because byte identity was required.'
    $report | Set-Content -LiteralPath $verification -Encoding ascii
    $report
    throw "The build is structurally valid but differs from the reference in $differenceCount byte(s)."
}

New-Item -ItemType Directory -Path $pinmameRomDirectory -Force | Out-Null
if ((Test-Path -LiteralPath $pinmameArchive -PathType Leaf) -and
        -not (Test-Path -LiteralPath $packageBackup -PathType Leaf)) {
    New-Item -ItemType Directory -Path $packageBackupDirectory -Force | Out-Null
    Copy-Item -LiteralPath $pinmameArchive -Destination $packageBackup
}

if (Test-Path -LiteralPath $temporaryArchive) {
    Remove-Item -LiteralPath $temporaryArchive -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open(
    $temporaryArchive, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $rebuiltRom, 'u3_cpu.128',
        [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    foreach ($soundRom in $soundRoms) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $soundRom, (Split-Path -Leaf $soundRom),
            [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally {
    $archive.Dispose()
}

[System.IO.File]::Copy($temporaryArchive, $pinmameArchive, $true)
Remove-Item -LiteralPath $temporaryArchive -Force

$expectedEntries = @('u3_cpu.128', 'u3_snd.532', 'u4_snd.532', 'u5_snd.532')
$packageSources = @{
    'u3_cpu.128' = $rebuiltRom
    'u3_snd.532' = $soundRoms[0]
    'u4_snd.532' = $soundRoms[1]
    'u5_snd.532' = $soundRoms[2]
}
$archive = [System.IO.Compression.ZipFile]::OpenRead($pinmameArchive)
try {
    $actualEntries = @($archive.Entries | ForEach-Object { $_.FullName })
    if ($actualEntries.Count -ne $expectedEntries.Count -or
            (Compare-Object $expectedEntries $actualEntries).Count -ne 0) {
        throw "Packaged ROM set has unexpected entries: $($actualEntries -join ', ')"
    }

    foreach ($entryName in $expectedEntries) {
        $entry = $archive.GetEntry($entryName)
        $source = $packageSources[$entryName]
        $sourceLength = (Get-Item -LiteralPath $source).Length
        if ($null -eq $entry -or $entry.Length -ne $sourceLength) {
            throw "Packaged $entryName is missing or has the wrong length."
        }

        $entryStream = $entry.Open()
        $sha1 = [System.Security.Cryptography.SHA1]::Create()
        try {
            $entryHash = [System.BitConverter]::ToString(
                $sha1.ComputeHash($entryStream)).Replace('-', '')
        }
        finally {
            $sha1.Dispose()
            $entryStream.Dispose()
        }
        $sourceHash = (Get-FileHash -Algorithm SHA1 -LiteralPath $source).Hash
        if ($entryHash -ne $sourceHash) {
            throw "Packaged $entryName does not match its build input."
        }
    }
}
finally {
    $archive.Dispose()
}

$report += "PinMAME package: $pinmameArchive"
$report += "Package entries: $($expectedEntries -join ', ')"
if (Test-Path -LiteralPath $packageBackup -PathType Leaf) {
    $report += "First pre-build package backup: $packageBackup"
}
$report | Set-Content -LiteralPath $verification -Encoding ascii
$report
