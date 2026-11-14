Never modify the ROM files in `src/originals/roms/`.

Perform the initial, canonical analysis of the original ROM in
`src/originals/ghidra/`. The purpose of `src/originals/` is not merely to
archive a Ghidra database: it is the canonical, understandable reconstruction
of the original program from which all later rule changes will begin.

Create and maintain commented, reassemblable 6803/DASM source under
`src/originals/asm/`. It may be reorganized into readable modules and improved
with labels, constants, comments, and analysis-driven restructuring. Unknown
regions may remain byte declarations until they are understood. The permanent
requirement is a valid, behaviorally faithful 16 KiB ROM mapped at
`C000-FFFF`, not the original assembler's exact byte sequence. Compare each
canonical build with `src/originals/roms/u3_cpu.128` and report all differences
and both hashes. Byte identity is a valuable bootstrap/regression check, but
deliberate restructuring or equivalent instruction encodings may change the
hash. SHA-1 `25D310F169B92CE6B348330816DDC3B5710E57DA` identifies only the
immutable reference ROM.

Treat every canonical output as if it may be burned to an EPROM and installed
in a machine. Require a successful assembly, exactly 16 KiB of output, valid
vectors and address layout, no unresolved or overlapping regions, and a
recorded build hash. Validate it in PinMAME before calling it runnable. Test
boot/attract, switch handling, lamps, displays, sounds, solenoids, scoring,
ball start/end, tilt, and service diagnostics in proportion to the changed
areas. Give timing-sensitive interrupt, PIA, lamp-refresh, switch-scan, and
momentary-solenoid paths extra scrutiny; an emulator boot alone is not proof
that a ROM is safe for physical hardware.

As part of a successful build, package the rebuilt CPU image together with
the three unchanged sound ROMs from `src/originals/roms/` as
`VisualPinballX/VPinMAME/roms/eballchp.zip`. Never source the sound ROMs from
an existing ZIP, and never alter the immutable copies. Preserve the first
pre-build archive as a recoverable backup. The PinMAME smoke test must
exercise the exact complete archive produced by the build, not construct a
different test-only ROM set.

Every CPU-ROM build must preserve the machine's internal startup integrity
check. Assemble in two passes: generate the compensation byte at `C000`,
reassemble so the listing and ROM agree, and require the eight-bit sum of all
16 KiB from `C000-FFFF` to equal `FF` before comparing, packaging, or testing.
Never bypass the check in a hardware-targeted image. The canonical value is
`88`; variations will usually generate another value. A finite-frame PinMAME
run can falsely pass while the CPU spins in the checksum-failure loop at
`E3E0`, so process survival is not a substitute for this build-time check.

Do not overstate the automated PinMAME smoke test. A successful finite-frame
run proves only that PinMAME loaded the ROM, executed the CPU, and exited
cleanly; it can even pass while startup is stuck in a tight loop. It does not
validate boot completion, game rules, or physical outputs. Interactive
gameplay and service-mode testing are still required
before calling an image gameplay-ready, and timing/safety review of hardware
I/O is required before calling it suitable to burn and install in a machine.

After the canonical Ghidra analysis and assembly source are verified, copy
them to a named variation directory (currently
`src/loop-score-change/ghidra/` and `src/loop-score-change/asm/`). Make
behavior-changing source edits, experimental restructuring that changes the
binary, and ROM modifications only in that variation. A variation must always
be traceable back to the validated canonical source and its recorded build.

## Eight Ball Champ analysis references

Before naming hardware or changing game behavior, start with
`src/originals/ghidra/HARDWARE_MAP.md`. It records the evidence-backed memory
map, interrupt flow, and the ROM-to-schematic links already established.

Use the canonical Ghidra project at `src/originals/ghidra/EightBallChamp.gpr`
to follow the annotated code. The most useful anchors are reset at `E388`, the
timer-output interrupt at `E022`, periodic I/O refresh at `E28C`, and the
momentary-solenoid helper at `F5DF`. The labels and comments in that project
are generated reproducibly by `tools/ghidra_scripts/AnnotateEightBallChampHardware.java`.
For a playfield-switch change, begin at the five-strobe/eight-return matrix
scan at `E1F0` (`0020` drives the strobe; `0022` reads returns), then use the
number-to-feature table in `HARDWARE_MAP.md` before looking for the game-rule
handler.

The operations manual is `docs/Eight_Ball_Champ_OPS.pdf`; its schematic
section is the physical-hardware authority. Cross-check a proposed switch,
lamp, coil, or display name against both that manual and the ROM/Ghidra use
before treating it as final. The supplied scan contains the lamp and solenoid
driver sheets but does not contain all CPU/PIA sheets, so leave any remaining
U7/U8 package assignment or signal purpose explicitly untraced.

Use the exact switch and solenoid names printed on page 1-18 when documenting
the self tests. Two resolved exceptions must not be made ambiguous again:

- An actual-machine switch test establishes switch 26 as **Lane Change
  (Cabinet)** and switch 32 as **Spinner**, despite the reversed names printed
  on page 1-18.
- Page 1-18's solenoid-test numbering conflicts with the numbered locator
  drawing on page 1-19 and with some replacement manual scans. The ROM's
  automatic solenoid-test sequence confirms page 1-18, so use page 1-18 for
  test numbers and names. Use the schematics and driver-location table for
  connector pins, wiring, and physical driver identities; do not take
  self-test numbering from the page 1-19 locator drawing.

Keep documentation at the right level:

- `HARDWARE_MAP.md` records physical mappings, memory-mapped hardware, and
  concise notes resolving source discrepancies. Do not put lengthy ROM traces,
  scoring rules, or animation behavior there.
- Put instruction-level evidence, local control-flow explanations, and useful
  names directly into the canonical Ghidra program through the reproducible
  annotation scripts. Detailed proof belongs in code comments, not as a long
  preamble to a hardware table.
- Use `GAME_RULE_TRACES.md` for readable cross-function explanations of
  scoring, state, lamps, sounds, and other game behavior that cannot be
  understood from one local code comment.
- Carry established names and explanations from Ghidra into the canonical
  assembly source. The source, not only the Ghidra database, must remain a
  useful basis for later rule work.

For a behavior mod, trace the relevant event from an interrupt or main-loop
caller, through its RAM state and PIA writes, then make the change only in the
named variation. Keep the canonical project and its original ROM as the
reproducible reference point.

For scoring changes, distinguish stable gameplay state from blinking output
shadows. In particular, determine playfield double/triple from the authoritative
CHAMP completion state at `10C0`, not from a lamp-animation byte. Preserve
this distinction in both comments and new rules.
