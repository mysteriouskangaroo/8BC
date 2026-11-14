# Loop score change variation

This is an independent copy of `src/originals/` for behavior-changing work.
The canonical analysis, source, ROMs, and build flow remain unchanged under
`src/originals/`.

## Rule changes

- Switch 05 **Saucer**, when fully lit: 100,000 becomes 10,000.
- Switch 12 **Left Rollover Button** and switch 13 **Right Rollover Button**:
  the ten normal levels become 1,000 through 10,000 instead of 10,000 through
  100,000. The original table's separate 5,000 fallback is preserved.
- Both changes continue to use the original playfield double/triple scoring
  multiplier.

The instruction-level implementation and rationale are commented directly in
`asm/modules/20_scoring_and_switch_rules.asm` and
`asm/modules/30_drop_targets_and_game_rules.asm`. A concise verification
record is in `notes/SCORING_CHANGES.md`.

## Build and deploy

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\src\loop-score-change\asm\build.ps1
```

This writes all generated files under `src/loop-score-change/build/`, compares
the result with the immutable canonical CPU ROM, packages the variation CPU
with the unchanged canonical sound ROMs, and deploys the complete set to:

```text
VisualPinballX/VPinMAME/roms/eballchp.zip
```

Run the variation smoke test with:

```powershell
powershell -ExecutionPolicy Bypass -File .\src\loop-score-change\asm\test-pinmame.ps1
```

Do not use `-RequireByteIdentical` for this variation: its rule changes are
supposed to differ from the canonical ROM. Building or testing
`src/originals/asm/` remains a separate canonical flow; whichever build runs
last supplies the ZIP currently installed for Visual Pinball.
