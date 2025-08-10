<#
.SYNOPSIS
    Automates the OSDCloud deployment process for Windows 11 23H2 with custom configuration and post-deployment actions.

.DESCRIPTION
    This script initializes logging functions, sets up OSDCloud deployment variables, determines the target Windows OS version and edition, and configures deployment options.
    It retrieves the appropriate driver pack for the detected hardware, starts the OSDCloud deployment, copies a custom unattend.xml to skip OOBE, and reboots the system upon completion.

.PARAMETER None
    This script does not accept parameters; all configuration is handled within the script.

.FUNCTIONS
    Write-DarkGrayDate      - Writes a timestamped message in dark gray.
    Write-DarkGrayHost      - Writes a message in dark gray.
    Write-DarkGrayLine      - Writes a separator line in dark gray.
    Write-SectionHeader     - Writes a section header with timestamp and cyan message.
    Write-SectionSuccess    - Writes a success message in green with timestamp.

.NOTES
    File Name      : StartOSDCloud.ps1
    Script Name    : Automate Azure OSDCloud Deployment
    Script Version : 08.09.25.3
    Author         : [Brian Brito]
    Purpose        : Streamline and automate OSDCloud deployments with custom settings and post-install actions.

#>

#region Initialization
###############################################################
# Set accurate system time from internet time server
###############################################################
$TimeServerUrl = "time.google.com"
try {
    $DateHeader = (Invoke-WebRequest -Uri $TimeServerUrl -UseBasicParsing).Headers.Date
    if ($DateHeader) {
        $ParsedDate = [DateTime]::ParseExact($DateHeader, 'ddd, dd MMM yyyy HH:mm:ss ''GMT''', $null)
        Set-Date -Date $ParsedDate
            Write-Host "System time synchronized from $TimeServerUrl $ParsedDate - GMT"
    } else {
            Write-Host "No Date header received from $TimeServerUrl. System time not updated."
    }
} catch {
        Write-Host "Failed to synchronize system time from $TimeServerUrl - GMT"
}
function Write-DarkGrayDate {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [System.String]
        $Message
    )
    if ($Message) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) $Message"
    }
    else {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    }
}
function Write-DarkGrayHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message
    )
    Write-Host -ForegroundColor DarkGray $Message
}
function Write-DarkGrayLine {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray '========================================================================='
}
function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message
    )
    Write-DarkGrayLine
    Write-DarkGrayDate
    Write-Host -ForegroundColor Cyan $Message
}
function Write-SectionSuccess {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [System.String]
        $Message = 'Success!'
    )
    Write-DarkGrayDate
    Write-Host -ForegroundColor Green $Message
}
#endregion
#region Define Windows OS and Version
$ScriptName = 'Automate Azure OSDCloud Deployment'
$ScriptVersion = '08.09.25.3'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"

#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11'
$OSReleaseID = '23H2'
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'
#endregion

#region Define Global OSDCloud Variables $Global:MyOSDCloud
#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$true
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$False
    WindowsDefenderUpdate = [bool]$False
    SetTimeZone = [bool]$False
    ClearDiskConfirm = [bool]$False
    ShutdownSetupComplete = [bool]$False
    SyncMSUpCatDriverUSB = [bool]$true
    CheckSHA1 = [bool]$true
}

$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

Write-SectionHeader "OSDCloud Variables"
Write-Output $Global:MyOSDCloud

Write-SectionHeader -Message "Starting OSDCloud"
Write-Host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"
#region Start OSDCloud
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage
#endregion

#region Copy unattend.xml to C:\Windows\Panther to skip OOBE
# Copy unattend.xml to Panther folder
$UnattendSource = "$PSScriptRoot\\unattend.xml"
$UnattendTarget = "C:\\Windows\\Panther\\unattend.xml"

if (Test-Path $UnattendSource) {
    Write-Host "Copying unattend.xml to $UnattendTarget" -ForegroundColor Cyan
    Copy-Item -Path $UnattendSource -Destination $UnattendTarget -Force
} else {
    Write-Host "unattend.xml not found at $UnattendSource" -ForegroundColor Yellow
}

Write-SectionHeader -Message "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot"
#endregion

#region End of script and reboot
# Reboot into Windows
Write-SectionHeader -Message "Rebooting into Windows in 10 seconds..."
Start-Sleep 10
# Initiate system reboot after deployment
Restart-Computer
#endregion
