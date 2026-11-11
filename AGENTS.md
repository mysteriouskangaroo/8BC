Never modify the ROM files in `src/originals/roms/`.

Perform the initial, canonical analysis of the original ROM in
`src/originals/ghidra/`, then copy that Ghidra project to a named variation
directory (currently `src/loop-score-change/ghidra/`). Make experimental
analysis changes, source edits, and ROM modifications only in that variation.

## Eight Ball Champ analysis references

Before naming hardware or changing game behavior, start with
`src/originals/ghidra/HARDWARE_MAP.md`. It records the evidence-backed memory
map, interrupt flow, and the ROM-to-schematic links already established.

Use the canonical Ghidra project at `src/originals/ghidra/EightBallChamp.gpr`
to follow the annotated code. The most useful anchors are reset at `E388`, the
timer-output interrupt at `E022`, periodic I/O refresh at `E28C`, and the
momentary-solenoid helper at `F5DF`. The labels and comments in that project
are generated reproducibly by `tools/ghidra_scripts/AnnotateEightBallChampHardware.java`.

The operations manual is `docs/Eight_Ball_Champ_OPS.pdf`; its schematic
section is the physical-hardware authority. Cross-check a proposed switch,
lamp, coil, or display name against both that manual and the ROM/Ghidra use
before treating it as final. The supplied scan contains the lamp and solenoid
driver sheets but does not contain all CPU/PIA sheets, so leave any remaining
U7/U8 package assignment or signal purpose explicitly untraced.

For a behavior mod, trace the relevant event from an interrupt or main-loop
caller, through its RAM state and PIA writes, then make the change only in the
named variation. Keep the canonical project and its original ROM as the
reproducible reference point.
