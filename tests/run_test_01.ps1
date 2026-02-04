$ErrorActionPreference = "Stop"

# Test 01: Policy Gate Misuse (allow_multiple_matches outside wait_selector)
$env:ECT_RETAIN_RAW = "1"
$env:ECT_MODE = "STRICT"

$testDir  = ".\tests"
$flowPath = Join-Path $testDir "test_01_policy_gate_misuse.json"
$htmlPath = Join-Path $testDir "t01_policy_gate.html"

if (!(Test-Path $testDir)) { New-Item -ItemType Directory -Path $testDir | Out-Null }

# Fixture HTML (simple target)
$html = @"
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Policy Gate Test</title></head>
<body>
  <button id="btn">Click Me</button>
</body>
</html>
"@
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $htmlPath), $html, $utf8NoBom)

# Flow JSON: Illegal override on click_selector
$json = @"
{
  "case_label": "test_01_policy_gate_misuse",
  "flow_id": "t01",
  "capture_mode": "interactive",
  "start_url": "file:./tests/t01_policy_gate.html",
  "steps": [
    {
      "type": "click_selector",
      "selector": "#btn",
      "timeout_ms": 2000,
      "allow_multiple_matches": true,
      "note": "This must hard fail. allow_multiple_matches is forbidden outside wait_selector."
    }
  ]
}
"@
[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $flowPath), $json, $utf8NoBom)

Write-Host "TEST 01: Created fixture + flow." -ForegroundColor Green

# Sanity parse JSON
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" $flowPath
if ($LASTEXITCODE -ne 0) { throw "Setup Failure: Invalid JSON." }

# Run executor (EXPECT FAILURE)
Write-Host "Running ect.js (expect PolicyViolation)..." -ForegroundColor Cyan
node .\ect.js $flowPath
$code = $LASTEXITCODE
if ($code -eq 0) { throw "CRITICAL FAILURE: Executor returned 0 despite policy violation." }

# Verify sealed packet
$latestRun = Get-ChildItem .\runs -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latestRun) { throw "No run directory found." }

$statusPath   = Join-Path $latestRun.FullName "Deliverable_Packet\03_Verification\STATUS.txt"
$metadataPath = Join-Path $latestRun.FullName "Deliverable_Packet\03_Verification\run_metadata.json"
if (!(Test-Path $statusPath)) { throw "STATUS.txt not found at $statusPath" }

$status = Get-Content $statusPath -Raw
if ($status -notmatch "ERROR TYPE:\s+PolicyViolation") {
  Write-Error "STATUS.txt:`n$status"
  throw "Verification Failed: Missing 'ERROR TYPE: PolicyViolation'."
}
if ($status -notmatch "allow_multiple_matches is only permitted for wait_selector") {
  Write-Error "STATUS.txt:`n$status"
  throw "Verification Failed: Missing policy violation message."
}

$meta = Get-Content $metadataPath -Raw | ConvertFrom-Json
if ($meta.error_type -ne "PolicyViolation") {
  throw "Metadata Error: expected PolicyViolation, got '$($meta.error_type)'"
}

Write-Host "TEST 01 PASS: PolicyViolation classified and sealed." -ForegroundColor Green
exit 0
