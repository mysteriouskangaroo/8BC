param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Runner fixture (boot-free): see tools/Test-GameTestRunner.ps1.
Import-Module (Join-Path $PSScriptRoot '../../GameTest.psm1') -Force
Test-EbcItem -Name 'Always passes' -Doc 'runner fixture' -Body { Assert-EbcEqual -Expected 1 -Actual 1 -What 'one' }
Complete-EbcTests
