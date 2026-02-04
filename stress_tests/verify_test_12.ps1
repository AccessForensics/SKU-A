$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1).FullName

$manifestPath = Join-Path $run "Deliverable_Packet\03_Verification\manifest.json"

if (!(Test-Path $manifestPath)) {
  Write-Host "? TEST 12 FAILED: missing manifest.json" -ForegroundColor Red
  exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$hasInteraction = $false
foreach ($f in $manifest.files) {
  if ($f.path -eq "01_Report/interaction_log.json") {
    $hasInteraction = $true
    break
  }
}

if ($hasInteraction) {
  Write-Host "`n? TEST 12 PASSED" -ForegroundColor Green
  Write-Host "manifest.json includes 01_Report/interaction_log.json" -ForegroundColor Cyan
  exit 0
}

Write-Host "`n? TEST 12 FAILED" -ForegroundColor Red
Write-Host "manifest includes interaction_log.json: $hasInteraction"
exit 1
