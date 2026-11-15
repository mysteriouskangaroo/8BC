# Eight Ball Champ Deluxe game rules

This document translates `new-games-design-ideas/8 Ball Champ New Rules.pptx` into an implementation contract. The original ROM trace is used to resolve its descriptions of the existing rules and uncertain base values.

## Deluxe score scale

Deluxe stores and displays every gameplay award at one tenth of the original
manual/playfield value. Normal playfield awards use the common pending-score
transfer, which maps the original decimal queues to the next lower display
digit and makes the formerly unused ones digit meaningful. The end-of-ball
bonus bypasses those queues and is scaled separately at its two direct BCD
score-adder call sites. Thus original 10 scores 1, original 4,500 scores 450,
original 15,000 bonus scores 1,500, and original 250,000 scores 25,000.
Relative values, playfield multipliers, bonus multipliers, score sounds, and
award timing are unchanged. The seven-digit display can represent the
equivalent of 99,999,990 original points as a Deluxe score of 9,999,999.

Printed playfield inserts retain their physical legends. In this document,
phrases such as the **100,000 insert** identify that lamp or feature; an
explicit score describes the scaled Deluxe award.

Install this ROM with reset working RAM/NVRAM. The operations manual confirms
that registers 12-14 are operator-entered replay/extra-ball thresholds and
register 15 is the operator-entered High Score to Date, each accepting values
through 9,999,999. Re-enter them at one tenth of the former settings. The
manual's recommended settings therefore translate as follows:

| Setting | Original recommendation | Deluxe setting |
| --- | ---: | ---: |
| 3-ball first replay | 1,500,000 | 150,000 |
| 3-ball second replay | 3,000,000 | 300,000 |
| 3-ball High Score to Date | 4,000,000 | 400,000 |
| 5-ball first replay | 2,000,000 | 200,000 |
| 5-ball second replay | 4,000,000 | 400,000 |
| 5-ball High Score to Date | 5,000,000 | 500,000 |
| Extra-ball thresholds | 2,000,000 / 3,700,000 | 200,000 / 370,000 |

The manual defines Match against the tens digit, and the ROM continues to do
so. Activating the ones digit does not change Match probability or presentation.

## Existing rules established in the original ROM

- Switch 32 is the spinner. Its original handler is at `$CA3B`.
- Spinner value/lamp state is stored at `$10B1`. The bit state is changed by completing the C-H-A-M-P rollovers. The three physical lamp bits are labeled 1,000, 3,000, and 5,000; their Deluxe awards are 100, 300, and 500. Any subsequent completion after the 5,000 lamp keeps that bit selected.
- Switches 12 and 13 are the left and right rollover buttons. They enter the shared orbit-value handler at `$CB53` and `$CB4F`. Its first score-table entry calls `$C9EF`, establishing **500 Deluxe points** (original 5,000) as the unlit/default orbit score.
- The original orbit-value handler keeps the left and right values synchronized, advances the printed lit value by 10,000 (1,000 Deluxe points), and honors the operator setting that controls whether that value is retained between balls. At the printed 100,000 state, it lights a special collect on each orbit and awards 10,000 Deluxe points per collection.
- Switch 05 is the saucer/hole. State `$10C1` controls its progression through
  the 2x, 3x, and 5x bonus multipliers to the terminal 100,000 insert.
  Bit `$08` selects its repeatable 10,000-point Deluxe award at `$D070`,
  which is also affected by the current playfield multiplier. Once balls 1-7
  have been sunk (`$10C3 = $7F`), the saucer lights to collect the 8-ball. The
  next saucer hit runs the 8-ball collection routine at `$CEDC`: it advances
  the separate pool-bonus lamps in `$1044` through 120K, 240K, and
  120K+240K; clears the sunk-ball state for a new rack; and then continues
  through the normal saucer scoring/progression code at `$D069`.
- The original drain-bonus routine at `$C765` awards 1,500 Deluxe points for each sunk pool
  ball and repeats that award pass for the selected 2x, 3x, or 5x bonus. Its
  completed-rack calculation originally used only the two 120K/240K lamp bits
  in `$1044`, which can encode no more than three completed racks.
- New pool balls are recorded in `$10C3`; their first-sink path is `$CE07`.
  Its 2,500 playfield value follows Deluxe's divide-by-ten score scale, awarding
  250 displayed points through the current playfield multiplier. It activates
  the current Deluxe collect location, but it is separate from the E-I-G-H-T
  targets and does not advance the spinner value.
- Switches 33-37 are the five dedicated E, I, G, H, and T stand-up targets.
  They share the original handler at `$CC7C`, whose active-low collected-letter
  state is `$1045`. Their 2,500 playfield value follows Deluxe's divide-by-ten
  score scale, so every target hit awards 250 displayed points through the
  current playfield multiplier. A target hit clears its corresponding bit only
  if that letter was not already collected. When all five letters are
  collected, the original handler awards the next BALL letter and rearms
  E-I-G-H-T so each target can be collected again in the next round.
- CHAMP letters use `$1040`. Completing the five letters reaches `$CB07`, which originally advances the playfield score multiplier `$10C0` through double, triple, and special states. All multiplier-aware scoring helpers read `$10C0`.

## Deluxe collect feature

The collect feature has six ordered states:

`right orbit inactive -> right orbit active -> spinner inactive -> spinner active -> left orbit inactive -> left orbit active -> right orbit inactive`

In this section, a **newly sunk pool ball** means the first hit that changes
that ball's bit in `$10C3` from clear to set and lights its sunk-ball lamp.
Hitting a ball that is already sunk (its lamp is already on) follows the
existing 500-point Deluxe path at `$D034`; it does **not** activate, move, restart,
or otherwise advance the collect feature.

Collecting the lit 8-ball at the saucer is also one new-ball activation event.
Like balls 1-7, it activates the current location only when that location is
inactive. If the location is already active, the 8-ball has no collect-state
effect and is not queued for the next location. An ordinary saucer hit that
does not collect the lit 8-ball is not an activation event.

1. Starting a new ball places the feature at **right orbit inactive**.
2. A newly sunk pool ball changes the current location from inactive to active;
   it does not change the location. Activating either orbit promotes the
   original 5,000 baseline to the printed 10,000 value so the orbit-value
   arrows visibly indicate the active collect.
3. Collecting an active location clears its active state and advances to the
   next location's inactive state. The next newly sunk ball is required to
   activate that new location.
4. Sinking additional new pool balls while the current location is already
   active has no collect-state effect. They are not queued for later stages.
5. Hitting an inactive collect location does not advance the sequence.

### Left orbit

- When it is not active, switch 12 awards 500 and does not collect or advance
  the retained orbit value, including when that value has reached the original
  100,000/special terminal state. A qualified terminal special remains stored
  and can be collected later when the orbit is active; inactive rollover hits
  do not consume it.
- Reaching the retained 100,000 terminal state qualifies the original orbit
  special. Its live blinking indication (`$10C2` bit `$10`) is shown only while
  the collect feature is active at the left or right orbit. It is hidden while
  the orbit is inactive or the collect is at the spinner, without losing the
  retained qualification. The original already-collected latch in `$10A0` bit
  `$20` prevents it from being relit after collection during the same ball.
- When a newly sunk ball activates the collect feature at the left orbit, any
  higher orbit value carried forward by the operator's retain setting is
  preserved instead of being reduced to 10,000.
- When the left-orbit collect is active, switch 12 awards the current shared
  orbit value using the original handler and runs the original fast upward
  arrow-chase collect animation. Only after that animation finishes does it
  advance the printed value by 10,000 (1,000 Deluxe points), hide the
  orbit-value arrows, and move the feature to **right orbit inactive**. A later
  newly sunk pool ball must activate the right orbit.
- Each new activation that lights the left-orbit collect authorizes one future
  saucer 100,000-insert award of 10,000 Deluxe points. Collecting the orbit is not required to create that
  authorization, and the authorization persists after the orbit advances.

### Spinner

- An unlit spinner scores 10 points per spin and does not use the playfield
  multiplier.
- The spinner collect begins at 100 Deluxe points (the printed 1,000 lamp) at the start of every ball.
- While the feature is at spinner inactive, spinner pulses remain unlit 10-
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
  printed sequence 1,000 -> 3,000 -> 4,000 -> 5,000 -> 6,000 -> 8,000 ->
  9,000, awarding 100 -> 300 -> 400 -> 500 -> 600 -> 800 -> 900 Deluxe
  points. It remains at 900 after reaching the top state.
- While the spinner collect is active, every spin scores its displayed value
  using the current 1x/2x/3x playfield multiplier.
- Spinner sounds follow the highest lit value lamp, matching the original
  sound tiers: unlit 10 uses the original 100 sound; 100 uses the original
  1,000 sound; printed 3,000 and 4,000 use the 3,000 sound; and printed 5,000,
  6,000, 8,000, and 9,000 use the 5,000 sound.
- The collect remains active while the spinner is producing switch pulses.
  Every pulse scores and restarts an approximately two-second inactivity timer;
  another pulse inside that window continues the same collect and can add more
  score.
- Only after approximately two seconds with no further spinner pulse is the
  spinner considered to have stopped. The collect then closes and advances to
  **left orbit inactive**; a later newly sunk pool ball must activate it.
- Spinner value lamps are shown only while the spinner is the active collect.

### Right orbit

- Activating the right orbit from the original 5,000 baseline lights the
  printed 10,000 value, just as activation at the left orbit does. A higher
  retained orbit value is preserved.
- When the right-orbit collect is active, switch 13 awards the same shared
  orbit value as the left side and runs the original fast upward arrow-chase
  collect animation. Only after that animation finishes does it advance the
  printed value by 10,000 (1,000 Deluxe points), hide the orbit-value arrows,
  and move to **spinner inactive**.
- When it is not active, switch 13 awards 500 and does not advance the shared
  orbit value.

## Hole / saucer

- The existing bonus progression remains 2x -> 3x -> 5x -> the 100,000 insert,
  whose Deluxe award is 10,000.
- The left-orbit collect activation and the saucer progression are independent
  gates. Newly lighting the left-orbit collect can arm one printed 100,000
  insert award (10,000 Deluxe points), but
  it never advances 2x, 3x, or 5x and cannot cause the saucer to skip 5x.
- The player must actually collect the lit 5x saucer step before 100,000 can
  blink. If 5x is collected first, the progression waits there until the next
  left-orbit activation. If the left orbit was activated first, 100,000 begins
  blinking immediately after the later 5x collection.
- Collecting the lit 100,000 consumes that left-orbit authorization and turns
  off 100,000. The bonus multiplier remains at 5x; only the live 100,000 flash
  and award are disabled. A later new left-orbit activation can arm and light
  one more scaled 10,000 award without replaying the multiplier progression.
- Once qualified, the scaled 10,000 award retains its original playfield-multiplier
  behavior.
- Bonus progression, left-orbit authorization, and the waiting qualification
  all reset when a new ball starts.

## Pool-ball bonus

- Every successfully collected 8-ball completes one rack and increments that
  player's completed-rack counter, including the fourth and all later clears.
- The 120K and 240K center inserts retain their original visual progression.
  Because those two lamps can represent only one, two, or three completed
  racks, both remain lit for any count of three or more; the RAM counter, not
  the lamps, is authoritative for scoring.
- At drain, each completed rack is worth `8 * 1,500 = 12,000`, and each ball
  already sunk in the unfinished current rack adds another 1,500 Deluxe points.
- The existing 1x/2x/3x/5x end-of-ball bonus multiplier applies to the entire
  result. For example, six completed racks contribute `6 * 12,000` before
  the multiplier, plus 1,500 for each sunk ball in the current partial rack.
- Each player's completed-rack counter carries across that player's balls and
  is restored after the intervening players' turns. All four counters reset at
  the start of a new game. Each one-byte counter saturates at 255 rather than
  wrapping to zero; only its temporary bonus working copy resets each ball.
- During end-of-ball bonus, the two-digit credit display temporarily shows the
  number of completed racks. The actual credit-display bytes are saved before
  bonus begins and restored after all multiplier passes finish, so displaying
  racks does not add, remove, or otherwise change credits. Counts from 0-99
  display exactly; 100-255 display as 99 while still scoring from the full RAM
  counter.

## B-A-L-L and E-I-G-H-T bonus

- Every completed E-I-G-H-T target set still lights the next physical B-A-L-L
  letter, and also increments the active player's B-A-L-L counter. Completions
  beyond the four physical B-A-L-L inserts continue increasing this counter.
- The four B-A-L-L inserts retain their original visual progression and remain
  all lit for any count of four or more. The RAM counter is authoritative for
  end-of-ball scoring.
- After the completed-rack bonus finishes, the credit display changes from the
  rack total to the number of B-A-L-L letters collected. It stays on that total
  throughout the B-A-L-L/E-I-G-H-T bonus phase, then the genuine credit count
  is restored.
- At drain, each completed B-A-L-L letter is worth five scaled 1,000-point
  E-I-G-H-T units, or 5,000. Each E-I-G-H-T letter collected toward the next
  B-A-L-L letter adds another 1,000.
- The 1x/2x/3x/5x end-of-ball bonus multiplier applies to the complete result.
  Each player's counter carries across their later balls, saturates at 255,
  and resets only with a new game. The two-digit display caps at 99 without
  changing the scored count.
- The B-A-L-L/E-I-G-H-T bonus animation uses approximately 20% shorter pass,
  completed-letter, and individual-target delays than the original routine.
  Scoring, sounds, lamp order, and multiplier passes are otherwise unchanged.

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

- Collecting any special also awards 25,000 points multiplied by the current
  playfield value: 25,000 at 1x, 50,000 at 2x, or 75,000 at 3x.
- These points are additional to the original adjustment-controlled special
  award and do not replace its sound, animation, or knocker behavior.
- The points are awarded only when a lit special is actually collected, not
  when a special is lit or while its qualification state is retained.
- ROM trace: most special collectors enter at `$C1D6`, which plays sound `$6F`,
  and then fall through to the common special-award path at `$C1DB`; one
  original collector enters `$C1DB` directly. All five confirmed collection
  routes therefore pass through `$C1DB`. Deluxe hooks that single convergence
  point, adds two scaled multiplier-aware 10,000 awards plus one scaled
  multiplier-aware 5,000 award, and resumes the untouched original routine at
  `$C1DE`.

## Deluxe implementation state

The original four-player records occupy `$10C7-$10EA`. Deluxe uses `$10EB`
through `$10FD` for active state, temporary bonus/display work, and parallel
per-player counters:

| Address | Meaning |
| --- | --- |
| `$10EB` | Collect location in bits 0-1; active flag in bit 2; hole-waiting flag in bit 6; left-collect authorization in bit 7 |
| `$10EC` | Spinner inactivity countdown |
| `$10ED` | CHAMP completion count for the current ball |
| `$10EE` | Spinner weighted binary value mask (`$20/$40/$80`) |
| `$10EF` | Retained orbit-value low nibble while inactive orbit lamps are hidden |
| `$10F0` | Active player's completed 8-ball racks (saturates at 255) |
| `$10F1` | Working completed-rack countdown, reloaded for each bonus-multiplier pass |
| `$10F2` | Saved credit-display ones byte during end-of-ball bonus |
| `$10F3` | Saved credit-display tens byte during end-of-ball bonus |
| `$10F4` | Active player's completed B-A-L-L letters (saturates at 255) |
| `$10F5` | Working B-A-L-L countdown, reloaded for each bonus-multiplier pass |
| `$10F6-$10F9` | Completed-rack counters for players 1-4 |
| `$10FA-$10FD` | Completed B-A-L-L-letter counters for players 1-4 |

The canonical new-game loop initializes all four original player records at
`$C4E6`; Deluxe hooks the same loop to clear the prior collect state before
capturing the new game's baseline orbit value and to clear all eight parallel
counters. The canonical player restore ends at `$C603`; Deluxe loads
`$10F0/$10F4` from the selected player's parallel entries there. Counter
increments are written back immediately, so drain animations cannot erase
another player's progress.

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

- Start a new game and verify it begins at right-orbit inactive and the first
  newly sunk ball activates that same location.
- Verify the complete sequence is right inactive -> right active -> spinner
  inactive -> spinner active -> left inactive -> left active -> right
  inactive, with a distinct newly sunk ball required for each activation.
- Verify additional newly sunk balls while a location is already active do not
  move it and are not queued to activate the following location.
- After reset, enter replay/extra-ball thresholds and High Score to Date at
  one tenth of the former values. Verify the displays accept the scaled values
  and the awards occur at those thresholds.
- Verify a manual/playfield 10-point Rebound scores 1, a 500-point target
  scores 50, a 3,000-point CHAMP lane scores 300, and a combined 4,500-point
  award path scores 450. Verify carries use the ones digit correctly across
  9 -> 10, 99 -> 100, and 999 -> 1,000.
- Verify Match retains the factory tens-digit behavior and approximately 10%
  award probability even when the score's ones digit is nonzero.
- Verify a first sink awards 250 at 1x, 500 at 2x, or 750 at 3x.
  Verify hitting an already-sunk ball still follows its scaled 500-point path,
  retains the physical 5,000 lamp effect, and does not activate, move, restart,
  or advance the collect feature.
- Verify collecting the lit 8-ball activates the current location when it is
  inactive, does nothing to an already-active collect state, and is never
  queued for the next location. Verify ordinary saucer hits do not activate it.
- Verify unlit left/right orbit shots score 500 without advancing their value.
- Verify the first active orbit collect lights the printed 10,000 insert
  (or preserves a higher retained value), scores 1,000, and advances the shared
  printed value by 10,000 / Deluxe value by 1,000.
- Verify collecting left and right hides their active orbit indication while
  retaining the next orbit value, and that a later activation restores it.
  On each collect, verify the original fast upward arrow chase completes before
  the arrows turn off and the logical state advances.
- Verify an inactive left rollover still scores only 500 at the retained
  100,000/special terminal state and does not consume the special. Verify the
  special indication is hidden whenever neither orbit is active, begins
  blinking when the collect activates at either orbit, and hides again when
  that orbit collect advances. Verify the printed 100,000/special behavior
  occurs when the active orbit collects it and awards 10,000 Deluxe points.
- Verify spinner values and lamps advance through the weighted binary states,
  active spins receive 2x/3x, and an unlit spin remains 10. Verify the score /
  original-sound tiers are 10 -> 100 sound, 100 -> 1K sound, 300/400 -> 3K
  sound, and 500/600/800/900 -> 5K sound.
- Verify activating spinner collect or sinking a pool ball does not advance its
  accumulated value. Verify every dedicated E-I-G-H-T target hit awards 250 at
  1x, 500 at 2x, or 750 at 3x; each target advances the spinner exactly once
  per letter round; an already-lit letter still scores but does not advance it;
  completing E-I-G-H-T awards a BALL letter and rearms the five letters; and
  the visible lamp combinations include both 8K and 9K.
- Verify every spinner pulse restarts the inactivity window, a pulse inside two
  seconds continues scoring, and roughly two seconds with no pulse closes the
  collect and advances it to the left orbit.
- Verify the saucer displays and collects 2x, then 3x, then 5x without a left-
  orbit activation changing those steps. Verify the 100,000 insert cannot blink until
  both 5x has been collected and the left-orbit collect has been newly lit, in
  either order. After collecting it, verify it awards 10,000 at 1x, turns off, and cannot be
  awarded again until a later new left-orbit activation rearms it, while end-
  of-ball bonus and the 5x indication remain at 5x throughout.
- Complete at least four 8-ball racks in one ball and verify the center inserts
  remain capped at their 120K+240K display while every completed rack is still
  counted at drain. With six completed racks, verify the completed-rack portion
  is 72,000 at 1x, 144,000 at 2x, 216,000 at 3x, or 360,000 at 5x,
  plus 1,500 times the multiplier for each sunk ball in the partial rack.
- During that drain bonus, verify the credit display shows `06` for six
  completed racks, remains stable through every multiplier pass, and restores
  the exact prior credit count after the following B-A-L-L bonus finishes.
- Complete E-I-G-H-T at least five times in one ball. Verify all four physical
  B-A-L-L inserts remain lit after the fourth completion, the fifth completion
  is retained in RAM, and the credit display changes to `05` after the rack
  bonus. At 1x, verify those five letters contribute 25,000, plus 1,000 for
  each partial E-I-G-H-T letter; repeat at 2x/3x/5x to confirm multiplication.
- In a four-player game, give Player 1 four completed racks and five B-A-L-L
  letters, then play through Players 2-4. Verify Player 1's next ball restores
  `04` racks and `05` B-A-L-L letters for display and bonus while every other
  player retains only their own totals. Start a new game and verify all eight
  per-player totals return to zero.
- Verify CHAMP completions 2, 4, and 6 produce 2x, 3x, and both specials, and
  that CHAMP no longer changes spinner value.
- Collect each available special at 1x, 2x, and 3x and verify its additional
  score is respectively 25,000, 50,000, and 75,000 while the original
  special award and knocker behavior still occur exactly once.
- Verify drain/new-ball resets collect location, spinner value, saucer
  qualification, CHAMP count, and multiplier while respecting existing
  operator settings for retained CHAMP letters and orbit value.
