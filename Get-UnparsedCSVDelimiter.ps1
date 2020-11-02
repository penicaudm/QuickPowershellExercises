function Get-UnparsedCSVDelimiter
{
    [cmdletbinding()]
    param(
        [parameter (Mandatory, Position = 0)]
        [string] $CSVPath,

        [parameter (Position = 1)]
        [switch] $ImportIfFound 
    )
    # Get the most recurrent char that is not a letter, number or double quotes.
    # This is means that a CSV using double quotes as delimiter will not work with this.
    [char]$tentativeOperator = ( (Get-content -First 1 -Path $CSVPath) -replace "[A-z0-9]*" -replace ('"','') ).ToCharArray() | `
        Group-Object -NoElement | `
        Sort-Object -Property Count | `
        Select-Object -First 1 -ExpandProperty Name
    # Perform checks on the returned object
    if ($tentativeOperator.ToString() -eq "")
    {
        Write-Error "Could not get an operator for this CSV!"
        Break 0
    }
    # Try to use the operator as delimiter
    if (Import-Csv -Path $CSVPath -Delimiter $tentativeOperator)
    {
        $found = $true
        Write-Output $tentativeOperator
    }
    #

    if ($ImportIfFound -and $found)
    {
        Import-Csv -Path $CSVPath -Delimiter $tentativeOperator
    }
}