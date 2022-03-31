#Written by Kevin Azevedo on 12/16/20
#Modified by Martin Carrth o 3/31/2021 to support CIS245
#A script to grade Guided Practice Windows Update
$secpassword = ConvertTo-SecureString Password1 -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential("kmk\Administrator",$secpassword)
Write-Host -ForegroundColor Cyan "This script should be run as follows on the virtualization host:"
Write-Host -ForegroundColor Green "`tInvoke-Pester -Path <path to script> -Output Detailed"
Write-Host "`t`t`t" (hostname) -ForegroundColor Green
Write-Host "`t`t" (Get-Date).DateTime -ForegroundColor Green
#$session = New-PSSession -VMName SERVER -Credential $Credential
$Csession1 = New-PSSession -VMName CLIENT1 -Credential $Credential
#$Csession2 = New-PSSession -VMName CLIENT2 -Credential $Credential


#
Describe "Guided Practice - Windows Update" {
    Context "Local Policy is configured for WSUS server on CLIENT1" {
        $wsus = Invoke-Command -Session $Csession1 -ScriptBlock { (Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate") }
        IT "Windows update configured in Policy on CLIENT1" -TestCases @(@{wsus = $wsus; }){
            $wsus.WuServer | Should -be "http://10.254.7.2:8530"
        }
    }
    
    AfterAll {
            Write-Host -ForegroundColor Green "`t`t" (Get-Date).Ticks
    }
}
    