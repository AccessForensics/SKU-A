$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1).FullName

$manifestPath = Join-Path $run "Deliverable_Packet\03_Verification\manifest.json"
$statusPath   = Join-Path $run "Deliverable_Packet\03_Verification\STATUS.txt"

if (!(Test-Path $manifestPath)) { Write-Host "? TEST 11 FAILED: missing manifest.json" -ForegroundColor Red; exit 1 }
if (!(Test-Path $statusPath))   { Write-Host "? TEST 11 FAILED: missing STATUS.txt" -ForegroundColor Red; exit 1 }

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$hasStatus = $false
foreach ($f in $manifest.files) {
  if ($f.path -eq "03_Verification/STATUS.txt") {
    $hasStatus = $true
    break
  }
}

if ($hasStatus) {
  Write-Host "`n? TEST 11 PASSED" -ForegroundColor Green
  Write-Host "manifest.json includes 03_Verification/STATUS.txt" -ForegroundColor Cyan
  exit 0
}

Write-Host "`n? TEST 11 FAILED" -ForegroundColor Red
Write-Host "manifest includes STATUS.txt: $hasStatus"
exit 1
