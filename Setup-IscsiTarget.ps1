<#PSScriptInfo
Install and configure an iSCSI target server remotely

This short script assumes a single disk is NOT initiated so we can capture it through get-disk.
.NOTES
    Version             1.2
    Author              Marcellin Penicaud (github.com/penicaudm)
    Creation Date       04/06/2020
.OUTPUTS
System.String
The script returns the IQN and the iSCSI targets

/!\ DO NOT USE IN PRODUCTION /!\
#>
[cmdletbinding ()]
param (
    [parameter (Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $targetName = "iscsitarget01",
    [parameter ()]
    [switch] $InitializeRawDisk,
    [parameter (Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $targetIQN
)
# Since this script is used in a test virtual machine, clean up old things
Get-IscsiServerTarget | Remove-IscsiServerTarget
Get-IscsiVirtualDisk | Remove-IscsiVirtualDisk

# Enable the Windows Feature FS-iSCSITarget-Server if its not already available
Write-Verbose "Checking for FS-iSCSITarget-Server feature presence..."
if ((Get-WindowsFeature FS-iSCSITarget-Server).InstallState -ne 'Installed')
{
    Write-Verbose "Feature FS-iSCSITarget-Server is not installed. Beginning installation..."
    Try 
    {
        Install-WindowsFeature 'FS-iSCSITarget-Server' -ErrorAction Stop
    }
    catch
    {
        throw $_
        break 0
    }
}
# Importing ISCSI Powershell Module
if ($null -eq (get-module 'iSCSI'))
{
    Import-module iSCSI -ErrorAction 4>$null 
}
else 
{
    Write-verbose "Windows Feature FS-iSCSITarget-Server is installed."
}

if ($InitializeRawDisk)
{
    # Setup our target disk
    $RawDiskCount = (get-Disk | Where-Object PartitionStyle -eq 'RAW' | Measure-Object).Count
    if ($RawDiskCount -ne 1)
    {
        "Cannot setup disks, there $( if ($RawDiskCount -eq 0) {"are no raw disks"} else {"are too many raw disks"})"
        throw $_
    }
    else 
    {
        # Setup the disk in a single chain of piped cmdlets which is pretty cool
        Get-Disk | Where-Object PartitionStyle -eq 'RAW' | `
        Initialize-Disk -PartitionStyle GPT -PassThru | `
        New-Partition -AssignDriveLetter -UseMaximumSize | `
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "iscsitarget" -Confirm:$false -OutVariable 'NewDrive'
    }
    [Char]$NewDriveLetter = $NewDrive.DriveLetter
    $VolumeInfo = Get-Volume -DriveLetter $NewDriveLetter
    Write-Verbose "New drive has been setup! Drive letter is : $NewDriveLetter, Size is $((($volumeInfo.SizeRemaining /1gb).ToString())[0..4] -join '') Gb"
}
try 
{
    Write-Verbose "Setting up iSCSI target"
    New-IscsiServerTarget -targetName $targetName -erroraction Stop | Out-Null
}
Catch
{
    throw $_
}
# Create an iscsi disk taking half of the disk available space
try 
{
    $ISCSIDisk = New-iscsiVirtualDisk -UseFixed -Path "$NewDriveLetter`:\iscsidisk.vhdx" -Size ($volumeInfo.SizeRemaining / 2)
}
catch 
{
    throw $_
}
try 
{
    Add-IscsiVirtualDisktargetMapping -TargetName $targetName -Path $ISCSIDisk.Path
}
catch 
{
    throw $_
}
# We are using 2 NICs here so we'll take a shortcut setting up initiators
try 
{
    Set-IscsiServerTarget -TargetName $targetName -PassThru -InitiatorIds IQN:$targetIQN -Enable $true
}
catch 
{
    throw $_
}

Write-output "Target IQN is: $(Get-ISCSIServerTarget -TargetName $targetName | Select-Object -ExpandProperty TargetIQN)"

Restart-Service Wintarget
