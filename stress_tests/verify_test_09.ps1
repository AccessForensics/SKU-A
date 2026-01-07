$ect  = Join-Path $PSScriptRoot "..\ect.js"
$json = Join-Path $PSScriptRoot "test_09_failed_run_sealed.json"

# Run Test 09 (EXPECTED: ERROR)
cmd /c "node ""$ect"" ""$json"""

# Pull latest run folder
$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

$metaPath   = Join-Path $run "Deliverable_Packet\03_Verification\run_metadata.json"
$statusPath = Join-Path $run "Deliverable_Packet\03_Verification\STATUS.txt"
$manPath    = Join-Path $run "Deliverable_Packet\03_Verification\manifest.json"
$hashPath   = Join-Path $run "Deliverable_Packet\03_Verification\packet_hash.txt"

if (!(Test-Path $metaPath))   { Write-Host "? TEST 09 FAILED`nMissing: $metaPath" -ForegroundColor Red; exit 1 }
if (!(Test-Path $statusPath)) { Write-Host "? TEST 09 FAILED`nMissing: $statusPath" -ForegroundColor Red; exit 1 }
if (!(Test-Path $manPath))    { Write-Host "? TEST 09 FAILED`nMissing: $manPath" -ForegroundColor Red; exit 1 }
if (!(Test-Path $hashPath))   { Write-Host "? TEST 09 FAILED`nMissing: $hashPath" -ForegroundColor Red; exit 1 }

$meta = Get-Content $metaPath -Raw | ConvertFrom-Json
$status = Get-Content $statusPath -Raw

# PASS conditions:
# 1) Sealed metadata says error
# 2) STATUS.txt says ERROR
# 3) manifest.json exists
# 4) packet_hash.txt exists and looks like a 64-char hex sha256
$hash = (Get-Content $hashPath -Raw).Trim()
$hashOk = ($hash -match '^[a-fA-F0-9]{64}$')

if ($meta.status -eq "error" -and $status -match "RUN STATUS:\s*ERROR" -and $hashOk) {
  Write-Host "`n? TEST 09 PASSED" -ForegroundColor Green
  Write-Host "Run:" -ForegroundColor Cyan
  Write-Host $run
  Write-Host "Sealed error (from run_metadata):" -ForegroundColor Cyan
  Write-Host $meta.error
  Write-Host "Packet hash:" -ForegroundColor Cyan
  Write-Host $hash
  exit 0
}

Write-Host "`n? TEST 09 FAILED" -ForegroundColor Red
Write-Host "sealed status: $($meta.status)"
Write-Host "sealed error: $($meta.error)"
Write-Host "STATUS.txt contains ERROR: $([bool]($status -match 'RUN STATUS:\s*ERROR'))"
Write-Host "packet_hash format ok: $hashOk"
exit 1
