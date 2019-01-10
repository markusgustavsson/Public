<#
All envrionments perform differently. Please test this code before using it
in production.

THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY 
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR RESULTS FROM THE USE OF 
THIS CODE REMAINS WITH THE USER.

Author: ChrisC-NZ
Date: 07/01/2019

TODO:
Clear up errors
Tidy up script

#>

<#
.SYNOPSIS
Checks for existing tranpsort rule, if no matching rule exist it will be created.

.DESCRIPTION
Creates a rule to block auto-forwarding rules from inside organization to external senders.

.EXAMPLE
Set-TransportRuleBlockClientRuleForwarding.ps1
#>

###################################
#         Script Settings         #
###################################

#$ErrorActionPreference = 'silentlycontinue'
Import-Module $PSScriptRoot\AnyBox\0.3.3\AnyBox.psm1

###################################
#     CONNECT EXCHANGE ONLINE     #
###################################

# Promt to verify if Global Admin requires MFA
$2FA = Show-AnyBox -Icon 'Question' -Title 'MFA' -Message 'Does your Global Admin require MFA?' -Buttons 'No', 'Yes' -MinWidth 300

# Connect to Exchange Online with provided credentials
If ($2FA['No'])
{
    # $credential = Get-Credential -Message "Please enter your Office 365 credentials"
    
  $Creds = Show-AnyBox -Buttons 'Cancel', 'Login' -CancelButton 'Cancel' -Prompt @(
        (New-AnyBoxPrompt -InputType 'Text' -Message 'User Name:' -ValidateNotEmpty),
        (New-AnyBoxPrompt -InputType 'Password' -Message 'Password:' -ValidateNotEmpty)
      )
    if ($Creds['Cancel'])
    {
        Exit
    }
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($Creds['Input_0','Input_1'])

    Import-Module AzureAD
    $null = Connect-AzureAD -Credential $credential
    $exchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/"  -Authentication "Basic" -AllowRedirection -Credential $credential
    $null = Import-PSSession $exchangeSession -AllowClobber
}
Else
{
    $Modules = ((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter CreateExoPSSession.ps1 -Recurse).FullName | Where-Object{ $_ -notmatch "_none_" } | Select-Object -First 1)
    If ($Modules -eq $Null)
		{
            Write-Host "Exchange Online MFA Module was not found, please make sure you have downloaded and installed it from your tenant https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/connect-to-exchange-online-powershell/mfa-connect-to-exchange-online-powershell?view=exchange-ps" -ForegroundColor Red
            Exit
		}
    foreach ($Module in $Modules)
        {
           Import-Module "$Module"
        }
    Write-Host "Credential prompt to connect to Exchange Online" -ForegroundColor Yellow
    #Connect to Exchange Online w/ MFA
    Connect-EXOPSSession
}

###################################
#         TRANSPORT RULES         #
###################################

$externalTransportRuleName = "Client Rules Forwarding Block"
$rejectMessageText = "To improve security, auto-forwarding rules to external addresses has been disabled. Please contact your Microsoft Partner if you'd like to set up an exception."
$externalForwardRule = Get-TransportRule | Where-Object {$_.Identity -contains $externalTransportRuleName}

# Create transport rule if it does not exist with matching name
if (!$externalForwardRule) {
    Write-Host "$externalTransportRuleName not found, creating Rule" -ForegroundColor Yello
    New-TransportRule -name $externalTransportRuleName -Priority 0 -SentToScope NotInOrganization -FromScope InOrganization -MessageTypeMatches AutoForward -RejectMessageEnhancedStatusCode 5.7.1 -RejectMessageReasonText $rejectMessageText
}
    else {
        $null = Show-AnyBox -Title 'Confirmation' -Message "$externalTransportRuleName already exist" -Buttons 'OK' -MinWidth 300
    }

###################################
#             Cleanup             #
###################################
    
Get-PSSession | Remove-PSSession
Remove-Module AnyBox