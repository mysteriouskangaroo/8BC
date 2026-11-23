# Runs the game tests: builds each needed tree once, copies its packaged
# eballchp.zip to src/<tree>/build/game-tests/ before building the next tree,
# then runs every selected tests/**/*.tests.ps1 in its own pwsh.
#
#   tests/kit/            run once per selected tree
#   tests/<tree>/         run for that tree; tests/<tree>/long/ only with -Long
#   tests/compare/        run when both trees named in the file's
#                         "# Trees: a, b" line are selected
#   files at the root     run once with no tree and no build (runner fixtures)
# With 8bc-deluxe selected and no -Path, it also runs
# tools/tests/Test-DeluxeCoverage.ps1 and prints its result as
# 8bc-deluxe/coverage.
#
# A file that prints no result line, exits nonzero without a FAIL line, or
# runs past -TimeoutSeconds (-LongTimeoutSeconds for a file under long/)
# counts as a FAIL. Prints every result line, writes
# them to -ReportPath, ends with
#   Game tests: <p> passed, <f> failed, <s> seeded, <n> files
# and exits 1 on any failure.
# Usage: pwsh tools/Invoke-GameTests.ps1 [-Tree originals,loop-score-change,8bc-deluxe]
#        [-Path <file, folder or glob>] [-Jobs 1..4] [-Long] [-TimeoutSeconds 300]
#        [-LongTimeoutSeconds 1800]
#        [-TestRoot tests] [-ReportPath build/game-tests/report.txt] [-ListOnly]

[CmdletBinding()]
param(
    [string[]]$Tree = @('originals', 'loop-score-change', '8bc-deluxe'),
    [string]$Path,
    [ValidateRange(1, 4)][int]$Jobs = 1,
    [switch]$Long,
    [ValidateRange(1, 86400)][int]$TimeoutSeconds = 300,
    # The limit for a file under long/ (tests/<tree>/long/ holds runs longer
    # than the default limit, such as 300 games).
    [ValidateRange(1, 86400)][int]$LongTimeoutSeconds = 1800,
    [string]$TestRoot = 'tests',
    [string]$ReportPath,
    # Prints the planned runs ("RUN <tree> <file>") without building or running.
    [switch]$ListOnly
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$clock = [Diagnostics.Stopwatch]::StartNew()
$pwshPath = (Get-Process -Id $PID).Path

function Resolve-Under([string]$p) {
    if ([IO.Path]::IsPathRooted($p)) { return [IO.Path]::GetFullPath($p) }
    $here = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $p))
    if (Test-Path -LiteralPath $here) { return $here }
    [IO.Path]::GetFullPath((Join-Path $repo $p))
}
function Get-Rel([string]$base, [string]$full) { [IO.Path]::GetRelativePath($base, $full) -replace '\\', '/' }

$Tree = @($Tree | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($t in $Tree) {
    if (-not (Test-Path -LiteralPath (Join-Path $repo "src/$t/asm/build.ps1"))) { throw "Unknown tree '$t' (no src/$t/asm/build.ps1)." }
}
$root = Resolve-Under $TestRoot
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "No test folder at $root." }
if (-not $ReportPath) { $ReportPath = Join-Path $repo 'build/game-tests/report.txt' }

# ---- Plan: one entry per (file, tree) run. ----
$plan = [Collections.Generic.List[object]]::new()
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.tests.ps1' | Sort-Object FullName)
if ($Path) {
    $want = Resolve-Under $Path
    $files = @($files | Where-Object {
        $_.FullName -eq $want -or $_.FullName.StartsWith($want.TrimEnd('/', '\') + [IO.Path]::DirectorySeparatorChar) -or
        (Get-Rel $repo $_.FullName) -like $Path -or $_.FullName -like $Path })
}
foreach ($f in $files) {
    $rel = Get-Rel $root $f.FullName
    $name = $rel -replace '\.tests\.ps1$', ''
    $parts = $rel -split '/'
    $isLong = $parts -contains 'long'
    if ($isLong -and -not $Long) { continue }
    if ($parts.Count -eq 1) {
        $plan.Add([PSCustomObject]@{ File = $f.FullName; Name = $name; Tree = ''; Group = '-'; Needs = @(); Error = $null })
    }
    elseif ($parts[0] -eq 'kit') {
        foreach ($t in $Tree) { $plan.Add([PSCustomObject]@{ File = $f.FullName; Name = $name; Tree = $t; Group = $t; Needs = @($t); Error = $null }) }
    }
    elseif ($parts[0] -eq 'compare') {
        $line = Get-Content -LiteralPath $f.FullName -TotalCount 20 | Where-Object { $_ -match '^#\s*Trees:\s*(.+)$' } | Select-Object -First 1
        if (-not $line) {
            $plan.Add([PSCustomObject]@{ File = $f.FullName; Name = $name; Tree = ''; Group = 'compare'; Needs = @(); Error = "no '# Trees: a, b' line" })
            continue
        }
        $needs = @(($line -replace '^#\s*Trees:\s*', '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if (@($needs | Where-Object { $_ -notin $Tree }).Count -eq 0) {
            $plan.Add([PSCustomObject]@{ File = $f.FullName; Name = $name; Tree = ''; Group = 'compare'; Needs = $needs; Error = $null })
        }
    }
    elseif (Test-Path -LiteralPath (Join-Path $repo "src/$($parts[0])/asm/build.ps1")) {
        if ($parts[0] -in $Tree) { $plan.Add([PSCustomObject]@{ File = $f.FullName; Name = $name; Tree = $parts[0]; Group = $parts[0]; Needs = @($parts[0]); Error = $null; IsLong = $isLong }) }
    }
    else {
        $plan.Add([PSCustomObject]@{ File = $f.FullName; Name = $name; Tree = ''; Group = '-'; Needs = @(); Error = "not under kit/, compare/ or a tree folder" })
    }
}

if ($ListOnly) {
    foreach ($e in $plan) { Write-Output "RUN $($e.Group) $($e.Name)" }
    exit 0
}

$lines = [Collections.Generic.List[string]]::new()
function Emit([string]$s) { $lines.Add($s); Write-Output $s }
function Label($e) { $file = Split-Path -Leaf $e.Name; if ($e.Tree) { "$($e.Tree)/$file" } else { $file } }

# ---- Build each needed tree once, copying its zip before the next build. ----
$built = @{}
$buildError = @{}
function Get-Sha1([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($Bytes)) }
function Get-ZipCpuSha1([string]$Zip) {
    try {
        $z = [IO.Compression.ZipFile]::OpenRead($Zip)
        try {
            $e = $z.GetEntry('u3_cpu.128'); if (-not $e) { return '(no u3_cpu.128 entry)' }
            $ms = [IO.MemoryStream]::new(); $st = $e.Open(); try { $st.CopyTo($ms) } finally { $st.Dispose() }
            Get-Sha1 $ms.ToArray()
        } finally { $z.Dispose() }
    } catch { "(unreadable: $($_.Exception.Message))" }
}
$needed = @($Tree | Where-Object { $t = $_; @($plan | Where-Object { $t -in $_.Needs }).Count -gt 0 })
if ($needed.Count) {
    $logDir = Join-Path $repo 'build/game-tests'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
foreach ($t in $needed) {
    $b = [Diagnostics.Stopwatch]::StartNew()
    $log = Join-Path $logDir "build-$t.log"
    $buildArgs = @('-NoProfile', '-File', (Join-Path $repo "src/$t/asm/build.ps1"))
    if ($t -eq 'originals') { $buildArgs += '-RequireByteIdentical' }
    & $pwshPath @buildArgs *> $log
    $ok = $LASTEXITCODE -eq 0
    $zip = Join-Path $repo 'VisualPinballX/VPinMAME/roms/eballchp.zip'
    if ($ok -and (Test-Path -LiteralPath $zip)) {
        $dest = Join-Path $repo "src/$t/build/game-tests"
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        $copy = Join-Path $dest 'eballchp.zip'
        Copy-Item -LiteralPath $zip -Destination $copy -Force
        # The copy must hold this tree's CPU ROM, whatever was built before.
        $want = Get-Sha1 ([IO.File]::ReadAllBytes((Join-Path $repo "src/$t/build/u3_cpu.rebuilt.128")))
        $have = Get-ZipCpuSha1 $copy
        if ($have -eq $want) {
            $built[$t] = $copy
            Write-Output ("BUILD {0} ok in {1:N1} s (u3_cpu.128 SHA-1 {2})" -f $t, $b.Elapsed.TotalSeconds, $want)
        }
        else { $buildError[$t] = "zip check failed: $copy u3_cpu.128 SHA-1 $have, src/$t/build/u3_cpu.rebuilt.128 $want"; Write-Output "BUILD $t FAILED: $($buildError[$t])" }
    }
    else { $buildError[$t] = "build failed (exit $LASTEXITCODE; see $log)"; Write-Output "BUILD $t FAILED (exit $LASTEXITCODE); see $log" }
}

# ---- Run each file in its own pwsh, at most -Jobs at a time. ----
$privateRoot = Join-Path ([IO.Path]::GetTempPath()) ("ebc-game-tests-$PID")
New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null
$queue = [Collections.Generic.Queue[object]]::new()
$index = 0
foreach ($e in $plan) { $index++; $queue.Enqueue([PSCustomObject]@{ Entry = $e; Index = $index }) }
$running = [Collections.Generic.List[object]]::new()

function Complete-Run($r) {
    $e = $r.Entry; $label = Label $e
    $out = @($r.Out.Result -split "`r?`n" | Where-Object { $_ -ne '' })
    # pwsh's error view: keep the message lines, drop the source excerpt and markers.
    $err = @($r.Err.Result -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(Line \||\d+ \||\|\s*~*\s*$)' } |
        ForEach-Object { ($_ -replace '^\s*\|\s?', '').Trim() } | Where-Object { $_ -ne '' })
    $results = @($out | Where-Object { $_ -match '^(PASS|FAIL) ' })
    foreach ($l in $out) { if ($l -match '^(PASS|FAIL|INFO) ') { Emit $l } }
    $tail = (($err | Select-Object -Last 2) -join ' / ').Trim()
    if ($tail.Length -gt 300) { $tail = $tail.Substring(0, 300) + '...' }
    $code = $r.Code
    if ($r.TimedOut) { Emit "FAIL $label :: (file) :: timed out after $($r.Limit) s; process killed" }
    elseif ($results.Count -eq 0 -and $code -eq 0) { Emit "FAIL $label :: (file) :: printed no result lines (exit 0)" }
    elseif ($results.Count -eq 0) { Emit "FAIL $label :: (file) :: exited $code before any result line: $tail" }
    elseif ($code -ne 0 -and @($results | Where-Object { $_ -like 'FAIL *' }).Count -eq 0) { Emit "FAIL $label :: (file) :: exited $code after its results: $tail" }
    elseif ($code -eq 0 -and @($results | Where-Object { $_ -like 'FAIL *' }).Count -gt 0) { Emit "FAIL $label :: (file) :: exit 0 despite FAIL lines" }
    Remove-Item -LiteralPath $r.Dir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $r.Dir) { Emit "FAIL $label :: (file) :: private folder $($r.Dir) could not be deleted" }
}

while ($queue.Count -or $running.Count) {
    while ($queue.Count -and $running.Count -lt $Jobs) {
        $q = $queue.Dequeue(); $e = $q.Entry
        if ($e.Error) { Emit "FAIL $(Label $e) :: (file) :: $($e.Error)"; continue }
        $missing = @($e.Needs | Where-Object { -not $built.ContainsKey($_) })
        if ($missing.Count) { Emit "FAIL $(Label $e) :: (file) :: $(@($missing | ForEach-Object { "${_}: $($buildError[$_])" }) -join '; ')"; continue }
        $dir = Join-Path $privateRoot $q.Index
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $psi = [Diagnostics.ProcessStartInfo]::new($pwshPath)
        $a = @('-NoProfile', '-File', $e.File)
        if ($e.Tree) { $a += @('-Tree', $e.Tree, '-VpmZip', $built[$e.Tree]) }
        foreach ($x in $a) { $psi.ArgumentList.Add($x) }
        $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $psi.WorkingDirectory = $repo
        $psi.Environment['EBC_PRIVATE_DIR'] = $dir
        $psi.Environment['NO_COLOR'] = '1'
        # The trees whose zips this run built and checked (Invoke-EbcComparedScenario).
        $psi.Environment['EBC_BUILT_TREES'] = (@($built.Keys) | Sort-Object) -join ','
        $psi.Environment.Remove('EBC_SCENARIO') | Out-Null
        $p = [Diagnostics.Process]::Start($psi)
        $running.Add([PSCustomObject]@{ Entry = $e; Proc = $p; Dir = $dir; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync()
                                        Clock = [Diagnostics.Stopwatch]::StartNew(); TimedOut = $false; Code = $null
                                        Limit = $(if ($e.IsLong) { $LongTimeoutSeconds } else { $TimeoutSeconds }) })
    }
    foreach ($r in @($running)) {
        if (-not $r.Proc.HasExited -and $r.Clock.Elapsed.TotalSeconds -ge $r.Limit) {
            $r.TimedOut = $true
            try { $r.Proc.Kill($true) } catch { }
        }
        if ($r.Proc.HasExited) {
            $r.Proc.WaitForExit()
            $r.Code = $r.Proc.ExitCode
            [void]$running.Remove($r)
            Complete-Run $r
        }
    }
    if ($running.Count) { Start-Sleep -Milliseconds 50 }
}
Remove-Item -LiteralPath $privateRoot -Recurse -Force -ErrorAction SilentlyContinue

# ---- Deluxe coverage (boots nothing): every number in gamerules.md
# "Required gameplay verification" must be asserted by a Deluxe test. Runs
# when 8bc-deluxe is selected and the whole test folder is (no -Path). ----
if ('8bc-deluxe' -in $Tree -and -not $Path -and (Test-Path -LiteralPath (Join-Path $root '8bc-deluxe') -PathType Container)) {
    $covName = 'Every number in src/8bc-deluxe/gamerules.md "Required gameplay verification" is asserted by a Deluxe test'
    $cov = @(& $pwshPath -NoProfile -File (Join-Path $repo 'tools/tests/Test-DeluxeCoverage.ps1') -TestRoot $root 2>&1 | ForEach-Object { "$_" })
    $covCode = $LASTEXITCODE
    $covSummary = @($cov | Where-Object { $_ -like 'Deluxe coverage:*' }) -join ' '
    $covMissing = @($cov | Where-Object { $_ -like 'MISSING *' } | ForEach-Object { $_ -replace '^MISSING ', '' })
    if ($covCode -eq 0) { Emit "PASS 8bc-deluxe/coverage :: $covName" }
    elseif ($covMissing.Count) { Emit "FAIL 8bc-deluxe/coverage :: $covName :: not asserted: $($covMissing -join ', ') ($covSummary; tools/tests/Test-DeluxeCoverage.ps1 lists each number's files)" }
    else { Emit "FAIL 8bc-deluxe/coverage :: $covName :: exited $covCode`: $((@($cov) | Select-Object -Last 2) -join ' / ')" }
}

# ---- Summary. ----
$pass = @($lines | Where-Object { $_ -like 'PASS *' }).Count
$fail = @($lines | Where-Object { $_ -like 'FAIL *' }).Count
$seeded = @($lines | Where-Object { $_ -match '^(PASS|FAIL) \S+ :: .*? \[seeded\]( :: |$)' }).Count
$summary = "Game tests: $pass passed, $fail failed, $seeded seeded, $($plan.Count) files"
$wall = "Wall time: {0:N1} s" -f $clock.Elapsed.TotalSeconds
Write-Output $wall
Write-Output $summary
New-Item -ItemType Directory -Path (Split-Path -Parent $ReportPath) -Force | Out-Null
Set-Content -LiteralPath $ReportPath -Value (@($lines) + $wall + $summary) -Encoding utf8
if ($fail -gt 0 -or $plan.Count -eq 0) { exit 1 }
exit 0
