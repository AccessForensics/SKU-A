$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1).FullName

$manifestPath = Join-Path $run "Deliverable_Packet\03_Verification\manifest.json"

if (!(Test-Path $manifestPath)) {
  Write-Host "? TEST 14 FAILED: missing manifest.json" -ForegroundColor Red
  exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$hasPlan = $false
foreach ($f in $manifest.files) {
  if ($f.path -eq "01_Report/flow_plan.sealed.json") {
    $hasPlan = $true
    break
  }
}

if ($hasPlan) {
  Write-Host "`n? TEST 14 PASSED" -ForegroundColor Green
  Write-Host "manifest.json includes 01_Report/flow_plan.sealed.json" -ForegroundColor Cyan
  exit 0
}

Write-Host "`n? TEST 14 FAILED" -ForegroundColor Red
Write-Host "manifest includes flow_plan.sealed.json: $hasPlan"
exit 1
