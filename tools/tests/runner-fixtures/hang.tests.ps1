param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Runner fixture (boot-free): see tools/Test-GameTestRunner.ps1.
Import-Module (Join-Path $PSScriptRoot '../../GameTest.psm1') -Force
# Runs past the runner's timeout (the checker passes -TimeoutSeconds 5).
Start-Sleep -Seconds 120
Test-EbcItem -Name 'Too late' -Doc 'runner fixture' -Body { }
Complete-EbcTests
