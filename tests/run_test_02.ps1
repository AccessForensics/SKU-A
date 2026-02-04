# ============================================================
# TEST 02 – Step Indexing & Navigation Provenance Contract
#
# CONTRACT:
#  • Step 001 is ALWAYS navigation provenance
#  • Navigation MUST emit 3 entries at step_index=1:
#       navigation
#       navigation_resolved
#       navigation_final_url
#    (Also accepts provenance_* variants for forward compatibility)
#  • Step 002+ map to plan steps
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host "TEST 02: Step indexing contract, Step 001 = navigation provenance, Step 002+ = plan steps." -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Environment
# ------------------------------------------------------------
$env:ECT_RETAIN_RAW = "0"
$env:ECT_MODE = "STRICT"

# ------------------------------------------------------------
# 2. Paths
# ------------------------------------------------------------
$testDir  = ".\tests"
$htmlPath = Join-Path $testDir "t02_indexing.html"
$flowPath = Join-Path $testDir "test_02_step_indexing.json"

if (!(Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir | Out-Null
}

# ------------------------------------------------------------
# 3. HTML Fixture
# ------------------------------------------------------------
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Test 02</title>
</head>
<body>
  <button id="btn">Click Me</button>
</body>
</html>
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $htmlPath), $html, $utf8NoBom)

# ------------------------------------------------------------
# 4. Flow JSON
# ------------------------------------------------------------
$json = @"
{
  "case_label": "test_02_step_indexing",
  "flow_id": "t02",
  "capture_mode": "interactive",
  "start_url": "file:./tests/t02_indexing.html",
  "steps": [
    { "type": "wait_selector", "selector": "#btn" },
    { "type": "click_selector", "selector": "#btn" }
  ]
}
"@

[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $flowPath), $json, $utf8NoBom)

Write-Host "Fixtures and flow ready." -ForegroundColor Green

# ------------------------------------------------------------
# 5. Run Executor
# ------------------------------------------------------------
Write-Host "Running ect.js..." -ForegroundColor Cyan
node .\ect.js $flowPath
if ($LASTEXITCODE -ne 0) { throw "TEST 02 FAIL: Executor exited non-zero on a success-path test." }

# ------------------------------------------------------------
# 6. Locate Latest Run
# ------------------------------------------------------------
$latestRun = Get-ChildItem .\runs -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latestRun) { throw "TEST 02 FAIL: No run directory created." }

$packet  = Join-Path $latestRun.FullName "Deliverable_Packet"
$logPath = Join-Path $packet "01_Report\interaction_log.json"
if (!(Test-Path $logPath)) { throw "TEST 02 FAIL: interaction_log.json not found." }

$log = Get-Content $logPath -Raw | ConvertFrom-Json

# ------------------------------------------------------------
# 7. Verify Navigation Provenance (Step 001)
# Accepts either legacy 'navigation*' OR newer 'provenance_*'
# ------------------------------------------------------------
function HasEntry($actionName, $stepIndex) {
    return ($log | Where-Object { $_.action -eq $actionName -and $_.step_index -eq $stepIndex } | Select-Object -First 1)
}

$navStart    = (HasEntry "navigation" 1) -or (HasEntry "provenance_start_url" 1)
$navResolved = (HasEntry "navigation_resolved" 1) -or (HasEntry "provenance_resolved_start_url" 1)
$navFinal    = (HasEntry "navigation_final_url" 1) -or (HasEntry "provenance_final_url" 1)

if (-not $navStart)    { throw "TEST 02 FAIL: Missing navigation/provenance_start_url at Step 001." }
if (-not $navResolved) { throw "TEST 02 FAIL: Missing navigation_resolved/provenance_resolved_start_url at Step 001." }
if (-not $navFinal)    { throw "TEST 02 FAIL: Missing navigation_final_url/provenance_final_url at Step 001." }

# Optional, enforce that all three are exactly step_index=1, not GOAL or 2+
# (We already required step_index=1 above, so this is redundant but explicit.)
Write-Host "Step 001 navigation provenance found." -ForegroundColor Green

# ------------------------------------------------------------
# 8. Verify Step Mapping
# ------------------------------------------------------------
$waitStep  = $log | Where-Object { $_.action -eq "wait_selector" -and $_.step_index -eq 2 } | Select-Object -First 1
$clickStep = $log | Where-Object { $_.action -eq "click_selector" -and $_.step_index -eq 3 } | Select-Object -First 1

if (-not $waitStep)  { throw "TEST 02 FAIL: wait_selector not recorded at Step 002." }
if (-not $clickStep) { throw "TEST 02 FAIL: click_selector not recorded at Step 003." }

Write-Host "TEST 02 PASS: Step 001 navigation provenance verified. Step indexing contract enforced." -ForegroundColor Green
