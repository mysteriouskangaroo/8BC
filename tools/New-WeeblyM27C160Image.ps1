[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$U3Rom,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$u2Size = 0x4000
$u3Size = 0x4000
$slotSize = $u2Size + $u3Size
$slotCount = 64
$imageSize = 0x200000
$u2Fill = [byte]0xFF

if (-not (Test-Path -LiteralPath $U3Rom -PathType Leaf)) {
    throw "The rebuilt U3 ROM was not found at $U3Rom"
}

$u3Bytes = [System.IO.File]::ReadAllBytes($U3Rom)
if ($u3Bytes.Length -ne $u3Size) {
    throw "The rebuilt U3 ROM is $($u3Bytes.Length) bytes; expected $u3Size."
}

$startupChecksum = 0
foreach ($value in $u3Bytes) {
    $startupChecksum = ($startupChecksum + $value) -band 0xFF
}
if ($startupChecksum -ne 0xFF) {
    throw "The rebuilt U3 ROM additive checksum is $('$' + $startupChecksum.ToString('X2')); expected `$FF."
}

if (($slotSize * $slotCount) -ne $imageSize) {
    throw 'Internal Weebly image geometry is inconsistent.'
}

$slotBytes = [byte[]]::new($slotSize)
for ($index = 0; $index -lt $u2Size; $index++) {
    $slotBytes[$index] = $u2Fill
}
[System.Array]::Copy($u3Bytes, 0, $slotBytes, $u2Size, $u3Size)

$imageBytes = [byte[]]::new($imageSize)
for ($slotIndex = 0; $slotIndex -lt $slotCount; $slotIndex++) {
    [System.Array]::Copy(
        $slotBytes, 0, $imageBytes, ($slotIndex * $slotSize), $slotSize)
}

# Validate every byte before writing the programmer image. Each 256-Kbit
# (32 KiB) game-select slot must contain an erased U2 half followed by the
# exact rebuilt U3 image.
for ($slotIndex = 0; $slotIndex -lt $slotCount; $slotIndex++) {
    $slotOffset = $slotIndex * $slotSize
    for ($index = 0; $index -lt $u2Size; $index++) {
        if ($imageBytes[$slotOffset + $index] -ne $u2Fill) {
            throw "Weebly slot $slotIndex has invalid U2 fill at offset $('0x' + ($slotOffset + $index).ToString('X6'))."
        }
    }
    for ($index = 0; $index -lt $u3Size; $index++) {
        if ($imageBytes[$slotOffset + $u2Size + $index] -ne $u3Bytes[$index]) {
            throw "Weebly slot $slotIndex does not match U3 at offset $('0x' + ($slotOffset + $u2Size + $index).ToString('X6'))."
        }
    }
}

$outputDirectory = Split-Path -Parent $OutputPath
if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
    $outputDirectory = (Get-Location).Path
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$temporaryOutput = Join-Path $outputDirectory ((Split-Path -Leaf $OutputPath) + '.tmp')
if (Test-Path -LiteralPath $temporaryOutput) {
    Remove-Item -LiteralPath $temporaryOutput -Force
}

try {
    [System.IO.File]::WriteAllBytes($temporaryOutput, $imageBytes)
    $writtenBytes = [System.IO.File]::ReadAllBytes($temporaryOutput)
    if ($writtenBytes.Length -ne $imageSize) {
        throw "Written Weebly image is $($writtenBytes.Length) bytes; expected $imageSize."
    }
    for ($index = 0; $index -lt $imageSize; $index++) {
        if ($writtenBytes[$index] -ne $imageBytes[$index]) {
            throw "Written Weebly image failed read-back verification at offset $('0x' + $index.ToString('X6'))."
        }
    }
    Move-Item -LiteralPath $temporaryOutput -Destination $OutputPath -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryOutput) {
        Remove-Item -LiteralPath $temporaryOutput -Force
    }
}

[pscustomobject]@{
    Path = $OutputPath
    Size = (Get-Item -LiteralPath $OutputPath).Length
    Sha1 = (Get-FileHash -Algorithm SHA1 -LiteralPath $OutputPath).Hash
    SlotCount = $slotCount
    SlotSize = $slotSize
    U2Fill = $u2Fill.ToString('X2')
    U3Sha1 = (Get-FileHash -Algorithm SHA1 -LiteralPath $U3Rom).Hash
}
