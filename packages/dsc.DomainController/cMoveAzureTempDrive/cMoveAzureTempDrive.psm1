[DscResource()]
class cMoveAzureTempDrive
{
    <#
        This property is the name of the system - its not used for anything
        other than they key.
    #>
    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Mandatory)]
    [string]$TempDriveLetter

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
         properties.
    #>
    [cMoveAzureTempDrive] Get()
    {
        $this.Name = $Env:COMPUTERNAME
        #This is the default PartitionType
        $this.TempDriveLetter = $this.GetTempDriveLetter()
        return $this
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test()
    {
        try {
            Write-Verbose "cMoveAzureTempDrive:Test - Start"
            $TestResult = $true

            $this.TempDriveLetter = $this.ValidateDriveLetter($this.TempDriveLetter)
            If ($this.TempDriveLetter -eq 'D:' ) {
                Throw "New Temp Drive cannot be D:"
            }
                        
            #See if the Azure Temp drive is on the TempDriveLetter
            $CurTempDrive = $this.GetTempDriveLetter()
            Write-Verbose "cMoveAzureTempDrive:Test -   Azure temp drive is on '$CurTempDrive'"
            If ($this.TempDriveLetter -ne $CurTempDrive ) {
                Write-Verbose ("cMoveAzureTempDrive:Test -   Temp drive is on '$CurTempDrive' not on " + $this.TempDriveLetter)
                $TestResult = $false
            } else {
                #and the pagefile is on that drive 
                if ( -not  ( $this.DoesPageFileExistOnDrive($this.TempDriveLetter) )) {
                    Write-Verbose ("cMoveAzureTempDrive:Test -   Pagefile not on " + $this.TempDriveLetter)          
                    $TestResult = $false
                } else {
                    Write-Verbose ("cMoveAzureTempDrive:Test -   Found pagefile on temp drive: " + $this.TempDriveLetter )
                }
            }

            return $TestResult
        }
        finally {
            Write-Verbose "cMoveAzureTempDrive:Test - End"
        }
    }

    <#
        This method is equivalent of the Set-TargetResource script function.
        It sets the resource to the desired state.
    #>
    [void] Set()
    {
        try {
            Write-Verbose "cMoveAzureTempDrive:Set - Start"

            $this.TempDriveLetter = $this.ValidateDriveLetter($this.TempDriveLetter)

            #Our inital state should be TempDrive - D:, Page: D:

            #First, see if AzureTempDrive is on D:
            $curTempDrive = $this.GetTempDriveLetter() 
            Write-Verbose ("cMoveAzureTempDrive:Set -   Current Temp Drive Letter: " + $curTempDrive)

            If ($curTempDrive -ne $this.TempDriveLetter) {
                Write-Verbose ("cMoveAzureTempDrive:Set -   Current Temp Drive Letter: " + $curTempDrive + " not on " + $this.TempDriveLetter)
                #See if PageFile is still on D
                if ($this.DoesPageFileExistOnDrive( $curTempDrive )) {
                    Write-Verbose ("cMoveAzureTempDrive:Set -   Pagefile exists on Current Temp Drive Letter: " + $curTempDrive )
                    #Remove page file
                    $filter = ("name like '" + $curTempDrive  + "\\%'")
                    $pf = Get-WmiObject -Class win32_pagefilesetting -Filter $filter 
                    if ($pf -ne $null) {
                        Write-Verbose ("cMoveAzureTempDrive:Set -   Deleting pagefile from " + $curTempDrive )
                        $pf.Delete()
                        Write-Verbose "cMoveAzureTempDrive:Set -   Rebooting"
                        #Restart here - Our state will be TempDrive - D:, Page: Null
                        Restart-Computer -Force 
                        return 
                    }                    
                } else {
                    #Move this drive to the new temp drive letter
                    try {
                        Write-Verbose ("cMoveAzureTempDrive:Set -   Moving azure temp drive from '$curTempDrive' to '" + $this.TempDriveLetter + "'")
                        $filter = 'DriveLetter = "' + $curTempDrive + '"'
                        $drv = Get-WmiObject win32_volume -filter $filter
                        $drv.DriveLetter = $this.TempDriveLetter
                        $drv.Put() | out-null
                        #Our state should now be  TempDrive - T:, Page: Null:
                        #Re-read our current Temp Drive Letter
                        $curTempDrive = $this.GetTempDriveLetter() 
                    } catch {
                        Write-Verbose ("cMoveAzureTempDrive:Set -   Error Moving azure temp drive: '" + $this.TempDriveLetter + "'")
                    }
                }
            }
            
            If ($curTempDrive -eq $this.TempDriveLetter) {
                #Our state should now be  TempDrive - T:, Page: Null:                           
                $filter = "name like '" + $this.TempDriveLetter + "\\%'"
                $pf = Get-WmiObject -Class win32_pagefilesetting -Filter $filter 
                if ($pf -eq $null) {
                    #re-enable page file on new Drive
                    $PageFile = $this.TempDriveLetter + '\pagefile.sys'
                    Set-WMIInstance -Class Win32_PageFileSetting -Arguments @{ Name = $PageFile ; InitialSize=0; MaximumSize = 0; }
                    Restart-Computer -Force    
                } 
            }
        } finally {
            Write-Verbose "cMoveAzureTempDrive:Set - End"
        }
    }

    <#
        Helper method to get the Temp Drive letter
    #>
    [string] GetTempDriveLetter()
    {
        #Change temp drive and Page file Location 
        $filter = 'Label = "Temporary Storage"'
        $drive = Get-WmiObject -Class win32_volume -Filter $filter
        if ($drive -eq $null) {
            throw "Could not find 'Temporary Storage' drive"    
        } 
        #This returns C: not just the letter
        return $drive.DriveLetter
    }

    <#
        Tests to see if any pagefiles exist
    #>
    [bool] DoesPageFileExist() 
    {
        $pf = Get-WmiObject -Class win32_pagefilesetting
        if ($pf -eq $null) {
            return $false
        } else {
            return $true
        }
    }

    <#
        Tests to see if a pagefile exists on a given drive letter
    #>
    [bool] DoesPageFileExistOnDrive([string] $DriveLetter) 
    {
        Write-Debug ("DoesPageFileExistOnDrive - Start - '$DriveLetter'")
        try {
            $DriveLetter = $this.ValidateDriveLetter($DriveLetter)

            $TestResult = $false
            $pf = Get-WmiObject -Class win32_pagefilesetting
            if ($pf -ne $null) {
                #$pf can be an array so we need to iterate
                foreach ($item in $pf) {
                    if ($pf.Name.ToUpper().StartsWith($DriveLetter.ToUpper() ) ) {
                        #Found it
                        $TestResult = $true
                    }
                }
            }
            return $TestResult 
        }
        finally {
            Write-Debug ("DoesPageFileExistOnDrive - End")
        }

    }

    <# 
        Validates drive letter 
    #>
    [string] ValidateDriveLetter([string] $DriveLetter) 
    {
        Write-Debug ("ValidateDriveLetter - Start - '$DriveLetter'")
        try {
            #WMI always requires format X:
            If ($DriveLetter -match "^[d-z]$" ) {
                $DriveLetter = $DriveLetter.ToUpper() + ":"
            } elseif ($DriveLetter -match "^[d-z]:$" ) {
                $DriveLetter = $DriveLetter.ToUpper()
            } else {
                throw "DriveLetter must in the form [D-Z] or [D-Z]: i.e. 'T' or 'T:' "
            }
            return $DriveLetter  
        } finally {
            Write-Debug ("ValidateDriveLetter - End")
        }        
    }
}

