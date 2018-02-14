Param(
  [parameter(Mandatory=$false)]
  [string]$Region = "us-west-2" ,
  [parameter(Mandatory=$false)]
  [string]$cidrBlock = '10.199.0.0/16' ,
  [parameter(Mandatory=$false)]
  [string]$zonename = "online.staging-dr."
)

##############################################################################
##
## DR_create_VPC
## Created by Jamin Shanti
## Date : 422/2015
## Version : 1.0
## Creates the VPC
## Resources Generated : VPC, Gateway , Subnets, Private DNS
##############################################################################


Set-AWSCredentials -ProfileName online-staging_jshanti
Set-DefaultAWSRegion -Region $Region

$reverseZone2 = "2.199.10.in-addr.arpa."
$reverseZone3 = "3.199.10.in-addr.arpa."
$reverseZone4 = "4.199.10.in-addr.arpa."
$reverseZone5 = "254.199.10.in-addr.arpa."


$ErrorActionPreference = "Stop"



echo "Create the VPC..."
$VPC = New-EC2VPC -CidrBlock $cidrBlock -region $Region

# $VPC = Get-EC2Vpc -vpcid vpc-dffd47ba
# tag VPC
New-EC2Tag -Resource $VPC.VpcId -Tag @( @{ Key="Name"; Value="Stage VPC DR" } )
$VPC
echo "Create Border subnets..."
$BorderSubnets = @()
$BorderSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.0.0/26 -AvailabilityZone us-west-2a
New-EC2Tag -Resource $BorderSubnets[0].SubnetId -Tag @( @{ Key="Name"; Value="Border Subnet 1" } )
#Create a subnet
$BorderSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.0.64/26 -AvailabilityZone us-west-2b
New-EC2Tag -Resource $BorderSubnets[1].SubnetId -Tag @( @{ Key="Name"; Value="Border Subnet 2" } )
#Create a subnet
$BorderSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.0.128/26 -AvailabilityZone us-west-2c
New-EC2Tag -Resource $BorderSubnets[2].SubnetId -Tag @( @{ Key="Name"; Value="Border Subnet 3" } )
$BorderSubnets
echo "Create application subnets..."
$applicationSubnets = @()
$applicationSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.2.0/26 -AvailabilityZone us-west-2a
New-EC2Tag -Resource $applicationSubnets[0].SubnetId -Tag @( @{ Key="Name"; Value="application Subnet 1" } )
#Create a subnet
$applicationSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.2.64/26 -AvailabilityZone us-west-2b
New-EC2Tag -Resource $applicationSubnets[1].SubnetId -Tag @( @{ Key="Name"; Value="application Subnet 2" } )
#Create a subnet
$applicationSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.2.128/26 -AvailabilityZone us-west-2c
New-EC2Tag -Resource $applicationSubnets[2].SubnetId -Tag @( @{ Key="Name"; Value="application Subnet 3" } )
$applicationSubnets
echo "Create mongoDB subnets..."
$mongoDBSubnets = @()
$mongoDBSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.4.0/26 -AvailabilityZone us-west-2a
New-EC2Tag -Resource $mongoDBSubnets[0].SubnetId -Tag @( @{ Key="Name"; Value="Database Subnet 1" } )
#Create a subnet
$mongoDBSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.4.64/26 -AvailabilityZone us-west-2b
New-EC2Tag -Resource $mongoDBSubnets[1].SubnetId -Tag @( @{ Key="Name"; Value="Database Subnet 2" } )
#Create a subnet
$mongoDBSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.4.128/26 -AvailabilityZone us-west-2c
New-EC2Tag -Resource $mongoDBSubnets[2].SubnetId -Tag @( @{ Key="Name"; Value="Database Subnet 3" } )
$mongoDBSubnets
echo "Create Customer subnets..."
$CustomerSubnets = @()
$CustomerSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.3.0/26 -AvailabilityZone us-west-2a
New-EC2Tag -Resource $CustomerSubnets[0].SubnetId -Tag @( @{ Key="Name"; Value="Customer Subnet 1" } )
#Create a subnet
$CustomerSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.3.64/26 -AvailabilityZone us-west-2b
New-EC2Tag -Resource $CustomerSubnets[1].SubnetId -Tag @( @{ Key="Name"; Value="Customer Subnet 2" } )
#Create a subnet
$CustomerSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.3.128/26 -AvailabilityZone us-west-2c
New-EC2Tag -Resource $CustomerSubnets[2].SubnetId -Tag @( @{ Key="Name"; Value="Customer Subnet 3" } )
$CustomerSubnets
echo "Create Management subnets..."
$ManagementSubnets = @()
$ManagementSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.254.0/26 -AvailabilityZone us-west-2a
New-EC2Tag -Resource $ManagementSubnets[0].SubnetId -Tag @( @{ Key="Name"; Value="Management Subnet 1" } )
#Create a subnet
$ManagementSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.254.64/26 -AvailabilityZone us-west-2b
New-EC2Tag -Resource $ManagementSubnets[1].SubnetId -Tag @( @{ Key="Name"; Value="Management Subnet 2" } )
#Create a subnet
$ManagementSubnets += New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock 10.199.254.128/26 -AvailabilityZone us-west-2c
New-EC2Tag -Resource $ManagementSubnets[2].SubnetId -Tag @( @{ Key="Name"; Value="Management Subnet 3" } )
$ManagementSubnets

echo "Creating internet gateway..."
$InternetGateway = New-EC2InternetGateway
Add-EC2InternetGateway -InternetGatewayId $InternetGateway.InternetGatewayID -VpcId $VPC.vpcID


echo "Creating a route table and add public subnet..."
$routeTable = New-EC2RouteTable -VpcId $VPC.VpcId
New-EC2Route -RouteTableId $routeTable.routeTableID -DestinationCidrBlock '0.0.0.0/0' -GatewayId $InternetGateway.InternetGatewayID
New-EC2Tag -Resource $routeTable.routeTableID -Tag @( @{ Key="Name"; Value="igw_route" } )

echo "associate border subnets with gateway..."
Register-EC2RouteTable $BorderSubnets[0].SubnetId -RouteTableId $routeTable.routeTableID
Register-EC2RouteTable $BorderSubnets[1].SubnetId -RouteTableId $routeTable.routeTableID
Register-EC2RouteTable $BorderSubnets[2].SubnetId -RouteTableId $routeTable.routeTableID

echo "create route53 zone..."
$newHostedZone = New-R53HostedZone -Name $zonename -CallerReference "DRSetup_$(Get-Random -minimum 0 -maximum 1000)" -HostedZoneConfig_Comment "$($zonename) private hosted zone" -VPC_VPCId $VPC.VpcId -VPC_VPCRegion $Region

$newHostedZone.HostedZone | format-list

echo "create in-addr.arpa zones..."
$newHostedZone = New-R53HostedZone -Name $reverseZone2 -CallerReference "DRSetup_$(Get-Random -minimum 0 -maximum 1000)" -HostedZoneConfig_Comment "$($reverseZone2) private hosted zone" -VPC_VPCId $VPC.VpcId -VPC_VPCRegion $Region
$newHostedZone.HostedZone | format-list
$newHostedZone = New-R53HostedZone -Name $reverseZone3 -CallerReference "DRSetup_$(Get-Random -minimum 0 -maximum 1000)" -HostedZoneConfig_Comment "$($reverseZone3) private hosted zone" -VPC_VPCId $VPC.VpcId -VPC_VPCRegion $Region
$newHostedZone.HostedZone | format-list
$newHostedZone = New-R53HostedZone -Name $reverseZone4 -CallerReference "DRSetup_$(Get-Random -minimum 0 -maximum 1000)" -HostedZoneConfig_Comment "$($reverseZone4) private hosted zone" -VPC_VPCId $VPC.VpcId -VPC_VPCRegion $Region
$newHostedZone.HostedZone | format-list
$newHostedZone = New-R53HostedZone -Name $reverseZone5 -CallerReference "DRSetup_$(Get-Random -minimum 0 -maximum 1000)" -HostedZoneConfig_Comment "$($reverseZone5) private hosted zone" -VPC_VPCId $VPC.VpcId -VPC_VPCRegion $Region
$newHostedZone.HostedZone | format-list

echo "Register DHCP with VPC"
$DHCPOptions = New-EC2DhcpOption -DhcpConfiguration @( @{Key="domain-name";Values=$zonename} , @{Key="domain-name-servers";Values="AmazonProvidedDNS"})
Register-EC2DhcpOption -DhcpOptionsId $DHCPOptions.DhcpOptionsId -VpcId $VPC.VpcId

echo "Enable DNSSupport and DNShostnames"
Edit-EC2VpcAttribute -VpcId $VPC.VpcId -EnableDnsSupport $true
Edit-EC2VpcAttribute -VpcId $VPC.VpcId -EnableDnsHostnames $true

echo "Script Completed Successfully..."
$VPC
