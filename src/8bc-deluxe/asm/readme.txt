EIGHT BALL CHAMP DELUXE REASSEMBLY
=================================

Purpose
-------

This directory is the buildable 6803 source for the Eight Ball Champ Deluxe
rules variation. It began as a copy of the canonical source in
`src/originals/asm/`. Original ROM files under `src/originals/roms/` are
immutable build inputs and are never modified.

The source is split into address-ordered modules. Instructions recognized in
the canonical Ghidra project are represented as real DASM 6803 mnemonics.
Data and regions not yet confidently decoded remain explicit dc.b bytes. This
distinction is intentional: it gives us a working source base without
pretending that unknown data has already been understood.

The intended behavior is recorded in `../gamerules.md`. Expansion routines in
`modules/35_deluxe_rules.asm` implement those rules in verified original-ROM
FF padding at D3B2-DFFF. Small fixed-address hooks redirect the relevant
original handlers there; the comments at those hooks and routines are the
code-level rule trace.

Prerequisites
-------------

From the repository root, the build expects:

  dasm-2.20.14.1-win-x64/dasm.exe
  src/originals/roms/u3_cpu.128
  src/originals/roms/u3_snd.532
  src/originals/roms/u4_snd.532
  src/originals/roms/u5_snd.532

The reference CPU and sound ROMs are read but never modified.

Recompilation process
---------------------

From a PowerShell prompt at the repository root, run:

  powershell -ExecutionPolicy Bypass -File .\src\8bc-deluxe\asm\build.ps1

The script performs the structural build checks and records comparison data:

  1. Verifies the immutable reference ROM's SHA-1.
  2. Performs a first assembly with a generated checksum placeholder.
  3. Calculates the compensation byte at C000, then reassembles so the final
     listing and ROM contain that value.
  4. Requires exactly 16,384 bytes and an eight-bit ROM sum of FF, as required
     by the machine's startup check at E3DB-E40D.
  5. Validates that every interrupt/reset vector points inside C000-FFFF.
  6. Verifies every Deluxe fixed-address rule hook in the executable image.
  7. Compares every rebuilt byte with the reference ROM and records both
     hashes plus the number and first differences.
  8. Packages the rebuilt CPU ROM with the three immutable sound ROMs as
     VisualPinballX/VPinMAME/roms/eballchp.zip.

Generated files are written to ../build/:

  u3_cpu.rebuilt.128  rebuilt ROM
  u3_cpu.rebuilt.lst  assembler listing
  u3_cpu.rebuilt.sym  symbol table
  rom_checksum.inc    generated second-pass checksum value
  verification.txt   size, hash, and byte-comparison result

The packaged PinMAME set contains exactly these archive entries:

  u3_cpu.128   rebuilt CPU ROM
  u3_snd.532   unchanged sound ROM
  u4_snd.532   unchanged sound ROM
  u5_snd.532   unchanged sound ROM

Each successful build replaces VisualPinballX/VPinMAME/roms/eballchp.zip. If
an archive is already present and no backup has yet been made, the script
first preserves it at:

  src/8bc-deluxe/build/visual-pinball-package-backup/eballchp.pre-8bc-deluxe.zip

This local package is a generated deployment artifact. It does not modify the
reference ROM files in `src/originals/roms/`. Because the CPU ROM is
intentionally changed, VPinMAME can warn that its catalogue CRC or SHA-1 does
not match the original set. That audit warning is expected. The machine's own
additive startup checksum is separate and must still pass; `build.ps1`
calculates and verifies its compensation byte on every build.

A structurally valid Deluxe build reports PASS while also recording every byte
that differs from the original. Byte identity is not expected for this rules
variation. PinMAME validation and targeted gameplay/service tests are still
required before treating a changed image as runnable. Timing-sensitive I/O and
solenoid paths require additional care before burning a physical EPROM.

PinMAME smoke test
------------------

After a successful build, run the automated smoke test from the repository
root:

  powershell -ExecutionPolicy Bypass -File .\src\8bc-deluxe\asm\test-pinmame.ps1

By default it runs 600 unthrottled frames. Use -Frames to request a longer
run. The script:

  1. Runs build.ps1 and all structural ROM checks.
  2. Copies the complete package emitted by build.ps1 into an isolated test
     directory without changing any of its entries.
  3. Uses isolated config, NVRAM, snapshot, and wave directories.
  4. Runs PinMAME for the requested frame count and requires exit code zero.

The build deliberately changes VisualPinballX/VPinMAME/roms/eballchp.zip; the
smoke test does not change that package or any other Visual Pinball files. The
smoke test proves that PinMAME can load, reset, and continue executing the
complete packaged ROM set. It does not prove the rules or physical outputs.
Before a ROM is considered gameplay-ready, exercise attract mode, game start,
drain and ball transitions, scoring, tilt, switches, lamps, displays, sounds,
and all service tests. Before burning an EPROM, review timing-sensitive
interrupt and momentary-solenoid changes separately.

The interactive rule checklist is in ../gamerules.md. For the spinner collect,
each pulse during the active collection window must score and restart the
approximately two-second inactivity timer. A further pulse inside that window
continues the same collect. Only two seconds with no further pulse means the
spinner has stopped and advances the collect to the inactive orbit stage.

Source maintenance
------------------

Keep all module includes in ascending address order. Labels, comments,
constants, file boundaries, and code structure may be improved while
preserving behavior, address-dependent data, hardware timing, and all updated
references. Replace dc.b regions with instructions only after the canonical
Ghidra analysis establishes that they are code, and run build.ps1 after every
such change.

The initial modules were bootstrapped by
tools/ghidra_scripts/ExportEightBallChampCanonicalAsm.java after running the
canonical hardware and rules annotation scripts. Re-exporting overwrites the
module files, so do it only deliberately and review the diff; normal source
maintenance should edit the assembly directly.

Variation boundary
------------------

Make Deluxe rule changes here, not in `src/originals/`. Keep the canonical
analysis/source and every file in `src/originals/roms/` unchanged. Preserve
fixed addresses unless all incoming references and timing consequences have
been traced, then rerun both the build and PinMAME smoke test after each
executable change.
