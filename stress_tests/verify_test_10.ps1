$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1).FullName

$metaPath = Join-Path $run "Deliverable_Packet\03_Verification\run_metadata.json"
$logPath  = Join-Path $run "Deliverable_Packet\01_Report\interaction_log.json"
$hashPath = Join-Path $run "Deliverable_Packet\03_Verification\packet_hash.txt"

if (!(Test-Path $metaPath)) { Write-Host "? TEST 10 FAILED: missing run_metadata.json" -ForegroundColor Red; exit 1 }
if (!(Test-Path $logPath))  { Write-Host "? TEST 10 FAILED: missing interaction_log.json" -ForegroundColor Red; exit 1 }
if (!(Test-Path $hashPath)) { Write-Host "? TEST 10 FAILED: missing packet_hash.txt" -ForegroundColor Red; exit 1 }

$meta = Get-Content $metaPath -Raw | ConvertFrom-Json
$log  = Get-Content $logPath  -Raw

$startLogged = $log -match "httpbin.org"
$finalLogged = $log -match "example.com"

$hash = (Get-Content $hashPath -Raw).Trim()
$hashOk = ($hash -match '^[a-fA-F0-9]{64}$')

if ($meta.status -eq "success" -and $startLogged -and $finalLogged -and $hashOk) {
  Write-Host "`n? TEST 10 PASSED" -ForegroundColor Green
  Write-Host "Start URL and final URL both logged" -ForegroundColor Cyan
  Write-Host "Packet sealed with valid hash" -ForegroundColor Cyan
  exit 0
}

Write-Host "`n? TEST 10 FAILED" -ForegroundColor Red
Write-Host "status: $($meta.status)"
Write-Host "start_url logged: $startLogged"
Write-Host "final_url logged: $finalLogged"
Write-Host "packet hash valid: $hashOk"
exit 1
