param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# The runner builds every tree into the same VisualPinballX/VPinMAME/roms/eballchp.zip
# and must copy each tree's zip before building the next one. This test shows
# the ROM the emulator is running is this tree's own build.
# Usage: pwsh tests/kit/trees.tests.ps1 -Tree <tree> -VpmZip src/<tree>/build/game-tests/eballchp.zip
Import-Module (Join-Path $PSScriptRoot '../../tools/GameTest.psm1') -Force
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# The tree's build output, written by src/<tree>/asm/build.ps1.
$rebuilt = Join-Path $repo "src/$Tree/build/u3_cpu.rebuilt.128"

Start-EbcGame -Tree $Tree -VpmZip $VpmZip
Test-EbcItem -Name 'Each tree boots its own ROM' -Doc "src/$Tree/build/u3_cpu.rebuilt.128" -Body {
    # The CPU's address space (region 0x81) holds the running ROM at C000-FFFF.
    Step-EbcFrames -Frames 10
    $running = Read-EbcRam -Address 0xC000 -Count 0x4000
    $expected = [IO.File]::ReadAllBytes($rebuilt)
    # Byte 0 is the checksum-compensation byte; it could coincide between trees.
    Assert-EbcEqual -Expected ('{0:X2}' -f $expected[0]) -Actual ('{0:X2}' -f $running[0]) -What 'C000 compensation byte'
    Assert-EbcEqual -Expected $expected.Length -Actual $running.Length -What 'C000-FFFF byte count'
    $firstDifference = -1
    for ($index = 0; $index -lt [Math]::Min($expected.Length, $running.Length); $index++) {
        if ($expected[$index] -ne $running[$index]) { $firstDifference = $index; break }
    }
    Assert-EbcEqual -Expected -1 -Actual $firstDifference -What 'First differing byte in C000-FFFF (-1 means source build matches)'
}
Complete-EbcTests
