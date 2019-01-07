<#
All envrionments perform differently. Please test this code before using it
in production.

THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY 
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR RESULTS FROM THE USE OF 
THIS CODE REMAINS WITH THE USER.

Author: ChrisC
Date: 07/01/2019

TODO:
- Improve connect to EXOnline to better support MFA and non MFA logins
- https://cmdletpswmodule.blob.core.windows.net/exopsmodule/Microsoft.Online.CSE.PSModule.Client.application
#>

<#
.SYNOPSIS
Checks for existing tranpsort rule, if no matching rule exist it will be created.

.DESCRIPTION
Creates a rule to block auto-forwarding rules from inside organization to external senders.

.EXAMPLE
Set-TransportRuleBlockClientRuleForwarding.ps1
#>

# Connect to EXonline using Microsoft Exchange Online Powershell Module
$CreateEXOPSSession = (Get-ChildItem -Path $env:userprofile -Filter CreateExoPSSession.ps1 -Recurse -ErrorAction SilentlyContinue -Force | Select -Last 1).DirectoryName
. "$CreateEXOPSSession\CreateExoPSSession.ps1"

# Get Admin credentials and sign in to EXOnline with Modern Auth - MFA
Write-Host "Connecting to Office 365 Session with Modern Auth - MFA"
$AdminCred = Read-Host -Prompt "Specify Global Administrator Username"
Connect-EXOPSSession -UserPrincipalName $AdminCred 

# Transport rule variables
$externalTransportRuleName = "Client Rules Forwarding Block"
$rejectMessageText = "To improve security, auto-forwarding rules to external addresses has been disabled. Please contact your Microsoft Partner if you'd like to set up an exception."
$externalForwardRule = Get-TransportRule | Where-Object {$_.Identity -contains $externalTransportRuleName}

# Create transport rule if it does not exist with matching name
if (!$externalForwardRule) {
    Write-Output "Client Rules To External Block not found, creating Rule"
    New-TransportRule -name "Client Rules Forwarding Block" -Priority 0 -SentToScope NotInOrganization -FromScope InOrganization -MessageTypeMatches AutoForward -RejectMessageEnhancedStatusCode 5.7.1 -RejectMessageReasonText $rejectMessageText
}