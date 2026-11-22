# Checks tools/Invoke-GameTests.ps1 and the comparison helper on boot-free
# fixtures: files that crash, hang or print nothing count as FAILs, the summary
# counts seeded results, the runner selects kit, tree, long and compare files
# by tree, and Invoke-EbcComparedScenario reports a difference.
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

    # ---- Comparison helper, run directly (its children are boot-free). ----
    $cmp = @(& $pwshPath -NoProfile -File (Join-Path $sel 'compare/two-trees.tests.ps1') 2>&1 | ForEach-Object { "$_" })
    $cmpCode = $LASTEXITCODE
    $cmpAll = $cmp -join "`n"
    Write-Check 'Compared scenario: same tree matches' (@($cmp | Where-Object { $_ -like 'PASS *two-trees :: Same tree matches' }).Count -eq 1) $cmpAll
    Write-Check 'Compared scenario: a difference fails at its first line' (@($cmp | Where-Object { $_ -like "FAIL *two-trees :: Different trees differ :: *observation 1*'tree originals'*'tree 8bc-deluxe'*" }).Count -eq 1 -and $cmpCode -eq 1) "exit $cmpCode; $cmpAll"
    Write-Check 'Compared scenario: Normalize applies' (@($cmp | Where-Object { $_ -like 'PASS *two-trees :: Normalize hides the tree' }).Count -eq 1) $cmpAll
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
if ($script:failed -gt 0) { exit 1 }
exit 0
