#kmw-Lab-Installing Active Directory.test.ps1 written by Kevin Azevedo on 1/29/2020
#A script to test the successful completion of the Installing Active Directory lab.
$secpassword = ConvertTo-SecureString Password1 -AsPlainText -Force
$ServerCredential = New-Object System.Management.Automation.PSCredential("kmk\administrator",$secpassword)
$ServerSession = New-PSSession -VMName SERVER -Credential $ServerCredential
$line = "=" * 66

Write-Host -ForegroundColor Green "`tVirtual Network Setup in HyperV"
Write-Host -ForegroundColor Green "This script should be run as follows on the virtualization host:"
Write-Host -ForegroundColor Green "`tInvoke-Pester -Path <path to script>"
Write-Host "`t`t`t" (hostname) -ForegroundColor Cyan
Write-Host "`t`t" (Get-WMIObject -Class Win32_computerSystemProduct).UUID -Foreground Cyan
Write-Host "`t`t" (Get-Date).DateTime -ForegroundColor Cyan
$vmName = "SERVER"
Describe "Guided Practice Installing Active Directory" {
    $session = New-PSSession -VMName $vmName -Credential $ServerCredential
    $DNSDomain = "kmk.local"
    $forest = "kmk.local"
    $domainController = "DC-01.kmk.local"
    Context "Establishing Prerequisites for Installing Active Directory" {
        $InstalledRoles = @("AD-Domain-Services","RSAT-AD-Tools")
            $roles = Invoke-Command -Session $session -ScriptBlock { Get-WindowsFeature }
            It "$InstalledRoles Roles are installed" -TestCases @(@{InstalldRoles = $InstalledRoles}){
                foreach ($role in $InstalledRoles)
                {
                   ($roles | ? Name -eq $role).Installed | Should -be $true
                }
            }
    }
    Context "Creating the Forest Root Domain" {
        $domain = Invoke-Command -Session $session -ScriptBlock { Get-ADDomain }
        It "Domain forest is $forest" -TestCases @(@{domain = $domain; forest = $forest; domainController = $domainController; line = $line}){
            write-host "Checking Domain forest name " (Get-Date).Ticks -ForegroundColor Cyan
            Write-Host $line -ForegroundColor DarkGreen
            $domain.forest | Should -be $forest
        }
        It "Domain DNS root should be $DNSDomain" -TestCases @(@{domain = $domain; DNSDomain = $DNSDomain; line = $line}){
            write-host "Checking DNS Domain forest name " (Get-Date).Ticks -ForegroundColor Cyan
            Write-Host $line -ForegroundColor DarkGreen
            $domain.DNSroot | should -be $DNSDomain
        }
        It "$domainController is a Domain Controller" -TestCases @(@{domain = $domain; domainController = $domainController; line = $line}){
            write-host "Checking SERVER is a Domain controller " (Get-Date).Ticks -ForegroundColor Cyan
            Write-Host $line -ForegroundColor DarkGreen
            $domainController | Should -bein $domain.ReplicaDirectoryServers
        }#End It
     }
     Context "Additional Configurations" {
        $userValues = @{
                            SamAccountName = "administrator"
                            ContainerPath = "CN=Users,DC=kmk,DC=local"
                        }
        $user = Invoke-Command -Session $session -ArgumentList $userValues -ScriptBlock {param($userValues) Get-ADUser -Identity $userValues.SamAccountName -Properties *}

        It ("User " + $userValues.SamAccountName + " was created") -TestCases @(@{user = $user; uservalues = $userValues; line = $line}){
            write-host "Checking Administrator account created " (Get-Date).Ticks -ForegroundColor Cyan
            Write-Host $line -ForegroundColor DarkGreen
            $user.SamAccountName | Should -be $userValues.SamAccountName
        }
        It ("User object location is " + $userValues.ContainerPath) -TestCases @(@{user = $user; uservalues = $userValues; line = $line}){

            $commaLocation = ($user.DistinguishedName).IndexOf(",")
            $userContainer = ($user.DistinguishedName).subString($commaLocation +1)
            $userContainer | Should -be $userValues.ContainerPath      
        }
    
       $groupInfo = @{
                        administrator = @("Domain Admins","Enterprise Admins")
        }
        foreach ($userName in $groupInfo.Keys)
        {
            $groupNames = $groupInfo.$userName
            foreach ($groupName in $groupNames){
                It "$userName is a member of $groupName" -TestCases @(@{username = $username; groupname = $groupName; session = $session; line = $line}) {    
                    Invoke-Command -Session $session -ArgumentList $groupName -ScriptBlock {param($groupName) (Get-ADGroupMember -Identity $groupName).samAccountName } | Should -Contain $userName
                }
            }
        }
        #end foreach

    }

    Context "Configuring TCP/IP Settings" {
        $vmconfigs = @{
            "SERVER" = @{
#                    IP = "10.1.1.1"
                    snm = "255.255.255.0"
                    gw = "10.1.1.254"
                    dns = "::1","127.0.0.1"
                    session = $ServerSession
            }
            
    }        
        foreach ($vmconfig in $vmconfigs.Keys) {
            It "$vmconfig TCP/IP settings configured correctly" -TestCases @(@{vmconfig = $vmconfig; vmconfigs = $vmconfigs; line = $line}) {
                write-host "Checking TCP/IP Settings $vmconfig " (Get-Date).Ticks -ForegroundColor Cyan
                Write-Host $line -ForegroundColor DarkGreen

                #Discovery
                $IPconfig =  Invoke-Command -Session ($vmconfigs.$vmconfig.session) -ScriptBlock { Get-NetIPAddress -interfacealias LAN -AddressFamily IPv4}
                $droute =  Invoke-Command -Session ($vmconfigs.$vmconfig.session) -ScriptBlock { Get-NetRoute -DestinationPrefix 0.0.0.0/0 -AddressFamily IPv4}
                $dns =  Invoke-Command -Session ($vmconfigs.$vmconfig.session) -ScriptBlock { Get-DnsClientServerAddress -InterfaceAlias LAN }
                #Tests
                $IPconfig | Should -Not -BeNullOrEmpty
                #$IPconfig.IPAddress | Should -be ($vmconfigs.$vmconfig.IP)
                $vmconfigs.$vmconfig.gw | Should -be $droute.nexthop
                $DNS.ServerAddresses | Should -bein $vmconfigs.$vmconfig.DNS
            }
            
        }

        $cleintName = "DE-01"

        $ClientValues = Invoke-Command -Session $ServerSession -ScriptBlock {get-Adcomputer "DE-01" -Properties *}
        IT "CLIENT1 Name & TCP/IP Settings cofigured correctly" -TestCases @(@{client=$ClientValues; name= "DE-01"; line = $line}){
                write-host "Checking CLIENT1 settings " (Get-Date).Ticks -ForegroundColor Cyan
                Write-Host $line -ForegroundColor DarkGreen
            $ClientValues.Name | Should -Be $cleintName
        }

    }
    # end Context
    Context "SERVER VMs activated"{
        It "SERVER is activated" -TestCases @(@{ServerSession = $ServerSession; line = $line}) {
                write-host "Checking SERVER activation " (Get-Date).Ticks -ForegroundColor Cyan
                Write-Host $line -ForegroundColor DarkGreen

                $activated = Invoke-Command -Session $ServerSession -ScriptBlock {Get-EventLog Application | Where-Object {$_.Message -Like '*msft:rm/algorithm/volume/1.0 0x4004f040*'} | Measure-Object -Line }
                $activated.Lines | Should -BeGreaterThan 0
        }

    }
    # end Context


    AfterAll {
        Write-Host "`t" (Get-Date).Ticks -ForegroundColor Cyan
        Write-Host "`t" (Get-WMIObject -Class Win32_computerSystemProduct).UUID -ForegroundColor Cyan
        $scriptName=&{$MyInvocation.ScriptName}
        Write-Host (Get-FileHash $scriptName).Hash -ForegroundColor Cyan        
        Write-Host "`t" $scriptName -ForegroundColor Cyan    }   
    
    
     

}
