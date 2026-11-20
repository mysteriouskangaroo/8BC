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

## Startup speech

- When speech is enabled, Deluxe prefixes the original adjustment-driven
  "Eight Ball, 3 Ball" or "Eight Ball, 5 Ball" boot announcement with
  "Super". The original pre-announcement delay and 3/5-ball selection are
  preserved, but no additional delay is inserted between the two commands.

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
- Switch 05 is the saucer/hole. State `$10C1` controls the original progression
  through 2x, 3x, and 5x to the terminal 100,000 insert. Deluxe RAM `$1149`
  then extends the actual bonus multiplier through 7x, 8x, and 10x.
  Bit `$08` selects its repeatable 10,000-point Deluxe award at `$D070`,
  which is also affected by the current playfield multiplier. Once balls 1-7
  have been sunk (`$10C3 = $7F`), the saucer lights to collect the 8-ball. The
  next saucer hit runs the 8-ball collection routine at `$CEDC`: it advances
  the separate pool-bonus lamps in `$1044` through 120K, 240K, and
  120K+240K; clears the sunk-ball state for a new rack; and then continues
  through the normal saucer scoring/progression code at `$D069`.
- The original drain-bonus routine at `$C765` awards 1,500 Deluxe points for each sunk pool
  ball. Deluxe repeats that award pass for the selected 1x, 2x, 3x, 5x, 7x,
  8x, or 10x bonus. Its
  completed-rack calculation originally used only the two 120K/240K lamp bits
  in `$1044`, which can encode no more than three completed racks.
- New pool balls are recorded in `$10C3`; their first-sink path is `$CE07`.
  Its 2,500 playfield value follows Deluxe's divide-by-ten score scale, awarding
  250 displayed points through the current playfield multiplier unless it is
  the currently called ball. It activates the current Deluxe collect location,
  but it is separate from the E-I-G-H-T targets and does not advance the
  spinner value.
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

The collect feature alternates between an **orbit stage** and a **spinner
stage**, each with inactive and active phases:

`orbit inactive -> orbit active --either orbit--> spinner inactive -> spinner active -> orbit inactive`

Internally, the opening and repeating orbit stages retain two legacy location
encodings, but both accept either physical rollover and behave identically
except for the side-specific value rule described below.

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

1. Starting a new ball places the feature at **orbit inactive**.
2. A newly sunk pool ball changes the current location from inactive to active;
   it does not change the location. Activating either orbit promotes the
   original 5,000 baseline to the printed 10,000 value so the orbit-value
   arrows visibly indicate the active collect.
3. Collecting either active orbit or the active spinner clears its active state
   and advances to the other location's inactive state. The next newly sunk
   ball is required to activate that location.
4. Sinking additional new pool balls while the current location is already
   active has no collect-state effect. They are not queued for later stages.
5. Hitting an inactive collect location does not advance the sequence.

Collect activation no longer overlays the H/A/M lamps. All five C-H-A-M-P
lamps continuously show their normal collected-letter state, independently of
the collect feature. This visual restoration does not change CHAMP scoring,
completion milestones, or the C/P anti-shatz latch.

### Left orbit

- When it is not active, switch 12 awards 500 and does not collect or advance
  the retained orbit value, including when that value has reached the original
  100,000/special terminal state. A qualified terminal special remains stored
  and can be collected later when the orbit is active; inactive rollover hits
  do not consume it. The inactive shot uses sound command `$31`, matching the
  playfield's 500-point center rollover instead of the active left-orbit sound.
- Reaching the retained 100,000 terminal state qualifies the original orbit
  special. Its live blinking indication (`$10C2` bit `$10`) is shown only while
  the collect feature is active at the left or right orbit. It is hidden while
  the orbit is inactive or the collect is at the spinner, without losing the
  retained qualification. The original already-collected latch in `$10A0` bit
  `$20` prevents it from being relit after collection during the same ball.
- When a newly sunk ball activates either encoded orbit stage, any higher orbit
  value carried forward by the operator's retain setting is preserved instead
  of being reduced to 10,000.
- During any active orbit stage, switch 12 awards the current shared
  orbit value using the original handler and runs the original fast upward
  arrow-chase collect animation. It then hides the orbit-value arrows and moves
  the feature to **spinner inactive**. It retains the collected arrow value;
  only the right rollover advances that value by 10,000 (1,000 Deluxe points).
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
- When a new E-I-G-H-T letter advances the value while spinner collect is
  inactive, the new value lamps blink for approximately three seconds as a
  visual preview. This does not activate spinner collect: spinner pulses during
  the preview retain the ordinary unlit 10-point award, do not use the
  playfield multiplier, and do not restart the preview timer. A later pool-
  ball activation cancels the preview and shows the active value steadily.
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
  **orbit inactive**; a later newly sunk pool ball must activate it.
- Spinner value lamps are otherwise shown only while spinner is the active
  collect; the temporary E-I-G-H-T preview is the sole inactive exception.

### Right orbit

- Activating either encoded orbit stage from the original 5,000 baseline lights
  the printed 10,000 value. A higher retained orbit value is preserved.
- During any active orbit stage, switch 13 awards the same shared
  orbit value as the left side and runs the original fast upward arrow-chase
  collect animation. Its existing sound command `$2A` is sent twice
  back-to-back before scoring and the chase, distinguishing the active right
  collect from an ordinary right-orbit hit. Only after that animation finishes
  does it advance the printed value by 10,000 (1,000 Deluxe points) and move to
  **spinner inactive**. The newly advanced arrow value then blinks for
  approximately three seconds before the orbit-value arrows turn off. This is
  a lamp-only preview and does not reactivate either orbit collect.
- When it is not active, switch 13 awards 500 and does not advance the shared
  orbit value. It uses the same `$31` center-rollover sound as an inactive left
  orbit, instead of the active right-orbit sound.

## Hole / saucer

- The saucer progression is 2x -> 3x -> 5x -> 100,000 -> 7x + 100,000 ->
  8x + 100,000 -> 10x + 100,000 -> repeatable 100,000 at 10x. The 100,000
  playfield award is scaled to 10,000 displayed Deluxe points.
- Collecting the lit 5x saucer step immediately advances to and lights the first
  100,000 award, irrespective of the collect feature's location or transition
  state. It also preserves the 5x end-of-ball bonus.
- Collecting the first standalone 100,000 turns every next-award lamp off. The
  next qualifying collect transition makes 7x+100,000 blink together, while
  the earned end-of-ball multiplier remains 5x until that saucer award is
  collected. Its collection earns 7x and turns the next-award lamps off; the
  following transition blinks 8x+100,000. The same sequence then blinks and
  awards 10x+100,000. The inserts represent 7x as 2x+5x, 8x as 3x+5x, and
  10x as 2x+3x+5x, with the complete combination and 100,000 blinking in phase.
- After any terminal 100,000 has been collected and turned off, either orbit collect
  advancing to spinner inactive or spinner active advancing to orbit inactive
  relights it. A completion before the first
  100,000 is available cannot advance or skip the 2x, 3x, or 5x saucer steps.
- If 100,000 is already lit, later active-to-inactive transitions do nothing.
- Collecting a lit terminal award consumes that transition authorization,
  advances the multiplier when a 7x/8x/10x step remains, and turns off its
  entire blinking combination. After 10x+100,000 is collected, every later
  active-to-inactive transition blinks 100,000 alone; collecting it turns it
  off again. This final qualify/collect pair repeats until ball drain. A saucer
  hit while dark scores only its ordinary value, makes no multiplier callout,
  and cannot advance the multiplier.
- Once qualified, the scaled 10,000 award retains its original playfield-multiplier
  behavior.
- Every terminal collection uses the original 100,000 sound; the extended
  multiplier stages do not attempt new 7x, 8x, or 10x speech.
- Bonus progression, collect-deactivation authorization, and the waiting state
  all reset when a new ball starts.

## Called ball score

- The spoken “Sink the N ball” selection is the authoritative call. Sinking
  that exact ball for the first time replaces its normal 2,500 playfield-value
  award with the active player's Called ball score.
- At the beginning of a ball, the first accepted scoring/playfield switch
  closure expires the original initial speech-delay timer so the game selects
  and speaks its first called ball immediately afterward. Outhole, credit,
  coin, tilt/slam, unused, and cabinet Lane Change events do not trigger it.
  The triggering switch still runs its normal rule and score, and subsequent
  called-ball reminder timing remains unchanged.
- While the call is active and that ball remains unsunk, the lamp on its
  individually numbered physical drop target flashes at the game's normal
  lamp-flash cadence. Balls 1-7 use the seven solid-ball target lamps and balls
  9-15 use the seven stripe-ball target lamps. The five shared 5,000 target
  lamps retain their original behavior and are not used for this indication.
  After the ball is sunk, its numbered target lamp stops carrying the called
  indication; the next spoken selection moves the flash to the newly called
  target.
- Called ball score begins at a 5,000 playfield value, displayed as 500 under
  Deluxe's divide-by-ten score scale. Every successful called ball advances the
  next value by 5,000 playfield points: 5,000, 10,000, 15,000, and so on
  (displayed as 500, 1,000, 1,500...). The value stops advancing at 50,000
  playfield / 5,000 displayed.
- Collecting the lit 8-ball to complete a rack always awards the current Called
  ball score and then advances its next value by 5,000, even though balls 1-7
  are the ones selected by the spoken call. It also restores any old called-
  target flash overlay, clears the old 8-ball reminder ID and delay, and lets
  the normal selector immediately call and flash the first target of the new
  rack (ball 1 for solids or ball 9 for stripes).
- Each Called ball award uses the current 1x/2x/3x playfield multiplier.
  An uncalled first sink retains its normal 2,500 playfield value, displayed as
  250 before multiplication; an already-sunk ball retains its separate normal
  5,000 playfield-value path, displayed as 500 before multiplication.
- Called ball score is stored separately for every player and survives drains
  and intervening players' turns. Starting a new game resets all four player
  values to 5,000. The one-byte stored progression saturates at 50,000 rather
  than wrapping or advancing farther. A zero/uninitialized value from an older
  NVRAM or saved game is migrated to the initial 5,000 value before it can be
  awarded; an above-cap value from an earlier Deluxe revision is clamped to
  50,000 before scoring.

## Sunk-ball award display

- Every newly sunk pool ball temporarily shows the exact Deluxe points awarded
  after the current 1x/2x/3x playfield multiplier. An ordinary uncalled ball
  therefore shows 250, 500, or 750; a successful called ball and the collected
  8-ball show the current Called ball score after that same multiplier.
- For approximately three seconds, the award blinks on all three score displays
  other than the scoring player's display. For example, player 2 keeps their
  live score while the award blinks on the player 1, 3, and 4 displays.
- The active player's score remains visible and continues updating normally.
  The three displaced scores are backed up and restored exactly when the timer
  ends, when end-of-ball bonus begins, or before the next ball starts; the
  overlay never awards points or changes another player's logical score.
- If another new pool ball is sunk during the three-second window, the newest
  award replaces the previous value and restarts the complete timer. Hitting an
  already-sunk pool-ball target or an E-I-G-H-T stand-up does not start it.

## Pool-ball bonus

- Every successfully collected 8-ball completes one rack and increments that
  player's completed-rack counter, including the fourth and all later clears.
- The 120K and 240K center inserts retain their original visual progression
  through three completed racks. Beginning with that player's fourth rack,
  both inserts blink together to signify that the stored total contains more
  racks than the two physical lamps can show. The RAM counter, not the blinking
  lamp output, remains authoritative for scoring.
- At drain, each completed rack is worth `8 * 1,500 = 12,000`, and each ball
  already sunk in the unfinished current rack adds another 1,500 Deluxe points.
- The selected 1x/2x/3x/5x/7x/8x/10x end-of-ball bonus multiplier applies to the entire
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
- The four B-A-L-L inserts retain their original visual progression through
  four completions. Beginning with that player's fifth completed letter, all
  four inserts blink together to signify that the stored total contains more
  letters than the physical inserts can show. The output overlay changes only
  `$1041` bits 0-3 (`$0F`); bits 4-7 belong to unrelated playfield-multiplier
  and special indications and remain untouched. The RAM counter is
  authoritative for end-of-ball scoring.
- After the completed-rack bonus finishes, the credit display changes from the
  rack total to the number of B-A-L-L letters collected. It stays on that total
  throughout the B-A-L-L/E-I-G-H-T bonus phase, then the genuine credit count
  is restored.
- At drain, each completed B-A-L-L letter is worth five scaled 1,000-point
  E-I-G-H-T units, or 5,000. Each E-I-G-H-T letter collected toward the next
  B-A-L-L letter adds another 1,000.
- The 1x/2x/3x/5x/7x/8x/10x end-of-ball bonus multiplier applies to the complete result.
  Each player's counter carries across their later balls, saturates at 255,
  and resets only with a new game. The two-digit display caps at 99 without
  changing the scored count.
- The B-A-L-L/E-I-G-H-T bonus animation uses approximately 20% shorter pass,
  completed-letter, and individual-target delays than the original routine.
  Scoring, sounds, lamp order, and multiplier passes are otherwise unchanged.

## CHAMP

- Only the C and P return lanes use the anti-shatz latch. The first new C or P
  of each ball is available immediately. After one is awarded, another new C
  or P requires either thumper/pop bumper, the saucer, either orbit rollover,
  the center rollover, spinner, a numbered pool-ball drop target, or an
  E-I-G-H-T target first.
- H, A, and M top-lane letters always advance normally and do not consume the
  C/P latch. Slingshots, the rebound, CHAMP lanes, outlanes, cabinet/service
  switches, and ball-management switches do not rearm C/P. A locked C or P
  still awards its normal lane points without lighting the new letter. Hitting
  an already-lit C or P does not consume a valid rearm.
- Completing the full C-H-A-M-P word rearms the C/P latch, regardless of which
  letter completed the word. The next new C or P is therefore immediately
  available, after which the normal qualifying-shot requirement resumes.
- First completion: raise the right thumper/pop bumper from 1,000 to 3,000.
- Second completion: light/award 2x playfield.
- Third completion: raise the left thumper/pop bumper from 1,000 to 3,000.
- Fourth completion: light/award 3x playfield.
- Fifth completion: retain 3x, light both outlane specials, and award 30,000.
- Every later completion: award another 30,000.
- Both upgraded 3,000 thumper values use the current 1x/2x/3x playfield
  multiplier. The 30,000 completion award is also a base value and uses that
  multiplier, so the fifth and later completions award 90,000 while 3x is
  active.
- CHAMP letters retain their original operator-setting behavior between balls,
  but the completion counter, thumper values, multiplier, and special
  milestones reset at the start of every ball.
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

The original player records occupy four 13-byte slots at `$10C7-$10FA`.
Each slot contains nine saved bytes plus four reserved stride bytes; the exact
per-player and per-field layout is in [HARDWARE_MAP.md](ghidra/HARDWARE_MAP.md#u4-ram-canonical-per-player-record-slots).
Deluxe begins at the next byte and uses `$10FB-$114B` for active state,
temporary bonus/display work, and parallel per-player counters. The
[authoritative Deluxe allocation](ghidra/HARDWARE_MAP.md#u4-ram-deluxe-allocation)
lists every assigned address, storage role, active-player mirror, reserved gap,
and scratch range. Its
[logical combined player table](ghidra/HARDWARE_MAP.md#logical-combined-player-state)
presents the original and Deluxe fields as one player record without changing
their safe physical layout.

The canonical new-game loop initializes all four original player records at
`$C4E6`; Deluxe hooks the same loop to clear the prior collect state before
capturing the new game's baseline orbit value, clear all eight bonus counters,
and set all four Called ball scores to their initial value. The canonical
player restore ends at `$C603`; Deluxe loads `$1100/$1104/$110E` from the
selected player's parallel entries there. Counter/value advances are written
back immediately, so drain animations cannot erase another player's progress.

The original `$10B1` byte remains the live spinner-lamp mask. It is zero when
the spinner collect is inactive and mirrors `$10FE` only while the spinner is
the active collect.

The original `$1044` byte still drives the live orbit-value lamps and retains
its unrelated upper-bit meanings. Deluxe shadows only its orbit-value low
nibble in `$10FF`, allowing an inactive orbit stage to be dark without losing
its next value. The player-record save hook substitutes that retained nibble,
preserving the original multiplayer and operator-retention behavior.

The original machine does not provide separate ROM lamp outputs for the left
and right orbit-value arrows. Its synchronized orbit state drives both physical
arrow banks together. The included VPX table mirrors that wiring by mapping
each of its five orbit lamp numbers to a pair of table light objects. Therefore
the ROM can show or hide the orbit arrows as a group, but it cannot illuminate
only the left or only the right bank without a coordinated VPX-table change
(or physical lamp-driver rewiring on a real machine).

To identify the active side without changing that wiring, the lamp-refresh
path at `$E111` normally uses the original `$1040-$1045` Phase-B shadows
directly. During either player-specific "more" blink, it instead copies those
six bytes to `$1119-$111E`, alters only the applicable rack or B-A-L-L bits,
and serializes the copy. This path never changes the authoritative CHAMP bits
in `$1040`, the live rack/letter shadows, or the per-player counters.

## Required gameplay verification

- Cold-boot with speech enabled under both the three-ball and five-ball
  adjustments. Verify the complete announcement is "Super" followed by the
  correct original "Eight Ball" ball-count phrase in one continuous flow,
  without a long pause or a cut-off command. Verify disabling speech still
  suppresses the sequence.
- Start a new game and verify it begins at orbit inactive and the first
  newly sunk ball activates that same location.
- Verify the repeating sequence is orbit inactive -> orbit active --either
  orbit--> spinner inactive -> spinner active -> orbit inactive, with a
  distinct newly sunk ball required for each activation.
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
- Verify an uncalled first sink awards 250 at 1x, 500 at 2x, or 750 at 3x.
  Verify hitting an already-sunk ball still follows its scaled 500-point path,
  retains the physical 5,000 lamp effect, and does not activate, move, restart,
  or advance the collect feature.
- With each player active in turn, verify those 250/500/750 first-sink awards
  blink for about three seconds on the other three player displays while the
  active player's live score remains visible. Verify successful called balls
  and the collected 8-ball show their exact multiplied Called ball award.
  Sink two new balls in quick succession and verify the second value replaces
  the first and restarts the timer. Drain during the blink and verify every
  displaced score is restored before the next player/ball begins.
- Follow the spoken call and verify the first three successful called balls
  award 500/1,000/1,500 at 1x, 1,000/2,000/3,000 at 2x, or
  1,500/3,000/4,500 at 3x, replacing rather than adding the normal 250-point
  first-sink award. Verify an incorrect first sink does not advance the value.
- Verify the individually numbered physical drop-target lamp for the spoken
  ball flashes: targets 1-7 for solids and 9-15 for stripes. Verify the five
  shared 5,000 target lamps retain their original behavior, no sunk ball keeps
  the called indication, and an incorrect sink leaves or moves it only as
  dictated by the next spoken call.
- Complete a rack with the lit 8-ball and verify it awards the current Called
  ball value, then advances that player's next value by 5,000 playfield
  points. Verify the old called lamp is restored and the new rack immediately
  calls and flashes ball 1 for solids or ball 9 for stripes, with no stale
  reminder delay or wrong target flash. Drain and verify the next ball retains
  the advanced value. In a
  four-player game, advance each player differently and verify their values
  restore independently; drain and verify each value persists. Start a new
  game and verify all return to 5,000.
- Advance Called Ball to 50,000 and verify successful calls and collected
  8-balls continue awarding 5,000 displayed points at 1x (10,000 at 2x or
  15,000 at 3x) without advancing or wrapping the stored value.
- Verify collecting the lit 8-ball activates the current location when it is
  inactive, does nothing to an already-active collect state, and is never
  queued for the next location. Verify ordinary saucer hits do not activate it.
- Verify unlit left/right orbit shots score 500 without advancing their value
  and use the same sound as the playfield's 500-point center rollover. Verify
  the active left collect retains its original side-specific sound and the
  active right collect sends its original `$2A` sound twice back-to-back.
- Verify either rollover can collect during both the opening and repeating
  active orbit stages. Both sides must score the current value, finish the
  original fast upward arrow chase, hide the active orbit indication, and move
  to spinner inactive.
- Verify the right rollover advances the shared printed value by 10,000 /
  Deluxe value by 1,000 and blinks that new value for approximately three
  seconds. Verify the left rollover retains the value it just awarded and does
  not show a false next-value preview. A later orbit activation must restore
  the appropriate retained value in either case.
- During the right-orbit value preview, activate the spinner with a newly sunk
  pool ball and verify the orbit preview is canceled immediately while the
  spinner's accumulated value is shown. Also trigger an E-I-G-H-T spinner
  preview during the orbit preview and verify the two independent lamp previews
  do not corrupt either retained value or collect state.
- Activate and collect both orbits with several C-H-A-M-P patterns. Verify all
  five letter lamps continuously retain the normal collected-letter display
  with no H/A/M blackout or roll, while CHAMP scoring, completion, multiplier
  progression, and the C/P anti-shatz latch remain unchanged.
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
- With spinner collect inactive, verify each value advance blinks the new lamp
  combination for about three seconds and then hides it. Verify its first
  visible pulse is a complete blink phase rather than a brief flicker. During
  that preview, verify spinner pulses still score only the ordinary unlit 10
  points, do not use the playfield multiplier, and do not activate or restart
  the preview.
  Activate spinner during a preview and verify the timer is cancelled and the
  current value becomes steady immediately.
- Verify every spinner pulse restarts the inactivity window, a pulse inside two
  seconds continues scoring, and roughly two seconds with no pulse closes the
  collect and advances it to the inactive orbit stage.
- Verify the saucer displays and collects 2x, then 3x, then 5x without any
  collect transition changing or skipping those steps. Verify collecting 5x
  immediately lights the first 100,000 regardless of the current collect state.
  While it is already lit, complete another active collect and verify nothing
  changes. Collect 100,000, verify it awards 10,000 at 1x and every next-award
  lamp turns off, then
  verify either active orbit -> spinner inactive and spinner active -> orbit
  inactive can each relight it. Verify the first qualifying transition blinks
  7x+100,000 (2x+5x+100,000 lamps) while bonus remains 5x. Its collection earns
  7x and darkens the combination; the next transition blinks 8x+100,000
  (3x+5x+100,000), and the following one blinks 10x+100,000
  (2x+3x+5x+100,000). Verify collecting that award earns 10x and darkens it,
  then every later transition blinks only 100,000 and every collection darkens
  it again. At every stage, verify a dark saucer hit gives no 5x announcement
  and does not advance, and an already-lit collect transition does nothing.
- Complete at least four 8-ball racks in one ball and verify both 120K and 240K
  inserts blink together beginning with the fourth rack while every completed
  rack is still counted at drain. With six completed racks, verify the
  completed-rack portion is 72,000 at 1x, 144,000 at 2x, 216,000 at 3x, or
  360,000 at 5x, plus 1,500 times the multiplier for each sunk ball in the
  partial rack.
- During that drain bonus, verify the credit display shows `06` for six
  completed racks, remains stable through every multiplier pass, and restores
  the exact prior credit count after the following B-A-L-L bonus finishes.
- Complete E-I-G-H-T at least five times in one ball. Verify all four physical
  B-A-L-L inserts are lit after the fourth completion, begin blinking together
  with the fifth completion, the fifth completion is retained in RAM, and the
  credit display changes to `05` after the rack
  bonus. At 1x, verify those five letters contribute 25,000, plus 1,000 for
  each partial E-I-G-H-T letter; repeat at 2x/3x/5x/7x/8x/10x to confirm multiplication.
- In a four-player game, give Player 1 four completed racks and five B-A-L-L
  letters, then play through Players 2-4. Verify Player 1's next ball restores
  `04` racks and `05` B-A-L-L letters for display and bonus, resumes both blink
  indications only on Player 1's turn, and leaves every other player's lamps
  steady according to only their own totals. Start a new game and verify all
  eight per-player totals return to zero.
- Verify CHAMP completions 1-5 produce right thumper 3K, 2x playfield, left
  thumper 3K, 3x playfield, then both outlane specials plus 30K. Verify each
  later completion awards another 30K base through the playfield multiplier
  and CHAMP does not change spinner value. At the fifth and later completions,
  verify the milestone portion is 90K at 3x; including the completing CHAMP
  lane's normal 9K, the full switch-event score movement is 99K.
- Verify lighting the outlane specials on completion 5 does not enter the
  Special-collection path: no separate Special points, sound, knocker, or
  adjustment-controlled award may occur until an outlane Special is collected.
- Verify the upgraded left and right thumpers score 3K/6K/9K at 1x/2x/3x,
  return to their stock 1K value after a drain, and preserve their original
  sound, score gate, and momentary-solenoid behavior.
- Collect each available special at 1x, 2x, and 3x and verify its additional
  score is respectively 25,000, 50,000, and 75,000 while the original
  special award and knocker behavior still occur exactly once.
- Verify drain/new-ball resets collect location, spinner value, saucer
  qualification, CHAMP count, and multiplier while respecting existing
  operator settings for retained CHAMP letters and orbit value.
