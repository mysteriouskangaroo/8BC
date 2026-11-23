param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Coverage fixture (never run): see tools/Test-GameTestRunner.ps1. Clause 1:
# 500 through its arithmetic, 2x as a constant, 99K through a sum, '06' and
# 2A in expected text, 75% as a fraction through a pure function; 7 only in
# -What and the test name. Clause 2: the reviewer's probes, none an expected
# value. Clause 3 (321) is asserted but no file is tagged with it. Clause
# 4: an index into a measured list and a format placeholder.
# Clause: A target scores 500
# Clause: Probes 444
# Clause: Index 6543
$Target = 5000 / 10
$Ratio = 0.75
function Get-Want { "shown '06', sound 2A, ratio $Ratio" }
function Get-Thing { param($Frames) Step-EbcFrames -Frames $Frames; 1 }
function Get-Text { Write-Output 'msg 777'; 'ok' }
$x = Get-Thing -Frames 555
$items = @(1, 2)
$list = @($items | Where-Object { $_ -eq 888 })
$measured = @(Get-Thing -Frames 1)
Test-EbcItem -Name 'Scores 7' -Doc 'fixture' -Body {
    Assert-EbcEqual -Expected @($Target, 2, ((90000 + 9000)), 321) -Actual @() -What 'seven 7'
    Assert-EbcEqual -Expected (Get-Want) -Actual '' -What 'text'
    Assert-EbcTrue ($true -or 444 -eq 444) 'tautology'
    Assert-EbcEqual -Expected $x -Actual 1 -What 'measured'
    Assert-EbcEqual -Expected (Get-Text) -Actual 'ok' -What 'message'
    Assert-EbcEqual -Expected $list -Actual @() -What 'filtered'
    Assert-EbcEqual -Expected $measured[6543] -Actual 1 -What 'indexed'
    Assert-EbcEqual -Expected ('{3}{0}{1}{2}' -f 'a', 'b', 'c', 'd') -Actual 'dabc' -What 'formatted'
}
