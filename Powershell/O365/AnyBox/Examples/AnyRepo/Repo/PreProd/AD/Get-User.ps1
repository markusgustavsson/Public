param(
  [ValidateNotNullOrEmpty()]
  [string]$UserName
)

Get-ADUser $UserName
