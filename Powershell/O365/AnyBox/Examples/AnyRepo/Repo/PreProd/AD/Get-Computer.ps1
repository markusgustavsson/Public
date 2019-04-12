param(
  [ValidateNotNullOrEmpty()]
  [string]$ComputerName
)

Get-ADComputer $ComputerName
