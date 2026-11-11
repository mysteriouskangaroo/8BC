# Editable rules-ROM workspace

This directory is deliberately separate from `src/originals/`.

- `ghidra/` is an independent copy of the original analysis project. Make all
  Ghidra annotations and code/data decisions here; preserve
  `src/originals/ghidra/` as the baseline.
- `asm/` will hold hand-curated 6803/DASM source once Ghidra analysis confirms
  which bytes are code and which are data.
- `build/` will hold generated 16 KiB modified game-ROM images, assembler
  listings, and verification reports.
- `notes/` will hold rule-change proposals, hardware-map notes, and emulator or
  machine test results.

There is no editable `.asm` source yet. The next task is to use the Ghidra
project in `src/originals/ghidra/` to identify and document routines before
creating source here.
