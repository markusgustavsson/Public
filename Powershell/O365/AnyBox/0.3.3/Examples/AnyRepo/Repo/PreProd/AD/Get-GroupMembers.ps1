param(
  [ValidateNotNullOrEmpty()]
  [string]$GroupName,
  [switch]$Recursive
)

Get-ADGroupMember $GroupName -Recursive:$Recursive
