# Eight Ball Champ Deluxe (EBCD)

This project documents and modifies the game logic for the 1985 Bally/Midway
**Eight Ball Champ** pinball machine.  The target is the game-ROM code running
on the original Motorola 6803 MPU; the original displays, lamps, switches,
solenoids, sound board, and MPU remain in use.

## Scope and preservation

Original CPU and sound ROM files are not distributed in this repository.
Both CPU images build from assembly source without an original CPU ROM.
Run either build script with `-SkipPackaging` to assemble and validate without
any ROM inputs:

```powershell
pwsh -File tools/Get-Dasm.ps1
pwsh -File src/originals/asm/build.ps1 -SkipPackaging
pwsh -File src/8bc-deluxe/asm/build.ps1 -SkipPackaging
```

CI runs these source builds on Linux, Windows and macOS, also checks Windows
PowerShell 5.1, documentation paths and the boot-free game-test runner fixtures.
It does not run ROM hash comparisons or emulator tests and requires no ROM
files or secrets. Build checks cover image size, vectors, the machine's startup
checksum and the Deluxe executable layout.

For local PinMAME packaging and emulator tests, supply authorized copies of
`u3_snd.532`, `u4_snd.532` and `u5_snd.532` in `src/roms/`, then run the build
without `-SkipPackaging`. These sound inputs remain ignored and are never
modified. The original CPU ROM is not used.

The repository still contains reconstructed assembly, Ghidra analysis, and
modified release images. Removing original ROM files does not make it a
patch-only distribution.

Canonical outputs are generated under `src/originals/build/`; Deluxe outputs
are generated under `src/8bc-deluxe/build/`.

## Ghidra project

The Ghidra 12.2-compatible **GhidraMC6800** extension is installed locally at
`ghidra_12.2_PUBLIC_20261016/ghidra_12.2_PUBLIC/Ghidra/Extensions/GhidraMC6800`.
It provides `MC6801:BE:16:default`, the language variant that covers the
Motorola 6803 in Eight Ball Champ.

[`src/originals/ghidra/EightBallChamp.gpr`](src/originals/ghidra/EightBallChamp.gpr)
is an initialized project containing `u3_cpu.128`, imported as a raw binary at
`$C000` with that language. Open the project in Ghidra and analyze it from the
reset vector at `$E388`; do not select Ghidra's built-in 6809 language.

`tools/ghidra_scripts/SeedEightBallChamp.java` supplies Ghidra with the ROM's
reset and interrupt entry points before auto-analysis. It invokes Ghidra's own
MC6801/6803 disassembler; it is not a separate disassembler.

## Working layout

| Location | Purpose |
| --- | --- |
| `src/roms/` | Local sound inputs for PinMAME packaging; unused in CI. |
| `src/originals/ghidra/` | Ghidra project analyzing the untouched CPU ROM. |
| `src/originals/asm/` | Canonical commented DASM source for behaviorally faithful builds. |
| `src/originals/build/` | Generated canonical ROM, listing, symbols, and verification report. |
| `src/8bc-deluxe/ghidra/` | Independent Ghidra copy for the Deluxe variation. |
| `src/8bc-deluxe/asm/` | Modified source based on the verified canonical reconstruction. |
| `src/8bc-deluxe/build/` | Generated modified ROM images and listings. |
| `src/8bc-deluxe/gamerules.md` | Deluxe rules and required gameplay verification. |

## Initial vector map

| Vector address | Entry point | Purpose |
| --- | ---: | --- |
| `$FFF0` | `$E05B` | SCI |
| `$FFF2` | `$E05B` | timer overflow |
| `$FFF4` | `$E022` | timer output compare |
| `$FFF6` | `$E05C` | timer input capture |
| `$FFF8` | `$E032` | IRQ |
| `$FFFA` | `$E388` | SWI |
| `$FFFC` | `$E387` | NMI |
| `$FFFE` | `$E388` | reset |

## Next analysis stages

1. Follow code reachable from reset (`$E388`) and the active interrupts, while
   separating code from tables.
2. Identify the Bally 6803 memory map, PIA accesses, RAM variables, and the
   main game loop.
3. Label switch, scoring, bonus, lamp, solenoid, and game-state routines.
4. Continue converting unclassified `dc.b` regions in the canonical assembly
   into annotated instructions as Ghidra analysis confirms them.
5. Run `src/originals/asm/build.ps1 -SkipPackaging` after source changes to
   validate the 16 KiB image, vectors and two-pass startup checksum. The
   final eight-bit ROM sum must be `$FF`. Omit `-SkipPackaging` locally to
   package the rebuilt CPU with supplied sounds as
   `VisualPinballX/VPinMAME/roms/eballchp.zip`.
6. Validate canonical and modified builds in PinMAME before treating them as
   runnable or suitable for an EPROM.

## Local tools

- DASM 2.20.14.1 is the 6803-capable assembler used by every `build.ps1`;
  `tools/Get-Dasm.ps1` downloads and verifies the build for the host OS. Full
  recompilation instructions are in
  `src/originals/asm/readme.txt`.
- libpinmame runs each tree's `asm/test-pinmame.ps1` boot test (PowerShell 7);
  `tools/Get-LibPinmame.ps1` downloads and verifies it.
- Ghidra is installed with the GhidraMC6800 extension. Use
  `MC6801:BE:16:default` for this ROM; do **not** decode it as Ghidra's
  built-in 6809 language.
- Visual Pinball X and PinMAME provide the observation/test environment.  The
  known-good ROM archive is also present at
  `VisualPinballX/VPinMAME/roms/eballchp.zip`.

### Game tests

`tools/Invoke-GameTests.ps1` (PowerShell 7) plays each tree's ROM in
libpinmame and checks what it does against the tree's documents. It builds
each tree once, boots that tree's own packaged zip in a private folder, runs
every `tests/**/*.tests.ps1` file in its own `pwsh`, prints one `PASS` or
`FAIL` line per test, and writes `build/game-tests/report.txt`. A pass shows
the emulated ROM followed those rules; it says nothing about physical
hardware.

```
pwsh tools/Invoke-GameTests.ps1                 # all trees
pwsh tools/Invoke-GameTests.ps1 -Tree originals -Path tests/kit
pwsh tools/Test-GameTestRunner.ps1              # checks the runner itself
```

`tests/kit/` runs on every tree, `tests/<tree>/` on that tree
(`tests/<tree>/long/` only with `-Long`), and a comparison file when both of
the trees it names are selected. A file that crashes, hangs or prints no
result counts as a failure. A test marked `[seeded]` wrote RAM to reach its
starting state instead of playing there; the summary line counts them.

The `temp/` and `other-examples/` directories are older Bally examples and use
different hardware/toolchains; they are reference material, not build inputs
for this machine.

## Burning ROM
Weebly board: you need a blank M27C160 chip
