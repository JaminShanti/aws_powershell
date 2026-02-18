<#
.SYNOPSIS
    Dumps IAM Policies and Security Groups.
.DESCRIPTION
    Copies the group and role security locally for review.
    Reference: http://techdebug.com/blog/2014/08/05/powershell-aws-and-iam-policy-retrieval/
.NOTES
    Created by Jamin Shanti
    Date: 3/9/2015
    Version: 1.0
#>
[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

Import-Module AWSPowerShell
# For URL Decode of Policy document
Add-Type -AssemblyName System.Web
# Form Output for script
Add-Type -AssemblyName System.Windows.Forms

# Current Path
$path = (Get-Item -Path ".\" -Verbose).FullName

# Notify User
$caption = "Warning!"
$message = "This Script will override all current policies in:`n$path\Groups`nand`n$path\Roles`n with current AWS Policies! Do you want to proceed?"
$yesNoButtons = [System.Windows.Forms.MessageBoxButtons]::YesNo

if ([System.Windows.Forms.MessageBox]::Show($message, $caption, $yesNoButtons) -eq "No") {
    Write-Host "Script Terminated" -ForegroundColor Red
    Break
} else {
    # Delete existing policies stored locally
    if (Test-Path -LiteralPath "$path\SecurityGroups" -PathType Container) {
        Remove-Item -Recurse -Force "$path\SecurityGroups"
    }

    $groups = Get-EC2SecurityGroup

    foreach ($group in $groups) {
        Write-Host "SecurityGroup: $($group.GroupName)" -ForegroundColor Cyan
        Write-Host "Creating Dir... " -ForegroundColor Cyan

        # Create new dir
        New-Item -ItemType Directory -Path "$path\SecurityGroups\$($group.VpcId)\$($group.GroupName)" | Out-Null

        # Get policies for each group and role and write out to directories
        Write-Host "Saving Description for... " -ForegroundColor Cyan
        $group | Select-Object Description, GroupId, GroupName | Format-List | Out-File "$path\SecurityGroups\$($group.VpcId)\$($group.GroupName)\$($group.GroupName)_Description.txt"

        Write-Host "Saving IpPermissionsIngress for... " -ForegroundColor Cyan
        $ingress = $group.IpPermissions

        # If IpRanges are not used, convert GroupId to GroupName.
        if ($ingress.IpRanges.Count -eq 0) {
            $ingress = $group.IpPermissions | Select-Object FromPort, IpProtocol, IpRanges, ToPort, @{Name="UserIdGroupPairs"; Expression={(Get-EC2SecurityGroup -GroupId $_.UserIdGroupPairs.GroupId).GroupName}}
        } else {
            $ingress = $group.IpPermissions | Select-Object FromPort, IpProtocol, IpRanges, ToPort, @{Name="UserIdGroupPairs"; Expression={$_.UserIdGroupPairs.GroupId}}
        }

        $ingress | ConvertTo-Json | Out-File "$path\SecurityGroups\$($group.VpcId)\$($group.GroupName)\IpPermissionsIngress.json"

        Write-Host "Saving IpPermissionsEgress for..." -ForegroundColor Cyan
        $egress = $group.IpPermissionsEgress | Select-Object FromPort, IpProtocol, IpRanges, ToPort, @{Name="UserIdGroupPairs"; Expression={$_.UserIdGroupPairs.GroupId}}
        $egress | ConvertTo-Json | Out-File "$path\SecurityGroups\$($group.VpcId)\$($group.GroupName)\IpPermissionsEgress.json"
    }

    Write-Host "Script Finished" -ForegroundColor Green
}
