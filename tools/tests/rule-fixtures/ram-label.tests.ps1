param([string]$Tree, [string]$VpmZip, [string]$ObserveTo)
# RAM-write label fixture (boot-free): see tools/Test-GameTestRunner.ps1.
# No machine runs, so Write-EbcRam throws; the module counts the call as a
# RAM write all the same.
Import-Module (Join-Path $PSScriptRoot '../../GameTest.psm1') -Force
function Invoke-TryWrite { try { Write-EbcRam -Address 0x17FE -Bytes ([byte[]]@(0x5A)) } catch { } }
Test-EbcItem -Name 'Unlabelled write fails' -Doc 'fixture' -Body { Invoke-TryWrite }
Test-EbcItem -Name 'Seeded write passes' -Doc 'fixture' -Seeded -Body { Invoke-TryWrite }
Test-EbcItem -Name 'No write passes' -Doc 'fixture' -Body { }
Invoke-TryWrite
Test-EbcItem -Name 'Write before the item fails' -Doc 'fixture' -Body { }
Test-EbcItem -Name 'Later items stay seeded' -Doc 'fixture' -Body { }
Complete-EbcTests
