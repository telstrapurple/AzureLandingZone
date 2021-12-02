Configuration Main
{

Param 
( 
    [string] $nodeName = $env:COMPUTERNAME,
    [Int]$retryCount = 5,
    [Int]$retryIntervalSec = 30
)

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xDisk, xTimeZone, xComputerManagement

    Node $nodeName
    {
        xTimeZone TimeZonePerth {
            TimeZone = "W. Australia Standard Time"
            IsSingleInstance = "Yes"
        }
        
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyAndAutoCorrect'
            RebootNodeIfNeeded = $true
            ActionAfterReboot = 'ContinueConfiguration'
            AllowModuleOverwrite = $true
        }
        Script DisablePageFile
        {
            GetScript  = { @{ Result = "" } }
            TestScript = {
                $pf=Get-WmiObject win32_pagefilesetting
                #There's no page file so okay to enable on the new drive
                if ($pf -eq $null)
                {
                    return $true
                }
                #Page file is still on the D drive
                if ($pf.Name.ToLower().Contains('d:'))
                {
                    return $false
                }
                
                else
                {
                    return $true
                }
            }
            SetScript  = {
                #Change temp drive and Page file Location
                Get-WmiObject win32_pagefilesetting
                $pf=Get-WmiObject win32_pagefilesetting
                $pf.Delete()
                Restart-Computer -Force
            }
        }      
        
        xWaitforDisk DataDisk {
            DiskNumber = 2
            RetryIntervalSec = $retryIntervalSec
            RetryCount = $retryCount
        }
        
        xDisk DataDisk {
            DiskNumber = 2
            DriveLetter = "D"
        }
        
        File CreateTempDirectory {
            Type = "Directory"
            DestinationPath = "D:\Windows"
            Ensure = "Present"
        }
        
        WindowsFeature DNS
        {
            Ensure = "Present"
            Name = "DNS"
        }
        
        Script EnableDNSDiags
        {
            SetScript = {
                Set-DnsServerDiagnostics -All $true
                Write-Verbose -Verbose "Enabling DNS client diagnostics"
            }
            GetScript =  { @{} }
            TestScript = { $false }
            DependsOn = "[WindowsFeature]DNS"
        }
        
        WindowsFeature DnsTools
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }
        
        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            DependsOn="[WindowsFeature]DNS"
        }
        
        WindowsFeature ADDSTools
        {
            Ensure = "Present"
            Name = "RSAT-ADDS-Tools"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
        
        WindowsFeature ADPowerShell
        {
            Ensure = 'Present'
            Name   = 'RSAT-AD-PowerShell'
        }
        
        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
        WindowsFeature RSAT_GPMC
        {
            Ensure = 'Present'
            Name   = 'GPMC'
        }

        WindowsFeature TelnetClient
        {
            Ensure = 'Present'
            Name   = 'telnet-client'
        }
    }
}