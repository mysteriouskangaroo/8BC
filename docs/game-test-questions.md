# Questions from the game tests

The game tests (`tools/Invoke-GameTests.ps1`, branch `game-tests`) play each
ROM in libpinmame and compare what it does with `gamerules.md`,
`GAME_RULE_TRACES.md`, `SCORING_CHANGES.md`, `HARDWARE_MAP.md` and the
operations manual. These questions came up while writing them.

Unless a question says otherwise, `gamerules.md` means
`src/8bc-deluxe/gamerules.md`, and times assume 60 frames a second. That rate
is supported by PinMAME's `BY6803_ZCFREQ`, by the ROM's 7,200-per-minute
count at `E0FB`, and by `core.c`.

## 1. Failing tests: the doc and the ROM disagree

On every platform the suite gives 325 passed and 13 failed, and each failure is
one of the questions below. For each one: is the doc wrong or the ROM wrong?
The fix then goes in that file.

1. **Original drop targets and E-I-G-H-T standups: 500 or 2,500?** On the
   original ROM, a drop target's first sink scores 500 at 1x (1,000 at 2x,
   1,500 at 3x), and each E-I-G-H-T standup scores 500 at 1x.
   `GAME_RULE_TRACES.md` agrees. `gamerules.md` "Existing rules established in
   the original ROM" gives both a 2,500 playfield value (250 displayed in
   Deluxe). Tests: `tests/originals/drop-targets.tests.ps1` and
   `tests/originals/eight-targets.tests.ps1`.

2. **Deluxe timers run at half the documented length.** The Deluxe periodic
   tick (`DELUXE_PERIODIC_TICK`) runs twice per frame, 120 times a second, but
   the timer constants appear to assume 60. Measured:
   - The sunk-ball award blink lasts 90 frames (1.5 s), against "for
     approximately three seconds" in "Sunk-ball award display". Its overlay
     counts 180 ticks.
   - The orbit-advance preview lasts 89-90 frames, against "approximately three
     seconds" (left and right orbit).
   - The spinner's E-I-G-H-T preview lasts 90 frames, against "about three
     seconds". The source comment calls its `$BF` constant 3.2 s; it runs
     1.6 s.
   - Spinner collecting ends 61 frames after the last pulse, against "roughly
     two seconds".

   Should the constants be doubled, or the doc changed? Tests:
   `tests/8bc-deluxe/sunk-ball-awards.tests.ps1`,
   `tests/8bc-deluxe/orbits.tests.ps1` and
   `tests/8bc-deluxe/spinner.tests.ps1`.

3. **Deluxe ignores "orbit value recall off" (adjustment 48 = 0).** With 48 set
   to 0, Deluxe still carries the orbit value into the next ball. The original
   ROM resets it, as "Existing rules" says the original handler does. This
   looks like a Deluxe bug. Tests: `tests/8bc-deluxe/drain-reset.tests.ps1` and
   `tests/compare/original-vs-deluxe-orbit-recall.tests.ps1`.

4. **Which display is the "credit display"?** During end-of-ball bonus, the
   rack and B-A-L-L counts (`06`, `05`, `04`) appear on the ball-in-play
   (status) display, PinMAME display index 5. The credit display (index 4)
   keeps showing credits. `gamerules.md` says "credit display" in "Pool-ball
   bonus", "B-A-L-L and E-I-G-H-T bonus" and "Required gameplay verification".
   The bytes written are `$1069`/`$106A`, named `CREDIT_DISPLAY_ONES`/`_TENS` in
   `src/8bc-deluxe/asm/symbols.inc` and "credit-display" in the Deluxe
   `HARDWARE_MAP.md` `1102-1103` row. If the ball-in-play display is intended,
   those names are wrong too. For the first 3 frames the display shows `08`
   and `09`. Tests: `tests/8bc-deluxe/ball-bonus.tests.ps1` and
   `tests/8bc-deluxe/rack-bonus.tests.ps1`.

5. **Does the orbit special relight on a later ball?** After the orbit special
   is collected, carrying the recalled 100,000 value into the next ball does
   not relight it. "Left orbit" says the `$10A0` bit `$20` latch prevents a
   relight "during the same ball". The original ROM blocks the relight too, so
   the doc's "during the same ball" may be what's wrong. Tests:
   `tests/8bc-deluxe/specials.tests.ps1` and
   `tests/compare/original-vs-deluxe-orbit-special-later-ball.tests.ps1`.

6. **Is "`$29`" the byte sent to the sound board?** `gamerules.md` gives the
   left orbit's collect sound (and the maxed right orbit's) as "single `$29`".
   Both ROMs send `$00` on the wire. `$29` is only the value queued at `$1024`
   before scoring clears it. If the doc means the queued value, the test should
   change instead. This is also the one number in "Required gameplay
   verification" that the coverage check finds unasserted (142 of 143).
   Tests: `tests/8bc-deluxe/orbits.tests.ps1` and
   `tools/tests/Test-DeluxeCoverage.ps1`.

## 2. Readings of `gamerules.md` to confirm

The tests rest on these readings. A different answer changes the expected
values.

1. **CHAMP values.** The 3,000 / 30,000 / 90,000 thumper and completion values
   are read as playfield values, displayed divided by ten (300 and so on), as
   the AGENTS.md default says.
2. **Specials.** "Specials" says "25,000 points multiplied by the current"
   multiplier. The ROM adds 25,000 displayed points (50,000 at 2x, 75,000 at
   3x), so the tests read 25,000 as a displayed value. The AGENTS.md default
   would read it as 2,500 displayed.
3. **"A 500-point target scores 50".** This is read as the center rollover.
   The manual gives 500 for the drop targets, and `gamerules.md` gives the first
   sink as 2,500 (question 1.1).
4. **"A combined 4,500-point path".** This is read as three hits in a row:
   CHAMP lane, thumper and center rollover. Was one single 4,500 award meant?
5. **Startup speech.** The speech checks run after a restart from service
   mode, not a cold power-on. Is that enough?
6. **75% bonus time.** Against the reference build at `7d9c960` (the commit
   before "speedier bonus count"), the new count takes 78.9% of the time
   (242 to 191 frames, and 133 to 105). Phases are timed between sound
   commands `$37`, `$38` and the end sound. That is inside the test's
   75% ± 5% window but near its top. Other phase boundaries are estimated, not
   measured, at 73-77%, or over 80% if drain and serve are included. Which
   boundary does "approximately 75%" mean? Test:
   `tests/8bc-deluxe/bonus-timing.tests.ps1`.

## 3. Behavior not in the docs

1. **Fresh memory disables the orbit special.** On fresh NVRAM, adjustment 51
   reads `FF` (`$16A0`), which is not in the manual's table, and the orbit
   special never lights until 51 is set to 0. The factory setup never writes it.
   "Existing rules" says the special lights at the 100,000 state without that
   condition. Is this intended?
2. **Drop groups re-arm only through the standup.** A drop-target group resets
   only when the E-I-G-H-T standup behind it is hit while the group is down.
   Neither doc says so.
3. **`$10C1` on a new ball reads `81`, not `01`.** Bit `$80` comes from NVRAM
   `$168B` bit `$40`. The tests mask with `0F`. Is the high bit meaningful?

## 4. Operations manual questions

1. **Saucer 100,000 lamp.** The manual prints connector J12-14 (lamp 56), but
   wire code 73 matches J12-12 (lamp 58), and lamp 58 is the one that blinks. A
   manual typo?
2. **Switches 14 and 16.** Switch 14, printed "Not Used", resets the game like a
   slam switch (`C025` to `C94C`, sound `$1B`, SWI at `F34F`). Switch 16,
   printed "Slam", runs a do-nothing handler. Are the two names swapped on page
   1-18 and in `HARDWARE_MAP.md`?
3. **Adjustment numbers.** Page 1-11 gives the spinner start as adjustment 46,
   but the page 1-5 table gives 49, and 49 is the one that works. Page 1-10
   titles adjustment 29 as replays, but pages 1-5 and 1-9 give Match.
4. **Extra Ball on the first E-I-G-H-T completion.** Page 1-11 says the first
   completion also awards an Extra Ball. This is untested. Should it be?
5. **6803 port numbering.** Both `HARDWARE_MAP.md` files call `0002` "port 2",
   but on the 6803, `0002` is the port 1 data register.

## 5. The test suite itself

1. **Run time.** The default run takes about 6 minutes (about 9½ with the
   long tests), against the goal of "a few minutes". Acceptable?
2. **CI stays red until section 1 is settled.** While the known failures
   remain, a new regression is easy to miss. Settle them first, or have CI
   compare against a list of known failures?
3. **Deployed ROM.** A test run leaves `VisualPinballX/VPinMAME/roms/eballchp.zip`
   as the last tree built. The runner prints which tree that is. Should it
   restore a particular tree instead?
4. **Proof that tests can fail.** Each test file was run once against a
   deliberately wrong value and failed. That proves the file can fail, not
   every check in it; reviewers read every check for whether it can fail.
   Is that enough?
5. **Long-test timeout.** The runner's `-LongTimeoutSeconds` (default 1,800)
   gives the long tests more time. Keep it?
