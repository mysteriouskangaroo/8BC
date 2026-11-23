param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Timeout fixture (boot-free): see tools/Test-GameTestRunner.ps1. Runs longer
# than the checker's -TimeoutSeconds 2 and shorter than its
# -LongTimeoutSeconds 60.
Import-Module (Join-Path $PSScriptRoot '../../../GameTest.psm1') -Force
Start-Sleep -Seconds 6
Test-EbcItem -Name 'Finishes after 6 s' -Doc 'timeout fixture' -Body { }
Complete-EbcTests
