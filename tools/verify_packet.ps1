param(
  [Parameter(Mandatory=$true)]
  [string]$RunDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "af_verify.ps1")

try {
  [void](Verify-EvidencePacket -RunDir $RunDir)
  exit 0
} catch {
  Write-Error $_
  exit 1
}
