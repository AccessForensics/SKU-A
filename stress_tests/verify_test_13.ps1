$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1).FullName

$manifestPath = Join-Path $run "Deliverable_Packet\03_Verification\manifest.json"

if (!(Test-Path $manifestPath)) {
  Write-Host "? TEST 13 FAILED: missing manifest.json" -ForegroundColor Red
  exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$hasReport = $false
foreach ($f in $manifest.files) {
  if ($f.path -eq "01_Report/Execution_Report.txt") {
    $hasReport = $true
    break
  }
}

if ($hasReport) {
  Write-Host "`n? TEST 13 PASSED" -ForegroundColor Green
  Write-Host "manifest.json includes 01_Report/Execution_Report.txt" -ForegroundColor Cyan
  exit 0
}

Write-Host "`n? TEST 13 FAILED" -ForegroundColor Red
Write-Host "manifest includes Execution_Report.txt: $hasReport"
exit 1
