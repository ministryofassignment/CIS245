#Written by Kevin Azevedo on 12/16/20
#Modified by Martin Carrth o 3/31/2021 to support CIS245
#A script to grade Guided Practice Upgradng and Installing
$secpassword = ConvertTo-SecureString Password1 -AsPlainText -Force 
$ServerCredential = New-Object System.Management.Automation.PSCredential("KMK\administrator",$secpassword) 
$ClientCredential = New-Object System.Management.Automation.PSCredential("KMK\administrator",$secpassword) 
$line = "=" * 66
Write-Host -ForegroundColor Green "`t`t`tInstall and Upgrade"
Write-Host "`t`t`t" (hostname) -ForegroundColor Cyan
Write-Host "`t`t" (Get-WMIObject -Class Win32_computerSystemProduct).UUID -Foreground Cyan
Write-Host "`t`t" (Get-Date).DateTime -ForegroundColor Cyan
$vmconfigs = @{
                "SERVER" = @{
                                    OS = "ServerDatacenter"
                                    Name = "DC-01"
                                    Memory = 2GB
                                    Credential = $ServerCredential
                                    Update="4"
                }
                
                "CLIENT1" = @{
                                    OS = "Education"
                                    Name = "DE-01"
                                    Memory = 2GB
                                    Credential = $ClientCredential
                                    Update="3"
                }
                "CLIENT2" = @{
                                    OS = "Education"
                                    Name = "DE-02"
                                    Memory = 2GB
                                    Credential = $ClientCredential
                                    Update="3"
                }
}


Describe "Guided Practice - Install and Upgrade" {
    
        foreach ($vmconfig in $vmconfigs.Keys) {
            $vm = Get-VM -VMName $vmconfig
            $vmname = $vm.Name
            Context "$vmname Configuration" {
                It "Virtual Machine Created" -TestCases @(@{vm = $vm; line = $line}) {
                write-host "Checking VM Creation " (Get-Date).Ticks -ForegroundColor Cyan
                Write-Host $line -ForegroundColor DarkGreen
                    $vm | Should -not -BeNullOrEmpty
                }
                It "Correct amount of RAM configured" -TestCases @(@{vm = $vm; vmconfig = $vmconfig; vmconfigs = $vmconfigs; line = $line; vmname = $vmname}) {
                    write-host "Checking RAM in $vmname VM  " (Get-Date).Ticks -ForegroundColor Cyan
                    Write-Host $line -ForegroundColor DarkGreen
                    $vm.MemoryStartup | Should -Be ($vmconfigs.$vmconfig.Memory)
                }

                It "Dynamic Memory is enabled" -TestCases @(@{vm = $vm; vmconfig = $vmconfig; vmconfigs = $vmconfigs; line = $line; vmname = $vmname}) {
                    write-host "Verifying Dynamic Memory enabled in $vmname VM  " (Get-Date).Ticks -ForegroundColor Cyan
                    Write-Host $line -ForegroundColor DarkGreen
                    $vm.DynamicMemoryEnabled | Should -BeTrue
                }
                $cred = $vmconfigs.$vmconfig.Credential
                It "Computer is correctly named" -TestCases @(@{vmconfig = $vmconfig; vmconfigs = $vmconfigs; cred = $cred; line = $line; vmname = $vmname }) {
                    write-host "Verifying $vmname named correctly " (Get-Date).Ticks -ForegroundColor Cyan
                    Write-Host $line -ForegroundColor DarkGreen
                    Invoke-Command -VMName $vmconfig -Credential $cred -ScriptBlock { hostname } | Should -Be ($vmconfigs.$vmconfig.Name)
                }
                It "Computer is correct operating system and version" -TestCases @(@{vmconfig = $vmconfig; vmconfigs = $vmconfigs; cred = $cred; line = $line; vmname = $vmname }) {
                    write-host "Checking OS version in $vmname  " (Get-Date).Ticks -ForegroundColor Cyan
                    Write-Host $line -ForegroundColor DarkGreen
                    Invoke-Command -VMName $vmconfig -Credential $cred -ScriptBlock { (Get-WindowsEdition -Online).Edition } | Should -Be ($vmconfigs.$vmconfig.OS)
                }
                It "Windows update is disabled " -TestCases @(@{vmconfig = $vmconfig; vmconfigs = $vmconfigs; cred = $cred ; line = $line; vmname = $vmname}) {
                    write-host "Checking Windows Update setting in $vmname " (Get-Date).Ticks -ForegroundColor Cyan
                    Write-Host $line -ForegroundColor DarkGreen
                    $update= Invoke-Command -VMName $vmconfig -Credential $cred -ScriptBlock { (Get-Service wuauserv).StartType} | Should -Be ($vmconfigs.$vmconfig.Update)
                }
                It "Computer is activated" -TestCases @(@{vmconfig = $vmconfig; vmconfigs = $vmconfigs; cred = $cred ; line = $line; vmname = $vmname}) {
                    write-host "Checking Computer activation in $vmname " (Get-Date).Ticks -ForegroundColor Cyan
                    Write-Host $line -ForegroundColor DarkGreen
                    $activated = Invoke-Command -VMName $vmconfig -Credential $cred -ScriptBlock {Get-EventLog Application | Where-Object {$_.Message -Like '*msft:rm/algorithm/volume/1.0 0x4004f040*'} | Measure-Object -Line }
                    $activated.Lines | Should -BeGreaterThan 0
                }
            }
        }
    

    AfterAll {
        Write-Host "`t" (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host "`t" (Get-WMIObject -Class Win32_computerSystemProduct).UUID -ForegroundColor Cyan
        $scriptName=&{$MyInvocation.ScriptName}
        Write-Host (Get-FileHash $scriptName).Hash -ForegroundColor Cyan        
        Write-Host "`t" $scriptName -ForegroundColor Cyan
        }
        }
    