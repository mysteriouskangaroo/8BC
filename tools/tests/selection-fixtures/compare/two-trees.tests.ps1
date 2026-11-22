param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# Selection and comparison fixture (boot-free): see tools/Test-GameTestRunner.ps1.
# The scenario never boots, so the children need no zip.
Import-Module (Join-Path $PSScriptRoot '../../../GameTest.psm1') -Force
$scenario = { Add-EbcObservation "tree $Tree"; Add-EbcObservation 'common line' }
Invoke-EbcComparedScenario -Name 'Same tree matches' -Doc 'fixture' -Trees originals, originals -Scenario $scenario
Invoke-EbcComparedScenario -Name 'Different trees differ' -Doc 'fixture' -Trees originals, 8bc-deluxe -Scenario $scenario
Invoke-EbcComparedScenario -Name 'Normalize hides the tree' -Doc 'fixture' -Trees originals, 8bc-deluxe -Scenario $scenario -Normalize { $_ -replace '^tree .*', 'tree X' }
Complete-EbcTests
