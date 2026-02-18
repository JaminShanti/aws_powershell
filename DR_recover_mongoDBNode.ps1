<#
.SYNOPSIS
    Recovers a MongoDB Node for DR.
.DESCRIPTION
    Creates the Elastic Load Balancer, MongoDBNode Instance with data snapshot.
    Resources Generated: Elastic Load Balancer, MongoDBNode Instance with data snapshot.
.NOTES
    Created by Jamin Shanti
    Date: 4/22/2015
    Version: 1.0
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$NewNodeName,
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-west-2",
    [Parameter(Mandatory=$false)]
    [string]$ZoneName = "online.staging-dr.",
    [Parameter(Mandatory=$true)]
    [string]$VpcId,
    [Parameter(Mandatory=$false)]
    [string]$Ami = "ami-xxxxxxxx",
    [Parameter(Mandatory=$false)]
    [string]$DataSnapshot = "snap-xxxxxxxx"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "Info" { Write-Host $formattedMessage -ForegroundColor Cyan }
        "Success" { Write-Host $formattedMessage -ForegroundColor Green }
        "Warning" { Write-Host $formattedMessage -ForegroundColor Yellow }
        "Error" { Write-Host $formattedMessage -ForegroundColor Red }
        Default { Write-Host $formattedMessage }
    }
}

Set-AWSCredentials -ProfileName online-staging_jshanti
Set-DefaultAWSRegion -Region $Region

$currentSubnetNumber = Get-Random -Minimum 0 -Maximum 3

$mongoDBsearchSubnets = (Get-EC2Subnet | Where-Object { $_.VpcId -eq $VpcId -and $_.Tag.Key -eq "Name" -and $_.Tag.Value -match "Database" }).SubnetId

Write-Log -Message "Selecting AMI..."
$image = Get-EC2Image -ImageId $Ami
$BlockDeviceMapping_includingSnapshot = $image.BlockDeviceMappings

Write-Log -Message "Adding data snapshot...$DataSnapshot"
$BlockDeviceMapping_includingSnapshot[1].Ebs.SnapshotId = $DataSnapshot

# Fetch the Security Group ID
$mongoSecurityGroupID = (Get-EC2SecurityGroup | Where-Object { $_.GroupName -eq "Mongo" }).GroupId

$NewInstanceResponse = New-EC2Instance -ImageId $Ami -MinCount 1 -MaxCount 1 -Region $Region -KeyName West-Staging-VPC -SecurityGroupId $mongoSecurityGroupID -InstanceType m3.large `
    -SubnetId $mongoDBsearchSubnets[$currentSubnetNumber] -InstanceProfile_Name database -BlockDeviceMapping $BlockDeviceMapping_includingSnapshot -EncodeUserData `
    -UserDataFile "$($pwd)\mongodb_startup_userdata"

$filter_reservation = New-Object Amazon.EC2.Model.Filter -Property @{Name = "reservation-id"; Values = $NewInstanceResponse.ReservationId}
$newlyCreatedEc2Instance = (Get-EC2Instance -Filter $filter_reservation).Instances

while ($newlyCreatedEc2Instance.BlockDeviceMappings.Count -eq 0) {
    $newlyCreatedEc2Instance = (Get-EC2Instance -Filter $filter_reservation).Instances
    Start-Sleep -Seconds 5
}

Write-Log -Message "Newly Created Instance:" -Level "Success"
$newlyCreatedEc2Instance | Select-Object InstanceId, InstanceType, LaunchTime, PrivateIpAddress, VpcId

Write-Log -Message "Adding Ec2Tags..."
New-EC2Tag -Resource $newlyCreatedEc2Instance.InstanceId -Tag @{ Key="Name"; Value=$NewNodeName }
New-EC2Tag -Resource $newlyCreatedEc2Instance.BlockDeviceMappings[0].Ebs.VolumeId -Tag @{ Key="Name"; Value="$($NewNodeName) Root volume" }
New-EC2Tag -Resource $newlyCreatedEc2Instance.BlockDeviceMappings[1].Ebs.VolumeId -Tag @{ Key="Name"; Value="$($NewNodeName) Data volume" }
New-EC2Tag -Resource $newlyCreatedEc2Instance.BlockDeviceMappings[2].Ebs.VolumeId -Tag @{ Key="Name"; Value="$($NewNodeName) volume 1" }
New-EC2Tag -Resource $newlyCreatedEc2Instance.BlockDeviceMappings[3].Ebs.VolumeId -Tag @{ Key="Name"; Value="$($NewNodeName) volume 2" }

Write-Log -Message "Registering ELB - Mongo..."

# Use subnets for VPCs, availability zones for EC2-Classic
if (-not ((Get-ELBLoadBalancer).LoadBalancerName -match "elb-MongoDB")) {
    Write-Log -Message "Creating ELB - elb-MongoDB..."
    # Fetch the Security Group ID
    $ELBMongoDBSecurityGroupID = (Get-EC2SecurityGroup | Where-Object { $_.GroupName -eq "ELBMongoDB" }).GroupId
    $ELBmongoDB = New-ELBLoadBalancer -LoadBalancerName elb-MongoDB -SecurityGroup $ELBMongoDBSecurityGroupID -Subnets $mongoDBsearchSubnets -Scheme internal -Listener @{ LoadBalancerPort=27017; InstancePort=27017; Protocol="TCP"; InstanceProtocol="TCP" }
    Set-ELBHealthCheck -LoadBalancerName elb-MongoDB -HealthCheck_Target "TCP:27017" -HealthCheck_Timeout 5 -HealthCheck_Interval 30 -HealthCheck_HealthyThreshold 2 -HealthCheck_UnhealthyThreshold 2
}

Write-Log -Message "Associate Instances with Load Balancer..."
Register-ELBInstanceWithLoadBalancer -LoadBalancerName "elb-MongoDB" -Instances @($newlyCreatedEc2Instance.InstanceId)

Write-Log -Message "Running aws_ec2_register_route53.ps1 $NewNodeName $(($newlyCreatedEc2Instance).PrivateIpAddress) online.staging. Type = A"
.\aws_ec2_register_route53.ps1 -newNodeName $NewNodeName -newNodeValue $newlyCreatedEc2Instance.PrivateIpAddress -zoneName $ZoneName -targetType A

$splitIP = $newlyCreatedEc2Instance.PrivateIpAddress.Split('.')
[array]::Reverse($splitIP)
$reversezoneName = $splitIP[1,2,3] -join '.'
$reversezoneNameFullName = $reversezoneName + ".in-addr.arpa."

Write-Log -Message "Adding Reverse DNS $reversezoneNameFullName..."
.\aws_ec2_register_route53.ps1 -newNodeName $splitIP[0] -newNodeValue "$NewNodeName.$ZoneName" -zonename $reversezoneNameFullName -targetType PTR

Write-Log -Message "Provision completed $NewNodeName" -Level "Success"
