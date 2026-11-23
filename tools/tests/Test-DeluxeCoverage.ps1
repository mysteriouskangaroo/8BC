# Checks that every number in each clause of src/8bc-deluxe/gamerules.md
# "Required gameplay verification" is asserted as an expected value by a
# Deluxe test file tagged with that clause. Boots nothing. Prints one line per
# clause number, COVERED or MISSING, then a summary, and exits 1 when a number
# is missing or a tag is bad.
# Usage: pwsh tools/tests/Test-DeluxeCoverage.ps1 [-Doc <gamerules.md>] [-TestRoot <tests>]
#
# Clauses. Each "- " bullet of the section is one clause, numbered from 1.
# A test file names the clauses it checks with header lines
#   # Clause: <the clause's opening words>
# whose text (whitespace normalized) must begin exactly one clause. A clause
# number is covered only by a file tagged with that clause. The test files
# are those under tests/8bc-deluxe/ (long/ included) and the tests/compare/
# files whose "# Trees:" line names 8bc-deluxe.
#
# Numbers. A clause's text is scanned for, in this order: sound bytes ($2A),
# K values (3K = 3,000), multipliers (2x), percentages (75%), display digits
# in backticks (`06`), and plain numbers with or without thousands commas
# (4,500). Ranges count as their ends (1-7 gives 1 and 7). "8-ball" is a
# name, not a number.
#
# Expected values. A number is asserted by a file when it occurs in an
# expected value, found from the file's PowerShell syntax tree:
#   1. The roots are the -Expected argument of every Assert-EbcEqual call and
#      the condition of every Assert-EbcTrue call.
#   2. A variable brings in the right-hand side of each assignment to it in
#      the file (and the collection of a foreach loop over it), repeatedly.
#   3. A command contributes nothing, its arguments included, except
#      ForEach-Object (its script blocks are followed) and a pure function of
#      the file (its body and its arguments are followed). A function is pure
#      when neither it nor a file function it calls runs a machine command:
#      a GameTest.psm1 command other than the name lookups Get-EbcNames,
#      Get-EbcLampNumber, Get-EbcSwitch, Get-EbcSolenoid, Get-EbcRamAddress
#      and Get-EbcServiceKey. So a measurement ($x = Get-Thing -Frames 555,
#      where Get-Thing steps or reads the machine), a filter
#      (Where-Object { $_ -eq 888 }), a message (Write-Output 'msg 777') and
#      a name lookup (Get-EbcLampNumber 'Bonus 120,000') add nothing, while
#      an expected-text builder such as Want-Collect 'Right' 90000 $Terminal
#      adds its arguments.
#   4. In a comparison (-eq, -ge, -in, ...) a side counts only when the other
#      side holds a variable other than $true, $false and $null, so a
#      constant comparison such as 444 -eq 444 adds nothing.
#   5. A number occurs as a numeric constant, as the value of arithmetic over
#      constants, or as a whole number in a string's literal text (for
#      example '120K+240K blinking in phase'); the $(...) parts of a string
#      are followed as expressions, not read as text.
# The test name, -Doc and an assertion's -What text are never expected
# values. Because arithmetic is evaluated, a number matches through the
# doc's one-tenth scale only when the test writes that arithmetic (5000 / 10
# counts as 500; (90000 + 9000) counts as 99,000). A K value matches its value
# or its K spelling in a string. A multiplier (2x) matches its number. A
# percentage matches only the fraction N/100 or its text (75%). A sound byte
# matches the constant 0x2A or the text 2A. A backticked display value (`06`)
# matches only the text 06.

[CmdletBinding()]
param([string]$Doc, [string]$TestRoot)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $Doc) { $Doc = Join-Path $repo 'src/8bc-deluxe/gamerules.md' }
if (-not $TestRoot) { $TestRoot = Join-Path $repo 'tests' }

# ---- The section's clauses and their numbers ----
$text = Get-Content -LiteralPath $Doc -Raw
$m = [regex]::Match($text, '(?ms)^## Required gameplay verification\s*$(.*?)(?=^## |\z)')
if (-not $m.Success) { throw "no 'Required gameplay verification' section in $Doc" }
function Format-Space([string]$s) { ($s -replace '\s+', ' ').Trim() }
$tokenRx = [regex]'(?<hex>\$[0-9A-Fa-f]{2}\b)|(?<k>\b\d+K\b)|(?<x>\b\d+x\b)|(?<pct>\b\d+%)|(?<disp>`\d+`)|(?<num>\b\d{1,3}(?:,\d{3})+\b(?!-ball)|\b\d+\b(?!-ball))'
$clauses = @()
foreach ($b in @([regex]::Split($m.Groups[1].Value, '(?m)^- ') | Select-Object -Skip 1)) {
    $t = Format-Space $b
    $nums = [ordered]@{}
    foreach ($tok in $tokenRx.Matches($t)) {
        $kind = @('hex', 'k', 'x', 'pct', 'disp', 'num') | Where-Object { $tok.Groups[$_].Success } | Select-Object -First 1
        $key = switch ($kind) { 'num' { [string][long]($tok.Value -replace ',', '') } 'disp' { $tok.Value } default { $tok.Value.ToUpperInvariant() } }
        if (-not $nums.Contains($key)) { $nums[$key] = [PSCustomObject]@{ Kind = $kind; Text = $tok.Value; Files = [Collections.Generic.List[string]]::new() } }
    }
    $clauses += [PSCustomObject]@{ Index = $clauses.Count + 1; Text = $t; Numbers = $nums; Tagged = [Collections.Generic.List[string]]::new() }
}

# ---- Test files ----
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
$LookupCommands = @('get-ebcnames', 'get-ebclampnumber', 'get-ebcswitch', 'get-ebcsolenoid', 'get-ebcramaddress', 'get-ebcservicekey')
$Comparisons = @('Ieq', 'Ine', 'Ige', 'Igt', 'Ile', 'Ilt', 'Ceq', 'Cne', 'Cge', 'Cgt', 'Cle', 'Clt', 'Iin', 'Inotin', 'Cin', 'Cnotin', 'Icontains', 'Inotcontains', 'Ccontains', 'Cnotcontains', 'Ilike', 'Inotlike', 'Imatch', 'Inotmatch')
function Test-HasVariable($a) {
    @($a.FindAll({ param($n) $n -is [Management.Automation.Language.VariableExpressionAst] -and (Get-VarName $n) -notin @('true', 'false', 'null') }, $true)).Count -gt 0
}

# Visits an expected-value AST by rules 2-5, adding to $script:Facts.
function Invoke-Visit($a) {
    if ($null -eq $a) { return }
    if ($a -is [Management.Automation.Language.AssignmentStatementAst] -or $a -is [Management.Automation.Language.FunctionDefinitionAst] -or $a -is [Management.Automation.Language.TypeExpressionAst]) { return }
    if ($a -is [Management.Automation.Language.StringConstantExpressionAst]) { $script:Facts.Strings.Add([string]$a.Value); return }
    if ($a -is [Management.Automation.Language.ConstantExpressionAst]) { $v = Get-Folded $a; if ($null -ne $v) { $script:Facts.Constants.Add($v) }; return }
    if ($a -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
        $chars = $a.Extent.Text.ToCharArray(); $start = $a.Extent.StartOffset
        foreach ($n in $a.NestedExpressions) { for ($i = $n.Extent.StartOffset - $start; $i -lt $n.Extent.EndOffset - $start; $i++) { $chars[$i] = ' ' } }
        $script:Facts.Strings.Add((-join $chars))
        foreach ($n in $a.NestedExpressions) { Invoke-Visit $n }
        return
    }
    if ($a -is [Management.Automation.Language.VariableExpressionAst]) {
        $k = Get-VarName $a
        if (-not $script:SeenVars[$k] -and $script:Assigned[$k]) { $script:SeenVars[$k] = $true; foreach ($r in @($script:Assigned[$k])) { Invoke-Visit $r } }
        return
    }
    if ($a -is [Management.Automation.Language.CommandAst]) {
        $name = ([string]$a.GetCommandName()).ToLowerInvariant()
        if ($name -in @('foreach-object', '%', 'foreach')) {
            foreach ($e in $a.CommandElements) { if ($e -is [Management.Automation.Language.ScriptBlockExpressionAst]) { Invoke-Visit $e.ScriptBlock } }
        }
        elseif ($name -and $script:Functions[$name] -and $script:Pure[$name]) {
            if (-not $script:SeenFuncs[$name]) { $script:SeenFuncs[$name] = $true; Invoke-Visit $script:Functions[$name] }
            for ($i = 1; $i -lt $a.CommandElements.Count; $i++) {
                $e = $a.CommandElements[$i]
                if ($e -is [Management.Automation.Language.CommandParameterAst]) { Invoke-Visit $e.Argument } else { Invoke-Visit $e }
            }
        }
        return
    }
    if ($a -is [Management.Automation.Language.BinaryExpressionAst]) {
        if ([string]$a.Operator -in $Comparisons) {
            if (Test-HasVariable $a.Right) { Invoke-Visit $a.Left }
            if (Test-HasVariable $a.Left) { Invoke-Visit $a.Right }
            return
        }
        $v = Get-Folded $a; if ($null -ne $v) { $script:Facts.Constants.Add($v) }
        Invoke-Visit $a.Left; Invoke-Visit $a.Right
        return
    }
    if ($a -is [Management.Automation.Language.InvokeMemberExpressionAst]) { Invoke-Visit $a.Expression; foreach ($x in @($a.Arguments)) { Invoke-Visit $x }; return }
    if ($a -is [Management.Automation.Language.MemberExpressionAst]) { Invoke-Visit $a.Expression; return }
    foreach ($c in @($script:Children[$a])) { if ($null -ne $c) { Invoke-Visit $c } }
}

function Get-ExpectedFacts([string]$Path) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "$Path does not parse: $($errors[0].Message)" }
    $script:Children = [Collections.Generic.Dictionary[object, object]]::new([Collections.Generic.ReferenceEqualityComparer]::Instance)
    foreach ($n in $ast.FindAll({ param($x) $true }, $true)) {
        if ($null -eq $n.Parent) { continue }
        if (-not $script:Children.ContainsKey($n.Parent)) { $script:Children[$n.Parent] = [Collections.Generic.List[object]]::new() }
        $script:Children[$n.Parent].Add($n)
    }
    $script:Functions = @{}
    foreach ($f in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) { $script:Functions[$f.Name.ToLowerInvariant()] = $f.Body }
    # Pure functions (rule 3), to a fixed point over calls between them.
    $calls = @{}; $script:Pure = @{}
    foreach ($k in $script:Functions.Keys) {
        $names = @($script:Functions[$k].FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { ([string]$_.GetCommandName()).ToLowerInvariant() })
        $script:Pure[$k] = -not @($names | Where-Object { $_ -match '^[a-z]+-ebc' -and $_ -notin $LookupCommands }).Count
        $calls[$k] = @($names | Where-Object { $script:Functions.ContainsKey($_) })
    }
    do {
        $changed = $false
        foreach ($k in @($script:Functions.Keys)) { if ($script:Pure[$k] -and @($calls[$k] | Where-Object { -not $script:Pure[$_] }).Count) { $script:Pure[$k] = $false; $changed = $true } }
    } while ($changed)
    $script:Assigned = @{}
    foreach ($x in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        $v = @($x.Left.FindAll({ param($n) $n -is [Management.Automation.Language.VariableExpressionAst] }, $true) | Select-Object -First 1)
        foreach ($t in $v) { $k = Get-VarName $t; if (-not $script:Assigned[$k]) { $script:Assigned[$k] = [Collections.Generic.List[object]]::new() }; $script:Assigned[$k].Add($x.Right) }
    }
    foreach ($x in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
        $k = Get-VarName $x.Variable; if (-not $script:Assigned[$k]) { $script:Assigned[$k] = [Collections.Generic.List[object]]::new() }; $script:Assigned[$k].Add($x.Condition)
    }
    $script:SeenVars = @{}; $script:SeenFuncs = @{}
    $script:Facts = [PSCustomObject]@{ Constants = [Collections.Generic.List[double]]::new(); Strings = [Collections.Generic.List[string]]::new() }
    # Rule 1: the roots.
    foreach ($c in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true)) {
        $name = $c.GetCommandName()
        if ($name -ne 'Assert-EbcEqual' -and $name -ne 'Assert-EbcTrue') { continue }
        $want = if ($name -eq 'Assert-EbcEqual') { 'Expected' } else { 'Condition' }
        $el = $c.CommandElements; $root = $null; $positional = @()
        for ($i = 1; $i -lt $el.Count; $i++) {
            $e = $el[$i]
            if ($e -is [Management.Automation.Language.CommandParameterAst]) {
                $arg = $e.Argument
                if (-not $arg -and $i + 1 -lt $el.Count -and $el[$i + 1] -isnot [Management.Automation.Language.CommandParameterAst]) { $i++; $arg = $el[$i] }
                if ($e.ParameterName -eq $want) { $root = $arg }
            }
            else { $positional += $e }
        }
        if (-not $root -and $positional.Count) { $root = $positional[0] }
        Invoke-Visit $root
    }
    $tags = @(Get-Content -LiteralPath $Path | Where-Object { $_ -cmatch '^#\s*Clause:\s*(.+)$' } | ForEach-Object { Format-Space ($_ -replace '^#\s*Clause:\s*', '') })
    [PSCustomObject]@{ Constants = $script:Facts.Constants; Strings = $script:Facts.Strings; Tags = $tags }
}

function Test-StringHas($Strings, [string]$Pattern) { foreach ($s in $Strings) { if ($s -match $Pattern) { return $true } }; $false }
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

$bad = 0
foreach ($f in $files) {
    $facts = Get-ExpectedFacts $f.FullName
    $rel = [IO.Path]::GetRelativePath($TestRoot, $f.FullName) -replace '\\', '/'
    foreach ($tag in $facts.Tags) {
        $hit = @($clauses | Where-Object { $_.Text.StartsWith($tag, [StringComparison]::Ordinal) })
        if ($hit.Count -ne 1) { $bad++; Write-Output ("BADTAG {0} :: '# Clause: {1}' begins {2} clauses, expected 1" -f $rel, $tag, $hit.Count); continue }
        $c = $hit[0]; $c.Tagged.Add($rel)
        foreach ($key in $c.Numbers.Keys) { if (Test-Covered $c.Numbers[$key] $key $facts) { $c.Numbers[$key].Files.Add($rel) } }
    }
}
$total = 0; $missing = 0
foreach ($c in $clauses) {
    $label = "clause {0} ({1})" -f $c.Index, ((($c.Text -split ' ') | Select-Object -First 5) -join ' ')
    foreach ($key in $c.Numbers.Keys) {
        $n = $c.Numbers[$key]; $total++
        if ($n.Files.Count) { Write-Output ("COVERED {0} :: {1} :: {2}" -f $n.Text, $label, ($n.Files -join ', ')) }
        else { $missing++; Write-Output ("MISSING {0} :: {1} :: tagged {2}" -f $n.Text, $label, $(if ($c.Tagged.Count) { $c.Tagged -join ', ' } else { 'by no file' })) }
    }
}
Write-Output ("Deluxe coverage: {0} clause numbers in {1} clauses, {2} covered, {3} missing, {4} bad tags, {5} test files" -f $total, $clauses.Count, ($total - $missing), $missing, $bad, $files.Count)
if ($missing -or $bad) { exit 1 }
exit 0
