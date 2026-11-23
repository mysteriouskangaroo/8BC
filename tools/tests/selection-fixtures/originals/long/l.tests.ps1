param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Selection fixture (boot-free): see tools/Test-GameTestRunner.ps1.
Import-Module (Join-Path $PSScriptRoot '../../../../GameTest.psm1') -Force
Test-EbcItem -Name 'Runs' -Doc 'selection fixture' -Body { }
Complete-EbcTests
