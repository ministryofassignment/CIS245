#kmw-Lab-Installing Active Directory.test.ps1 written by Kevin Azevedo on 1/29/2020
#A script to test the successful completion of the Installing Active Directory lab.
$studentid = Read-Host -Prompt "Type your studentid and then hit enter"
$secpassword = ConvertTo-SecureString Password1 -AsPlainText -Force
$ClientCredential = New-Object System.Management.Automation.PSCredential("GE\Administrator",$secpassword)
$ServerCredential = New-Object System.Management.Automation.PSCredential("GE\Administrator",$secpassword)
$ServerSession = New-PSSession -VMName GE-SERVER -Credential $ServerCredential
$clientSession = New-PSSession -VMName GE3 -Credential $ClientCredential
Write-Host -ForegroundColor Cyan "This script should be run as follows on the virtualization host:"
Write-Host -ForegroundColor Green "`tInvoke-Pester -Path <path to script> -Output Detailed"
Write-Host "`t`t`t" (hostname) -ForegroundColor Green
Write-Host "`t`t" (Get-Date).DateTime -ForegroundColor Green
$vmName = "GE-SERVER" 

$vmconfigs = @{
            "GE3" = @{
                    IP = "172.15.50.26"
                    snm = "255.255.255.0"
                    gw = "172.15.50.254"
                    dns = "172.15.50.2"
                    session = $clientSession
                    adapter = "Ethernet"
                    Name = "GE\Domain Users"
                    directory = "C:\PerfLogs\Admin\PA3\"
                    rootPath = "%systemdrive%\PerfLogs\Admin\PA3"
            }
        }        

Describe "Performance Assessment: Remote Management" {
    $session = New-PSSession -VMName $vmName -Credential $ServerCredential
    $DNSDomain = "GE.local"
    $forest = "GE.local"
    $domainController = "GE-DC01.GE.local"
    $clientVM = "GE3"
    $cleintName = "GE-DE03"
   
    Context "GE3 Initial Startup and client joined to domain (10 points)" {
        $ticks = (Get-Date).Ticks
        $client = Invoke-Command -Session $session -ScriptBlock { Get-ADComputer -Filter 'Name -like "*D*" ' }
        IT "$cleintName - Windows 10 is installed and joined to domain - $ticks " -TestCases @(@{domain = $domain; forest = $forest;}){
            $client.Name | Should -be $clientName
        }#End It
     }# end Context

    Context "DE3 TCP/IP Settings (10 points)" {
        
        foreach ($vmconfig in $vmconfigs.Keys) {
            $ticks = (Get-Date).Ticks
            It "$vmconfig TCP/IP settings & NIC Name configured correctly - $ticks " -TestCases @(@{vmconfig = $vmconfig; vmconfigs = $vmconfigs}) {
                #Discovery
                $IPconfig =  Invoke-Command -Session ($vmconfigs.$vmconfig.session) -ScriptBlock { Get-NetIPAddress -interfacealias Ethernet -AddressFamily IPv4}
                $droute =  Invoke-Command -Session ($vmconfigs.$vmconfig.session) -ScriptBlock { Get-NetRoute -DestinationPrefix 0.0.0.0/0 -AddressFamily IPv4}
                $dns =  Invoke-Command -Session ($vmconfigs.$vmconfig.session) -ScriptBlock { Get-DnsClientServerAddress -InterfaceAlias Ethernet }
                $adapter = Invoke-Command -Session ($vmconfigs.$vmconfig.session) -ScriptBlock {get-netAdapter}
                #Tests
                $IPconfig | Should -Not -BeNullOrEmpty
                $IPconfig.IPAddress | Should -be ($vmconfigs.$vmconfig.IP)
                $vmconfigs.$vmconfig.gw | Should -be $droute.nexthop
                $DNS.ServerAddresses | Should -bein $vmconfigs.$vmconfig.DNS
                $adapter.Name | Should -be ($vmconfigs.$vmconfig.adapter)

            }
            
        }#End It
    }# end Context   

    Context "Client configurations for Windows Update (10 points)" {
        $ticks = (Get-Date).Ticks
        $wuauserv = Invoke-Command -Session $clientSession -ScriptBlock { get-service wuauserv | select -property name,starttype }
        IT "Windows update is set to Manual on $cleintName - $ticks " -TestCases @(@{wuauserv = $wuauserv}){
            $wuauserv.StartType  | Should -be "3"
        }
        #End It

     }# end Context

    Context "Users created and added to Global Groups (10 points)" {
        $ticks = (Get-Date).Ticks
        $accounts = @{
            "Admin" = @{
                SamAccountName = $studentid
                group = "Domain Admins"
            }
        }

        foreach($account in $accounts.Keys){
            $group = Invoke-Command -Session $ServerSession -ArgumentList ($accounts.$account.group), ($accounts.$account.SamAccountName) -ScriptBlock { 
                param($group, $SamAccountName) get-AdGroupMember $group | where {$_.SamAccountName -eq $SamAccountName} 
            }

            IT "<account> account is created and in the correct group - $ticks " -TestCases @(@{ account = $account; accounts = $accounts; group=$group }){
                $group.SamAccountName  | Should -be $accounts.$account.SamAccountName
            }
            #End It
        }
     }# end Context

    Context "Windows Update Set to manual on GE3 (10 points)" {
        $ticks = (Get-Date).Ticks
        $wuauserv = Invoke-Command -Session $clientSession -ScriptBlock { get-service wuauserv | select -property name,starttype }
        IT "Windows update is disabled on $cleintName - $ticks (10 pts)" -TestCases @(@{wuauserv = $wuauserv}){
            $wuauserv.StartType  | Should -be "3"
        }
        #End It

     }# end Context    

    Context "GE3 - Remote Configuration (30 points)" {
    $ticks = (Get-Date).Ticks
        foreach ($vmconfig in $vmconfigs.Keys) {
            $dl = Invoke-Command -Session $clientSession -ScriptBlock {  get-localgroupmember "remote desktop users" |where {$_.Name -eq "GE\Domain Users"} }
            $remote = Invoke-Command -Session $clientSession -ScriptBlock {  Test-WsMan } 
            It "Remote Desktop Users group is not empty on GE3 - $ticks " -TestCases @(@{dl = $dl; vmconfigs=$vmconfigs; vmconfig=$vmconfig}) {
                $dl.Name | Should -not -BeNullOrEmpty
            }
            It "Domain users added to Remote Desktop Users group on GE3  - $ticks" -TestCases @(@{dl = $dl; vmconfigs=$vmconfigs; vmconfig=$vmconfig}) {
                $dl.Name | Should -be $vmconfigs.$vmconfig.Name
            }
            It "Powershell Remote is enabled on GE3 - $ticks" -TestCases @(@{remote = $remote; vmconfigs=$vmconfigs; vmconfig=$vmconfig}) {
                $remote.ProductVendor | Should -not -BeNullOrEmpty
            }
        }
        $rsat = Invoke-Command -Session $clientSession -ScriptBlock {  get-module -list ActiveDirectory }
        IT "RSAT - Active Directory installed on GE3" -TestCases @(@{rsat = $rsat; }){
            $rsat.Name | Should -not -BeNullOrEmpty
        }#End It
            
    }# end Context         
    Context "GE3 - Data Collector set (20 points)" {
    $ticks = (Get-Date).Ticks
        foreach ($vmconfig in $vmconfigs.Keys) {
            $dl = Invoke-Command -Session $clientSession -ScriptBlock {  Get-ChildItem "C:\PerfLogs\Admin\PA3\"} }
            $dataset = Invoke-Command -Session $clientSession -ScriptBlock { 
                $datacollectorset = New-Object -COm pla.datacollectorset
                $datacollectorset.Query("PA3","localhost")
                $datacollectorset
                } 
            It "GE3  Datacollector path is not empty - $ticks" -TestCases @(@{dataset = $dataset; vmconfigs=$vmconfigs; vmconfig=$vmconfig}) {
                $dataset.RootPath | Should -not -BeNullOrEmpty
            }#End It
            It "GE3  Datacollector storage path is set correctly - $ticks" -TestCases @(@{dataset = $dataset; vmconfigs=$vmconfigs; vmconfig=$vmconfig}) {
                $dataset.RootPath | Should -be $vmconfigs.$vmconfig.rootPath
            }#End It
            It "GE3  Datacollector set has run - $ticks" -TestCases @(@{dl = $dl; vmconfigs=$vmconfigs; vmconfig=$vmconfig}) {
                $dl.Name | Should -not -BeNullOrEmpty
            }#End It
        }# end Context


    AfterAll {
        Write-Host (Get-Date).Ticks -ForegroundColor Green
    }   
    
    
     

}
