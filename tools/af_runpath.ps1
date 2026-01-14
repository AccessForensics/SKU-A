Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\af_time.ps1"
function New-RunFolderName {
  param([Parameter(Mandatory=$true)][string]$CaseLabel)
  $ts = (Get-UtcIso8601Ms) -replace "[:]", ""
  "${ts}_$CaseLabel"
}
Export-ModuleMember -Function New-RunFolderName
