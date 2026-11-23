param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Runner fixture (boot-free): see tools/Test-GameTestRunner.ps1.
Import-Module (Join-Path $PSScriptRoot '../../GameTest.psm1') -Force
# Prints no result line and exits 0; the runner must count it as a FAIL.
exit 0
