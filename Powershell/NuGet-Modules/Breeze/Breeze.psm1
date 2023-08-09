[string] $BreezeAddress = "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/ScriptExecution"
[string] $BreezeAddressLongStore = "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/LongStoredScriptExecution"

function getLocationInformation {
    try {
        $script:connected = Invoke-Sqlcmd -ServerInstance '.\EZ360' -Username EZ360System -Password EZ360System -Query "SELECT TOP 1 [LocationID],[DisplayAs] FROM [EZ360Objects].[Location].[Locations]"  -ErrorAction SilentlyContinue
        $script:locationIDValue = $connected.LocationID
        $script:displayASValue = $connected.DisplayAs
        Write-Output("  -> db connection succesfull")
    }
    catch {
        Write-Output("  -> db connection unsuccesfull, getting information from registry")
        $script:locationIDValue = Get-ItemPropertyValue -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller -name LocationID
        $script:displayASValue = $locationIDValue
    }
}

function Invoke-Breeze {
    <#
    .Description
    Invoke-Breeze | Sends gathered data as json to Breeze database.
    #>
    param (
        [Parameter(Mandatory)] [string] $ScriptName,
        [Parameter(Mandatory)] [string] $ScriptId,
        [Parameter(Mandatory)] [string] $Result,
        [string] $OptionalResult1 = 'NULL',
        [string] $OptionalResult2 = 'NULL',
        [string] $OptionalResult3 = 'NULL',
        [string] $OptionalResult4 = 'NULL',
        [string] $ErrorCode       = 'NULL',
        [string] $ErrorDetails    = 'NULL',
        [switch] $LongStore = $false
    )

    getLocationInformation

    $body = @{
        locationId      = $locationIDValue
        locationName    = $displayASValue
        timestamp       = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
        timezoneId      = Get-Date -UFormat "%Z"
        scriptName      = $scriptName
        scriptId        = $scriptId
        executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
        result          = $result
        optionalResult1 = $optionalResult1
        optionalResult2 = $optionalResult2
        optionalResult3 = $optionalResult3
        optionalResult4 = $optionalResult4
        errorCode       = $errorCode
        errorDetails    = $errorDetails
    } | ConvertTo-Json

    [Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"
    if ($true -eq $LongStore) {
        Invoke-RestMethod -Method Post -Uri $BreezeAddressLongStore -Body $body -ContentType 'application/json'
    } else {
        Invoke-RestMethod -Method Post -Uri $BreezeAddress -Body $body -ContentType 'application/json'
    }
}

Export-ModuleMember -Variable 'BreezeAddress','BreezeAddressLongStore' -Function 'Invoke-Breeze'