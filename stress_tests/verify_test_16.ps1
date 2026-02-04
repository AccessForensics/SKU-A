$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1).FullName

$manifestPath = Join-Path $run "Deliverable_Packet\03_Verification\manifest.json"

if (!(Test-Path $manifestPath)) { Write-Host "? TEST 16 FAILED: missing manifest.json" -ForegroundColor Red; exit 1 }

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$hasHash = $false
foreach ($f in $manifest.files) {
  if ($f.path -eq "03_Verification/packet_hash.txt") { $hasHash = $true; break }
}

if ($hasHash) {
  Write-Host "`n? TEST 16 PASSED" -ForegroundColor Green
  Write-Host "manifest.json includes 03_Verification/packet_hash.txt" -ForegroundColor Cyan
  exit 0
}

Write-Host "`n? TEST 16 FAILED" -ForegroundColor Red
Write-Host "manifest includes packet_hash.txt: $hasHash"
exit 1
