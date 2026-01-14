Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-FileSha256Hex {
  param([Parameter(Mandatory=$true)][string]$Path)
  (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

param([Parameter(Mandatory=$true)][string]$RunDir)

$manifestPath = Join-Path $RunDir "manifest.json"
$packetHashPath = Join-Path $RunDir "packet_hash.txt"

if (!(Test-Path $manifestPath)) { throw "Missing manifest.json" }
if (!(Test-Path $packetHashPath)) { throw "Missing packet_hash.txt" }

if ((Get-FileSha256Hex $manifestPath) -ne (Get-Content $packetHashPath -Raw).Trim()) {
  throw "Packet hash mismatch"
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
foreach ($f in $manifest.files) {
  $full = Join-Path $RunDir ($f.path -replace "/","\")
  if (!(Test-Path $full)) { throw "Missing file $($f.path)" }
  if ((Get-FileSha256Hex $full) -ne $f.sha256) {
    throw "Hash mismatch $($f.path)"
  }
}

Write-Host "PASS: packet verified"
