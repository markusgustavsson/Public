param(
  [ValidateNotNullOrEmpty()]
  [string]$GroupName
)

Get-ADGroup $GroupName
