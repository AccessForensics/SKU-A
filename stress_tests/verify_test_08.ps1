$ect  = Join-Path $PSScriptRoot "..\ect.js"
$json = Join-Path $PSScriptRoot "test_08_goal_step_naming.json"

# Run test
cmd /c "node ""$ect"" ""$json"""

# Pull latest run
$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

$metaPath = Join-Path $run "Deliverable_Packet\03_Verification\run_metadata.json"
$logPath  = Join-Path $run "Deliverable_Packet\01_Report\interaction_log.json"
$execPath = Join-Path $run "Deliverable_Packet\01_Report\Execution_Report.txt"

if (!(Test-Path $metaPath)) { Write-Host "? TEST 08 FAILED`nMissing: $metaPath" -ForegroundColor Red; exit 1 }
if (!(Test-Path $logPath))  { Write-Host "? TEST 08 FAILED`nMissing: $logPath" -ForegroundColor Red; exit 1 }
if (!(Test-Path $json))     { Write-Host "? TEST 08 FAILED`nMissing plan: $json" -ForegroundColor Red; exit 1 }

$meta = Get-Content $metaPath -Raw | ConvertFrom-Json
$log  = Get-Content $logPath  -Raw
$plan = Get-Content $json     -Raw | ConvertFrom-Json

# PASS conditions:
# 1) Run succeeded (sealed)
# 2) Plan contains goal_selector (plan-level truth)
# 3) Some goal marker exists in sealed outputs (log or report)
$hasGoalSelector = ($plan.PSObject.Properties.Name -contains "goal_selector") -and ([string]$plan.goal_selector).Length -gt 0

$goalMarker = $false
if ($log -match "GOAL" -or $log -match "goal") { $goalMarker = $true }
if (!$goalMarker -and (Test-Path $execPath)) {
  $exec = Get-Content $execPath -Raw
  if ($exec -match "GOAL" -or $exec -match "goal") { $goalMarker = $true }
}

if ($meta.status -eq "success" -and $hasGoalSelector -and $goalMarker) {
  Write-Host "`n? TEST 08 PASSED" -ForegroundColor Green
  Write-Host "Run:" -ForegroundColor Cyan
  Write-Host $run
  Write-Host "Plan goal_selector:" -ForegroundColor Cyan
  Write-Host $plan.goal_selector
  exit 0
}

Write-Host "`n? TEST 08 FAILED" -ForegroundColor Red
Write-Host "sealed status: $($meta.status)"
Write-Host "plan goal_selector present: $hasGoalSelector"
if ($hasGoalSelector) { Write-Host "plan goal_selector: $($plan.goal_selector)" }
Write-Host "goal marker present: $goalMarker"
if ($meta.PSObject.Properties.Name -contains "error") { Write-Host "sealed error: $($meta.error)" }
exit 1
