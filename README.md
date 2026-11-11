# Eight Ball Champ rules-ROM project

This project documents and modifies the game logic for the 1985 Bally/Midway
**Eight Ball Champ** pinball machine.  The target is the game-ROM code running
on the original Motorola 6803 MPU; the original displays, lamps, switches,
solenoids, sound board, and MPU remain in use.

## Scope and preservation

`src/originals/roms/` is immutable reference material.  In particular,
`u3_cpu.128` is the original 16 KiB game ROM, mapped from `$C000` through
`$FFFF`.  Its verified SHA-1 is:

```
25d310f169b92ce6b348330816ddc3b5710e57da
```

No work product overwrites that file.  Future modified images belong under
`src/new-roms/build/` and must be compared against this baseline.

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
| `src/originals/roms/` | Untouched CPU and sound ROMs. |
| `src/originals/ghidra/` | Ghidra project analyzing the untouched CPU ROM. |
| `src/new-roms/ghidra/` | Independent Ghidra working copy for labels, comments, and analysis edits. |
| `src/new-roms/asm/` | Hand-curated, reassemblable DASM source as it is reconstructed. |
| `src/new-roms/build/` | Generated modified ROM images and listings; never an original ROM. |
| `src/new-roms/notes/` | Rule changes, hardware map notes, and testing records. |

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
4. Convert confirmed regions into an annotated, reassemblable source tree.
5. Use the local DASM installation to create a fixed-address 16 KiB image and
   prove that an unmodified rebuild is byte-identical to the original before
   changing any rule.

## Local tools

- `dasm-2.20.14.1-win-x64/dasm.exe` is the local 6803-capable assembler we
  will use only after the source is accurately reconstructed.
- Ghidra is installed with the GhidraMC6800 extension. Use
  `MC6801:BE:16:default` for this ROM; do **not** decode it as Ghidra's
  built-in 6809 language.
- Visual Pinball X and PinMAME provide the observation/test environment.  The
  known-good ROM archive is also present at
  `VisualPinballX/VPinMAME/roms/eballchp.zip`.

The `temp/` and `other-examples/` directories are older Bally examples and use
different hardware/toolchains; they are reference material, not build inputs
for this machine.
