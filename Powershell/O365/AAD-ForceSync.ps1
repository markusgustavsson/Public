function CleanupSession {
Get-PSSession | Remove-PSSession
Get-Module | Where-Object { $_.Name -eq "AnyBox" } | Remove-Module
$null = Stop-Transcript
Exit
}

##################################
#         Script Settings        #
##################################

$null = Start-Transcript $env:TEMP\ForceADSync.log
Get-PSSession | Remove-PSSession
Import-Module $PSScriptRoot\AnyBox\0.3.3\AnyBox.psd1

##################################
#             ADSync             #
##################################

# Get varialbes
if (Get-Module -ListAvailable -Name ADSync) {
    $prompts = @(New-Prompt -Message 'ADSync Module has been loaded on this host, is this correct?' -DefaultValue $env:COMPUTERNAME -ShowSeparator -ValidateNotEmpty)
    $prompts += @(New-Prompt -Message 'Choose ADSync Option Delta: (Recommended) / Initial (Only use when troubleshooting)' -ValidateSet 'Delta', 'Initial' -DefaultValue 'Delta' -ShowSetAs 'Radio_Wide' -ShowSeparator)
    $ForceADSync = Show-AnyBox -Title 'Force ADSync' -Prompts $prompts -Buttons 'Cancel', 'Continue' -CancelButton 'Cancel' -AccentColor 'Gray' -MinWidth 300
    $ADSyncServer = ($ForceADSync['Input_0'])
}
else {
    $prompts = @(New-Prompt -Message 'Please provide ADSync server name:' -ShowSeparator -ValidateNotEmpty)
    $prompts += @(New-Prompt -Message 'Choose ADSync Option Delta: (Recommended) / Initial (Only use when troubleshooting)' -ValidateSet 'Delta', 'Initial' -DefaultValue 'Delta' -ShowSetAs 'Radio_Wide' -ShowSeparator)
    $ForceADSync = Show-AnyBox -Title 'Force ADSync' -Prompts $prompts -Buttons 'Cancel', 'Continue' -CancelButton 'Cancel' -AccentColor 'Gray' -MinWidth 300
    $ADSyncServer = ($ForceADSync['Input_0'])
}

# Run ADSync
if ($ForceADSync['Delta']) {
    $Result = Invoke-Command -ComputerName $ADSyncServer Start-ADSyncSyncCycle -PolicyType -Delta
    Show-AnyBox -Title 'Result' -Message $Result -Buttons 'OK' -MinWidth 300
}
elseif ($ForceADSync['Initial']) {
    Invoke-Command -ComputerName $ADSyncServer Start-ADSyncSyncCycle -PolicyType -Initial
}

##################################
#             Cleanup            #
##################################
CleanupSession
