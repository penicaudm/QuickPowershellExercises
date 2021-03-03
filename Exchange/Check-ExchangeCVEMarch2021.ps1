function Check-CVE_2021_26855
{
    [cmdletbinding ()]
    param(
        [string]$ComputerName
    )
    # this will take a long time
    Invoke-Command -ComputerName $ComputerName -ScriptBlock `
    {
        Import-Csv -Path (Get-ChildItem -Recurse -Path "$env:PROGRAMFILES\Microsoft\Exchange Server\V15\Logging\HttpProxy" -Filter '*.log').FullName `
        | Where-Object { $_.AuthenticatedUser -eq '' -and $_.AnchorMailbox -like 'ServerInfo~*/*' } `
        | Select-Object DateTime, AnchorMailbox
    }
}
function Check-CVE_2021_26858
{
    [cmdletbinding ()]
    param(
        [string]$ComputerName
    )
    Invoke-Command -ComputerName $ComputerName -ScriptBlock `
    {
        findstr /snip /c:"Download failed and temporary file" "%PROGRAMFILES%\Microsoft\Exchange Server\V15\Logging\OABGeneratorLog\*.log"
    }
}
function Check-CVE_2021_26857
{
[cmdletbinding ()]
    param(
        [string]$ComputerName
    )
    Get-EventLog -ComputerName $ComputerName -LogName Application -Source "MSExchange Unified Messaging" -EntryType Error `
    | Where-Object { $_.Message -like "*System.InvalidCastException*" } | 
    if ($error[0].FullyQualifiedErrorId -eq 'GetEventLogNoEntriesFound,Microsoft.PowerShell.Commands.GetEventLogCommand' )
    {
        Write-Output "not vulnerable to CVE_2021_26857"
    }
}

function Check-CVE_2021_27065
{
    [cmdletbinding ()]
    param(
        [string]$ComputerName
    )
    Invoke-Command -ComputerName $ComputerName -ScriptBlock `
    {
        Select-String -Path "$env:PROGRAMFILES\Microsoft\Exchange Server\V15\Logging\ECP\Server\*.log" -Pattern 'Set-.+VirtualDirectory'
    }
}
function Check-AllCVEs
{
    [cmdletbinding ()]
    param(
        [string]$ComputerName
    )
    Check-CVE_2021_26855 -ComputerName $ComputerName
    Check-CVE_2021_26858 -ComputerName $ComputerName
    Check-CVE_2021_26857 -ComputerName $ComputerName
    Check-CVE_2021_27065 -ComputerName $ComputerName
}