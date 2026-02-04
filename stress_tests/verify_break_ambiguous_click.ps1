$run = (Get-ChildItem (Join-Path $PSScriptRoot "..\runs") -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1).FullName

$verDir = Join-Path $run "Deliverable_Packet\03_Verification"
$repDir = Join-Path $run "Deliverable_Packet\01_Report"

$manifestPath     = Join-Path $verDir "manifest.json"
$manifestCorePath = Join-Path $verDir "manifest_core.json"
$packetHashPath   = Join-Path $verDir "packet_hash.txt"
$statusPath       = Join-Path $verDir "STATUS.txt"
$metaPath         = Join-Path $verDir "run_metadata.json"
$ilogPath         = Join-Path $repDir "interaction_log.json"

function Fail($msg) { Write-Host "`n❌ BREAK TEST FAILED: $msg" -ForegroundColor Red; exit 1 }
function Pass($msg) { Write-Host "`n✅ BREAK TEST PASSED" -ForegroundColor Green; Write-Host $msg -ForegroundColor Cyan; exit 0 }

if (!(Test-Path $manifestPath))     { Fail "missing manifest.json" }
if (!(Test-Path $manifestCorePath)) { Fail "missing manifest_core.json" }
if (!(Test-Path $packetHashPath))   { Fail "missing packet_hash.txt" }
if (!(Test-Path $statusPath))       { Fail "missing STATUS.txt" }
if (!(Test-Path $metaPath))         { Fail "missing run_metadata.json" }
if (!(Test-Path $ilogPath))         { Fail "missing interaction_log.json" }

$meta = Get-Content $metaPath -Raw | ConvertFrom-Json
if ($meta.status -ne "error") { Fail "run_metadata.status is not error (got: $($meta.status))" }

$statusTxt = Get-Content $statusPath -Raw
if ($statusTxt -notmatch "RUN STATUS:\s*ERROR") { Fail "STATUS.txt does not show RUN STATUS: ERROR" }

# Error reason must indicate ambiguity
$err = [string]$meta.error
if (($err -notmatch "Ambiguity") -and ($err -notmatch "matched\s+2") -and ($err -notmatch "matched\s+\d+\s+elements")) {
  Fail "error reason does not look like ambiguity (run_metadata.error: $err)"
}

# manifest.json must include packet_hash.txt entry (Test 16 requirement)
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$hasPacketHashEntry = $false
foreach ($f in $manifest.files) {
  if ($f.path -eq "03_Verification/packet_hash.txt") { $hasPacketHashEntry = $true; break }
}
if (!$hasPacketHashEntry) { Fail "manifest.json does not include 03_Verification/packet_hash.txt" }

# Non-circular sealing check: packet_hash.txt == SHA256(manifest_core.json bytes)
$expected = (Get-FileHash -Algorithm SHA256 $manifestCorePath).Hash.ToLower()
$actual = ((Get-Content $packetHashPath -Raw).Trim()).ToLower()
if ($expected -ne $actual) { Fail "packet_hash.txt does not match SHA-256(manifest_core.json). expected=$expected actual=$actual" }

# interaction_log must show click_selector error
$ilog = Get-Content $ilogPath -Raw | ConvertFrom-Json
$hasClickError = $false
foreach ($e in $ilog) {
  if ($e.action -eq "click_selector" -and $e.result -eq "error") { $hasClickError = $true; break }
}
if (!$hasClickError) { Fail "interaction_log does not contain click_selector with result=error" }

Pass "Ambiguous selector click hard-failed, and packet sealing is intact (manifest includes packet_hash, packet_hash seals manifest_core)."
