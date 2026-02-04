# run_test_03.ps1
# FINAL VERIFICATION HARNESS — Runtime Selector Ambiguity

$ErrorActionPreference = "Stop"

# 1. Environment Configuration
$env:ECT_RETAIN_RAW = "1"
$env:ECT_MODE = "STRICT"

# 2. Paths
$testDir = ".\tests"
$flowPath = Join-Path $testDir "test_03_selector_ambiguity.json"
$htmlPath = Join-Path $testDir "ambiguity.html"

if (!(Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir | Out-Null
}

# 3. HTML Fixture (2 matching elements, strict violation)
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head><title>Ambiguity Test</title></head>
<body>
    <button class="target-btn">Target A</button>
    <button class="target-btn">Target B</button>
</body>
</html>
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $htmlPath), $htmlContent, $utf8NoBom)

# 4. Flow JSON
$json = @"
{
  "case_label": "test_03_selector_ambiguity",
  "flow_id": "t03",
  "capture_mode": "interactive",
  "start_url": "file:./tests/ambiguity.html",
  "steps": [
    {
      "type": "click_selector",
      "selector": ".target-btn",
      "timeout_ms": 2000,
      "note": "Must fail due to strict selector ambiguity"
    }
  ]
}
"@

[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $flowPath), $json, $utf8NoBom)

Write-Host "Fixtures created" -ForegroundColor Green

# 5. Sanity check JSON
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" $flowPath
if ($LASTEXITCODE -ne 0) { throw "Invalid flow JSON" }

# 6. Run executor (FAILURE EXPECTED)
node .\ect.js $flowPath
$code = $LASTEXITCODE

if ($code -eq 0) {
    throw "FAIL: ect.js exited 0 despite selector ambiguity"
}

Write-Host "ect.js failed as expected ($code)" -ForegroundColor Yellow

# 7. Verify packet
$latestRun = Get-ChildItem .\runs -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latestRun) { throw "No run directory found" }

$statusPath = Join-Path $latestRun.FullName "Deliverable_Packet\03_Verification\STATUS.txt"
$metaPath   = Join-Path $latestRun.FullName "Deliverable_Packet\03_Verification\run_metadata.json"

$status = Get-Content $statusPath -Raw
$meta   = Get-Content $metaPath -Raw | ConvertFrom-Json

if ($status -notmatch "ERROR TYPE:\s+SelectorAmbiguity") {
    throw "STATUS missing SelectorAmbiguity header"
}

if ($status -notmatch "matched 2 elements") {
    throw "STATUS missing mechanical ambiguity count"
}

if ($meta.error_type -ne "SelectorAmbiguity") {
    throw "Metadata error_type mismatch"
}

Write-Host "TEST 03 PASS: Ambiguity classified and sealed correctly" -ForegroundColor Green
