Param(
  [parameter(Mandatory=$true)]
  [string]$newNodeName ,
  [parameter(Mandatory=$false)]
  [string]$Region = "us-west-2" ,
  [parameter(Mandatory=$false)]
  [string]$zonename = "online.staging-dr." ,
  [parameter(Mandatory=$true)]
  [string]$vpcid ,
  [parameter(Mandatory=$false)]
  [string]$ami = "ami-xxxxxxxx" ,
  [parameter(Mandatory=$false)]
  [string]$datasnapshot = "snap-xxxxxxxx"
)

##############################################################################
##
## DR_recover_mongoDB
## Created by Jamin Shanti
## Date : 422/2015
## Version : 1.0
## Creates the elasticSearchNode Cluster
## Resources Generated : Elastic Load Balancer, MongoDBNode Instance with data snapshot
##############################################################################


#$newNodeName = "s-mongo-west-1a_DR"
$ErrorActionPreference = "Stop"
Set-AWSCredentials -ProfileName online-staging_jshanti
Set-DefaultAWSRegion -Region $Region

$currentSubnetNumber = Get-Random -minimum 0 -maximum 3

$mongoDBsearchSubnets = (Get-EC2Subnet | where {$_.VpcId -eq $vpcid �and $_.Tag.Key -eq  "Name" -and $_.Tag.Value -match "Database"}).SubnetId

echo "selecting ami ..."

Get-EC2Image -ImageId $ami
$BlockDeviceMapping_includingSnapshot = (Get-EC2Image -ImageId $ami).BlockDeviceMappings

echo "adding data snapshot...$datasnapshot"

$BlockDeviceMapping_includingSnapshot[1].Ebs.SnapshotId = $datasnapshot

#Feach the Security Group ID
$mongoSecurityGroupID = (Get-EC2SecurityGroup | where GroupName -eq "Mongo").GroupID

$NewInstanceResponse =  New-EC2Instance -ImageId $ami -MinCount 1 -MaxCount 1 -Region $Region -KeyName West-Staging-VPC -SecurityGroupID $mongoSecurityGroupID -InstanceType m3.large `
        -SubnetId $mongoDBsearchSubnets[$currentSubnetNumber] -InstanceProfile_Name  database -BlockDeviceMapping $BlockDeviceMapping_includingSnapshot -EncodeUserData  `
        -UserDataFile "$($pwd)\mongodb_startup_userdata"
$filter_reservation = New-Object Amazon.EC2.Model.Filter -Property @{Name = "reservation-id"; Values = $NewInstanceResponse.ReservationId}
$newlyCreatedEc2Instance = (Get-EC2Instance -Filter $filter_reservation).Instances
While ($newlyCreatedEc2Instance.BlockDeviceMappings.Count -eq 0)
{
  $newlyCreatedEc2Instance = (Get-EC2Instance -Filter $filter_reservation).Instances
  Start-Sleep -Seconds 5
}
echo "Newly Created Instance:"
echo $newlyCreatedEc2Instance | select InstanceId, InstanceType, LaunchTime, PrivateIpAddress, VpcId 

echo "adding Ec2Tags..."
New-EC2Tag -Resource $newlyCreatedEc2Instance.InstanceId -Tag @( @{ Key="Name"; Value=$newNodeName } )
New-EC2Tag -Resource $newlyCreatedEc2Instance.BlockDeviceMappings[0].Ebs.VolumeId -Tag @( @{ Key="Name"; Value="$($newNodeName) Root volume" } )
New-EC2Tag -Resource $newlyCreatedEc2Instance.BlockDeviceMappings[1].Ebs.VolumeId -Tag @( @{ Key="Name"; Value="$($newNodeName) Data volume" } )
New-EC2Tag -Resource $newlyCreatedEc2Instance.BlockDeviceMappings[2].Ebs.VolumeId -Tag @( @{ Key="Name"; Value="$($newNodeName) volume 1" } )
New-EC2Tag -Resource $newlyCreatedEc2Instance.BlockDeviceMappings[3].Ebs.VolumeId -Tag @( @{ Key="Name"; Value="$($newNodeName) volume 2" } )

 


echo "registering ELB - Mongo..."

#  use subnets for VPCs  availablity zones for ec2-classic

if (-not((Get-ELBloadbalancer).LoadBalancerName -match "elb-MongoDB" ))
{
echo "creating ELB - elb-MongoDB..."
#Feach the Security Group ID
$ELBMongoDBSecurityGroupID = (Get-EC2SecurityGroup | where GroupName -eq "ELBMongoDB").GroupID
$ELBmongoDB = New-ELBLoadBalancer -LoadBalancerName elb-MongoDB -SecurityGroup $ELBMongoDBSecurityGroupID -Subnets $mongoDBsearchSubnets -Scheme internal -Listener @{ LoadBalancerPort=27017;InstancePort=27017;Protocol="TCP";InstanceProtocol="TCP" }
Set-ELBHealthCheck -LoadBalancerName elb-MongoDB   -HealthCheck_Target "TCP:27017" -HealthCheck_Timeout 5 -HealthCheck_Interval 30    -HealthCheck_HealthyThreshold 2 -HealthCheck_UnhealthyThreshold 2 
}
echo "Associate Instances with Load Balancer..."
Register-ELBInstanceWithLoadBalancer -LoadBalancerName �elb-MongoDB� -Instances @($newlyCreatedEc2Instance.InstanceId)

echo "Running aws_ec2_register_route53.ps1 $newNodeName $(($newlyCreatedEc2Instance).PrivateIpAddress)  online.staging. Type = A"
.\aws_ec2_register_route53.ps1  -newNodeName $newNodeName -newNodeValue $newlyCreatedEc2Instance.PrivateIpAddress -zoneName $zonename -targetType A
$splitIP = $newlyCreatedEc2Instance.PrivateIpAddress.Split('.')
[array]::Reverse($splitIP)
$reversezoneName = $splitIP[1,2,3] -join '.'
$reversezoneNameFullName = $reversezoneName + ".in-addr.arpa."
echo "Adding Reverse DNS $reversezoneNameFullName..."
.\aws_ec2_register_route53.ps1  -newNodeName $splitIP[0] -newNodeValue "$newNodeName.$zonename" -zonename $reversezoneNameFullName -targetType PTR
echo "provision completed $newNodeName"
