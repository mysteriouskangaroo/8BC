# Eight Ball Champ Game-Rule Traces

This note accompanies the canonical Ghidra analysis of the original,
read-only ROM. It follows physical events through the ROM's dispatchers,
gameplay state, scoring, lamps, sounds, and output queues. Physical addresses,
switch-matrix positions, and driver identities remain in
[HARDWARE_MAP.md](HARDWARE_MAP.md).

Each trace should start with an input or scheduled event, identify its handler,
follow all material RAM changes and helper calls, and end at the observable
game behavior. Names are treated as final only after the manual and ROM agree.

The detailed names and instruction-level comments are applied to the Ghidra
program by `../../../tools/ghidra_scripts/AnnotateEightBallChampRules.java`,
separately from the physical-I/O annotations in
`AnnotateEightBallChampHardware.java`.
This document is the readable index and cross-function explanation; it is not
a substitute for annotating the actual code. The canonical binary keeps the
original control flow intact. Functional modularization belongs in the
reassemblable source of a named variation when rule changes begin.

## Switch 07: Rebound

Switch 07 is a useful first complete rule trace because the manual explicitly
calls it the **10 Point Rebound** (page 1-4) and its handler is small. The
canonical ROM path is:

```text
PIA0 scan E1F0 -> debounced event at 1026 mask 0x40
                  -> dispatcher E5BD -> table entry C013
                  -> Rebound handler CA95
                  -> sound command 0x22 + score gate
                  -> original 10/20/30-point queue at CA1B
                  -> pending score 0094-0099 -> displayed player score
```

The scan stores three related five-byte groups. Bytes run from strobe 0
through strobe 4; within each byte, bits 0 through 7 are returns 0 through 7:

| RAM | Meaning | Switch 07 location |
| --- | --- | --- |
| `1026-102A` | Latched, debounced new-closure events | `1026` mask `0x40` |
| `102C-1030` | Current raw samples | `102C` mask `0x40` |
| `1032-1036` | Previous raw samples | `1032` mask `0x40` |

At `E1FD-E213`, a closure is accepted only when it is present in the two most
recent samples and was absent in the older sample. The result is ORed into the
event byte, so the main loop cannot lose a short event before consuming it.

The normal-play dispatcher at `E5BD-E646` scans `1026-102A`, most-significant
bit first, clears one event bit, and uses its position to index the pointer
table at `C011`. Because Rebound is strobe 0 / return 6, it selects the word at
`C013`, which points to `CA95`.

`CA95` queues command `0x22` in `1024`; the periodic controller-to-sound-board
path consumes that byte. It then checks a common gate at `F4DF`: bits 7 and 6
of lamp-shadow byte `103A` must both be set or the handler exits without
scoring. `103A` is demonstrably part of the lamp refresh buffer, but the exact
physical lamp names represented by these two gate bits have not yet been
traced through the schematic, so they remain unnamed.

When the gate passes, `CA1B` adds one unit to the lowest pending-score digit
at `0094`. The canonical ROM displays that unit as 10 points; Deluxe's common
transfer at `F38C` deliberately maps it to **1 displayed point**. Every higher
pending class is likewise shifted down one decimal position. `FA1A` carries
decimal overflow through `0094-0098`, and `F38C` transfers the pending amount
into the active player's displayed score over subsequent main-loop passes.
The end-of-ball bonus is the exception to this queue path: its calls at
`C7F0-C7FB` and `C906-C90B` feed the BCD score adder directly, so Deluxe also
scales those constants from 10,000 + 5,000 to 1,000 + 500 per pool ball and
from 10,000 to 1,000 per E-I-G-H-T bonus step.

This trace establishes a reusable analysis pattern for the other playfield
switches: locate the event bit, resolve its `C011` table entry, follow the
handler's RAM changes and helper calls, then follow queued score, sound, lamp,
and solenoid work to their periodic output routines.

## Pool-ball drop targets: scaled 2,500 first sink and later scaled 5,000

The five switch groups numbered 25, 27, 28, 30, and 31 feed two shared rule
handlers. Their entries in the normal-play table are ordered by the
dispatcher's bit-7-to-bit-0 scan, not by ascending switch number:

| Switch | Page 1-18 name | Handler | Sunk-ball bit(s) |
| ---: | --- | --- | --- |
| 25 | Drop Target 1,2,9,10 | `CDD8`, paired | balls 1 then 2 (`10C3` bits 0, 1) |
| 27 | Drop Target 3,11 | `D005`, single | ball 3 (`10C3` bit 2) |
| 28 | Drop Target 4,5,12,13 | `CDD8`, paired | balls 4 then 5 (`10C3` bits 3, 4) |
| 30 | Drop Target 6,14 | `D005`, single | ball 6 (`10C3` bit 5) |
| 31 | Drop Target 7,15 | `D005`, single | ball 7 (`10C3` bit 6) |

The important state bytes have separate jobs:

| RAM | Meaning |
| --- | --- |
| `10C3` | Persistent seven-bit record of pool balls 1 through 7 already sunk |
| `10C5` | Physical-closure latch for the five drop-target switch groups |
| `10BF` | Mask for the five physical 5,000 drop-target lamp effects |

On a new physical closure, either handler first sets the corresponding bit in
`10C5`. If that bit was already set, it returns without scoring again while
the switch remains closed. For a ball not yet recorded in `10C3`, the path at
`CE07` calls `DELUXE_AWARD_SCALED_2500`, which applies Deluxe's global
divide-by-ten score scale to the 2,500 playfield value and therefore awards
**250 Deluxe points** through the current CHAMP playfield double/triple
multiplier before recording the ball's bit in `10C3`.

The paired switches require two first-sink hits. Switch 25 records ball 1 on
its first eligible hit and ball 2 on its next eligible hit; switch 28 does the
same for balls 4 and 5. Only after both bits belonging to the pair are set is
the group in its later-value state. The single switches need only their one
corresponding bit.

When the relevant sunk bit or bits are already set, the branch at `D034`
calls `C9EF`, awarding **500 Deluxe points** (original 5,000), again through
the current playfield multiplier. It also updates the physical 5,000 lamp effect through `10BF`
and lamp shadow `103F`.

The reset sequence explains how the physical target's return changes the next
hit without losing the sunk-ball state. `C6C9-C6F6` pulses reset selectors
`M0`, `M1`, `M2`, `M3`, and `M4`. After each pulse, `C6F7-C6FC` clears that
group's bit in `10C5`, rearming the switch for another closure. It deliberately
does **not** clear `10C3`. Consequently, the reset target comes back up, its
next closure is accepted, and the preserved sunk-ball bit selects the scaled
500 and the physical 5,000 lamp effect instead of the scaled 250 first-sink
award.
This is the ROM implementation of the observed rule, with the two paired groups
entering that later state only after both balls in the pair have first been
sunk.

## E-I-G-H-T stand-up targets: scaled 2,500 per hit

Switches 33-37 share the handler at `CC7C`. Its score call at `CC85` occurs
before the active-low letter-state test at `CC8D`, so every switch hit scores
whether or not that letter was already collected in the current round. Deluxe
redirects `CC85` to `DELUXE_AWARD_SCALED_2500`: the 2,500 playfield value is
divided by ten and awarded as **250 displayed points** through the current
CHAMP playfield multiplier (250 / 500 / 750 at 1x / 2x / 3x).

Only a new letter reaches the hook at `CC91`, clears its bit in `1045`, and
advances the Deluxe spinner value. An already-lit letter branches around that
hook, so it still scores 250 through `CC85` but does not advance the spinner.

## Playfield Scores Double and Triple

The authoritative gameplay byte is `CHAMP_COMPLETION_STATE` at `10C0`. New
rules should read this byte, not the blinking lamp-shadow byte at `1041`:

```c
if ((CHAMP_COMPLETION_STATE & 0x20) != 0) {
    /* Playfield Scores Triple is active. */
}
else if ((CHAMP_COMPLETION_STATE & 0x10) != 0) {
    /* Playfield Scores Double is active. */
}
else {
    /* The normal, single playfield value is active. */
}
```

Testing triple first makes the intended precedence explicit. The original
game generates only the valid states below, in which bits `0x10` and `0x20`
are mutually exclusive:

| Value at `10C0` | Meaning for scoring |
| ---: | --- |
| `00` | Normal playfield value; CHAMP has not yet been completed this ball |
| `10` | **Double**; first CHAMP completion |
| `20` | **Triple**; second CHAMP completion |
| `60` | **Triple** remains active; third CHAMP completion also recorded in bit `0x40` |
| `E0` | **Triple** remains active; fourth-or-later completion also recorded in bit `0x80` |

Switches 17 through 21 share the CHAMP-lane handler at `CAD4`. Each lane first
receives its scaled 300-point award (original 3,000) through `C9F3`, using the multiplier that was
already active. The handler then records that lane in `1040`; when all five
letters are complete, `CB07-CB23` advances `10C0` through
`00 -> 10 -> 20 -> 60 -> E0`. Consequently, the lane that completes CHAMP for
the first time still scores its pre-completion value, and **double begins with
the next scoring event**. The same timing applies when advancing to triple.

The periodic lamp-animation code at `C1B3-C1B8` XORs `10C0` into `1041`,
making the corresponding Double/Triple and later-completion lamps blink.
Because `1041` alternates as part of that animation, it is only an output
shadow and is not a safe rule condition. `10C0` is the stable source of truth.

The per-ball initialization entry at `C4F6` clears `10C0` at `C507`. Double,
triple, and the later-completion flags therefore last only for the current
ball; they are not a persistent per-player state restored on a later ball.
