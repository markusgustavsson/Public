param(
      [string]$ComputerName
)

[hashtable]$computer_name = @{}

if ($ComputerName) {
      $computer_name.Add('ComputerName', $ComputerName)
}

Get-CimInstance @computer_name -Class Win32_Service -Property Name,DisplayName,Started,ProcessID,StartMode,StartName,Description,PathName -ea Stop |
      select DisplayName,Name,Started,@{Name='ProcessID';Expression={$_.ProcessID -as [string]}},`
            StartMode,StartName,Description,PathName
