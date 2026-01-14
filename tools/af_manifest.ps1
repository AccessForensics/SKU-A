Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-FileSha256Hex {
  param([Parameter(Mandatory=$true)][string]$Path)
  (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function New-EvidenceManifest {
  param([Parameter(Mandatory=$true)][string]$RunDir)

  $manifestPath = Join-Path $RunDir "manifest.json"
  $packetHashPath = Join-Path $RunDir "packet_hash.txt"

  $files = Get-ChildItem $RunDir -Recurse -File | Where-Object {
    $_.Name -notin @("manifest.json","packet_hash.txt")
  } | Sort-Object FullName

  $entries = foreach ($f in $files) {
    $rel = $f.FullName.Substring($RunDir.Length).TrimStart("\","/")
    [ordered]@{
      path   = ($rel -replace "\\","/")
      bytes  = $f.Length
      sha256 = Get-FileSha256Hex $f.FullName
    }
  }

  [ordered]@{
    manifest_version = "1.0"
    generated_utc    = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
    root             = (Split-Path -Leaf $RunDir)
    files            = $entries
  } | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8

  Get-FileSha256Hex $manifestPath | Set-Content $packetHashPath -Encoding ASCII
}

Export-ModuleMember -Function New-EvidenceManifest
