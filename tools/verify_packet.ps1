param(
  [Parameter(Mandatory=$true)]
  [string]$RunDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRunDir = Resolve-Path $RunDir -ErrorAction Stop

if (-not (Test-Path $resolvedRunDir)) {
  throw "RunDir does not exist: $resolvedRunDir"
}

$manifestPath = Join-Path $resolvedRunDir "manifest.json"
if (-not (Test-Path $manifestPath)) {
  throw "Missing manifest.json in run directory"
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

foreach ($item in $manifest.artifacts) {
  $artifactPath = Join-Path $resolvedRunDir $item.path
  if (-not (Test-Path $artifactPath)) {
    throw "Missing artifact: $($item.path)"
  }

  $hash = Get-FileHash $artifactPath -Algorithm SHA256
  if ($hash.Hash.ToLower() -ne $item.sha256.ToLower()) {
    throw "Hash mismatch for $($item.path)"
  }
}

exit 0
