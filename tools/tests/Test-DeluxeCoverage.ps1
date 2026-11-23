# Checks that every number in src/8bc-deluxe/gamerules.md "Required gameplay
# verification" is asserted as an expected value by a Deluxe test: a file
# under tests/8bc-deluxe/ (long/ included), or a tests/compare/ file whose
# "# Trees:" line names 8bc-deluxe. Boots nothing. Prints one line per
# number, COVERED <number> :: <files> or MISSING <number>, then a summary, and
# exits 1 when a number is missing.
# Usage: pwsh tools/tests/Test-DeluxeCoverage.ps1 [-Doc <gamerules.md>] [-TestRoot <tests>]
#
# Numbers. The section's text is scanned for, in this order: sound bytes
# ($2A), K values (3K = 3,000), multipliers (2x), percentages (75%), display
# digits in backticks (`06`), and plain numbers with or without thousands
# commas (4,500). Ranges count as their ends (1-7 gives 1 and 7).
#
# Matching rule. A test file asserts a number when the number occurs in an
# expected value, found from the file's PowerShell syntax tree:
#   1. The expected values are the -Expected argument of every
#      Assert-EbcEqual call and the condition of every Assert-EbcTrue call.
#   2. A variable used there brings in the right-hand side of every
#      assignment to that variable in the file (and the collection of a
#      foreach loop over it), and the variables those use, repeatedly.
#      Commands called in such a right-hand side are not followed, so a
#      measurement (for example $drains = Measure-Bonus) adds nothing.
#   3. A function of the file called directly in an expected value (or in a
#      body reached by this rule) brings in its body.
#   4. In those expressions a number occurs as a numeric constant, as the
#      value of arithmetic over constants, or as a whole number inside a
#      string (a test's expected text such as '120K+240K blinking in phase'
#      or "shown '06'").
# The test name passed to Test-EbcItem -Name, its -Doc, and an assertion's
# -What text are not expected values. Because arithmetic is evaluated, a
# number matches through the doc's one-tenth scale only when the test writes
# that arithmetic (5000 / 10 counts as 500; (90000 + 9000) / 10 counts as
# 9,900, and its (90000 + 9000) as 99,000). A K value matches its value or its
# K spelling in a string (120K). A multiplier (2x) matches its number. A
# percentage matches only the fraction N/100 (0.75) or its text (75%). A sound
# byte matches the constant 0x2A or the text 2A. A backticked display value
# (`06`) matches only the text 06.

[CmdletBinding()]
param([string]$Doc, [string]$TestRoot)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $Doc) { $Doc = Join-Path $repo 'src/8bc-deluxe/gamerules.md' }
if (-not $TestRoot) { $TestRoot = Join-Path $repo 'tests' }

# ---- The section's numbers ----
$text = Get-Content -LiteralPath $Doc -Raw
$m = [regex]::Match($text, '(?ms)^## Required gameplay verification\s*$(.*?)(?=^## |\z)')
if (-not $m.Success) { throw "no 'Required gameplay verification' section in $Doc" }
$section = $m.Groups[1].Value
$tokenRx = [regex]'(?<hex>\$[0-9A-Fa-f]{2}\b)|(?<k>\b\d+K\b)|(?<x>\b\d+x\b)|(?<pct>\b\d+%)|(?<disp>`\d+`)|(?<num>\b\d{1,3}(?:,\d{3})+\b|\b\d+\b)'
$numbers = [ordered]@{}
foreach ($t in $tokenRx.Matches($section)) {
    $kind = @('hex', 'k', 'x', 'pct', 'disp', 'num') | Where-Object { $t.Groups[$_].Success } | Select-Object -First 1
    $raw = $t.Value
    $key = switch ($kind) {
        'num' { [string][long]($raw -replace ',', '') }
        'disp' { $raw }
        default { $raw.ToUpperInvariant() }
    }
    if (-not $numbers.Contains($key)) { $numbers[$key] = [PSCustomObject]@{ Kind = $kind; Text = $raw; Files = [Collections.Generic.List[string]]::new() } }
}

# ---- Each test file's expected values ----
$files = @(Get-ChildItem -LiteralPath (Join-Path $TestRoot '8bc-deluxe') -Recurse -File -Filter '*.tests.ps1')
$cmp = Join-Path $TestRoot 'compare'
if (Test-Path -LiteralPath $cmp) {
    $files += @(Get-ChildItem -LiteralPath $cmp -File -Filter '*.tests.ps1' | Where-Object {
        $line = Get-Content -LiteralPath $_.FullName -TotalCount 20 | Where-Object { $_ -match '^#\s*Trees:' } | Select-Object -First 1
        $line -and $line -match '\b8bc-deluxe\b' })
}
function Get-VarName($v) { ($v.VariablePath.UserPath -replace '^(script|global|local):', '').ToLowerInvariant() }

# The value of arithmetic (+ - * /) over numeric constants, or $null.
function Get-Folded($a) {
    if ($a -is [Management.Automation.Language.ConstantExpressionAst] -and $a -isnot [Management.Automation.Language.StringConstantExpressionAst]) { if ($a.Value -is [ValueType] -and $a.Value -isnot [bool]) { return [double]$a.Value } else { return $null } }
    if ($a -is [Management.Automation.Language.ParenExpressionAst]) {
        $pl = $a.Pipeline
        if ($pl -is [Management.Automation.Language.PipelineAst] -and $pl.PipelineElements.Count -eq 1 -and $pl.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) { return (Get-Folded $pl.PipelineElements[0].Expression) }
        return $null
    }
    if ($a -is [Management.Automation.Language.BinaryExpressionAst]) {
        $l = Get-Folded $a.Left; $r = Get-Folded $a.Right
        if ($null -eq $l -or $null -eq $r) { return $null }
        switch ([string]$a.Operator) { 'Plus' { return $l + $r } 'Minus' { return $l - $r } 'Multiply' { return $l * $r } 'Divide' { if ($r -ne 0) { return $l / $r } } }
    }
    $null
}

function Get-ExpectedFacts([string]$Path) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "$Path does not parse: $($errors[0].Message)" }
    $functions = @{}
    foreach ($f in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) { $functions[$f.Name.ToLowerInvariant()] = $f.Body }
    $assigned = @{}
    foreach ($a in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        $targets = @($a.Left.FindAll({ param($n) $n -is [Management.Automation.Language.VariableExpressionAst] }, $true) | Select-Object -First 1)
        foreach ($v in $targets) { $k = Get-VarName $v; if (-not $assigned[$k]) { $assigned[$k] = [Collections.Generic.List[object]]::new() }; $assigned[$k].Add($a.Right) }
    }
    foreach ($l in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
        $k = Get-VarName $l.Variable; if (-not $assigned[$k]) { $assigned[$k] = [Collections.Generic.List[object]]::new() }; $assigned[$k].Add($l.Condition)
    }
    # Rule 1: the roots.
    $queue = [Collections.Generic.Queue[object]]::new()
    foreach ($c in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true)) {
        $name = $c.GetCommandName()
        if ($name -ne 'Assert-EbcEqual' -and $name -ne 'Assert-EbcTrue') { continue }
        $el = $c.CommandElements
        for ($i = 1; $i -lt $el.Count; $i++) {
            if ($el[$i] -is [Management.Automation.Language.CommandParameterAst]) {
                $p = $el[$i].ParameterName
                $arg = if ($el[$i].Argument) { $el[$i].Argument } elseif ($i + 1 -lt $el.Count) { $el[$i + 1] } else { $null }
                if ($arg -and (($name -eq 'Assert-EbcEqual' -and $p -eq 'Expected') -or ($name -eq 'Assert-EbcTrue' -and $p -eq 'Condition'))) { $queue.Enqueue([PSCustomObject]@{ Ast = $arg; FollowCalls = $true }) }
                if (-not $el[$i].Argument) { $i++ }
            }
            elseif ($name -eq 'Assert-EbcTrue') { $queue.Enqueue([PSCustomObject]@{ Ast = $el[$i]; FollowCalls = $true }); break }
            elseif ($name -eq 'Assert-EbcEqual') { $queue.Enqueue([PSCustomObject]@{ Ast = $el[$i]; FollowCalls = $true }); break }
        }
    }
    # Rules 2-3: follow variables and directly called functions.
    $seenVars = @{}; $seenFuncs = @{}
    $constants = [Collections.Generic.List[double]]::new(); $strings = [Collections.Generic.List[string]]::new()
    while ($queue.Count) {
        $item = $queue.Dequeue()
        $nodes = $item.Ast.FindAll({ param($n) $true }, $true)
        foreach ($n in $nodes) {
            if ($n -is [Management.Automation.Language.ConstantExpressionAst] -and $n -isnot [Management.Automation.Language.StringConstantExpressionAst]) { $v = Get-Folded $n; if ($null -ne $v) { $constants.Add($v) } }
            elseif ($n -is [Management.Automation.Language.StringConstantExpressionAst] -or $n -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
                if ($n.Parent -is [Management.Automation.Language.CommandAst] -and $n.Parent.CommandElements[0] -eq $n) { continue }   # a command name
                $strings.Add([string]$n.Value)
            }
            elseif ($n -is [Management.Automation.Language.BinaryExpressionAst]) { $v = Get-Folded $n; if ($null -ne $v) { $constants.Add($v) } }
            elseif ($n -is [Management.Automation.Language.VariableExpressionAst]) {
                $k = Get-VarName $n
                if (-not $seenVars[$k] -and $assigned[$k]) { $seenVars[$k] = $true; foreach ($r in $assigned[$k]) { $queue.Enqueue([PSCustomObject]@{ Ast = $r; FollowCalls = $false }) } }
            }
            elseif ($item.FollowCalls -and $n -is [Management.Automation.Language.CommandAst]) {
                $f = ([string]$n.GetCommandName()).ToLowerInvariant()
                if ($f -and $functions[$f] -and -not $seenFuncs[$f]) { $seenFuncs[$f] = $true; $queue.Enqueue([PSCustomObject]@{ Ast = $functions[$f]; FollowCalls = $true }) }
            }
        }
    }
    [PSCustomObject]@{ Constants = $constants; Strings = $strings }
}

function Test-StringHas([Collections.Generic.List[string]]$Strings, [string]$Pattern) { foreach ($s in $Strings) { if ($s -match $Pattern) { return $true } }; $false }
function Test-Covered($n, [string]$key, $facts) {
    $consts = @($facts.Constants)
    $hasValue = { param([double]$v) @($consts | Where-Object { [Math]::Abs($_ - $v) -lt 1e-9 }).Count -gt 0 }
    switch ($n.Kind) {
        'hex' { $v = [Convert]::ToInt32($key.Substring(1), 16); return ((& $hasValue $v) -or (Test-StringHas $facts.Strings ('(?<![0-9A-Fa-f])' + $key.Substring(1) + '(?![0-9A-Fa-f])'))) }
        'k' { $d = [double]($key.TrimEnd('K')); return ((& $hasValue ($d * 1000)) -or (Test-StringHas $facts.Strings ('(?<![\d,])' + [regex]::Escape($key) + '(?![\dA-Za-z])'))) }
        'x' { return (& $hasValue ([double]($key.TrimEnd('X')))) }
        'pct' { $d = [double]($key.TrimEnd('%')); return ((& $hasValue ($d / 100)) -or (Test-StringHas $facts.Strings ('(?<![\d.])' + $d + '%'))) }
        'disp' { return (Test-StringHas $facts.Strings ('(?<!\d)' + $key.Trim('`') + '(?!\d)')) }
        default {
            $v = [double]$key
            $withCommas = '{0:N0}' -f [long]$v
            return ((& $hasValue $v) -or (Test-StringHas $facts.Strings ('(?<![\d,.])(' + [regex]::Escape($key) + '|' + [regex]::Escape($withCommas) + ')(?![\d,]\d)(?!\.\d)')))
        }
    }
}

foreach ($f in $files) {
    $facts = Get-ExpectedFacts $f.FullName
    $rel = [IO.Path]::GetRelativePath($TestRoot, $f.FullName) -replace '\\', '/'
    foreach ($key in $numbers.Keys) { if (Test-Covered $numbers[$key] $key $facts) { $numbers[$key].Files.Add($rel) } }
}
$missing = 0
foreach ($key in $numbers.Keys) {
    $n = $numbers[$key]
    if ($n.Files.Count) { Write-Output ("COVERED {0} :: {1}" -f $n.Text, ($n.Files -join ', ')) }
    else { $missing++; Write-Output ("MISSING {0}" -f $n.Text) }
}
Write-Output ("Deluxe coverage: {0} numbers, {1} covered, {2} missing, {3} test files" -f $numbers.Count, ($numbers.Count - $missing), $missing, $files.Count)
if ($missing) { exit 1 }
exit 0
