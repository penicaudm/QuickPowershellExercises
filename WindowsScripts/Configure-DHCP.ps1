<# PSSCRIPTInfo
# Deploy DHCP configuration to our network through Powershell
# DHCP range clients = 10.100.0.100 - 10.100.0.150
.NOTES
    Version         1.1
    Author          Marcellin Penicaud
    Creation Date   24/04/2020
    https://github.com/penicaudm?tab=repositories

# 51 clients lease available
# And create a reservation for one computer
#>
[cmdletbinding()]
param (
    [parameter ()]
    [System.Net.IPAddress] $StartRangeIP = "10.100.0.100",

    [parameter ()]
    [System.Net.IPAddress] $EndRangeIP = "10.100.0.150",

    [parameter ()]
    [System.Net.IPAddress] $Subnetmask = "255.255.255.0",

    [parameter ()]
    [string] $RangeName = "LAN Clients",

    [parameter ()]
    [System.TimeSpan] $LeaseDurationTimespan = "8:00", #format day.hrs:mins:secs

    [parameter ()]
    [System.Net.IPAddress] $DNSServerIP = "10.100.0.1",

    [parameter ()]
    [string] $ServerNameReservation = 'RDSH01',

    [parameter ()]
    [System.Net.IPAddress] $ReservedIPAddress = "10.100.0.101",

    [parameter ()]
    [string] $DHCPServerFQDN = 'dc01.mars.eni'
)
# Create a trap to handle errors
trap 
{
    "Error found"
    Write-error $error[0]
}
# Load required modules
if ($null -eq (get-module DhcpServer)) 
{
    Import-Module DHCPServer -ErrorAction Stop 4>$null
}
# Get Mac address to create the reservation
Try 
{
    Write-Verbose "getting $servernameReservation MAC Address..."
    $Macaddress = Invoke-Command -ComputerName $ServerNameReservation -ScriptBlock {
        Get-NetAdapter | Select-Object -ExpandProperty Macaddress 
    }
    if ($null -eq $Macaddress) 
    {
        Throw $_
    }
    else 
    {
        Write-Output "MAC address successfully retrieved!`n$Macaddress"
    }
}
Catch
{
    Write-Error "Could not get macaddress of $ServerNameReservation, make sure you can reach the computer!"
}
try 
{
    Add-DhcpServerInDC -DnsName $DHCPServerFQDN -IPAddress $DNSServerIP -ErrorAction Stop
}
catch 
{
    throw $_
}
# Create the scope
try 
{
    Write-Verbose "Creating the DHCP scope.."
    Add-DhcpServerv4Scope -StartRange $StartRangeIP `
        -EndRange $EndRangeIP `
        -Name $RangeName `
        -LeaseDuration $LeaseDurationTimespan `
        -SubnetMask $Subnetmask `
        -State Active `
        -type DHCP `
        -ComputerName $DHCPServerFQDN `
        -erroraction Stop
}
catch 
{
    Write-Error $_
}
Write-Verbose "Successful."

# Get the Newly created DHCP Scope
$Scope = Get-DhcpServerv4Scope -ComputerName dc01 | Where-Object Name -eq $RangeName 
try 
{
    Write-Verbose "Adding options to DHCP scope.."
    Set-DhcpServerv4OptionValue `
    -ComputerName $DHCPServerFQDN `
    -DnsServer $DNSServerIP `
    -ScopeID $Scope.ScopeID `
    -ErrorAction Stop
}
catch
{
    throw $_
}
Write-Verbose "Successful."
Write-Verbose "Adding scope reservation for $ServerNameReservation"
Add-DhcpServerv4Reservation `
    -Name $ServerNameReservation `
    -ScopeID $Scope.ScopeID `
    -ClientID $Macaddress `
    -IPAddress $ReservedIPAddress `
    -ComputerName $DHCPServerFQDN

Get-DHCPServerV4SCope -ScopeID $Scope.ScopeID -ComputerName $DHCPServerFQDN

Get-DHCPServerv4Reservation -ScopeID $Scope.ScopeID -Computer $DHCPServerFQDN