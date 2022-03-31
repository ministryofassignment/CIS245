#A grading script written by Kevin Azevedo on 10/28/20.  
#Modified by Martin Carruth on 2/10/2021
#A Script to grade the CI251 Setup - VCastle lab

#Initialization
$lastname = Read-Host -Prompt "Type your lastname"
$line = "=" * 66
Write-Host -ForegroundColor Cyan "This script should be run as follows on the virtualization host:"
Write-Host -ForegroundColor Green "`tInvoke-Pester -Path <path to script>"
Write-Host "`t`t" (Get-WMIObject -Class Win32_computerSystemProduct).UUID -Foreground Cyan
Write-Host (Get-Date).DateTime


Describe "HyperV Lab Setup - VCastle" {
    $hostname = "$lastname-VM-Host"
    It "Host (Computer) name  should be <hostname> "  -TestCases @(@{hostname = $hostname; line = $line}) {
        write-host "Checking VMHost " (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen
        hostname | Should -Be $hostname
    }
    It "One adapter renamed to LAN" -TestCases @(@{line = $line}) {
        (Get-NetAdapter).Name | Should -Contain "LAN"
        write-host "Checking adapter name " (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen
    }
    It "LAN adapter should be enabled" -TestCases @(@{line = $line})  {
        (Get-NetAdapter -Name LAN).Status | Should -Be "Up"
        write-host "Checking adapter enabled" (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen
    }
    It "One adapter renamed to LAN1" -TestCases @(@{line = $line}) {
        write-host "Checking adapter name " (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen
        (Get-NetAdapter).Name | Should -Contain "LAN1"
    }
    It "LAN1 adapter should be disabled" -TestCases @(@{line = $line}) {
        write-host "Checking adapter disabled " (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen
        (Get-NetAdapter -Name LAN1).Status | Should -Bein ("Not Present","Disabled")
    }
    It "Windows update service should be disabled" -TestCases @(@{line = $line}) {
        write-host "Checking Windows update service " (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen
        (Get-Service -Name wuauserv).StartType | Should -Be "Disabled"
    }
    It "Hyper-V and its management tools should be installed" -TestCases @(@{line = $line}) {
        write-host "Checking Hyper-V management tools " (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen
        (Get-WindowsFeature -Name Hyper-V).Installed | Should -Be $true
        (Get-WindowsFeature -Name RSAT-Hyper-V-Tools).Installed | Should -Be $true
        
    }
    It "Execution Policy should be Unrestrictred" -TestCases @(@{line = $line}) {
        write-host "Checking Powershell Execution policy " (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen

        Get-ExecutionPolicy | Should -be "unrestricted"
    }
    It "VM-Host is activated" -TestCases @(@{line = $line}) {
        write-host "Checking VMHost Windows activation " (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host $line -ForegroundColor DarkGreen
        $activated = Get-EventLog Application | Where-Object {$_.Message -Like '*msft:rm/algorithm/volume/1.0 0x4004f040*'} | Measure-Object -Line 
        $activated.Lines | Should -BeGreaterThan 0
    }
    AfterAll {
        Write-Host "`t" (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host "`t" (Get-WMIObject -Class Win32_computerSystemProduct).UUID -ForegroundColor Cyan
        $scriptName=&{$MyInvocation.ScriptName}
        Write-Host (Get-FileHash $scriptName).Hash -ForegroundColor Cyan        
        Write-Host "`t" $scriptName -ForegroundColor Cyan
    }
        
}