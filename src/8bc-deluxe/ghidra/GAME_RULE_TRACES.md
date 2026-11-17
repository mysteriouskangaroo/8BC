# Eight Ball Champ Game-Rule Traces

This note records cross-function behavior for the Eight Ball Champ Deluxe
variation, building on the canonical original-ROM analysis in
`../../originals/ghidra/GAME_RULE_TRACES.md`. It follows physical events
through dispatchers, gameplay state, scoring, lamps, sounds, and output queues.
Physical addresses, player-memory allocations, switch-matrix positions, and
driver identities remain in [HARDWARE_MAP.md](HARDWARE_MAP.md).

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

## Deluxe startup speech prefix

The canonical startup path tests speech-enable bit 6 at `$168D` from
`$C45B-$C460`. If speech is disabled it branches directly to `$C483`, so the
Deluxe prefix is skipped with the original announcement. When speech is
enabled, `$C462-$C46B` preserves the original `$0258`-tick pre-announcement
delay through countdown word `$10B3`, then the Deluxe hook at `$C46D` enters
`DELUXE_PREPEND_STARTUP_SUPER`.

The Deluxe helper sends Squawk & Talk command `$6F` through `$C27E`, restores
the displaced `LDAB $161F` without adding another countdown, and returns to
`$C470`. The canonical code immediately derives the configured ball-count
command and sends it at `$C47A`. The final sound-board sequence is therefore
`$6F` (Super), followed directly by the unchanged 3-ball or 5-ball Eight Ball
announcement. The sender at `$C28D-$C2B1` writes the low nibble through 6803
port 2, strobes port 3 bit 4, then writes the high nibble.

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

## Pool-ball drop targets: Called ball or scaled first-sink award

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
| `10C4` | Current called-ball speech ID (`51-57` for odd players, `59-5F` for even players) |
| `10C5` | Physical-closure latch for the five drop-target switch groups |
| `10BF` | Mask for the five physical 5,000 drop-target lamp effects |

The original ball-start speech path loads `10B3` with `03C0`, and the call
selector at `C37F-C382` refuses to choose a target until that countdown reaches
zero. Deluxe hooks the accepted normal-play switch event at `E63A`, where B is
the even handler-table offset, and clears `10B3` on the first genuine scoring
or playfield closure while `10C4` is still zero. The offset filter excludes
outhole, credit/coin, tilt/slam, unused positions, and the cabinet Lane Change
button. The dispatcher then resolves and calls the original switch handler as
before. Because the hook is disabled as soon as `10C4` contains the selected
speech ID, later reminders retain the original timer behavior.

On a new physical closure, either handler first sets the corresponding bit in
`10C5`. If that bit was already set, it returns without scoring again while
the switch remains closed. For a ball not yet recorded in `10C3`, the path at
`CE07` calls `DELUXE_AWARD_POOL_BALL_FIRST_SINK` before recording the ball's
bit. The helper reproduces the canonical `CE1A-CE28` conversion from target bit
to the current player's speech ID and compares it with `10C4`.

When the IDs differ, it applies Deluxe's divide-by-ten score scale to the
normal 2,500 playfield value and awards **250 Deluxe points** through the
current CHAMP playfield multiplier. When the IDs match, it instead awards that
player's Called ball score through the same multiplier. The per-player value
starts at 10,000 playfield / 1,000 displayed and advances by 10,000 playfield /
1,000 displayed after each successful call. The collected 8-ball path at
`CFAE` also awards and advances this value. After restoring any reversible
called-lamp overlay, that hook clears both the stale call ID at `10C4` and the
16-bit reminder delay at `10B3-10B4`; the canonical selector can therefore
choose the new rack's first solid or stripe immediately instead of interpreting
the 8-ball reminder as a numbered target. Active state is at `110E`; parallel
player values are at `110F-1112` and use the existing `C4E6` new-game and
`C603` player-restore hooks, so drains preserve the value while a new game
resets every player to 10,000. Restore and award both normalize a zero legacy
record to the initial value before scoring, allowing existing NVRAM to migrate
without producing a zero-point first award.

Both first-sink outcomes also start the reversible sunk-ball award display.
The uncalled branch formats 250/500/750 directly from authoritative multiplier
state `10C0`. The called-ball helper multiplies the pre-advance value at `110E`
by the same 1x/2x/3x state, converts the resulting 1-765 displayed-thousands
value to the canonical seven digit-byte format at `111F-1125`, and then queues
the real score normally. Thus the visual value is the exact award for that hit,
including the collected 8-ball path, rather than the later incremented Called
ball value.

On the first popup, `DELUXE_BEGIN_SUNK_BALL_SCORE_DISPLAY` copies the four
seven-byte score buffers at `1046-1061` to `112B-1146` and records the scoring
player at `1127`. The periodic `C14E` hook alternates the formatted award and
blank digits on only the other three buffers for roughly three seconds. The
scoring player's buffer is never replaced, so pending-score transfer continues
to update and display it. Expiry, the `C765` end-of-ball bonus entry, or
`DELUXE_INITIALIZE_BALL` restores only the three displaced buffers. Restoring at
`C765` also guarantees later bonus, replay, and high-score logic cannot inspect
temporary display values. A second sink while active retains the original
backup, replaces the formatted value, and reloads the full timer, preventing an
overlay from being saved as another player's real score.

The visual call indication uses the same authoritative `10C4` ID and hooks the
original lamp-flash block at `C1AC`, after its established divider and gameplay
gates. This is important: toggling from the earlier `C14E` periodic entry can
run faster than PinMAME's lamp-smoothing boundary and appear steady. The hook
first reproduces the displaced five-lamp `103F`/`10BF` operation, then overlays
the individual called lamp at the canonical visible cadence. Byte `1113`
records which called ID is currently XORed into the shadow, allowing the next
edge to restore it before the call moves or ends.

The manual/PinWiki lamp rows identify fourteen individual Phase-A lamps: Drop
Target 1-7 and Drop Target 9-15. PinMAME's Bally 6803 connector conversion and
the ROM serializer at `E107-E1EF` map targets 1-7 to `103B` bits 0-6 and
targets 9-15 to `103C` bits 0-6. Called speech IDs `51-57` select the first
byte and `59-5F` select the second; the low three ID bits select the exact lamp
bit. The five shared 5,000 target lamps remain at `103F` bits 0-4. A ball
already set in `10C3` is omitted, so a sunk ball cannot continue carrying the
called indication. The complete physical and emulator mapping is recorded in
[HARDWARE_MAP.md](HARDWARE_MAP.md).

## Deluxe Phase-B "more" indicators

The directional orbit sweep has been removed. Orbit collect activation no
longer starts a timer or substitutes an H/A/M output pattern; `1040` remains
the continuously displayed authoritative C-H-A-M-P state.

The Phase-B serializer hook at `E111` remains because extended completed-rack
and B-A-L-L counts still need output-only "more" blinks. Only when either
counter exceeds its physical lamps does `DELUXE_SELECT_PHASE_B_LAMP_OUTPUT`
copy `1040-1045` to `1119-111E`. It preserves copied byte `1040` exactly and
changes only the applicable rack or B-A-L-L bits before returning the temporary
buffer to the unchanged serializer. With neither extended indication active,
the helper returns live `1040` directly, matching the original fast path.

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

## Saucer 100,000 relight qualification

The saucer state in `10C1` still progresses through 2x (`01`), 3x (`02`), 5x
(`04`), and the post-5x/100,000 state (`08`). When the player collects 5x,
`DELUXE_HANDLE_HOLE_STATE` clears any stale waiting flag and sets the
authorization before the original dispatch advances `10C1` to `08`. The first
100,000 therefore lights immediately, independent of the collect feature, while
the same `08` state keeps the end-of-ball bonus at 5x.

The three paths that end an active collect call
`DELUXE_RELIGHT_100000_ON_COLLECT_DEACTIVATION` only after storing the next
inactive state: the right-orbit chase advances to spinner inactive, spinner
inactivity advances to left-orbit inactive, and the left-orbit chase advances
to right-orbit inactive. The helper requires both `10C1` bit `08` and the
waiting flag, then clears waiting and sets the generic collect-deactivation
authorization. Consequently, every active collect can relight 100,000 after its
previous award has been collected, while a completion during the initial lit
award is a no-op. The inactive-to-active pool-ball helper has no 100,000 side
effect.

Collecting 100,000 awards the existing scaled 10,000 through its original
multiplier-aware path, clears the authorization, and restores the waiting flag.
The next active-to-inactive transition at any collect stage can therefore
relight exactly one more award.

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
When the collect state at `10FB` is not spinner-active, the hook also loads the
temporary preview timer at `1114`. `DELUXE_PERIODIC_TICK` alternates the live
lamp mask at `10B1` between the accumulated value in `10FE` and zero for about
three seconds, then leaves it hidden. The `$BF` reload also aligns bit 4 so the
preview begins with a complete visible phase. This is output state only: the switch-32
handler continues to authorize the accumulated award solely from `10FB`, so a
spinner pulse during the preview follows the unlit 10-point path. Activating
spinner clears `1114` before displaying `10FE` steadily.

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

Testing triple first makes the intended precedence explicit. Deluxe's
`DELUXE_CHAMP_COMPLETION_COUNT` is the per-ball milestone counter; it writes
only the scoring states below to `10C0`:

| Value at `10C0` | Meaning for scoring |
| ---: | --- |
| `00` | Normal playfield value; fewer than two CHAMP completions this ball |
| `10` | **Double**; reached on the second CHAMP completion |
| `20` | **Triple**; reached on the fourth CHAMP completion |
| `E0` | **Triple** remains active; reached on the sixth completion and lights both outlane specials |

Switches 17 through 21 share the CHAMP-lane handler at `CAD4`. Each lane first
receives its scaled 300-point award (original 3,000) through `C9F3`, using the multiplier that was
already active. If the letter is new, the hook at `CAE4` checks its bit mask.
H (`02`), A (`04`), and M (`08`) always continue directly to the original
recording path. Only C (`01`) and P (`10`) test
`DELUXE_CHAMP_INLANE_REARMED` at `1148`. A locked C/P exits without changing
`1040`; its already-awarded lane score remains. An accepted C/P clears the
latch before the original handler records its bit. Because the test occurs
after the original already-lit check at `CAE0`, repeating an existing C/P does
not consume a valid rearm.

The normal-play dispatcher hook at `E63A` rearms `1148` only for verified
C011 table offsets belonging to either thumper/pop bumper, the saucer,
left/right orbit rollover, center rollover, spinner, numbered pool-ball drops,
and E-I-G-H-T targets. It excludes slings, the rebound, CHAMP lanes, outlanes,
cabinet/service and ball-management switches, and unused matrix positions. The
first new C/P of a ball is armed by `DELUXE_INITIALIZE_BALL`; thereafter one
qualifying shot permits one new C/P. H/A/M neither test nor consume this state.

When all five accepted letters are complete, the hook at `CB07` calls
`DELUXE_ADVANCE_CHAMP`. Its first action rearms the C/P latch at `1148`, so a
completed word makes the next new C or P immediately available irrespective
of which letter completed that word. Completions 2, 4, and 6 then select
double, triple, and the two outlane specials respectively. Consequently, the
lane that reaches a milestone still scores at the pre-milestone multiplier,
and the new multiplier begins with the next scoring event.

The periodic lamp-animation code at `C1B3-C1B8` XORs `10C0` into `1041`,
making the corresponding Double/Triple and later-completion lamps blink.
Because `1041` alternates as part of that animation, it is only an output
shadow and is not a safe rule condition. `10C0` is the stable source of truth.

The per-ball initialization entry at `C4F6` clears `10C0` at `C507`. Double,
triple, and the later-completion flags therefore last only for the current
ball; they are not a persistent per-player state restored on a later ball.
