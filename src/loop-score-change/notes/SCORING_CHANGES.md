# Scoring changes

This variation changes two rule paths while retaining the original switch
dispatch, scoring accumulator, decimal carry logic, and playfield
double/triple multiplier.

## Fully lit saucer

Switch 05 dispatches to the saucer handler at `$D04A`. When bit `0x08` of
state byte `$10C1` is set, the original call at `$D070` targets `$C96C`, which
awards 100,000 through the playfield multiplier. The variation retargets that
single call to `$C9A4`, the existing 10,000-point multiplier-aware helper.
The ordinary 500-point saucer branch and its `01 -> 02 -> 04 -> 08`
progression through the 2x, 3x, and 5x lamps are unchanged. As a regression
check, bytes `$D04A-$D079` now differ from the canonical ROM only at `$D072`,
the low byte of the terminal helper call (`C96C -> C9A4`).

## Left and right rollover buttons

Switches 12 and 13 enter the shared handler at `$CB53` and `$CB4F`. The
original lamp-level lookup produces index 2 through 11 for the ten normal
values and dispatches through a table to 10,000 through 100,000-point helper
entries.

The variation replaces only that pointer dispatch with a call to the new
fixed-address routine at `$CC32`. It subtracts one from normal indices 2
through 11 and passes 1 through 10 to the existing generic thousand-point
helper at `$C9F9`, producing 1,000 through 10,000. Index 1 retains the
original table's distinct 5,000-point fallback through `$C9EF`.

## Verification

The variation build remains exactly 16,384 bytes with all eight vectors still
inside `$C000-$FFFF`. Its two-pass build generates the checksum compensation
byte at `$C000` and refuses to package unless the machine's startup sum is
`$FF`. The build report records its SHA-1 and all byte differences from
`src/originals/roms/u3_cpu.128`. The canonical source must continue to pass
its own `-RequireByteIdentical` build independently.

Verified build results:

- Canonical build SHA-1: `25D310F169B92CE6B348330816DDC3B5710E57DA`
  (byte-identical to the immutable reference).
- Variation build SHA-1: `369F2C3DD1CEFB8D65D4AF2BFE2F1808AED541D3`.
- Generated checksum compensation: `$E6` at `$C000`; final sum `$FF`.
- Intentional byte differences from canonical: 34, including the generated
  checksum byte.
- Variation-specific opcode checks: passed.
- Canonical PinMAME smoke test: 600 frames, exit code 0.
- Variation PinMAME smoke test: 600 frames, exit code 0. PinMAME reports the
  expected checksum mismatch because this is deliberately not the registered
  original CPU ROM; the local VPinMAME configuration permits modified ROMs.
