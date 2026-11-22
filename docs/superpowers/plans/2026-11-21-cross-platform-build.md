# Cross-platform build, boot test and CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the three ROM builds and a libpinmame boot test run on macOS, Linux and Windows, and check them in GitHub Actions on every push and PR.

**Architecture:** The existing per-tree PowerShell scripts stay separate; each gets forward-slash paths and an inline OS switch for DASM. Two tracked fetch scripts download pinned, hash-checked DASM and libpinmame releases. A shared `tools/LibPinmameBoot.ps1` holds an `Add-Type` C# class that drives libpinmame; each tree's `test-pinmame.ps1` dot-sources it. One workflow runs hash, doc-path, build and boot checks.

**Tech Stack:** PowerShell 7 (builds also under Windows PowerShell 5.1), C# 5 via `Add-Type`, DASM 2.20.14.1, libpinmame v3.7.0-477-6589fc5, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-21-ci-design.md`

## Global Constraints

- Never modify `src/*/roms/`. Reference SHA-1 `25D310F169B92CE6B348330816DDC3B5710E57DA`.
- No built ROM may change: every tree's `u3_cpu.rebuilt.128` SHA-1 must equal what `main`'s scripts build on Windows.
- Builds keep working under Windows PowerShell 5.1; the boot test requires PowerShell 7.
- DASM 2.20.14.1 only. SHA-256 (recorded 2026-11-21 from the GitHub release, which publishes no digests):
  - `dasm-2.20.14.1-win-x64.zip` `c6eddbf66d451c2c924dd7609daffc647e9d302426b00082b7417811bbc172f3`
  - `dasm-2.20.14.1-osx-x64.tar.gz` `58ebb7fac917ca0884fe97dc07c2bde6a0247962902b98a8c993c410b6f67340`
  - `dasm-2.20.14.1-linux-x64.tar.gz` `c2546d7a3a5c06f2642c8303ce5fb3e747493700f0c14a5b6c14e7719183b262`
- libpinmame `v3.7.0-477-6589fc5` from `vpinball/pinmame`, SHA-256 as published by GitHub:
  - `libpinmame-3.7.0-477-6589fc5-macos-arm64.tar.gz` `ba517d624ffc526a5181b55db1cd0df06c63ba15b7b5d4388ccbf28b2437f598` → `libpinmame.3.7.0.dylib`
  - `libpinmame-3.7.0-477-6589fc5-macos-x64.tar.gz` `bd32ac08fbdcd2ec447f454a4b8b0a841bfd4a6fd62e9fba9707b9940713a375` → `libpinmame.3.7.0.dylib`
  - `libpinmame-3.7.0-477-6589fc5-linux-x64.tar.gz` `5e09b42cf26bafea29851589ec427a6a166d569f53408c8f7e9cf93a683831cd` → `libpinmame.so.3.7.0`
  - `libpinmame-3.7.0-477-6589fc5-win-x64.zip` `a0d6d3672cbddedf4a32dffc99ae3157fb6afdaeec8ed2a92d4a2721206f14d3` → `pinmame64.dll`
- CI never uploads `eballchp.zip` or any `.bin`; the repository is public.
- Commit on branch `cross-platform-build` only. Pushing needs the user's go-ahead (Task 6).
- Machine is shared: one emulator process at a time.

## Review Focus

1. A path with spaces in the repo root (Windows user folders): every path stays a `Join-Path`/quoted argument; Task 1 runs one build from a copy of the repo under a folder with a space.
2. Running a fetch script twice: second run must verify the existing unpacked tool and do nothing, not re-download or fail (Tasks 1 and 4).
3. A fetch whose download hash is wrong must delete the download and throw before unpacking (Tasks 1 and 4 test this with a deliberately wrong expected hash).
4. A boot test given a ROM that hangs in the checksum loop must exit nonzero, never 0 (Task 4's negative test).
5. The doc checker must not flag local-only, gitignored paths (`VisualPinballX/`, `dasm-*`, `ghidra_*`, `pinmame/`, `libpinmame-*`, `src/*/build/`) nor URLs (Task 3 test).

---

### Task 1: Portable builds and DASM fetch

**Files:**
- Create: `tools/Get-Dasm.ps1`
- Modify: `src/originals/asm/build.ps1`, `src/loop-score-change/asm/build.ps1`, `src/8bc-deluxe/asm/build.ps1`, `.gitignore`

**Interfaces:**
- Produces: `tools/Get-Dasm.ps1 [-ExpectedSha256Override <string>]` — unpacks to `<repo>/dasm-2.20.14.1-win-x64/dasm.exe`, `<repo>/dasm-2.20.14.1-osx-x64/dasm` or `<repo>/dasm-2.20.14.1-linux-x64/dasm` (archives have `dasm`/`dasm.exe` at their root), marks it executable off Windows, prints the path. The override exists only for the negative test.
- Produces: each `build.ps1` resolves `$assembler` with the inline switch below; all other behavior unchanged.

- [ ] **Step 1: Create the branch** — `git switch -c cross-platform-build` from `main`.
- [ ] **Step 2: Record the failing state** — run `pwsh -NoProfile -File src/originals/asm/build.ps1 -RequireByteIdentical`. Expected: throws `DASM was not found at ...dasm-2.20.14.1-win-x64\dasm.exe`.
- [ ] **Step 3: Write `tools/Get-Dasm.ps1`** — pick asset by `$IsMacOS`/`$IsLinux` (undefined on 5.1 → Windows); download from `https://github.com/dasm-assembler/dasm/releases/download/2.20.14.1/<asset>` with `Invoke-WebRequest` to a temp file; compare `Get-FileHash -Algorithm SHA256` to the pinned value; on mismatch delete and throw; unpack (`Expand-Archive` for zip, `tar -xzf` otherwise); `chmod +x` off Windows. If the binary already exists, run it and check its first output line is `DASM 2.20.14.1`, then return.
- [ ] **Step 4: Add to `.gitignore`** — exceptions `!/tools/Get-Dasm.ps1` (and in later tasks each new `tools/` file).
- [ ] **Step 5: Edit the three `build.ps1`** — replace every backslash in a path literal with `/` (lines found by `rg -n "'[^']*\\\\[^']*'" src/*/asm/*.ps1`; leave the regex `'\s+...'` in Deluxe's symbol lookup alone) and replace the `$assembler` line with:

```powershell
# Windows PowerShell 5.1 has no $IsWindows; treat it as Windows.
$dasmDirectory = if ($IsMacOS) { 'dasm-2.20.14.1-osx-x64' }
                 elseif ($IsLinux) { 'dasm-2.20.14.1-linux-x64' }
                 else { 'dasm-2.20.14.1-win-x64' }
$dasmName = if ($IsMacOS -or $IsLinux) { 'dasm' } else { 'dasm.exe' }
$assembler = Join-Path (Join-Path $repositoryRoot $dasmDirectory) $dasmName
```

- [ ] **Step 6: Verify** — `pwsh -NoProfile -File tools/Get-Dasm.ps1` twice (second run downloads nothing), then `pwsh -NoProfile -File tools/Get-Dasm.ps1 -ExpectedSha256Override 00` must throw and leave no `dasm-*` change. Then run all three builds; `originals` with `-RequireByteIdentical`. Expected: each prints `... build: PASS`; originals reports `Rebuilt SHA-1:   25D310F169B92CE6B348330816DDC3B5710E57DA` and `Byte differences: 0`. Record the two variation SHA-1s in the task report.
- [ ] **Step 7: Space-in-path check** — `git worktree add "<scratchpad>/path with space/8bc" HEAD`, copy the `dasm-2.20.14.1-osx-x64/` folder in, run the originals build there with `-RequireByteIdentical`. Expected: PASS. Remove the worktree.
- [ ] **Step 8: Commit** — `git add tools/Get-Dasm.ps1 .gitignore src/*/asm/build.ps1 && git commit -m "Make ROM builds portable; add pinned DASM fetch"`.

### Task 2: Immutable ROM hash manifest

**Files:**
- Create: `tools/rom-hashes.sha1`
- Modify: `.gitignore` (exception)

**Interfaces:**
- Produces: `tools/rom-hashes.sha1` in `shasum -a 1` format, one line per file under `src/*/roms/` (12 lines), paths relative to repo root. CI runs `shasum -a 1 -c tools/rom-hashes.sha1`.

- [ ] **Step 1: Generate** — `shasum -a 1 src/*/roms/* > tools/rom-hashes.sha1`; check every `u3_cpu.128` line reads `25d310f169b92ce6b348330816ddc3b5710e57da`.
- [ ] **Step 2: Verify positive and negative** — `shasum -a 1 -c tools/rom-hashes.sha1` → 12 `OK`, exit 0. Copy the repo's `src/` to the scratchpad, flip one byte in the copy's `src/originals/roms/u4_snd.532`, run the check from the copy → `FAILED`, exit 1.
- [ ] **Step 3: Commit** — `git commit -m "Record SHA-1s of the immutable ROMs"` with both files.

### Task 3: Documentation path checker

**Files:**
- Create: `tools/Test-DocPaths.ps1`
- Modify: `.gitignore` (exception); any `.md` with a broken path it finds (known: `src/8bc-deluxe/gamerules.md` names `new-games-design-ideas/8 Ball Champ New Rules.pptx`; the file is `8 Ball Champ Deluxe Initial Design.pptx`)

**Interfaces:**
- Produces: `tools/Test-DocPaths.ps1 [-Root <path>]` — scans `git ls-files '*.md'` under `-Root` (default repo root); exit 0 if clean, else prints `file: missing path` per problem and exits 1.

- [ ] **Step 1: Write the negative fixture test** — in the scratchpad create a tiny git repo with `a.md` containing `[x](missing.md)`, `` `src/nope.txt` ``, `` `VisualPinballX/VPinMAME/roms/eballchp.zip` ``, `` `src/originals/build/verification.txt` ``, `[web](https://example.com)` and `[ok](a.md)`. Expected after Step 3: exit 1 with exactly two problems (`missing.md`, `src/nope.txt`).
- [ ] **Step 2: Run it** — before the script exists: fails (file not found).
- [ ] **Step 3: Implement** — Markdown links `[..](target)` resolved relative to the file, ignoring `http(s):`, `mailto:` and `#anchor`-only targets and stripping `#anchor`; backticked spans that start with `src/`, `docs/` or `tools/` resolved from root, also relative to the file's folder; a `*` in the span means a glob that must match something. Exempt prefixes: `VisualPinballX/`, `dasm-`, `ghidra_`, `pinmame/`, `libpinmame-`, `other-examples/`, `temp/`, and any path containing `/build/`.
- [ ] **Step 4: Run fixture and repo** — fixture: exit 1, two problems. Repo: fix each real broken path by correcting the words (doc rules: fix by replacing the wrong path, add nothing else), rerun until exit 0. Run the `doc-review` skill on the doc diff.
- [ ] **Step 5: Commit** — `git commit -m "Add documentation path checker; fix broken doc paths"`.

### Task 4: libpinmame boot test

**Files:**
- Create: `tools/Get-LibPinmame.ps1`, `tools/LibPinmameBoot.ps1`
- Modify: `src/originals/asm/test-pinmame.ps1`, `src/loop-score-change/asm/test-pinmame.ps1`, `src/8bc-deluxe/asm/test-pinmame.ps1`, `.gitignore` (`/libpinmame-*/` ignored; tool exceptions)

**Interfaces:**
- Produces: `tools/Get-LibPinmame.ps1 [-ExpectedSha256Override <string>]` — chooses asset by OS and `[System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture` (Arm64 → macos-arm64, X64 → macos-x64 / linux-x64 / win-x64; anything else throws), downloads from `https://github.com/vpinball/pinmame/releases/download/v3.7.0-477-6589fc5/<asset>`, verifies, unpacks to `<repo>/libpinmame-3.7.0-477/`, prints the full library path. Same idempotence and mismatch rules as `Get-Dasm.ps1`.
- Produces: `tools/LibPinmameBoot.ps1`, dot-sourced, defining `Invoke-EightBallChampBootTest -LibraryPath <string> -VpmPath <string> [-Frames <int> = 1500]` returning a PSCustomObject `{ Pass [bool]; Reason [string]; Frames [int]; DisplayEvents [int]; LampEvents [int]; Stack00FC [string]; U4WrittenBytes [int]; Digest [string] }`. `-VpmPath` is a folder holding `roms/eballchp.zip`; the function clears its `nvram/`, `cfg/`, `hi/` first.
- Produces: each `test-pinmame.ps1 [-Frames <int>] [-RequireByteIdentical]` (originals only has the latter, as now) — builds, copies the package into `build/pinmame-smoke/roms/`, calls the function, writes `build/pinmame-smoke/pinmame-boot-test.txt`, exits 1 on FAIL.

- [ ] **Step 1: Write the negative test first** — a scratchpad script that copies `src/originals/roms/*` to `<scratch>/bad/roms/`, flips the byte at offset 0 of `u3_cpu.128` in the copy, zips the four as `eballchp.zip`, dot-sources `tools/LibPinmameBoot.ps1` and calls the function. Expected after Step 4: `Pass = $false`, `Stack00FC = 'c000e3e0'`, `DisplayEvents = 0`.
- [ ] **Step 2: Run it** — fails: `tools/LibPinmameBoot.ps1` not found.
- [ ] **Step 3: Write `Get-LibPinmame.ps1`**, run twice, then with `-ExpectedSha256Override 00` (must throw).
- [ ] **Step 4: Write `LibPinmameBoot.ps1`** — port the C# from the approved trial, `/private/tmp/claude-501/-Users-islandhome-git-8BC/b39aa2e4-3af1-4672-a9f7-0bac7e8aba57/scratchpad/pinmame-spike/ps/boot-test.ps1`, keeping its lessons: resolver via `NativeLibrary` in C# (PowerShell 7 only; throw a clear error on 5.1), delegates in static fields, every callback body in try/catch, events after the frame cutoff not recorded, RAM read through `PinmameGetRawMemoryRegion(0x81)` (not `PinmameReadMainCPUMemory`, which returned zeros), `PinmameStop` then wait for `PinmameIsRunning() == 0`. Pass criteria unchanged from the trial: display events > 0, stack `00FC-00FF` ≠ `C000 E3E0`, U4 RAM `1000-17FF` not all `FF`. For Windows: library resolved by full path (`pinmame64.dll`), log formatting via `_vsnprintf` from `msvcrt` instead of `vsnprintf` from `libc`. C# 5 syntax only.
- [ ] **Step 5: Run the negative test** — FAIL result as in Step 1. Then the same call against `src/originals/roms/` zipped unmodified: `Pass = $true`; call it twice in one session and check identical `Digest`.
- [ ] **Step 6: Rewrite the three `test-pinmame.ps1`** — keep the build call, package copy and report; replace the `pinmame.exe` run with the function; default `-Frames 1500`, `[ValidateRange(600, 36000)]`. The report's scope line states what the boot test proves: the ROM booted past the startup checksum and drove the displays; rules and outputs are untested.
- [ ] **Step 7: Run all three** — `pwsh -NoProfile -File src/originals/asm/test-pinmame.ps1 -RequireByteIdentical`, then the two variations. Expected: each exits 0 and its report says PASS.
- [ ] **Step 8: Commit** — `git commit -m "Replace pinmame.exe smoke test with libpinmame boot test"`.

### Task 5: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: Tasks 1–4 scripts and manifest.

Jobs:
- `rom-hashes` (ubuntu-latest): `shasum -a 1 -c tools/rom-hashes.sha1`.
- `doc-paths` (ubuntu-latest): `pwsh -NoProfile -File tools/Test-DocPaths.ps1`.
- `build` (matrix ubuntu-latest, windows-latest, macos-latest; `fail-fast: false`): `Get-Dasm.ps1`, `Get-LibPinmame.ps1`, the three `test-pinmame.ps1` (originals with `-RequireByteIdentical`), then write `hashes.txt` (`<tree> <SHA-1 of src/<tree>/build/u3_cpu.rebuilt.128>`, sorted); upload artifact `build-<os>` containing `hashes.txt` and each tree's `build/verification.txt`, `*.lst`, `*.sym`, `pinmame-smoke/pinmame-boot-test.txt`. On macOS, run `/usr/bin/arch -x86_64 /usr/bin/true || softwareupdate --install-rosetta --agree-to-license` before the builds (the DASM binary is x86-64).
- `windows-ps51` (windows-latest): `Get-Dasm.ps1` under `pwsh`, then each `build.ps1` under `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...`; upload `hashes.txt` as `build-ps51`.
- `compare` (needs `build`, `windows-ps51`): download all `build-*` artifacts; fail unless every `hashes.txt` is identical.
- `baseline` (pull_request only, windows-latest): check out `github.event.pull_request.base.sha` into `base/`, put DASM win-x64 in `base/`, run each base-tree `build.ps1` under `powershell.exe`, and write a job-summary table of base vs head SHA-1 per tree. Report only; never fails.

- [ ] **Step 1: Lint** — `actionlint .github/workflows/ci.yml` if available (`brew install actionlint` needs the user's OK; otherwise skip and say so). Check every artifact path list against the anti-goal: no `*.zip`, no `*.bin`.
- [ ] **Step 2: Commit** — `git commit -m "Add CI: ROM hashes, doc paths, cross-platform builds and boot tests"`.

### Task 6: Docs, push and CI proof

**Files:**
- Modify: `README.md` (Local tools; step 5–6 of Next analysis stages), `src/*/asm/readme.txt`, `src/loop-score-change/README.md`, `AGENTS.md` (smoke-test paragraphs)

- [ ] **Step 1: Update tool docs** — each readme shows `pwsh -File src/<tree>/asm/build.ps1` (any OS) next to the existing Windows line, and `tools/Get-Dasm.ps1` / `tools/Get-LibPinmame.ps1` as setup; README's Local tools names DASM by version rather than the win-x64 path. Run `tools/Test-DocPaths.ps1` and the `doc-review` skill.
- [ ] **Step 2: AGENTS.md wording** — the smoke-test paragraphs describe a finite-frame `pinmame.exe` run that "can falsely pass while the CPU spins in the checksum-failure loop". Draft replacement sentences and bring them to the user for approval (exact sentences, plain option included) before committing.
- [ ] **Step 3: Commit** docs.
- [ ] **Step 4: Ask the user to push** `cross-platform-build` and open a PR. Then watch the run, reporting each job as it finishes.
- [ ] **Step 5: Proof** — all jobs green; `compare` passes; the `baseline` summary shows head SHA-1 = base SHA-1 for all three trees; Task 1's recorded variation hashes appear unchanged. Report the three hashes and any job output that differed.
