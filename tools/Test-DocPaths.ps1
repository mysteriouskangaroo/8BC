[CmdletBinding()]
param(
    # Repository to check; defaults to the one containing this script.
    [string]$Root
)

# Reports paths named in tracked Markdown files that do not exist.
#   - Markdown links [text](target) resolve relative to the file.
#   - A backticked span is treated as a path when it contains '/' and its first
#     segment names an existing top-level repository entry, or an entry next to
#     the file. It must exist from the root or from the file's folder. A span
#     followed by arguments ("tools/x.ps1 -Flag") is checked up to the first
#     space when the whole span is not a path. '*' is a glob.
# Local-only, gitignored tool and build paths are exempt. Fenced code blocks
# are skipped, as are implementation plans under docs/superpowers/plans/.
# Exit 0 when clean, 1 when anything is missing.

$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Root = (Resolve-Path -LiteralPath $Root).Path

$exemptPrefixes = @('VisualPinballX/', 'dasm-', 'ghidra_', 'pinmame/', 'libpinmame-',
    'other-examples/', 'temp/', '.superpowers/')

function Test-Exempt([string]$Path) {
    $normalized = $Path -replace '^\./', ''
    foreach ($prefix in $exemptPrefixes) {
        if ($normalized.StartsWith($prefix)) { return $true }
    }
    return ($normalized -match '(^|/)build(/|$)')
}

function Test-PathFrom([string]$Base, [string]$Path) {
    $candidate = Join-Path $Base $Path
    if ($Path.Contains('*')) { return [bool](Get-Item -Path $candidate -ErrorAction SilentlyContinue) }
    return (Test-Path -LiteralPath $candidate)
}

$topLevel = @(Get-ChildItem -LiteralPath $Root -Force | ForEach-Object { $_.Name })

Push-Location $Root
try {
    # Implementation plans quote example and fixture paths on purpose.
    $files = @(& git ls-files -- '*.md' | Where-Object { -not $_.StartsWith('docs/superpowers/plans/') })
    if ($LASTEXITCODE -ne 0) { throw "git ls-files failed in $Root" }
}
finally { Pop-Location }

$problems = [System.Collections.Generic.List[string]]::new()
foreach ($relative in $files) {
    $file = Join-Path $Root $relative
    $folder = Split-Path -Parent $file
    $siblings = @(Get-ChildItem -LiteralPath $folder -Force | ForEach-Object { $_.Name })
    $inFence = $false
    foreach ($line in [System.IO.File]::ReadAllLines($file)) {
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }

        foreach ($match in [regex]::Matches($line, '\[[^\]]*\]\(\s*(<[^>]+>|[^)\s]+)')) {
            $target = $match.Groups[1].Value.Trim('<', '>')
            if ($target -match '^(https?:|mailto:|#)') { continue }
            $target = [System.Uri]::UnescapeDataString(($target -split '#')[0])
            if (-not $target -or (Test-Exempt $target)) { continue }
            if (-not (Test-PathFrom $folder $target)) { $problems.Add("${relative}: $target") }
        }

        foreach ($match in [regex]::Matches($line, '`([^`]+)`')) {
            $span = $match.Groups[1].Value.Trim()
            if (-not $span.Contains('/') -or $span -match '[<>{}]|\.\.\.|://|^\$') { continue }
            $first = (($span -replace '^\./', '') -split '/')[0]
            if ($topLevel -notcontains $first -and $siblings -notcontains $first -and $first -ne '..') { continue }
            if (Test-Exempt $span) { continue }
            if ((Test-PathFrom $Root $span) -or (Test-PathFrom $folder $span)) { continue }
            $head = ($span -split '\s+')[0]
            if ($head -ne $span -and ((Test-PathFrom $Root $head) -or (Test-PathFrom $folder $head))) { continue }
            $problems.Add("${relative}: $span")
        }
    }
}

if ($problems.Count -eq 0) {
    "Documentation paths: PASS ($($files.Count) Markdown files)"
    exit 0
}
$problems | ForEach-Object { "missing: $_" }
"Documentation paths: FAIL ($($problems.Count) missing)"
exit 1
