param(
      [string]$ComputerName
)

[hashtable]$computer_name = @{}

if ($ComputerName) {
      $computer_name.Add('ComputerName', $ComputerName)
}

Get-CimInstance @computer_name -ClassName Win32_OperatingSystem -Property LastBootUpTime -ea Stop |
	select @{Name='Uptime';Expression={[datetime]::Now.Subtract($_.LastBootUpTime)}} -First 1 |
		select -ExpandProperty Uptime
