$ect  = Join-Path $PSScriptRoot "..\ect.js"
$json = Join-Path $PSScriptRoot "test_07_goal_text_forbidden.json"

# Run via cmd so PowerShell does not treat stderr as a terminating error
$outLines = cmd /c "node ""$ect"" ""$json"" 2>&1"
$out = ($outLines | Out-String)

if ($out -match "goal_text is forbidden") {
  Write-Host "`n? TEST 07 PASSED" -ForegroundColor Green
  Write-Host "Reason (from executor output):" -ForegroundColor Cyan
  Write-Host ($out.Trim())
  exit 0
}

Write-Host "`n? TEST 07 FAILED" -ForegroundColor Red
Write-Host ($out.Trim())
exit 1
