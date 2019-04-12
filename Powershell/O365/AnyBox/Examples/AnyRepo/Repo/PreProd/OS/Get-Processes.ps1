param(
      [string]$ComputerName
)

[hashtable]$computer_name = @{}

if ($ComputerName) {
      $computer_name.Add('ComputerName', $ComputerName)
}

Get-WmiObject @computer_name -ClassName Win32_Process -Property Handle,ProcessID,Name,CreationDate,CommandLine,ExecutablePath -ea Stop | # foreach {
      select @{Name='ProcessID';Expression={$_.ProcessID -as [string]}}, Name, `
            @{Name='Duration (m)';Expression={'{0:N1}' -f ([datetime]::Now.Subtract($_.ConvertToDateTime($_.CreationDate))).TotalMinutes}}, `
            @{Name='UserName';Expression={try {$_.GetOwner().User} catch {}}}, `
            CommandLine
