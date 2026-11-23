# Checks tools/Invoke-GameTests.ps1 and the comparison helper on boot-free
# fixtures: files that crash, hang or print nothing count as FAILs, the summary
# counts seeded results, the runner selects kit, tree, long and compare files
# by tree, a file under long/ gets -LongTimeoutSeconds,
# Invoke-EbcComparedScenario reports a difference, and
# tools/tests/Test-DeluxeCoverage.ps1 applies its matching rule.
# Usage: pwsh tools/Test-GameTestRunner.ps1   (exits 1 on any failure)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $repo 'tools/Invoke-GameTests.ps1'
$pwshPath = (Get-Process -Id $PID).Path
$script:failed = 0
function Write-Check([string]$Name, [bool]$Ok, [string]$Detail) {
    if ($Ok) { Write-Output "PASS runner :: $Name" }
    else { $script:failed++; Write-Output "FAIL runner :: $Name :: $Detail" }
}

$scratch = Join-Path ([IO.Path]::GetTempPath()) ('ebc-runner-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    # ---- Runner fixtures: pass, fail, silent, crash, hang, seeded. ----
    $report = Join-Path $scratch 'report.txt'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $out = @(& $pwshPath -NoProfile -File $runner -TestRoot (Join-Path $repo 'tools/tests/runner-fixtures') -TimeoutSeconds 5 -ReportPath $report 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $clock.Stop()
    $all = $out -join "`n"
    $summary = @($out | Where-Object { $_ -like 'Game tests:*' })
    Write-Check 'Runner exits 1 on a failure' ($code -eq 1) "exit code $code; output:`n$all"
    Write-Check 'Summary counts seeded' ($summary.Count -eq 1 -and $summary[0] -eq 'Game tests: 2 passed, 4 failed, 1 seeded, 6 files') "summary lines: '$($summary -join ''' / ''')', expected 'Game tests: 2 passed, 4 failed, 1 seeded, 6 files'"
    foreach ($f in 'silent', 'crash', 'hang') {
        $line = @($out | Where-Object { $_ -match "^FAIL (\S+/)?$f :: .+ :: .+" })
        Write-Check "A $f file is a FAIL with a reason" ($line.Count -eq 1) "FAIL lines for ${f}: $($line.Count), expected 1 with a reason; output:`n$all"
    }
    $failLine = @($out | Where-Object { $_ -like 'FAIL *fail :: Always fails :: one: expected 1, actual 2 (runner fixture)' })
    Write-Check 'Assertion text names What, values and Doc' ($failLine.Count -eq 1) "output:`n$all"
    Write-Check 'Hang is cut at the timeout' ($clock.Elapsed.TotalSeconds -lt 60) ("runner took {0:N1} s with a 5 s timeout" -f $clock.Elapsed.TotalSeconds)
    $reportText = if (Test-Path -LiteralPath $report) { Get-Content -LiteralPath $report -Raw } else { '' }
    Write-Check 'Report holds the lines and summary' ($reportText -like '*Game tests: 2 passed, 4 failed, 1 seeded, 6 files*' -and $reportText -like '*PASS*pass :: Always passes*') "report.txt:`n$reportText"

    # ---- Selection: kit per tree, tree files, long only with -Long, compare with both trees. ----
    $sel = Join-Path $repo 'tools/tests/selection-fixtures'
    function Get-Planned([string[]]$Arguments) {
        @(& $pwshPath -NoProfile -File $runner -TestRoot $sel -ListOnly @Arguments 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -like 'RUN *' } | Sort-Object)
    }
    $cases = @(
        @{ Args = @('-Tree', 'originals'); Expect = @('RUN originals kit/k', 'RUN originals originals/o') },
        @{ Args = @('-Tree', 'originals', '-Long'); Expect = @('RUN originals kit/k', 'RUN originals originals/long/l', 'RUN originals originals/o') },
        @{ Args = @('-Tree', 'originals,8bc-deluxe'); Expect = @('RUN 8bc-deluxe kit/k', 'RUN compare compare/two-trees', 'RUN originals kit/k', 'RUN originals originals/o') },
        @{ Args = @('-Tree', 'loop-score-change'); Expect = @('RUN loop-score-change kit/k') }
    )
    foreach ($c in $cases) {
        $got = Get-Planned $c.Args
        $want = @($c.Expect | Sort-Object)
        Write-Check "Selection for $($c.Args -join ' ')" (($got -join '|') -eq ($want -join '|')) "planned '$($got -join ''' , ''')', expected '$($want -join ''' , ''')'"
    }

    # ---- A file under long/ gets -LongTimeoutSeconds; other files keep
    # -TimeoutSeconds. Both fixtures sleep 6 s; they have no tree, so the
    # runner builds and deploys nothing. ----
    $tmoRoot = Join-Path $repo 'tools/tests/timeout-fixtures'
    $tmo = @(& $pwshPath -NoProfile -File $runner -TestRoot $tmoRoot -Long -TimeoutSeconds 2 -LongTimeoutSeconds 60 -ReportPath (Join-Path $scratch 'timeout.txt') 2>&1 | ForEach-Object { "$_" })
    $tmoAll = $tmo -join "`n"
    Write-Check 'A long/ file runs to -LongTimeoutSeconds' (@($tmo | Where-Object { $_ -eq 'PASS slow-long :: Finishes after 6 s' }).Count -eq 1) $tmoAll
    Write-Check 'Other files keep -TimeoutSeconds' (@($tmo | Where-Object { $_ -eq 'FAIL slow :: (file) :: timed out after 2 s; process killed' }).Count -eq 1) $tmoAll
    Write-Check 'The timeout check builds nothing' (@($tmo | Where-Object { $_ -like 'BUILD *' }).Count -eq 0) $tmoAll
    $noLong = @(& $pwshPath -NoProfile -File $runner -TestRoot $tmoRoot -ListOnly 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -like 'RUN *' })
    Write-Check 'A root long/ file runs only with -Long' (($noLong -join '|') -eq 'RUN - slow') ($noLong -join ' / ')

    # ---- Comparison helper, run directly (its children are boot-free). ----
    $env:EBC_BUILT_TREES = 'originals,8bc-deluxe'
    try { $cmp = @(& $pwshPath -NoProfile -File (Join-Path $sel 'compare/two-trees.tests.ps1') 2>&1 | ForEach-Object { "$_" }) }
    finally { Remove-Item Env:EBC_BUILT_TREES -ErrorAction SilentlyContinue }
    $cmpCode = $LASTEXITCODE
    $cmpAll = $cmp -join "`n"
    Write-Check 'Compared scenario: same tree matches' (@($cmp | Where-Object { $_ -like 'PASS *two-trees :: Same tree matches' }).Count -eq 1) $cmpAll
    Write-Check 'Compared scenario: a difference fails at its first line' (@($cmp | Where-Object { $_ -like "FAIL *two-trees :: Different trees differ :: *observation 1*'tree originals'*'tree 8bc-deluxe'*" }).Count -eq 1 -and $cmpCode -eq 1) "exit $cmpCode; $cmpAll"
    Write-Check 'Compared scenario: a seeded scenario that writes RAM passes' (@($cmp | Where-Object { $_ -like 'PASS *two-trees :: Seeded compare passes `[seeded`]' }).Count -eq 1) $cmpAll
    Write-Check 'Compared scenario: an unlabelled RAM write fails' (@($cmp | Where-Object { $_ -like 'FAIL *two-trees :: Unlabelled compare write fails :: *without -Seeded*' }).Count -eq 1) $cmpAll
    Write-Check 'Compared scenario: a tree the runner did not build fails' (@($cmp | Where-Object { $_ -like "FAIL *two-trees :: Unbuilt tree fails :: *loop-score-change*not built*" }).Count -eq 1) $cmpAll
    $bare = @(& $pwshPath -NoProfile -File (Join-Path $sel 'compare/two-trees.tests.ps1') 2>&1 | ForEach-Object { "$_" })
    Write-Check 'Compared scenario: outside the runner no tree counts as built' (@($bare | Where-Object { $_ -like 'FAIL *two-trees :: Same tree matches :: *not built*' }).Count -eq 1) ($bare -join "`n")

    # ---- RAM writes need -Seeded (boot-free: the write call itself counts). ----
    $ram = @(& $pwshPath -NoProfile -File (Join-Path $repo 'tools/tests/rule-fixtures/ram-label.tests.ps1') 2>&1 | ForEach-Object { "$_" })
    $ramAll = $ram -join "`n"
    $ramWant = @(
        'FAIL ram-label :: Unlabelled write fails :: *without -Seeded*',
        'PASS ram-label :: Seeded write passes `[seeded`]',
        'PASS ram-label :: No write passes',
        'FAIL ram-label :: Write before the item fails :: *without -Seeded*',
        'FAIL ram-label :: Later items stay seeded :: *without -Seeded*')
    foreach ($w in $ramWant) {
        Write-Check ("RAM label: " + ((($w -split ' :: ')[1]) -replace '`', '')) (@($ram | Where-Object { $_ -like $w }).Count -eq 1) "expected a line like '$w'; output:`n$ramAll"
    }
    # ---- Deluxe coverage script: its matching rule on a fixture doc and test. ----
    $cf = Join-Path $repo 'tools/tests/coverage-fixtures'
    $cov = @(& $pwshPath -NoProfile -File (Join-Path $repo 'tools/tests/Test-DeluxeCoverage.ps1') -Doc (Join-Path $cf 'gamerules.md') -TestRoot (Join-Path $cf 'tests') 2>&1 | ForEach-Object { "$_" })
    $covCode = $LASTEXITCODE
    $covWant = @(
        'COVERED 500 :: clause 1 (A target scores 500 at) :: 8bc-deluxe/a.tests.ps1', 'COVERED 2x :: clause 1 (A target scores 500 at) :: 8bc-deluxe/a.tests.ps1',
        'COVERED 99K :: clause 1 (A target scores 500 at) :: 8bc-deluxe/a.tests.ps1', 'COVERED `06` :: clause 1 (A target scores 500 at) :: 8bc-deluxe/a.tests.ps1',
        'COVERED 75% :: clause 1 (A target scores 500 at) :: 8bc-deluxe/a.tests.ps1', 'COVERED $2A :: clause 1 (A target scores 500 at) :: 8bc-deluxe/a.tests.ps1',
        'MISSING 7 :: clause 1 (A target scores 500 at) :: tagged 8bc-deluxe/a.tests.ps1',
        'MISSING 444 :: clause 2 (Probes 444, 555, 777 and) :: tagged 8bc-deluxe/a.tests.ps1', 'MISSING 555 :: clause 2 (Probes 444, 555, 777 and) :: tagged 8bc-deluxe/a.tests.ps1',
        'MISSING 777 :: clause 2 (Probes 444, 555, 777 and) :: tagged 8bc-deluxe/a.tests.ps1', 'MISSING 888 :: clause 2 (Probes 444, 555, 777 and) :: tagged 8bc-deluxe/a.tests.ps1',
        'MISSING 321 :: clause 3 (An untagged clause scores 321.) :: tagged by no file',
        'Deluxe coverage: 12 clause numbers in 3 clauses, 6 covered, 6 missing, 0 bad tags, 1 test files')
    Write-Check 'Deluxe coverage: asserted clause numbers covered; -What, name, measurement, filter, message, constant comparison and untagged clause missing; section bounded' ((($cov -join '|') -eq ($covWant -join '|')) -and $covCode -eq 1) ("exit $covCode; output:`n" + ($cov -join "`n"))
    Write-Check 'Compared scenario: Normalize applies' (@($cmp | Where-Object { $_ -like 'PASS *two-trees :: Normalize hides the tree' }).Count -eq 1) $cmpAll
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
if ($script:failed -gt 0) { exit 1 }
exit 0
