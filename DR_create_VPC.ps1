<#
.SYNOPSIS
    Creates the VPC for DR.
.DESCRIPTION
    Creates the VPC, Gateway, Subnets, and Private DNS.
    Resources Generated: VPC, Gateway, Subnets, Private DNS.
.NOTES
    Created by Jamin Shanti
    Date: 4/22/2015
    Version: 1.0
#>
[CmdletBinding()]
Param(
    [string]$Region = "us-west-2",
    [string]$CidrBlock = '10.199.0.0/16',
    [string]$ZoneName = "online.staging-dr."
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

$reverseZones = @(
    "2.199.10.in-addr.arpa.",
    "3.199.10.in-addr.arpa.",
    "4.199.10.in-addr.arpa.",
    "254.199.10.in-addr.arpa."
)

Write-Log -Message "Create the VPC..."
$VPC = New-EC2VPC -CidrBlock $CidrBlock -Region $Region

# Tag VPC
New-EC2Tag -Resource $VPC.VpcId -Tag @{ Key="Name"; Value="Stage VPC DR" }
$VPC

function New-DrSubnet {
    param (
        [string]$VpcId,
        [string]$CidrBlock,
        [string]$AvailabilityZone,
        [string]$Name
    )
    $subnet = New-EC2Subnet -VpcId $VpcId -CidrBlock $CidrBlock -AvailabilityZone $AvailabilityZone
    New-EC2Tag -Resource $subnet.SubnetId -Tag @{ Key="Name"; Value=$Name }
    return $subnet
}

Write-Log -Message "Create Border subnets..."
$BorderSubnets = @()
$BorderSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.0.0/26" -AvailabilityZone "us-west-2a" -Name "Border Subnet 1"
$BorderSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.0.64/26" -AvailabilityZone "us-west-2b" -Name "Border Subnet 2"
$BorderSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.0.128/26" -AvailabilityZone "us-west-2c" -Name "Border Subnet 3"
$BorderSubnets

Write-Log -Message "Create application subnets..."
$applicationSubnets = @()
$applicationSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.2.0/26" -AvailabilityZone "us-west-2a" -Name "application Subnet 1"
$applicationSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.2.64/26" -AvailabilityZone "us-west-2b" -Name "application Subnet 2"
$applicationSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.2.128/26" -AvailabilityZone "us-west-2c" -Name "application Subnet 3"
$applicationSubnets

Write-Log -Message "Create mongoDB subnets..."
$mongoDBSubnets = @()
$mongoDBSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.4.0/26" -AvailabilityZone "us-west-2a" -Name "Database Subnet 1"
$mongoDBSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.4.64/26" -AvailabilityZone "us-west-2b" -Name "Database Subnet 2"
$mongoDBSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.4.128/26" -AvailabilityZone "us-west-2c" -Name "Database Subnet 3"
$mongoDBSubnets

Write-Log -Message "Create Customer subnets..."
$CustomerSubnets = @()
$CustomerSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.3.0/26" -AvailabilityZone "us-west-2a" -Name "Customer Subnet 1"
$CustomerSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.3.64/26" -AvailabilityZone "us-west-2b" -Name "Customer Subnet 2"
$CustomerSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.3.128/26" -AvailabilityZone "us-west-2c" -Name "Customer Subnet 3"
$CustomerSubnets

Write-Log -Message "Create Management subnets..."
$ManagementSubnets = @()
$ManagementSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.254.0/26" -AvailabilityZone "us-west-2a" -Name "Management Subnet 1"
$ManagementSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.254.64/26" -AvailabilityZone "us-west-2b" -Name "Management Subnet 2"
$ManagementSubnets += New-DrSubnet -VpcId $VPC.VpcId -CidrBlock "10.199.254.128/26" -AvailabilityZone "us-west-2c" -Name "Management Subnet 3"
$ManagementSubnets

Write-Log -Message "Creating internet gateway..."
$InternetGateway = New-EC2InternetGateway
Add-EC2InternetGateway -InternetGatewayId $InternetGateway.InternetGatewayID -VpcId $VPC.vpcID

Write-Log -Message "Creating a route table and add public subnet..."
$routeTable = New-EC2RouteTable -VpcId $VPC.VpcId
New-EC2Route -RouteTableId $routeTable.routeTableID -DestinationCidrBlock '0.0.0.0/0' -GatewayId $InternetGateway.InternetGatewayID
New-EC2Tag -Resource $routeTable.routeTableID -Tag @{ Key="Name"; Value="igw_route" }

Write-Log -Message "Associate border subnets with gateway..."
foreach ($subnet in $BorderSubnets) {
    Register-EC2RouteTable -SubnetId $subnet.SubnetId -RouteTableId $routeTable.routeTableID
}

Write-Log -Message "Create route53 zone..."
$newHostedZone = New-R53HostedZone -Name $ZoneName -CallerReference "DRSetup_$(Get-Random -minimum 0 -maximum 1000)" -HostedZoneConfig_Comment "$($ZoneName) private hosted zone" -VPC_VPCId $VPC.VpcId -VPC_VPCRegion $Region
$newHostedZone.HostedZone | Format-List

Write-Log -Message "Create in-addr.arpa zones..."
foreach ($zone in $reverseZones) {
    $newHostedZone = New-R53HostedZone -Name $zone -CallerReference "DRSetup_$(Get-Random -minimum 0 -maximum 1000)" -HostedZoneConfig_Comment "$($zone) private hosted zone" -VPC_VPCId $VPC.VpcId -VPC_VPCRegion $Region
    $newHostedZone.HostedZone | Format-List
}

Write-Log -Message "Register DHCP with VPC"
$DHCPOptions = New-EC2DhcpOption -DhcpConfiguration @( @{Key="domain-name";Values=$ZoneName} , @{Key="domain-name-servers";Values="AmazonProvidedDNS"})
Register-EC2DhcpOption -DhcpOptionsId $DHCPOptions.DhcpOptionsId -VpcId $VPC.VpcId

Write-Log -Message "Enable DNSSupport and DNShostnames"
Edit-EC2VpcAttribute -VpcId $VPC.VpcId -EnableDnsSupport $true
Edit-EC2VpcAttribute -VpcId $VPC.VpcId -EnableDnsHostnames $true

Write-Log -Message "Script Completed Successfully..." -Level "Success"
$VPC
