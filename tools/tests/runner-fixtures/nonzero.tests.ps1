param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Runner fixture (boot-free): see tools/Test-GameTestRunner.ps1. Prints a PASS line, then exits 1 with no FAIL line.
Import-Module (Join-Path $PSScriptRoot '../../GameTest.psm1') -Force; Test-EbcItem -Name 'Passes, then exits 1' -Doc 'runner fixture' -Body { }; exit 1
