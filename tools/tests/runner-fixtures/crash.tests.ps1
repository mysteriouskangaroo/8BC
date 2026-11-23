param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Runner fixture (boot-free): see tools/Test-GameTestRunner.ps1.
Import-Module (Join-Path $PSScriptRoot '../../GameTest.psm1') -Force
# Throws before printing any result line.
throw 'deliberate crash before any result line'
