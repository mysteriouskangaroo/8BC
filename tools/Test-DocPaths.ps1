[CmdletBinding()]
param(
    # Repository to check; defaults to the one containing this script.
    [string]$Root
)

# Reports paths named in tracked Markdown and .txt files that do not exist.
#   - Markdown links [text](target) resolve relative to the file.
#   - In Markdown, a backticked span is a candidate path; in .txt files every
#     whitespace-separated word is. A candidate counts as a path when it
#     contains '/' or '\' and its first segment names an existing top-level
#     repository entry, an entry next to the file, or '..'. Backslashes are
#     read as '/', and a leading '/' means the repository root. It must exist
#     from the root or from the file's folder. A span followed by arguments
#     ("tools/x.ps1 -Flag") is checked up to the first space when the whole
#     span is not a path. '*' is a glob.
# Local-only, gitignored tool and build paths are exempt wherever a path
# resolves to them. Fenced code blocks are skipped, as are implementation plans
# under docs/superpowers/plans/. Exit 0 when clean, 1 when anything is missing.

$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Root = (Resolve-Path -LiteralPath $Root).Path

$exemptPrefixes = @('VisualPinballX/', 'dasm-', 'ghidra_', 'pinmame/', 'libpinmame-',
    'other-examples/', 'temp/', '.superpowers/')

# Repository-relative form of $Path read from a file in $Folder, or $null when
# it points outside the repository.
function Get-RepositoryRelative([string]$Folder, [string]$Path) {
    $full = [System.IO.Path]::GetFullPath((Join-Path $Folder $Path))
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('/', '\')
    if (-not $full.StartsWith($rootFull)) { return $null }
    return $full.Substring($rootFull.Length).TrimStart('/', '\').Replace('\', '/')
}

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

# Returns $null when $Text is not a path or exists; otherwise the text to report.
function Test-Candidate([string]$Text, [string]$Folder, [string[]]$Siblings) {
    $span = $Text.Trim()
    if (-not ($span.Contains('/') -or $span.Contains('\'))) { return $null }
    if ($span -match '[<>{}]|\.\.\.|://|^\$') { return $null }
    $path = $span.Replace('\', '/')
    $fromRootOnly = $path.StartsWith('/')
    $path = $path.TrimStart('/') -replace '^\./', ''
    $first = ($path -split '/')[0]
    if ($topLevel -notcontains $first -and ($fromRootOnly -or ($Siblings -notcontains $first -and $first -ne '..'))) {
        return $null
    }
    $bases = if ($fromRootOnly) { @($Root) } else { @($Root, $Folder) }
    foreach ($base in $bases) {
        $relative = Get-RepositoryRelative $base $path
        if ($relative -and (Test-Exempt $relative)) { return $null }
    }
    foreach ($candidate in @($path, ($path -split '\s+')[0]) | Select-Object -Unique) {
        foreach ($base in $bases) { if (Test-PathFrom $base $candidate) { return $null } }
    }
    return $span
}

$topLevel = @(Get-ChildItem -LiteralPath $Root -Force | ForEach-Object { $_.Name })

Push-Location $Root
try {
    # Implementation plans quote example and fixture paths on purpose.
    $files = @(& git ls-files -- '*.md' '*.txt' | Where-Object { -not $_.StartsWith('docs/superpowers/plans/') })
    if ($LASTEXITCODE -ne 0) { throw "git ls-files failed in $Root" }
}
finally { Pop-Location }

$problems = [System.Collections.Generic.List[string]]::new()
foreach ($relative in $files) {
    $file = Join-Path $Root $relative
    $folder = Split-Path -Parent $file
    $siblings = @(Get-ChildItem -LiteralPath $folder -Force | ForEach-Object { $_.Name })
    $isMarkdown = $relative.EndsWith('.md')
    $inFence = $false
    foreach ($line in [System.IO.File]::ReadAllLines($file)) {
        if (-not $isMarkdown) {
            foreach ($word in ($line -split '\s+')) {
                $word = $word -replace '^["''()\[\]`]+|["''()\[\]`.,;:]+$', ''
                if (-not $word) { continue }
                $problem = Test-Candidate $word $folder $siblings
                if ($problem) { $problems.Add("${relative}: $problem") }
            }
            continue
        }

        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }

        foreach ($match in [regex]::Matches($line, '\[[^\]]*\]\(\s*(<[^>]+>|[^)\s]+)')) {
            $target = $match.Groups[1].Value.Trim('<', '>')
            if ($target -match '^(https?:|mailto:|#)') { continue }
            $target = [System.Uri]::UnescapeDataString(($target -split '#')[0])
            if (-not $target) { continue }
            $resolved = Get-RepositoryRelative $folder $target
            if (($resolved -and (Test-Exempt $resolved)) -or (Test-Exempt $target)) { continue }
            if (-not (Test-PathFrom $folder $target)) { $problems.Add("${relative}: $target") }
        }

        foreach ($match in [regex]::Matches($line, '`([^`]+)`')) {
            $problem = Test-Candidate $match.Groups[1].Value $folder $siblings
            if ($problem) { $problems.Add("${relative}: $problem") }
        }
    }
}

if ($problems.Count -eq 0) {
    "Documentation paths: PASS ($($files.Count) Markdown and text files)"
    exit 0
}
$problems | ForEach-Object { "missing: $_" }
"Documentation paths: FAIL ($($problems.Count) missing)"
exit 1
