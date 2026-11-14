EIGHT BALL CHAMP CANONICAL REASSEMBLY
====================================

Purpose
-------

This directory is the readable, reassemblable form of the original 16 KiB
6803 CPU ROM. It is canonical analysis material, not a rules variation. Its
contract is to preserve the original game's behavior and hardware interface;
it does not have to reproduce the original assembler's exact byte sequence.

The source is split into address-ordered modules. Instructions recognized in
the canonical Ghidra project are represented as real DASM 6803 mnemonics.
Data and regions not yet confidently decoded remain explicit dc.b bytes. This
distinction is intentional: it gives us a working source base without
pretending that unknown data has already been understood.

Labels, RAM names, hardware-register names, and instruction comments are
exported from the canonical Ghidra project. Cross-function explanations remain
in ../ghidra/GAME_RULE_TRACES.md and should be reflected in local source
comments as the corresponding routines are refined.

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

  powershell -ExecutionPolicy Bypass -File .\src\originals\asm\build.ps1

The script performs the structural build checks and records comparison data:

  1. Verifies the immutable reference ROM's SHA-1.
  2. Assembles main.asm with DASM's 6803 processor definition.
  3. Requires the output to be exactly 16,384 bytes.
  4. Validates that every interrupt/reset vector points inside C000-FFFF.
  5. Compares every rebuilt byte with the reference ROM.
  6. Records the rebuilt SHA-1 and the number and first differences.
  7. Packages the rebuilt CPU ROM with the three immutable sound ROMs as
     VisualPinballX/VPinMAME/roms/eballchp.zip.

Generated files are written to ../build/:

  u3_cpu.rebuilt.128  rebuilt ROM
  u3_cpu.rebuilt.lst  assembler listing
  u3_cpu.rebuilt.sym  symbol table
  verification.txt   size, hash, and byte-comparison result

The packaged PinMAME set contains exactly these archive entries:

  u3_cpu.128   rebuilt CPU ROM
  u3_snd.532   unchanged sound ROM
  u4_snd.532   unchanged sound ROM
  u5_snd.532   unchanged sound ROM

Each successful build replaces VisualPinballX/VPinMAME/roms/eballchp.zip. If
an archive is already present and no backup has yet been made, the script
first preserves it at:

  src/originals/build/visual-pinball-package-backup/eballchp.pre-build.zip

This local package is a generated deployment artifact. It does not modify the
reference ROM files in src/originals/roms/.

A structurally valid build reports PASS even when deliberate restructuring
changes its bytes. To require the original byte sequence while checking the
initial reconstruction or an intentionally unchanged baseline, run:

  powershell -ExecutionPolicy Bypass -File .\src\originals\asm\build.ps1 -RequireByteIdentical

Byte identity is useful evidence, but it is not the permanent definition of
correctness. PinMAME validation and targeted gameplay/service tests are
required before treating a changed image as runnable. Timing-sensitive I/O
and solenoid paths require additional care before burning a physical EPROM.

PinMAME smoke test
------------------

After a successful build, run the automated smoke test from the repository
root:

  powershell -ExecutionPolicy Bypass -File .\src\originals\asm\test-pinmame.ps1

By default it runs 600 unthrottled frames. Use -Frames to request a longer
run, or -RequireByteIdentical when testing an intentionally unchanged source
baseline. The script:

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

Beginning a rules variation
---------------------------

Do not intentionally change game rules here. Once this canonical build passes
its structural checks and PinMAME validation, copy this source tree to a named
variation such as src/loop-score-change/asm/. Make
scoring, control-flow, or other byte-changing edits only in that variation.
The variation should retain its own build output and a documented comparison
against this canonical source.
