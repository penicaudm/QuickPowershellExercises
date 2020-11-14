[cmdletbinding ()]
param(
    [parameter ()]
    [uri]$ElvuiAPIUri = "https://www.tukui.org/api.php?ui=elvui",

    [Parameter ()]
    [string]$FileVersionFile = "C:\Scripts\AddonManagement\ElvuiVersion.txt"
)
#requires -version 5.1
#region Functions
Function Intialize-ElvUIUpdater
{
    param(
        [string]$LocalVersionFile = "C:\Scripts\AddonManagement\ElvuiVersion.txt"
    )
    New-Item -Path $LocalVersionFile -Force
}
function Get-WoWRootFOlder
{
    $InstallPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Blizzard Entertainment\World of Warcraft" | Select-Object -ExpandProperty InstallPath
    $AddonsPath = Join-Path -Path $InstallPath -ChildPath "Interface\addons"
    If (Test-Path $AddonsPath)
    {
        return $AddonsPath
    }
    else
    {
        throw "unable to retrieve AddonsPath"
    }
}
function Send-WindowsToast
{
    param(
        [string]$Version, 
        [string]$Title = "ElvUI has been updated"
    )
    $Miliseconds=50000
    $Text="Version $Version"

    Add-Type -AssemblyName System.Windows.Forms 
    $global:balloon = New-Object System.Windows.Forms.NotifyIcon
    $path = (Get-Process -id $pid).Path
    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path) 
    $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info 
    $balloon.BalloonTipText = "$Text"
    $balloon.BalloonTipTitle = "$Title" 
    $balloon.Visible = $true 
    $balloon.ShowBalloonTip($Miliseconds)
}
function Update-ElvUI
{
    [cmdletbinding ()]
    param(
        [parameter (Position = 0)]
        [string] $ArchiveURI,

        # if the script is unable to locate the addons folder, you may pass it as an arg (unlikely to be needed)
        [parameter (Position = 1)]
        [validateScript(
            {
                Test-path $_
            }
        )]
        [string] $InterfaceFolder,

        [string] $TempFile = "$env:TEMP\Elvui.zip"
    )
    if (Test-Path $TempFile)
    {
        Remove-Item $TempFile
    }
    Invoke-RestMethod -Uri $ArchiveURI -OutFile $TempFile -Method Get -ErrorAction Stop

    Expand-Archive -Path $env:TEMP\Elvui.zip -DestinationPath $InterfaceFOlder -Force -

    Remove-Item $TempFile
}
#endregion
#region Static
$ElvuiData = Invoke-RestMethod -Uri $ElvuiAPIUri
$CurrentVersion = [float]$ElvuiData.Version
$InstalledVersion = [float](Get-Content -Path $FileVersionFile)
#endregion
# Run the script
if (-not (Test-Path $FileVersionFile) )
{
    Write-Verbose "Running for the first time, setting up files"
    Intialize-ElvUIUpdater

    Update-ElvUI -ArchiveURI $ElvuiData.url -InterfaceFolder (Get-WoWRootFOlder)

    Send-WindowsToast -Version $CurrentVersion

    Set-Content -Force -Path $FileVersionFile -Value $CurrentVersion
}
Write-Verbose "Available version is $currentversion"
Write-Verbose "Installed Version is $InstalledVersion"
# If the available version is higher than installed, update the addon and the file
if ($CurrentVersion -gt $InstalledVersion)
{
    Update-ElvUI -ArchiveURI $ElvuiData.url -InterfaceFolder (Get-WoWRootFOlder)

    Send-WindowsToast -Version $CurrentVersion
    
    Set-Content -Force -Path $FileVersionFile -Value $CurrentVersion
}