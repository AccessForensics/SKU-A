Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-EvidenceManifest {
  param(
    [Parameter(Mandatory=$true)]
    [string]$RunDir
  )

  $resolved = (Resolve-Path -LiteralPath $RunDir -ErrorAction Stop).Path
  if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
    throw "RunDir does not exist: $resolved"
  }

  $manifestPath = Join-Path $resolved "manifest.json"

  $files = Get-ChildItem -LiteralPath $resolved -Recurse -File |
    Where-Object { $_.FullName -ne $manifestPath }

  $artifacts = foreach ($f in $files) {
    $rel = $f.FullName.Substring($resolved.Length).TrimStart('\')
    $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()

    [pscustomobject]@{
      path   = $rel -replace '\\','/'
      sha256 = $hash
      bytes  = [int64]$f.Length
    }
  }

  $manifest = [pscustomobject]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    artifacts        = $artifacts
  }

  $json = $manifest | ConvertTo-Json -Depth 12
  $json | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}
