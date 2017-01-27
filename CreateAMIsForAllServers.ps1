##############################################################################
##
## Create AMIs for all Servers
## Created by Jamin Shanti
## Date : 3/9/2015
## Version : 1.0
##############################################################################

$ErrorActionPreference = "Stop"

Import-Module AWSPowerShell

$instancelist = (Get-Ec2Instance).Instances
foreach ($instance in $instancelist)
     { $imageName = $($instance.tags | where key -eq "Name" | select Value -expand Value) ;
      "creating $($instance.InstanceId) -- $($imageName)_$(get-date -Format MMddyyyyHHmm) " ;
       New-EC2Image -InstanceId $($instance.InstanceId) -Name "$($imageName)_$(get-date -Format MMddyyyyHHmm)" -Description "$($imageName)_$(get-date -Format MMddyyyyHHmm)" -NoReboot:$true 
     }
