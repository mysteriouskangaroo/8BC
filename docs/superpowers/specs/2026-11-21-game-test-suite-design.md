# Game test suite: design

## Intent

Automated tests that play Eight Ball Champ in libpinmame and check what the
ROM does, for three purposes:

1. **Regression:** catch rule changes that break something while Deluxe
   development continues.
2. **Pre-burn confidence:** a broad, repeatable check of game behavior before
   an image is burned to an EPROM.
3. **Docs versus ROM:** show where `gamerules.md`, `GAME_RULE_TRACES.md`,
   `SCORING_CHANGES.md` and `HARDWARE_MAP.md` disagree with the ROM.

## Goals

- Test scripts drive switches and read RAM, displays, lamps, solenoids and
  sound commands, deterministically, on macOS, Linux and Windows.
- Every numeric item in Deluxe `gamerules.md` "Required gameplay verification"
  becomes one or more tests. Perception items ("about three seconds", "one
  continuous flow") are tested as frame or sound-command timing windows, and
  the test says so.
- The canonical tree gets tests for its traced rules (`GAME_RULE_TRACES.md`)
  and for the original-ROM facts listed in `gamerules.md` "Existing rules
  established in the original ROM".
- `loop-score-change` gets tests for its two changes (`SCORING_CHANGES.md`).
- Comparison tests: the same scenario run on the original ROM and a
  variation must give identical observations, except where the variation
  intentionally changes behavior.
- Mapping tests confirm PinMAME's switch, solenoid and lamp numbers against
  `HARDWARE_MAP.md` (switches and solenoid order via the ROM's own self-tests
  where possible).
- The suite runs in CI on every push and fails the run on any test failure.

## Non-goals

- Ball physics, switch bounce, flipper play, or real-machine switch timing.
- Hardware timing and electrical safety (interrupt, PIA, lamp refresh,
  momentary-solenoid pulse widths); these still need the review AGENTS.md
  requires before burning.
- Audio content; tests see sound-board command bytes only.
- Rewriting the rule docs.

## Anti-goals

- A test that passes while the behavior it names is broken (every test must be
  shown to fail against a deliberately wrong expectation or a mutated ROM).
- Flaky or host-timing-dependent results.
- Writing to `src/*/roms/` or changing any built ROM.
- A suite slow enough that people stop running it (target: the whole suite in
  a few minutes on one core).
- Silently encoding a doc/ROM disagreement as the expected value.

## Constraints

- libpinmame allows one boot per process (see `tools/LibPinmameBoot.ps1`), so
  each test file runs in its own `pwsh` process.
- PowerShell 7 and the C# 5 / `Add-Type` approach already used by the boot
  test; no new dependencies.
- RAM is read through `PinmameGetRawMemoryRegion(0x81)`;
  `PinmameReadMainCPUMemory` returned zeros.
- Tests boot the tree's packaged build output, as the boot test does, so they
  test the image that would be deployed.
- Shared machine: the runner's parallelism defaults to one process and is
  capped by an argument.

## Approaches

- **PowerShell test scripts with helper commands and a minimal runner
  (chosen by the user).** Extends the boot test's C#, one language, no new
  dependency, handles reactive steps.
- Pester 5: standard framework, but a new dependency and in-process by
  default, which clashes with one boot per process.
- Data-only scenario files: declarative, but reactive steps would need a
  home-grown mini-language.

Expected values live in the tests (chosen by the user), not in tables read
from the docs. A rule change updates the test alongside the ROM.

## Design

### Lockstep machine

A C# class, extending the boot test's, owns one emulator run. The display-0
callback (the frame clock) blocks on the emulation thread after each step
until the test asks for more frames. Between steps, on the test's thread, the
test can set switches and read state. Calls:

- start from a VPM folder with fresh NVRAM/config;
- advance N frames, or until a condition (a solenoid fires, a sound command
  arrives, a RAM byte changes) with a frame limit that fails the test;
- set/get a switch;
- write RAM bytes, for seeded setup only (see "Reaching game states");
- read RAM bytes, current display text per display, current lamp states;
- read the event log (switch, lamp, solenoid, sound, display changes, each
  stamped with its frame).

The existing boot test keeps working on top of this class.

### Helper commands (PowerShell module)

- Names: `tools/` holds a name table mapping switch, solenoid, lamp and sound
  command names to PinMAME numbers. Switch names are the established names in
  `HARDWARE_MAP.md`'s page 1-18 table; solenoid names and test numbers come
  from page 1-18 per AGENTS.md.
- Service mode: enter it, step to an operator adjustment, set a value, and
  leave, through the real service switches.
- Game flow: insert coin, start a game with N players, serve a ball (a
  scripted ball model: the outhole switch opens when the outhole kicker
  fires), drain, play through to game over.
- Switch actions: hit a switch once or N times with realistic close/open
  frame counts.
- Reads: player score (from RAM, cross-checked against the display), credits,
  ball in play, CHAMP state `10C0`, sunk balls `10C3`, and other RAM the docs
  name.
- Assertions that name the doc item they check and print expected versus
  actual on failure.

### Reaching game states (decided by the user)

Tests reach states by play wherever practical. Where play is impractical
(Called Ball at 50,000; four to six racks or five E-I-G-H-T completions in
one ball; a damaged value from old NVRAM), a test may write RAM to set its
starting state; such a test is labelled `seeded` and the label appears in
its result line. Operator settings (3 or 5 balls, speech, replay thresholds,
High Score to Date) are always set through the real service-mode menus.

### Doc/ROM mismatches (decided by the user)

A test whose expected value comes from a doc fails the suite when the ROM
disagrees. Each mismatch is brought to the user, who decides whether the doc
or the ROM is wrong; the fix then goes into that file. The game-test CI job
is separate from the build and boot jobs, so their results stay readable
while mismatches are worked through.

### Tests and runner

- `tests/<tree>/<feature>.tests.ps1`; one file is one boot and may run one
  game scenario with several assertions.
- `tests/compare/*.tests.ps1` run a scenario against two ROM sets (two child
  processes) and compare observation logs.
- A runner, `Invoke-GameTests.ps1` in `tools/`: selects trees and files, builds each
  needed tree once, runs each file in its own `pwsh`, prints one line per
  test and a summary, exits nonzero on any failure. A `-Long` switch adds the
  long tier (below); the default run and CI leave it out.
- Proving tests can fail (builder's call): when a test is written, it is run
  once against a deliberately wrong expected value and must fail; the
  authoring commit notes it. The permanent automated check is the existing CI
  negative control, not per-test mutation.

### Specific items (builder's calls)

- Match (about 10% award probability): the default suite checks the logic
  deterministically, by reading the match digit and the scores' tens digits
  over a fixed set of games and requiring an award exactly when they agree.
  The frequency itself is measured over many games in the long tier only.
- "75% of the preceding Deluxe ROM's drain-bonus time": the reference is the
  build at `7d9c960`, the commit before "speedier bonus count" (`934986c`).
  Its frame counts are measured once and written into the test with that
  commit, not rebuilt on each run.
- Comparison pairs: original against `loop-score-change` covers everything
  except saucer and left/right rollover scoring. Original against Deluxe
  covers only behavior Deluxe does not rescale or redesign: coin, credit and
  game start, ball serve and drain, switch-to-solenoid responses (thumpers,
  slingshots, saucer kick), tilt, and the service-mode solenoid test order.

### CI

A separate job runs the runner for all trees on each OS after the builds
pass, and fails the run on any failure.

## Left to the builder

File names inside `tests/`, helper command names, the name-table format, the
exact assertion output, and how comparison logs are normalized (for example
ignoring display text where Deluxe intentionally rescales scores).
