param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Coverage fixture (never run): see tools/Test-GameTestRunner.ps1. 500
# through its arithmetic, 2x as a constant, 99K through a sum, '06' and 2A in
# expected text, 75% as a fraction through a function; 7 only in -What and
# the test name, so it is not asserted.
$Target = 5000 / 10
$Ratio = 0.75
function Get-Want { "shown '06', sound 2A, ratio $Ratio" }
Test-EbcItem -Name 'Scores 7' -Doc 'fixture' -Body {
    Assert-EbcEqual -Expected @($Target, 2, ((90000 + 9000))) -Actual @() -What 'seven 7'
    Assert-EbcEqual -Expected (Get-Want) -Actual '' -What 'text'
}
