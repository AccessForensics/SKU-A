$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1).FullName

$manifestPath = Join-Path $run "Deliverable_Packet\03_Verification\manifest.json"

if (!(Test-Path $manifestPath)) {
  Write-Host "? TEST 15 FAILED: missing manifest.json" -ForegroundColor Red
  exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$hasMeta = $false
foreach ($f in $manifest.files) {
  if ($f.path -eq "03_Verification/run_metadata.json") {
    $hasMeta = $true
    break
  }
}

if ($hasMeta) {
  Write-Host "`n? TEST 15 PASSED" -ForegroundColor Green
  Write-Host "manifest.json includes 03_Verification/run_metadata.json" -ForegroundColor Cyan
  exit 0
}

Write-Host "`n? TEST 15 FAILED" -ForegroundColor Red
Write-Host "manifest includes run_metadata.json: $hasMeta"
exit 1
