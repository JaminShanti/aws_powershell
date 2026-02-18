<#
.SYNOPSIS
    Creates AMIs for all servers.
.DESCRIPTION
    Iterates through all EC2 instances and creates an AMI for each one.
.NOTES
    Created by Jamin Shanti
    Date: 3/9/2015
    Version: 1.0
#>
[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

Import-Module AWSPowerShell

$instanceList = (Get-EC2Instance).Instances

foreach ($instance in $instanceList) {
    $imageName = $instance.Tags | Where-Object { $_.Key -eq "Name" } | Select-Object -ExpandProperty Value
    $timestamp = Get-Date -Format "MMddyyyyHHmm"
    $amiName = "${imageName}_${timestamp}"

    Write-Host "Creating AMI for instance $($instance.InstanceId) -- $amiName" -ForegroundColor Cyan

    New-EC2Image -InstanceId $instance.InstanceId -Name $amiName -Description $amiName -NoReboot $true
}
