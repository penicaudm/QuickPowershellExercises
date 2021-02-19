function Schedule-Reboot {
    # Schedule a reboot is annoying
    # Let's use PowerShell instead!
    [cmdletbinding (DefaultParameterSetName = 'DateParameter', SupportsShouldProcess)]
    param(
        # Standard use of the function : Store (get-date x/y/z) in a variable then call this function, easy enough
        [parameter (Mandatory, Position = 0, ParameterSetName = 'DateParameter')]
        [datetime]$DateTime,
        # If you target a computerName, make sure it can be resolved
        # Doesnt support an array of computernames for now, use this:
        # [collection] | Foreach-object { Schedule-Reboot -Computername $_ }
        [parameter (Position = 1)]
        [ValidateScript(
            {
                Resolve-DnsName $_ -QuickTimeout 2>$null
            }
        )]
        [string]$ComputerName,
        # Advanced: provide a value as an integer...
        [parameter (Position = 2, ParameterSetName = 'TimeHelper', Mandatory)]
        [int]$In,
        #... of minutes, hours, days and let PowerShell do the job for you.
        # Does not work if you need to reboot in x hours AND minutes, use the DateTime object in that case.
        [parameter (Position = 3, ParameterSetName = 'TimeHelper', Mandatory)]
        [ValidateSet("Seconds", "Minutes", "Hours", "Days")]
        [string]$Unit
    )
#region FUNCTIONS
    function Get-DynamicDateObjectFromInput {

        param(
            [parameter (Position = 0)]
            [string]$Value,
            [parameter (Position = 1)]
            [ValidateSet("Seconds", "Minutes", "Hours", "Days")]
            [string]$Method
        )
        $DateObject = Get-Date
        $Expression = "`$DateObject.Add$Method($Value)"
        $RebootTime = Invoke-Expression $Expression
        if ($RebootTime -is [DateTime]) {
            $verbosestring = "Scheduled DateTime is {0} {1} {2} at {3:d2}h{4:d2}" -f `
                $RebootTime.DayOfWeek, `
                $RebootTime.Day, `
                (Get-date $RebootTime -UFormat %B), `
                $RebootTime.Hour, `
                $RebootTime.Minute

            Write-Verbose $verbosestring -Verbose

            return $RebootTime
        }
        else {
            throw "error building DateTimeObject"
        }
    }
    function Schedule-RebootCommand {
        param(
            [datetime]$RebootTime
        )
        [datetime]$CurrentTime = get-date

        if ($RebootTime -gt $CurrentTime) {
            throw "Cannot reboot in the past!"
        }
        else {
            [int]$Delay = ($RebootTime - $CurrentTime).TotalSeconds
            [string]$scriptblock = "shutdown -r -t $Delay"
            if ($ComputerName) {
                $scriptblock += " /m $ComputerName"
            }
            Write-Verbose "Scheduling reboot in $($delay/60) minutes"
            Invoke-Expression $scriptblock
        }
    }
#endregion
    if ($pscmdlet.ParameterSetName -eq 'TimeHelper') {
        #build date object with the data provided
        $DateTime = Get-DynamicDateObjectFromInput -Value $in -Method $Unit
    }
    if ($pscmdlet.ShouldProcess(
            "$(if ($computername) {"$computername"} else { $env:COMPUTERNAME + ' (this computer)' })",
            "Reboot at $Datetime") 
    ) {
        Schedule-RebootCommand -RebootTime $DateTime
        Write-Warning "Scheduled reboot set! Use shutdown -a (/m computername) if you need to cancel!"
    }
}