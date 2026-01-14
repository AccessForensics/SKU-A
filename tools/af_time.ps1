Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Get-UtcIso8601Ms {
  [DateTimeOffset]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
}
Export-ModuleMember -Function Get-UtcIso8601Ms
