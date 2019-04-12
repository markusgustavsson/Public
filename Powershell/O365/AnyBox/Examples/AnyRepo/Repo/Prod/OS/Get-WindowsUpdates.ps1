param(
      [string]$ComputerName
)

[hashtable]$computer_name = @{}

if ($ComputerName) {
      $computer_name.Add('ComputerName', $ComputerName)
}

Get-CimInstance @computer_name -Class Win32_QuickFixEngineering -ea Stop |
	select HotFixID, Description, InstalledBy, InstalledOn |
		sort InstalledOn -Descending
