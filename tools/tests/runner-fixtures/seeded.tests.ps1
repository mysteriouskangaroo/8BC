param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Runner fixture (boot-free): see tools/Test-GameTestRunner.ps1.
Import-Module (Join-Path $PSScriptRoot '../../GameTest.psm1') -Force
Test-EbcItem -Name 'Seeded passes' -Doc 'runner fixture' -Seeded -Body { Assert-EbcEqual -Expected 2 -Actual 2 -What 'two' }
Complete-EbcTests
