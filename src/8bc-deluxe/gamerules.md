# Eight Ball Champ Deluxe game rules

This document translates `new-games-design-ideas/8 Ball Champ New Rules.pptx` into an implementation contract. The original ROM trace is used to resolve its descriptions of the existing rules and uncertain base values.

## Existing rules established in the original ROM

- Switch 32 is the spinner. Its original handler is at `$CA3B`.
- Spinner value/lamp state is stored at `$10B1`. The bit state is changed by completing the C-H-A-M-P rollovers. The three lamp bits represent 1,000, 3,000, and 5,000. Any subsequent completion of C-H-A-M-P after 5,000 keeps it at the 5,000 bit. 
- Switches 12 and 13 are the left and right rollover buttons. They enter the shared orbit-value handler at `$CB53` and `$CB4F`. Its first score-table entry calls `$C9EF`, establishing **5,000** as the unlit/default orbit score.
- The original orbit-value handler keeps the left and right values synchronized, advances the lit value by 10,000, and honors the operator setting that controls whether that value is retained between balls. At 100,000, it lights a special collect on each orbit. Thereafter, it continues to award 100,000 for each rollover.
- Switch 05 is the saucer/hole. State `$10C1` controls its progression through
  the 2x, 3x, and 5x bonus multipliers to the terminal 100,000-point state.
  Bit `$08` selects the repeatable 100,000-point saucer award at `$D070`,
  which is also affected by the current playfield multiplier. Once balls 1-7
  have been sunk (`$10C3 = $7F`), the saucer lights to collect the 8-ball. The
  next saucer hit runs the 8-ball collection routine at `$CEDC`: it advances
  the separate pool-bonus lamps in `$1044` through 120K, 240K, and
  120K+240K; clears the sunk-ball state for a new rack; and then continues
  through the normal saucer scoring/progression code at `$D069`.
- New pool balls are recorded in `$10C3`; their first-sink path is `$CE07`.
  They activate the current Deluxe collect location, but they are separate
  from the E-I-G-H-T targets and do not advance the spinner value.
- Switches 33-37 are the five dedicated E, I, G, H, and T stand-up targets.
  They share the original handler at `$CC7C`, whose active-low collected-letter
  state is `$1045`. A target hit clears its corresponding bit only if that
  letter was not already collected. When all five letters are collected, the
  original handler awards the next BALL letter and rearms E-I-G-H-T so each
  target can be collected again in the next round.
- CHAMP letters use `$1040`. Completing the five letters reaches `$CB07`, which originally advances the playfield score multiplier `$10C0` through double, triple, and special states. All multiplier-aware scoring helpers read `$10C0`.

## Deluxe collect feature

The collect feature has six ordered states:

`left orbit inactive -> left orbit active -> spinner inactive -> spinner active -> right orbit inactive -> right orbit active -> left orbit inactive`

In this section, a **newly sunk pool ball** means the first hit that changes
that ball's bit in `$10C3` from clear to set and lights its sunk-ball lamp.
Hitting a ball that is already sunk (its lamp is already on) follows the
existing 5,000-point path at `$D034`; it does **not** activate, move, restart,
or otherwise advance the collect feature.

1. Starting a new ball places the feature at **left orbit inactive**.
2. A newly sunk pool ball changes the current location from inactive to active;
   it does not change the location.
3. Collecting an active location clears its active state and advances to the
   next location's inactive state. The next newly sunk ball is required to
   activate that new location.
4. Sinking additional new pool balls while the current location is already
   active has no collect-state effect. They are not queued for later stages.
5. Hitting an inactive collect location does not advance the sequence.

### Left orbit

- When it is not active, switch 12 normally awards 5,000 and does not advance
  the shared orbit value. The original 100,000/special terminal state is the
  exception: once that state is lit, switch 12 continues through the original
  handler so its 100,000 award and special behavior are preserved regardless
  of the Deluxe collect's current location. This does not move the Deluxe
  collect unless it is active at the left orbit.
- When a newly sunk ball first activates the collect feature at the left orbit,
  the original 5,000 baseline is promoted to a lit 10,000 value. If the
  operator's retain setting has carried a higher orbit value forward, that
  higher value is preserved instead of being reduced to 10,000.
- When the left-orbit collect is active, switch 12 awards the current shared
  orbit value using the original handler and runs the original fast upward
  arrow-chase collect animation. Only after that animation finishes does it
  advance the value by 10,000, hide the orbit-value arrows, and move the
  feature to **spinner inactive**. A later newly sunk pool ball must activate
  the spinner.
- Collecting the left orbit also authorizes the saucer's eventual 100,000 award
  for the remainder of the ball.

### Spinner

- An unlit spinner scores 100 points per spin and does not use the playfield
  multiplier.
- The spinner collect begins at 1,000 at the start of every ball.
- While the feature is at spinner inactive, spinner pulses remain unlit 100-
  point shots. A newly sunk pool ball changes it to spinner active and displays
  its current value.
- Activating spinner collect only reveals its current value; activation does
  not advance that value.
- Each dedicated E-I-G-H-T target advances the spinner only when its letter was
  not already collected in the current E-I-G-H-T round. Repeated hits on an
  already-lit letter do not advance it.
- Completing E-I-G-H-T lights the next BALL letter through the original rules
  and resets the five-letter round, after which newly recollected E-I-G-H-T
  letters can advance the spinner again.
- The three independent value lamps form a binary counter with the exact
  sequence 1,000 -> 3,000 -> 4,000 -> 5,000 -> 6,000 -> 8,000 -> 9,000. It
  remains at 9,000 after reaching the top state.
- While the spinner collect is active, every spin scores its displayed value
  using the current 1x/2x/3x playfield multiplier.
- Spinner sounds follow the highest lit value lamp, matching the original
  sound tiers: unlit 100 uses the 100 sound; 1,000 uses the 1,000 sound; 3,000
  and 4,000 use the 3,000 sound; and 5,000, 6,000, 8,000, and 9,000 use the
  5,000 sound.
- The collect remains active while the spinner is producing switch pulses.
  Every pulse scores and restarts an approximately two-second inactivity timer;
  another pulse inside that window continues the same collect and can add more
  score.
- Only after approximately two seconds with no further spinner pulse is the
  spinner considered to have stopped. The collect then closes and advances to
  **right orbit inactive**; a later newly sunk pool ball must activate it.
- Spinner value lamps are shown only while the spinner is the active collect.

### Right orbit

- When the right-orbit collect is active, switch 13 awards the same shared
  orbit value as the left side and runs the original fast upward arrow-chase
  collect animation. Only after that animation finishes does it advance the
  value by 10,000, hide the orbit-value arrows, and move to **left orbit
  inactive**.
- When it is not active, switch 13 awards 5,000 and does not advance the shared
  orbit value.

## Hole / saucer

- The existing bonus progression remains 2x -> 3x -> 5x -> 100,000.
- Reaching the step beyond 5x does not light or award 100,000 until the left
  orbit collect has also been made during that ball.
- If the hole progression reaches that point first, it waits there. Collecting
  the left orbit later lights 100,000 without requiring the collect feature to
  remain at the left orbit.
- Once qualified, the 100,000 award retains its original playfield-multiplier
  behavior.
- Bonus progression, left-orbit authorization, and the waiting qualification
  all reset when a new ball starts.

## CHAMP

- First completion: no playfield multiplier change.
- Second completion: light/award 2x playfield.
- Third completion: retain 2x.
- Fourth completion: light/award 3x playfield.
- Fifth completion: retain 3x.
- Sixth completion: retain 3x and light both outlane specials.
- CHAMP letters retain their original operator-setting behavior between balls,
  but the completion counter, multiplier, and special milestones reset at the
  start of every ball.
- CHAMP completion no longer changes the spinner value.

## Specials

- Collecting any special also awards 250,000 points multiplied by the current
  playfield value: 250,000 at 1x, 500,000 at 2x, or 750,000 at 3x.
- These points are additional to the original adjustment-controlled special
  award and do not replace its sound, animation, or knocker behavior.
- The points are awarded only when a lit special is actually collected, not
  when a special is lit or while its qualification state is retained.
- ROM trace: most special collectors enter at `$C1D6`, which plays sound `$6F`,
  and then fall through to the common special-award path at `$C1DB`; one
  original collector enters `$C1DB` directly. All five confirmed collection
  routes therefore pass through `$C1DB`. Deluxe hooks that single convergence
  point, adds two multiplier-aware 100,000 awards plus one multiplier-aware
  50,000 award, and resumes the untouched original routine at `$C1DE`.

## Deluxe implementation state

The original four-player records occupy `$10C7-$10EA`. Deluxe uses the next
five working-RAM bytes for per-ball state:

| Address | Meaning |
| --- | --- |
| `$10EB` | Collect location in bits 0-1; active flag in bit 2; hole-waiting flag in bit 6; left-collect authorization in bit 7 |
| `$10EC` | Spinner inactivity countdown |
| `$10ED` | CHAMP completion count for the current ball |
| `$10EE` | Spinner weighted binary value mask (`$20/$40/$80`) |
| `$10EF` | Retained orbit-value low nibble while inactive orbit lamps are hidden |

The original `$10B1` byte remains the live spinner-lamp mask. It is zero when
the spinner collect is inactive and mirrors `$10EE` only while the spinner is
the active collect.

The original `$1044` byte still drives the live orbit-value lamps and retains
its unrelated upper-bit meanings. Deluxe shadows only its orbit-value low
nibble in `$10EF`, allowing an inactive orbit stage to be dark without losing
its next value. The player-record save hook substitutes that retained nibble,
preserving the original multiplayer and operator-retention behavior.

The original machine does not provide separate ROM lamp outputs for the left
and right orbit-value arrows. Its synchronized orbit state drives both physical
arrow banks together. The included VPX table mirrors that wiring by mapping
each of its five orbit lamp numbers to a pair of table light objects. Therefore
the ROM can show or hide the orbit arrows as a group, but it cannot illuminate
only the left or only the right bank without a coordinated VPX-table change
(or physical lamp-driver rewiring on a real machine).

## Required gameplay verification

- Start a new game and verify it begins at left-orbit inactive and the first
  newly sunk ball activates that same location.
- Verify the complete sequence is left inactive -> left active -> spinner
  inactive -> spinner active -> right inactive -> right active -> left
  inactive, with a distinct newly sunk ball required for each activation.
- Verify additional newly sunk balls while a location is already active do not
  move it and are not queued to activate the following location.
- Verify hitting an already-sunk ball still follows its existing 5,000-point
  path and does not activate, move, restart, or advance the collect feature.
- Verify unlit left/right orbit shots score 5,000 without advancing their value.
- Verify the first active left-orbit collect lights at 10,000 (or preserves a
  higher retained value), scores that amount, and advances the shared value by
  10,000.
- Verify collecting left and right hides their active orbit indication while
  retaining the next orbit value, and that a later activation restores it.
  On each collect, verify the original fast upward arrow chase completes before
  the arrows turn off and the logical state advances.
- Verify the left orbit's original 100,000/special terminal behavior remains
  collectible while the Deluxe collect is at the spinner or right orbit, and
  that doing so does not move the Deluxe collect.
- Verify spinner values and lamps advance through the weighted binary states,
  active spins receive 2x/3x, and an unlit spin remains 100. Verify the sound
  tiers are 100 -> 100 sound, 1K -> 1K sound, 3K/4K -> 3K sound, and
  5K/6K/8K/9K -> 5K sound.
- Verify activating spinner collect or sinking a pool ball does not advance its
  accumulated value. Verify each dedicated E-I-G-H-T target advances exactly
  once per letter round, an already-lit letter does not advance it, completing
  E-I-G-H-T awards a BALL letter and rearms the five letters, and the visible
  lamp combinations include both 8K and 9K.
- Verify every spinner pulse restarts the inactivity window, a pulse inside two
  seconds continues scoring, and roughly two seconds with no pulse closes the
  collect and advances it to the right orbit.
- Verify the saucer cannot light/award 100,000 until both the post-5x step and
  left collect authorization have occurred, in either order.
- Verify CHAMP completions 2, 4, and 6 produce 2x, 3x, and both specials, and
  that CHAMP no longer changes spinner value.
- Collect each available special at 1x, 2x, and 3x and verify its additional
  score is respectively 250,000, 500,000, and 750,000 while the original
  special award and knocker behavior still occur exactly once.
- Verify drain/new-ball resets collect location, spinner value, saucer
  qualification, CHAMP count, and multiplier while respecting existing
  operator settings for retained CHAMP letters and orbit value.
