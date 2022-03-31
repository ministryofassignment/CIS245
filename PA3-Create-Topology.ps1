#Create-Topology.ps1 written by Kevin Azevedo on 8/29/17
#Script edited & pourpose changed by Cartin Carruth 0n 3/31/2021
#A Script to create a virtual network and associated virtual machines to support a Performance Assessent in CIS245 course
#
#=================Changes===============================
#Modified 3/11/20 to include additional base images
#Modified 1/18/21 to include settings for VCastle
#=======================================================
#Initialization
#The path to the virtual disk images change to match your system
#$vdiskPath = "c:\VirtualDisks"
$vdiskPath = "D:\Images" #This is usually the configuration for VCastle
 
$OSImages = @{ 
                "W7" = @{ 
                            ParentDisk = "W7-Base.vhdx"
                            Gen = 1
                            DMemory = $true
                        }
                "W8" = @{ 
                            ParentDisk = "W8-Base.vhdx"
                            Gen = 2
                            DMemory = $true
                        }

                "W10" = @{ 
                            ParentDisk = "W10-Base.vhdx"
                            Gen = 2
                            DMemory = $true
                        }
                "SVR2K3R2" = @{ 
                            ParentDisk = "2K3-Base.vhdx"
                            Gen = 1
                            DMemory = $true
                        }
                "SVR2K8" = @{ 
                            ParentDisk = "2K8-Base.vhdx"
                            Gen = 1
                            DMemory = $true
                        } 
                "SVR2K8R2" =  @{ 
                            ParentDisk = "2K8R2-Base.vhdx"
                            Gen = 1
                            DMemory = $true
                        } 
                "SVR2012G" = @{ 
                            ParentDisk = "2K12R2-Base.vhdx"
                            Gen = 2
                            DMemory = $true
                        }
                "SVR2019C" = @{ 
                            ParentDisk = "2K19-Core-Base.vhdx"
                            Gen = 2
                            DMemory = $true
                        }
                "SVR2019G" = @{ 
                            ParentDisk = "2K19-GUI-Base.vhdx"
                            Gen = 2
                            DMemory = $true
                        }
                "CentOS7" = @{ 
                            ParentDisk = "CentOS-Base.vhdx"
                            Gen = 2
                            DMemory = $false
                        } 
                "CentOS8" = @{ 
                            ParentDisk = "CentOS8-Base.vhdx"
                            Gen = 2
                            DMemory = $false
                        }
                "Metasploitable" = @{ 
                            ParentDisk = "MS-Base.vhdx"
                            Gen = 1
                            DMemory = $false
                        }
                 "EmptyWin" = @{ 
                            ParentDisk = "EmptyWin.vhdx"
                            Gen = 2
                            DMemory = $true
                        }
                 "Other" = @{ 
                            ParentDisk = ""
                            Gen = 1
                            DMemory = $false
                        }
            }  #Map the OS names to the image files
$line = "=" * 66

$linuxOS = "Centos7","Centos8","Metasploitable"
$gen1VMs = "W7","SVR2K3R2","SVR2K8","SVR2K8R2","Metasploitable"

#Uncomment line below if running on Windows 10...it sometimes forgets it's a hypervisor
#Restart-Service vmms

#Create-VM a function to create a new virtual machine or a clone and any associated switches
function Create-VM {
Param (
    [parameter(Mandatory=$true)]
    [string] $VMName,   
    [parameter(Mandatory=$true)] 
    [ValidateSet("W7","W8","W10","SVR2K3R2","SVR2K8","SVR2K8R2","SVR2012G","SVR2019C","SVR2019G","CentOS7","CentOS8","Metasploitable","EmptyWin","Other")]
    [String] $OS,
    [parameter(Mandatory=$false)]
    [int64] $RAM = 2GB,
    [parameter(Mandatory=$false)]
    [switch] $Clone = $true,
    [parameter(Mandatory=$true)]
    [string] $Switch   
)

#Create the virtual machines folder if it doesn't exist
#Uncomment if running in seat
#$vmpath = "$env:userprofile\Documents\Virtual Machines"
$vmpath = "D:\VM"
$vhdpath = "D:\VHD" #This is the typical path for VCastle

if (!(Test-Path -Path $vmpath )) { New-Item -Path $vmpath -ItemType Directory}

Write-Host "Creating a $OS $vmtype virtual machine named $name using the image $diskImage with $RAM memory connected to the $switch switch!" -ForegroundColor DarkGreen

#Create the virtual switch if it does not exist
if (!(Get-VMSwitch -Name $switch -ErrorAction SilentlyContinue )) 
{ 
            Write-host -ForegroundColor Yellow "Switch name '$switch' ..."
    if($switch -ne "CIS-NAT-01"){
            Write-host -ForegroundColor Yellow "Creating Internal virtual switch $switch..."
            Write-host -ForegroundColor Yellow $line
            New-VMSwitch -Name PA-NAT-01 -SwitchType Internal
            New-NetNat -Name PA-NAT -InternalIPInterfaceAddressPrefix 172.15.50.0/24 -Verbose
            Get-NetAdapter -Name *A-NAT* | New-NetIPAddress -IPAddress 172.15.50.254 -PrefixLength 24
    } else 
    {
        Write-host -ForegroundColor Yellow "Creating private virtual switch $switch..."
        Write-host -ForegroundColor Yellow $line
        New-VMSwitch -Name $switch -SwitchType Private
    }
}

#Create the virtual machine
Write-Host -ForegroundColor Yellow "Creating virtual machine..."
$Generation = $OSImages.$OS.Gen
$DynMemory = $OSImages.$OS.Dmemory
New-VM -Name $vmname -MemoryStartupBytes $RAM -Generation $Generation -NoVHD -Path $vmpath -SwitchName $switch -Verbose
Set-VMNetworkAdapter -VMName $VMName -DeviceNaming On #Name the network adapter after the switch and propagate to the VM
if ($DynMemory) { Set-VM -Name $VMName -DynamicMemory } 
#This allows the student and a script to see which switch the network adapter is connected to
Rename-VMNetworkAdapter -VMName $VMName -NewName $switch

#Automatic checkpoints just slow things down and cause students to ask questions
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false

if ($Clone)
{
    $diskImage = $OSImages.$OS.parentDisk
    New-VHD -Path "$vhdpath\$vmname.vhdx" -ParentPath "$vdiskPath\$diskImage" -Differencing
    Add-VMHardDiskDrive -VMName $vmname -Path "$vhdpath\$vmname.vhdx"
 }
 else
 {
    New-VHD -Path "$vhdpath\$vmname.vhdx" -Dynamic
    Add-VMHardDiskDrive -VMName $vmname -Path "$vhdpath\$vmname.vhdx"
 }

#Set the boot order for the virtual machine
if ($Generation -eq 2){
    Set-VMFirmware -VMName $vmname -FirstBootDevice (Get-VMHardDiskDrive -VMName $vmname)
}

}

function Add-Disk ([int] $Number, [string] $VMName)
{
    if (!(Get-VM -Name $vmname)) { Write-Host -ForegroundColor Cyan "VM not found"; exit }
    #$vhdpath = (Get-VM -Name $vmname).Path + "\Virtual Hard Disks\" #Uncomment if using on ground
    for ($i=1; $i -le $number; $i++)
    {
        $disk = New-VHD -Dynamic -Path "$vhdpath\$VMName-HD-0$i.vhdx" -SizeBytes 127GB
        Add-VMHardDiskDrive -VMName $vmname -Path $disk.Path
    } 
}

Function Add-NetworkAdapter ([string] $VMName, [string] $switch)
{
    #Create the virtual switch if it does not exist
    if (!(Get-VMSwitch -Name $switch -ErrorAction SilentlyContinue )) 
    { 
            Write-host -ForegroundColor Yellow "Creating private virtual switch $switch..."
            Write-host -ForegroundColor Yellow $line
            New-VMSwitch -Name $switch -SwitchType Private
    }
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $switch -Name $switch -DeviceNaming On
    
}

#Main Loop - this is where you create the virtual machines and 

#Create-VM -VMName CIS220-W10-Client -RAM 2GB -OS W10 -Clone -switch LAN
# The command above creates a virtual machine named CIS220-W10-Client with 2GB of ram 
# using a Windows 10 differencing disk and creates and connects the vm to the LAN virtual switch 

#Add-Disk -VMName CIS220-2K16-Server -Number 5
# The command above adds 5 disks to the CIS220-2K16-Server virtual machine

#Add-NetworkAdapter -VMName Server1 -switch LAN 
# The command above adds a network adapter named LAN to the Server1 virtual machine and turns on device naming. 
# It will also create the LAN virtual switch if it does not exist

Create-VM -VMName GE3 -RAM 2GB -OS W10 -Clone -switch PA-NAT-01