# Editable rules-ROM workspace

This directory is deliberately separate from `src/originals/`.

- `ghidra/` is an independent copy of the original analysis project. Make
  behavior-specific annotations here; canonical analysis remains in
  `src/originals/ghidra/`.
- `asm/` will receive a copy of the verified source from
  `src/originals/asm/` when behavior-changing work on this variation begins.
- `build/` will hold generated 16 KiB modified game-ROM images, assembler
  listings, and verification reports.
- `notes/` will hold rule-change proposals, hardware-map notes, and emulator or
  machine test results.

There is intentionally no variation `.asm` source yet. The canonical source
now lives in `src/originals/asm/` and produces a verified 16 KiB ROM. Copy it
here immediately before the first rule change, then keep all byte-changing
edits and modified ROM products inside this variation.
