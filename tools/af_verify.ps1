Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Verify-EvidencePacket {
  param(
    [Parameter(Mandatory=$true)]
    [string]$RunDir
  )

  $resolved = (Resolve-Path -LiteralPath $RunDir -ErrorAction Stop).Path
  if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
    throw "RunDir does not exist: $resolved"
  }

  $manifestPath = Join-Path $resolved "manifest.json"
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing manifest.json in run directory: $resolved"
  }

  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if (-not $manifest.artifacts) { throw "Manifest has no artifacts array: $manifestPath" }

  foreach ($item in $manifest.artifacts) {
    if (-not $item.path)   { throw "Manifest item missing path" }
    if (-not $item.sha256) { throw "Manifest item missing sha256 for path $($item.path)" }

    $artifactPath = Join-Path $resolved ($item.path -replace '/','\')
    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
      throw "Missing artifact: $($item.path)"
    }

    $hash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLower()
    if ($hash -ne ($item.sha256.ToLower())) {
      throw "Hash mismatch for $($item.path)"
    }
  }

  return $true
}
