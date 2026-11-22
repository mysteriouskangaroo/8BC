# Game Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automated PowerShell game tests that play Eight Ball Champ in libpinmame, checking each tree's rules against its docs and comparing variations with the original.

**Architecture:** A lockstep C# machine (`EightBallChampMachine`) owns one emulator run per process and pauses the emulation thread after every frame the test asks for. A PowerShell module of helpers (names, service mode, game flow, assertions) sits on it. A runner builds each tree once, runs every `tests/**/*.tests.ps1` file in its own `pwsh`, and summarizes the results. The existing boot test is rebuilt on the same machine.

**Tech Stack:** PowerShell 7, C# 5 via `Add-Type`, libpinmame v3.7.0-477-6589fc5 (from `tools/Get-LibPinmame.ps1`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-21-game-test-suite-design.md`

## Global Constraints

- Never write to `src/*/roms/`; never change a built ROM. Tests boot the tree's packaged `eballchp.zip`, copied to a private VPM folder.
- One libpinmame boot per process: each test file runs in its own `pwsh`; `EightBallChampMachine.Start` throws on a second call in the same process.
- PowerShell 7 only, with no new dependencies. C# stays at C# 5 syntax. RAM is read and written through `PinmameGetRawMemoryRegion(0x81)`.
- Deterministic: results depend only on frame counts, never on wall-clock time. Wall-clock limits exist only as hang guards, and hitting one is a FAIL.
- Every C# callback body catches every exception (an escaping exception kills the process).
- Expected values live in the test files, copied from the doc they cite. A test that disagrees with its doc FAILS. Never encode the ROM's behavior as the expected value without the user's ruling.
- A test that writes RAM to reach its state carries the label `seeded` in its result line. Operator settings are always changed through the service-mode menus, never by RAM writes.
- Each test is shown to fail at least once, against a deliberately wrong expected value, before it is committed, and the commit message says so (`proved failing: <what was changed>`).
- Runner parallelism defaults to 1 (`-Jobs`, maximum 4). Target: the default suite runs in a few minutes on one core.
- The repository is public: CI artifacts carry test reports only, never `eballchp.zip`, `.bin` images or listings.
- Switch numbers are the `HARDWARE_MAP.md` page 1-18 numbers (26 = Lane Change (Cabinet), 32 = Spinner). Solenoid names and test numbers come from page 1-18.
- Deluxe numeric values are displayed values (already divided by ten), as written in `src/8bc-deluxe/gamerules.md`.
- After any change to the boot test or the build flow, run all three `src/*/asm/test-pinmame.ps1` and `tools/Test-BootNegativeControl.ps1`.

## Review Focus

1. **A stalled emulation thread.** If the test thread throws while the emulator is paused, the process must still stop the emulator and exit nonzero within the hang guard, not hang. (Task 1 test `Exception while paused still exits`.)
2. **Overshooting a frame.** `Advance(n)` must stop at exactly `frame + n`, including n = 1 repeated 1,000 times. (Task 1 test `Advance is exact`.)
3. **The same zip from two trees.** Building one tree overwrites `VisualPinballX/VPinMAME/roms/eballchp.zip`. The runner must copy each tree's zip before building the next tree, or a Deluxe test silently boots the original ROM. (Task 4 test `Each tree boots its own ROM`, which compares the C000 byte read from RAM-mapped ROM with each tree's `u3_cpu.rebuilt.128`.)
4. **A test file that prints nothing.** A file that crashes before any result line, exits 0 without results, or hangs must count as a FAIL. (Task 4 runner fixtures.)
5. **A seeded test hiding a play-path bug.** The `seeded` label must appear in the runner summary as a count, so a suite that has become mostly seeded is visible. (Task 4 test `Summary counts seeded`.)

---

### Task 0: Commit the spec and plan

- [ ] **Step 1:** Run the doc-review skill on the spec and this plan, and apply its fixes.
- [ ] **Step 2:** Run `pwsh ./tools/Test-DocPaths.ps1`. Expected: `Documentation paths: PASS`.
- [ ] **Step 3:** Commit both files: `git commit -m "Game test suite: design and plan"`.

### Task 1: Lockstep machine

**Files:**
- Create: `tools/LibPinmameMachine.ps1`
- Create: `tests/kit/machine.tests.ps1`

**Interfaces:**
- Produces C# `public static class EightBallChampMachine`:
  - `LoadLibrary(string path)`, `Start(string vpmPath)` (clears `nvram/ cfg/ hi/`, waits for the run state and unthrottles, then pauses at frame 0) and `Stop()`.
  - `Advance(int frames)`: runs exactly that many frames, then pauses.
  - `AdvanceUntilEvent(string prefix, int maxFrames)`: returns the frame of the first new event starting with `prefix`, or -1 when `maxFrames` elapse.
  - `int Frame` and `SetSwitch(int sw, bool closed)` / `bool GetSwitch(int sw)`.
  - `byte[] ReadRam(int addr, int n)` and `WriteRam(int addr, byte[] bytes)`.
  - `string Display(int i)` and `int Lamp(int n)`.
  - `string[] EventsSince(int index)` and `int EventCount`.
  - Events keep the boot test's text form: `"<frame> disp|lamp|sol|snd|sw ..."`.
- Produces PowerShell functions:
  - `Start-EbcMachine -LibraryPath -VpmPath`, `Stop-EbcMachine` and `Step-EbcFrames [-Frames n]`.
  - `Wait-EbcEvent -Prefix -MaxFrames` (throws on timeout with the prefix and frame).
  - `Set-EbcSwitch -Number -Closed`, `Read-EbcRam -Address -Count` and `Write-EbcRam -Address -Bytes`.
  - `Get-EbcDisplay -Index`, `Get-EbcLamp -Number` and `Get-EbcEvents [-Since]`.

The display-0 callback is the frame clock. After it increments `frame`, if `frame == target` it sets `paused` and waits on `resume`. It also waits on `resume` when `Stop()` is called. `Advance` sets `target`, signals `resume` and waits for `paused`. Each wait has a 600 s hang guard; on expiry it throws `TimeoutException` naming the frame. Keep the boot test's one-boot guard, gate lock and `closed` flag. A `trap` or `try/finally` in the PowerShell wrapper calls `Stop()` so that an exception on the test thread releases the emulator.

- [ ] **Step 1: Write `tests/kit/machine.tests.ps1`**, using a temporary minimal result printer: lines of the form `PASS kit/machine :: <name>` or `FAIL ... :: <detail>`, and exit 1 on any FAIL. Task 3 replaces the printer with the module. The tests:
  - `Advance is exact`: after `Start`, 1,000 calls to `Advance(1)` and then `Advance(500)` leave `Frame == 1500`.
  - `Paused means frozen`: `ReadRam(0x1000, 0x800)` is identical before and after a 200 ms sleep while paused.
  - `Deterministic`: the event list after 1,500 frames equals the list from a second run of the same script in a child `pwsh`. The child writes its events to a temp file.
  - `Switch reaches the ROM`: close switch 8 at frame 0. By frame 300 the `SWITCH_SAMPLE_CURRENT_STROBE0` (`$102C`) bit `0x80` is set (switch 08 is strobe 0, return 7).
  - `RAM write is seen`: write `0x5A` to an unused U4 byte the ROM never writes (pick one that stays `0xFF` through 1,500 frames in the Deterministic run, and record which byte in a comment). Advance 1 frame and read back `0x5A`.
  - `Second start throws`: a second `Start` throws with a message containing `one boot per process`.
  - `Exception while paused still exits`: a child `pwsh` starts the machine, throws, and must exit nonzero within 60 s.
- [ ] **Step 2: Run** `pwsh tests/kit/machine.tests.ps1 -Tree originals`, with the packaged zip copied as in Task 4 (for now, copy `VisualPinballX/VPinMAME/roms/eballchp.zip` after `src/originals/asm/build.ps1`). Expected: FAIL, because `tools/LibPinmameMachine.ps1` does not exist.
- [ ] **Step 3: Implement** `tools/LibPinmameMachine.ps1` with the interface above.
- [ ] **Step 4: Run** it again. Expected: 7 PASS, exit 0.
- [ ] **Step 5: Commit:** `git commit -m "Lockstep libpinmame machine (proved failing: ...)"`.

### Task 2: Boot test on the machine

**Files:**
- Modify: `tools/LibPinmameBoot.ps1` (it becomes a thin layer that dot-sources `LibPinmameMachine.ps1`)

**Interfaces:**
- Consumes the Task 1 machine.
- Keeps `Invoke-EightBallChampBootTest -LibraryPath -VpmPath [-Frames]` and its output object unchanged (`Pass, Reason, Frames, WallSeconds, DisplayEvents, LampEvents, SolenoidEvents, SoundEvents, Stack00FC, U4WrittenBytes, Digest, Logs`).

- [ ] **Step 1: Record the current outputs.** Run all three `src/*/asm/test-pinmame.ps1` and `tools/Test-BootNegativeControl.ps1` on the unchanged code, and save their reports in the workspace.
- [ ] **Step 2: Reimplement** the boot test: start, close switch 8, and read the stack and U4 snapshots at frames 60, 300 and `Frames-1` through `Advance`. The pass rules stay the same.
- [ ] **Step 3: Run the same four commands.** Expected: the three trees PASS, and the negative control prints `Negative control: PASS` with `c000e3e0`. Display, lamp, solenoid and sound event counts equal the Step 1 reports. If the digest changes, note the reason in the commit message.
- [ ] **Step 4: Commit:** `git commit -m "Boot test runs on the lockstep machine"`.

### Task 3: Discovery and the name table

The facts the helpers need, measured in libpinmame and recorded with their evidence. A finding that contradicts `HARDWARE_MAP.md` is brought to the user rather than recorded.

**Files:**
- Create: `tools/GameNames.psd1`
- Create: `tests/kit/names.tests.ps1`

**Interfaces:**
- Produces `tools/GameNames.psd1`, a hashtable with these keys:
  - `Switches` (name → number, all 37 from page 1-18, using the established names), `SelfTestSwitch`, and `Solenoids` (page 1-18 name → libpinmame solenoid number).
  - `Lamps`: name → number, only the lamps a test uses.
  - `Sounds`: name → command byte, for example `Rebound = 0x22`.
  - `Ram`: name → address. This includes the `symbols.inc` names plus `Credits`, `BallInPlay`, `CurrentPlayer`, `PlayerCount`, `GameOver` (or the flag that marks it), `MatchDigit`, and `ScoreBuffer1..4` (`1046`, `104D`, `1054`, `105B`).
  - `FramesPerSecond`.
- Each value has a comment that names its evidence: a source label or address, or the test in `names.tests.ps1` that measures it.

- [ ] **Step 1: Write `tests/kit/names.tests.ps1`.** It asserts each discovered fact by play:
  - `Self-test switch enters service mode`: holding `SelfTestSwitch` changes the displays to the test-number display. The candidate is `BY6803_SWSELFTEST = -7` in pinmame `src/wpc/by6803.h` at the pinned tag.
  - `Solenoid test order is page 1-18`: during the ROM's automatic solenoid test, the sequence of `sol <n> 1` events maps, through `Solenoids`, to tests 01-12 in page 1-18 order (Drop Target 1,2,9,10 … Knocker). The test also checks the claim that libpinmame's number is `M+1`.
  - `Coin adds a credit`: closing `Coin I (Left)` for 4 frames raises `Ram.Credits` by the factory coinage.
  - `Start sets players`: `Credit` with credits > 0 sets `PlayerCount` to 1 and `BallInPlay` to 1.
  - `Score buffers match display`: after a scored switch, the score in `ScoreBuffer1` (ones-first, displayed digit in the high nibble) equals display 1's text.
- [ ] **Step 2: Run.** Expected: FAIL (no `GameNames.psd1`).
- [ ] **Step 3: Find each value.** Use the source first (`src/originals/asm/modules/*.asm`, `symbols.inc`, the Ghidra comments). Confirm each by watching RAM change in a scratch script. Write the table.
- [ ] **Step 4: Run.** Expected: all PASS.
- [ ] **Step 5: Commit:** `git commit -m "Game test name table with measured evidence (proved failing: ...)"`.

### Task 4: Helper module and runner

**Files:**
- Create: `tools/GameTest.psm1`
- Create: `tools/Invoke-GameTests.ps1`
- Create: `tools/tests/runner-fixtures/{pass,fail,silent,crash,hang,seeded}.tests.ps1`
- Create: `tools/Test-GameTestRunner.ps1`
- Create: `tests/kit/trees.tests.ps1`

**Interfaces:**
- Test-file contract: each file begins with `param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)` and `Import-Module <repo>/tools/GameTest.psm1`. It prints one line per test, `PASS|FAIL <tree>/<file> :: <test name>[ [seeded]][ :: <detail>]`, and exits 1 when any test fails.
- `GameTest.psm1` exports:
  - `Start-EbcGame -Tree -VpmZip`, which copies the zip to a private temp VPM folder and starts the machine.
  - `Test-EbcItem -Name -Doc [-Seeded] -Body {}`, which catches failures, prints the line, and records a failure for the exit code.
  - `Assert-EbcEqual -Expected -Actual -What`: the failure text is `<What>: expected <e>, actual <a> (<Doc>)`.
  - `Complete-EbcTests`, which exits with the right code.
  - Names: `Get-EbcSwitch <name>`, `Get-EbcSolenoid <name>`, `Get-EbcLampNumber <name>` and `Get-EbcRamAddress <name>`, all from `GameNames.psd1`.
  - Switch actions: `Invoke-EbcSwitchHit <name> [-Count n]`, which closes for 4 frames and opens for 8 (the builder may tune both after measuring debounce in Task 3).
  - Game flow:
    - `Add-EbcCredit [-Count]`, `Start-EbcPlay [-Players n]` and `Wait-EbcBallServed`.
    - The scripted ball model: the outhole switch opens when the Outhole solenoid fires.
    - `Invoke-EbcDrain`: the outhole closes, then the helper waits for the bonus count and the next serve or game over.
    - `Complete-EbcGame`.
  - Reads: `Get-EbcScore -Player` (from RAM, cross-checked against the display; it throws on mismatch), `Get-EbcCredits`, `Get-EbcBallInPlay`, `Get-EbcChampState` (`10C0`) and `Get-EbcSunkBalls` (`10C3`).
  - Service mode: `Enter-EbcServiceMode`, `Set-EbcAdjustment -Number -Value` and `Exit-EbcServiceMode`, through the self-test and credit switches.
  - Comparison: `Invoke-EbcComparedScenario -Trees a,b -Scenario {} [-Normalize {}]`. It runs the same file twice as children with `-ObserveTo <json>`, then compares the two observation lists. The scenario calls `Add-EbcObservation <text>` to build the list.
- `Invoke-GameTests.ps1 [-Tree originals,loop-score-change,8bc-deluxe] [-Path <glob>] [-Jobs 1..4] [-Long] [-TimeoutSeconds 300] [-TestRoot tests]`:
  - Builds each needed tree once (the originals with `-RequireByteIdentical`) and copies the packaged zip to `src/<tree>/build/game-tests/eballchp.zip` before the next build.
  - Runs each file in its own `pwsh -NoProfile -File`, prints its lines, and writes `build/game-tests/report.txt` at the repository root (gitignored).
  - Ends with `Game tests: <p> passed, <f> failed, <s> seeded, <n> files`, and exits 1 on any failure.
  - Files under `tests/<tree>/long/` run only with `-Long`. `tests/compare/` runs whenever both of its trees are selected.
  - With `-TestRoot`, the fixture test points the runner at the fixtures.

- [ ] **Step 1: Write the fixture files and `tools/Test-GameTestRunner.ps1`.**
  - `pass` prints one PASS line.
  - `fail` prints a FAIL line and exits 1.
  - `silent` exits 0 with no lines.
  - `crash` throws before printing.
  - `hang` sleeps longer than the timeout.
  - `seeded` prints `PASS ... [seeded]`.
  - The checker runs the runner with `-TestRoot tools/tests/runner-fixtures -TimeoutSeconds 5`, on the boot-free fixtures. It asserts exit 1, a summary of `2 passed, 4 failed, 1 seeded, 6 files`, and that `silent`, `crash` and `hang` each appear as FAIL lines with a reason.
- [ ] **Step 2: Write `tests/kit/trees.tests.ps1`.** `Each tree boots its own ROM` reads the byte at `$C000` from the running ROM region (or the compensation byte the ROM sums) and compares it with byte 0 of `src/<tree>/build/u3_cpu.rebuilt.128`. It runs once per tree.
- [ ] **Step 3: Run both.** Expected: FAIL (no runner or module).
- [ ] **Step 4: Implement** the module and runner. Convert `tests/kit/machine.tests.ps1` and `names.tests.ps1` to the module.
- [ ] **Step 5: Run** `pwsh tools/Test-GameTestRunner.ps1` and `pwsh tools/Invoke-GameTests.ps1 -Path tests/kit`. Expected: the checker passes; every kit test passes on all three trees.
- [ ] **Step 6:** Add `tools/GameTest.psm1`, `tools/Invoke-GameTests.ps1`, `tools/GameNames.psd1`, `tools/LibPinmameMachine.ps1`, `tools/Test-GameTestRunner.ps1` and `tools/tests/` to the `.gitignore` exceptions. Add a "Game tests" subsection to the README's "Local tools" section: what the suite proves, how to run it, and the `seeded` label.
- [ ] **Step 7: Commit:** `git commit -m "Game test helpers and runner (proved failing: ...)"`.

### Task 5: CI job

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1:** Add a `game-tests` job. It uses an `os` matrix of ubuntu, windows and macos, `fail-fast: false`, and `needs: build`. It runs the same Rosetta and fetch steps as `build`, then `./tools/Test-GameTestRunner.ps1` and `./tools/Invoke-GameTests.ps1`. It uploads only `build/game-tests/report.txt`, as `game-tests-${{ matrix.os }}`. All actions are SHA-pinned like the existing ones.
- [ ] **Step 2:** Push the branch to `fork` (the user's standing approval covers this branch) and watch the run, reporting progress every few minutes. Expected: the `game-tests` job passes on all three operating systems, and the existing jobs are unchanged.
- [ ] **Step 3: Commit** (before the push): `git commit -m "CI: game-test job"`.

### Task 6: Original ROM rule tests

**Files:** create `tests/originals/*.tests.ps1`, one file per scenario.

Expected values come from `src/originals/ghidra/GAME_RULE_TRACES.md` and `src/8bc-deluxe/gamerules.md` "Existing rules established in the original ROM". These are original (undivided) values, since this is the original ROM.

| File | Tests (name: expected) |
| --- | --- |
| `game-flow` | Coin I adds credits per factory coinage. Credit starts a 1-player game with ball 1 served (Outhole solenoid fires). Four Credit presses give 4 players. A drain advances player then ball. Game over after the last ball of the last player (3 balls, factory setting). |
| `rebound` | Switch 07 scores 10 at 1x, 20 at 2x and 30 at 3x, and sends sound `0x22` (GAME_RULE_TRACES "Switch 07: Rebound"). 2x/3x are reached by completing C-H-A-M-P in play. |
| `drop-targets` | A first sink scores 500 through the playfield multiplier (`CE07` → `C9C4`). A hit on an already-sunk ball scores 5,000 and leaves `10C3` unchanged. The `10C3` bit for each ball is set on its first sink (GAME_RULE_TRACES "Pool-ball drop targets"). The gamerules.md "Existing rules" section gives the first sink as 2,500 instead; that conflict goes to the user before this file is written. |
| `champ` | C-H-A-M-P completion advances `10C0` through double, triple and special. The multiplier-aware helpers multiply by the `10C0` state, not by the lamp shadow `1041` (GAME_RULE_TRACES "Playfield Scores Double and Triple"). |
| `rollovers` | Unlit switches 12 and 13 score 5,000. Lit values advance by 10,000 and stay synchronized left and right. At 100,000 an orbit special lights. |
| `saucer` | Saucer progression `10C1` goes `01 -> 02 -> 04 -> 08` (2x, 3x, 5x lamps). When `0x08` is set, the saucer awards 100,000 through the playfield multiplier. With `10C3 = 7F`, the next saucer hit runs the 8-ball collection (`1044` advances to 120K). |
| `spinner` | Spinner value `10B1` changes with C-H-A-M-P completion. Each spin scores the lit value. |
| `eight-targets` | Switches 33-37 clear their bit in `1045` on a first hit only. All five collected award a B-A-L-L letter and re-arm the targets. |
| `tilt` | The Tilt switch ends the ball with no bonus, and the next ball is served. |
| `match` | Over 12 fixed games, ended at different frames, a credit is awarded exactly when the match digit equals a player's score tens digit. Each game's match digit and outcome are printed. |
| `service-solenoids` | The automatic solenoid test fires page 1-18 tests 01-12 in order, then continuous output 13 (the Task 3 check, kept here as a rule test). |
| `switch-coils` | Switches 01-05 each fire their own coil: Right Thumper, Left Thumper, Right Slingshot, Left Slingshot, Saucer. |

- [ ] **Step 1:** For each file, in the table's order: write the file with its expected values; prove it fails (change one expected value, run, and see FAIL); restore the value and run it. A real doc/ROM mismatch is listed for the user and the test stays FAIL. Commit each file: `git commit -m "Original-ROM test: <file> (proved failing: ...)"`.
- [ ] **Step 2:** Run `pwsh tools/Invoke-GameTests.ps1 -Tree originals`. Expected: every test passes, apart from mismatches already reported to the user.

### Task 7: loop-score-change tests and comparisons

**Files:**
- Create: `tests/loop-score-change/{saucer,rollovers}.tests.ps1`
- Create: `tests/compare/{original-vs-loop,original-vs-deluxe}.tests.ps1`

- [ ] **Step 1:** In `tests/loop-score-change/saucer`, with `10C1` bit `0x08` set, the saucer awards 10,000 through the playfield multiplier: 10,000, 20,000 and 30,000 at 1x, 2x and 3x. The ordinary saucer score of 500 and the `01 -> 02 -> 04 -> 08` progression are unchanged (SCORING_CHANGES "Fully lit saucer").
- [ ] **Step 2:** In `tests/loop-score-change/rollovers`, normal indices 2-11 score 1,000 through 10,000, and index 1 still scores 5,000 (SCORING_CHANGES "Left and right rollover buttons").
- [ ] **Step 3:** In `tests/compare/original-vs-loop`, run one scripted two-player game: coins, start, and a fixed list of switch hits covering every switch except 05, 12 and 13, then drains to game over. The observation list holds, per hit, each player's score, the sound commands and the solenoids fired. The two trees must match exactly.
- [ ] **Step 4:** In `tests/compare/original-vs-deluxe`, compare credits after coins; ball, player and serve; drain and the next serve; the coil fired by each switch 01-05; the tilt outcome; and the service solenoid order. Scores and display text are normalized away.
- [ ] **Step 5:** Prove each fails, run it, and commit each file as in Task 6.

### Task 8: Deluxe tests

**Files:** create `tests/8bc-deluxe/<section>.tests.ps1`, one per group below, and `tests/8bc-deluxe/long/match-frequency.tests.ps1`.

Each test name quotes the clause it checks from `src/8bc-deluxe/gamerules.md` "Required gameplay verification", and its `-Doc` is that section. Every numeric clause in that section maps to exactly one test below. Before this task is complete, run a script that lists every number in that section and the test that asserts it. "About three seconds", "about two seconds" and "one continuous flow" become frame windows of `FramesPerSecond × 3 ± 20%` and `× 2 ± 20%`, and a gap of no more than 30 frames between sound commands. The test name says it is a timing window.

| File | Clauses covered (expected values as written in the doc) |
| --- | --- |
| `startup-speech` | "Super" followed by the ball-count phrase, for 3 and for 5 balls (set through service mode), with no gap over the window. Speech off suppresses it. |
| `scoring-scale` | Rebound 1, target 50, CHAMP lane 300, a combined path 450. Carries across 9→10, 99→100 and 999→1,000. Thresholds and High Score to Date at one tenth, set through service mode. Each award fires at its threshold. |
| `collect-cycle` | Starts at orbit inactive. The cycle is orbit inactive → active → spinner inactive → active → orbit inactive. Extra sinks while active neither move nor queue. Collecting the 8-ball activates, but is never queued. Saucer hits do not activate. |
| `sunk-ball-awards` | An uncalled first sink scores 250/500/750 at 1x/2x/3x. An already-sunk ball scores 500, keeps its 5,000 lamp effect, and does not touch the collect. The blink shows on the other three displays for the timing window. A second sink replaces the first and restarts the blink. A drain during the blink restores every displaced score. |
| `called-ball` | The first three called sinks score 500/1,000/1,500 at 1x (×2 and ×3 at 2x and 3x), replacing the 250. A wrong sink does not advance. The called lamp is 1-7 for solids and 9-15 for stripes. The rack's 8-ball awards the current value and then +500 displayed. The new rack calls ball 1 or 9. Values are per player in a 4-player game, persist through drains, and reset to 500 at a new game. With the stored value at 50,000 playfield points (`seeded`): 5,000/10,000/15,000 displayed at 1x/2x/3x, with no advance or wrap. |
| `orbits` | Unlit orbits score 500, with the center rollover's sound. Left collect plays its original sound. Right collect plays `$2A` twice, then `$29` once maxed. Either rollover collects in both active stages. Left advances by 1,000 and right by 2,000, each with the blink window. A right advance from 9,000 or 10,000 stops at 10,000/Special. The special shows and hides as the doc states, and awards 10,000 when collected. |
| `previews` | The orbit preview is cancelled when the spinner activates. Orbit and E-I-G-H-T previews together leave both values intact. |
| `champ-lamps` | All five letter lamps hold through orbit collects, with no H/A/M blackout. Completions 1-5 give right thumper 3K, 2x, left thumper 3K, 3x, then both outlane specials plus 30K. Later completions give 30K × multiplier; at 3x, the milestone 90K plus the lane 9K gives a 99K change. Lighting specials enters no Special path. Thumpers score 3K/6K/9K and return to 1K after a drain. |
| `spinner` | Spinner tiers and sounds: 10→100, 100→1K, 300/400→3K, 500/600/800/900→5K. Active spins at 2x/3x; an unlit spin stays 10. E-I-G-H-T hits score 250/500/750 and advance once per letter. Completing E-I-G-H-T awards a B-A-L-L letter. Lamp combinations reach 8K and 9K. The preview blinks for the window with a full first phase, unlit pulses score 10, and activating cancels the preview. Collecting refreshes the stop timer, and about two seconds with no pulse ends spinner scoring only. |
| `saucer` | The saucer gives 2x, 3x, 5x, then the 100,000 light. 100,000 awards 10,000 at 1x and clears the next-award lamps. Relighting blinks 7x+100,000, then 8x+100,000, then 10x+100,000 (with the lamp sets the doc names), then only 100,000. A dark saucer gives no announcement and no advance. |
| `rack-bonus` | From the 4th rack, both 120K and 240K blink. Six racks (`seeded`) give 72,000/144,000/216,000/360,000 at 1x/2x/3x/5x, plus 1,500 × multiplier for each partial-rack ball. The credit display shows `06`, stays stable, and is restored after the B-A-L-L bonus. |
| `ball-bonus` | Five E-I-G-H-T completions (`seeded`) light all four inserts after the 4th, blink them on the 5th, keep the 5th in RAM, and show `05`. Five letters give 25,000 plus 1,000 for each partial letter at 1x, multiplied at 2x/3x/5x/7x/8x/10x. In a 4-player game, Player 1's `04`/`05` are restored on their turn only. A new game zeroes all eight per-player totals. |
| `bonus-timing` | The partial-rack and B-A-L-L/E-I-G-H-T countdown phases take 75% ±5% of the frame counts measured at `7d9c960`, with identical totals and the same number of multiplier passes. |
| `specials` | Each special at 1x/2x/3x adds 25,000/50,000/75,000, with the original award and knocker exactly once. |
| `drain-reset` | A drain resets the collect location, spinner value, saucer qualification, CHAMP count and multiplier, respecting the retain settings (set through service mode). |
| `match` | The tens-digit logic is unchanged when the ones digit is nonzero: 12 fixed games, as in Task 6. |
| `long/match-frequency` | Over 300 games, the award rate falls between 6% and 14%. |

- [ ] **Step 1: Measure the timing reference.**
  - Create the worktree with a literal path: `git worktree add --detach .superpowers/ref-7d9c960 7d9c960`.
  - Build its Deluxe tree with `pwsh -File .superpowers/ref-7d9c960/src/8bc-deluxe/asm/build.ps1`, after copying the DASM folder in.
  - Run the `bonus-timing` scenario against that zip, using `-VpmZip`.
  - Record each phase's frame count in `bonus-timing.tests.ps1`, with a comment naming `7d9c960`, and remove the worktree.
- [ ] **Step 2:** For each file, in the table's order: write it, prove it fails, run it, and commit, as in Task 6. A doc/ROM mismatch stays FAIL and goes on the list for the user.
- [ ] **Step 3: Coverage check.** The script `tools/tests/Test-DeluxeCoverage.ps1` extracts every number in the "Required gameplay verification" section and fails when one is not asserted by name in a test under `tests/8bc-deluxe/`. Run it. Expected: PASS.
- [ ] **Step 4:** Run `pwsh tools/Invoke-GameTests.ps1` (all trees) and `-Long` once, and report the wall time of each. Expected: everything passes, apart from reported mismatches, with the default run in a few minutes.

### Task 9: Docs

- [ ] **Step 1:** Update AGENTS.md's boot-test paragraph so it names what the game tests prove and what they still do not prove (hardware timing and safety). Bring the exact sentences to the user for approval before editing (an AGENTS.md wording rule).
- [ ] **Step 2:** Update the three `src/*/asm/readme.txt` files with how to run that tree's game tests.
- [ ] **Step 3:** Run doc-review on the diff and `pwsh tools/Test-DocPaths.ps1`, then commit.
