param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# Trees: originals, 8bc-deluxe
# Selection and comparison fixture (boot-free): see tools/Test-GameTestRunner.ps1.
# The scenarios never boot, so the children need no zip; the checker sets
# EBC_BUILT_TREES as the runner would. The Write-EbcRam call throws (no
# machine) but counts as a RAM write.
Import-Module (Join-Path $PSScriptRoot '../../../GameTest.psm1') -Force
$scenario = { Add-EbcObservation "tree $Tree"; Add-EbcObservation 'common line' }
Invoke-EbcComparedScenario -Name 'Same tree matches' -Doc 'fixture' -Trees originals, originals -Scenario $scenario
Invoke-EbcComparedScenario -Name 'Different trees differ' -Doc 'fixture' -Trees originals, 8bc-deluxe -Scenario $scenario
Invoke-EbcComparedScenario -Name 'Normalize hides the tree' -Doc 'fixture' -Trees originals, 8bc-deluxe -Scenario $scenario -Normalize { $_ -replace '^tree .*', 'tree X' }
$writer = { try { Write-EbcRam -Address 0x17FE -Bytes ([byte[]]@(0x5A)) } catch { }; Add-EbcObservation 'wrote' }
Invoke-EbcComparedScenario -Name 'Seeded compare passes' -Doc 'fixture' -Seeded -Trees originals, originals -Scenario $writer
Invoke-EbcComparedScenario -Name 'Unlabelled compare write fails' -Doc 'fixture' -Trees originals, originals -Scenario $writer
Invoke-EbcComparedScenario -Name 'Unbuilt tree fails' -Doc 'fixture' -Trees originals, loop-score-change -Scenario $scenario
Complete-EbcTests
