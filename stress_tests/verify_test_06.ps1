# Test 06 Verification ? Ambiguity Hard-Fail (Sealed Metadata)

$run = (Get-ChildItem .\runs -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$meta = Get-Content "$run\Deliverable_Packet\03_Verification\run_metadata.json" | ConvertFrom-Json

if ($meta.status -eq "error" -and $meta.error -match "Ambiguity Error") {
    Write-Host "`n? TEST 06 PASSED" -ForegroundColor Green
    Write-Host "Reason (from sealed metadata):" -ForegroundColor Cyan
    Write-Host $meta.error
} else {
    Write-Host "`n? TEST 06 FAILED" -ForegroundColor Red
    Write-Host "Unexpected status or error:" -ForegroundColor Yellow
    Write-Host $meta.error
}
