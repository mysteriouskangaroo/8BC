param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Runner fixture (boot-free): see tools/Test-GameTestRunner.ps1. Prints a FAIL line, then exits 0.
Import-Module (Join-Path $PSScriptRoot '../../GameTest.psm1') -Force; Test-EbcItem -Name 'Fails, then exits 0' -Doc 'runner fixture' -Body { Assert-EbcTrue $false 'deliberate' }; exit 0
