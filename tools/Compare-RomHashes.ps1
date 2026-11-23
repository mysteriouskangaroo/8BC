[CmdletBinding()]
param(
    # Folder holding the downloaded build-*/hashes.txt artifacts.
    [string]$Directory = '.'
)

# Fails unless every platform's hashes.txt lists the same ROM SHA-1s. Lines
# are compared without their endings: Windows jobs write CRLF, others LF.

$ErrorActionPreference = 'Stop'

$files = @(Get-ChildItem -Path (Join-Path $Directory 'build-*/hashes.txt') | Sort-Object FullName)
if ($files.Count -lt 2) {
    throw "Expected hashes.txt from at least two platforms under $Directory; found $($files.Count)."
}

function Read-Hashes([string]$Path) {
    @([System.IO.File]::ReadAllText($Path) -split "\r?\n" | Where-Object { $_ -ne '' })
}

$reference = $files[0]
$expected = Read-Hashes $reference.FullName
if ($expected.Count -eq 0) { throw "$($reference.FullName) is empty." }
$expected | ForEach-Object { "  $_" }

$mismatches = 0
foreach ($file in $files) {
    $actual = Read-Hashes $file.FullName
    if (($actual -join "`n") -ne ($expected -join "`n")) {
        "::error::$($file.Directory.Name)/hashes.txt differs from $($reference.Directory.Name)/hashes.txt"
        $actual | ForEach-Object { "  $_" }
        $mismatches++
    }
}
if ($mismatches) { exit 1 }
"ROM hashes identical across $($files.Count) platform builds."
