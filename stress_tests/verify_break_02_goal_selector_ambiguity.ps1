$ErrorActionPreference = "Stop"

function Fail($msg) {
  Write-Host "`n? BREAK 2 FAILED: $msg" -ForegroundColor Red
  exit 1
}
function Pass($msg) {
  Write-Host "`n? BREAK 2 PASSED" -ForegroundColor Green
  Write-Host $msg -ForegroundColor Cyan
  exit 0
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$runsDir = Join-Path $root "runs"
if (!(Test-Path $runsDir)) { Fail "runs folder not found at: $runsDir" }

$run = Get-ChildItem $runsDir -Directory |
  Where-Object { $_.Name -like "*stress_break_goal_selector_ambiguity*" } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (!$run) { Fail "no run folder found matching *stress_break_goal_selector_ambiguity*" }

$packet = Join-Path $run.FullName "Deliverable_Packet"
$verDir = Join-Path $packet "03_Verification"
$repDir = Join-Path $packet "01_Report"

$metaPath = Join-Path $verDir "run_metadata.json"
$corePath = Join-Path $verDir "manifest_core.json"
$hashPath = Join-Path $verDir "packet_hash.txt"
$ilogPath = Join-Path $repDir "interaction_log.json"

foreach ($p in @($metaPath,$corePath,$hashPath,$ilogPath)) {
  if (!(Test-Path $p)) { Fail "missing required file: $p" }
}

$meta = Get-Content $metaPath -Raw | ConvertFrom-Json
if ($meta.status -ne "error") { Fail "expected run_metadata.status=error, got: $($meta.status)" }

# Must be ambiguity, not not-found
$err = [string]$meta.error
if ($err -notmatch "Goal Failed: Selector" -or $err -notmatch "ambiguity|matched\s+2") {
  Fail "error reason does not look like goal ambiguity (run_metadata.error: $err)"
}

$ilog = Get-Content $ilogPath -Raw | ConvertFrom-Json
$hasGoalError = $false
foreach ($e in $ilog) {
  if ($e.step_index -eq "GOAL" -and $e.action -eq "verify_goal" -and $e.result -eq "error") {
    $hasGoalError = $true
    break
  }
}
if (!$hasGoalError) { Fail "interaction_log missing GOAL-stage verify_goal error entry" }

# Non-circular sealing integrity
$expected = (Get-FileHash $corePath -Algorithm SHA256).Hash.ToLower()
$actual   = ((Get-Content $hashPath -Raw).Trim()).ToLower()
if ($expected -ne $actual) { Fail "packet_hash.txt does not match SHA-256(manifest_core.json)" }

Pass "goal_selector ambiguity correctly hard-failed at GOAL stage, packet sealed correctly."
