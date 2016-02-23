##############################################################################
##
## dump Iam Policies
## Created by Jamin Shanti
## Date : 3/9/2015
## Version : 1.0
## Update: adding url check 
## reference : http://techdebug.com/blog/2014/08/05/powershell-aws-and-iam-policy-retrieval/ 
## copies the group and role security locally for review.
##############################################################################

#===============================================================================================
# Script to output all the IAM polcies
#===============================================================================================
$ErrorActionPreference = "Stop"

Import-Module AWSPowerShell
# For URL Decode of Policy document
[System.Reflection.Assembly]::LoadWithPartialName("System.web") | out-null
#Form Output for script
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | out-null

#Current Path
$path = (Get-Item -Path ".\" -Verbose).FullName

#Notify User
$caption = "Warning!"
$message = "This Script will override all current policies in:`n$path\Groups`nand`n$path\Roles`n with current AWS Policies! Do you want to proceed"
$yesNoButtons = 4

if ([System.Windows.Forms.MessageBox]::Show($message, $caption, $yesNoButtons) -eq "NO") {
    Write "Script Terminated"
    Break
}
else {
    #delete existing policies stored locally
    if (Test-Path -LiteralPath $path\SecurityGroups -PathType Container) {
        Remove-Item -Recurse -Force $path\SecurityGroups
    }
    $groups = Get-EC2SecurityGroup
    foreach ($this in $groups) {
        Write-Host  "SecurityGroup: $($this.GroupName)"
        Write-Host "Creating Dir... "
        #create new dir
        New-Item -ItemType directory -Path $path\SecurityGroups\$($this.VpcId)\$($this.GroupName) | out-null
         #Get policies for each group and role and write out to directories
        Write-Host "Saving Description for... "
        $b  = ($groups | where GroupName -eq $($this.GroupName)) | select Description , GroupId , GroupName | Format-List
        $b  > $path\SecurityGroups\$($this.VpcId)\$($this.GroupName)\$($this.GroupName)_Description.txt
        Write-Host "Saving IpPermissionsIngress for... "
        $c  =  (Get-EC2SecurityGroup | where GroupName -eq $($this.GroupName)).IpPermissions 
        # if IPranges are not used, convert groupID to groupName.
        if ($c.IpRanges.Count -eq 0) {
            $c = (Get-EC2SecurityGroup | where GroupName -eq $($this.GroupName)).IpPermissions  | select FromPort, IpProtocol , IpRanges , ToPort, @{Name="UserIdGroupPairs";Expression={(Get-EC2SecurityGroup -GroupId $_.UserIdGroupPairs.GroupId).GroupName}}
            }
        else{
            $c  = (Get-EC2SecurityGroup | where GroupName -eq $($this.GroupName)).IpPermissions  | select FromPort, IpProtocol , IpRanges , ToPort, @{Name="UserIdGroupPairs";Expression={$_.UserIdGroupPairs.GroupId}}
        }
        $c | ConvertTo-Json > $path\SecurityGroups\$($this.VpcId)\$($this.GroupName)\IpPermissionsIngress.json
        Write-Host  "Saving IpPermissionsEgress for..."
        #$d =  (Get-EC2SecurityGroup | where GroupName -eq $($this.GroupName)).IpPermissionsEgress | select FromPort, IpProtocol , IpRanges , ToPort, @{Name="UserIdGroupPairs";Expression={(Get-EC2SecurityGroup -GroupId $_.UserIdGroupPairs.GroupId).GroupName}}
        $d = ($groups | where GroupName -eq $($this.GroupName)).IpPermissionsEgress | select FromPort, IpProtocol , IpRanges , ToPort, @{Name="UserIdGroupPairs";Expression={$_.UserIdGroupPairs.GroupId}}
        $d | ConvertTo-Json > $path\SecurityGroups\$($this.VpcId)\$($this.GroupName)\IpPermissionsEgress.json
    }
    Write-Host "Script Finished"
}
