[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

[string] $BreezeAddress = "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/ScriptExecution"
[string] $BreezeAddressLongStore = "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/LongStoredScriptExecution"

function Invoke-Breeze {
	<#
	.Description
	Invoke-Breeze | Sends gathered data as json to Breeze database.
	#>
	param (
		[Parameter(Mandatory)] [string] $locationId,
		[Parameter(Mandatory)] [string] $displayName,
		[Parameter(Mandatory)] [string] $ScriptName,
		[Parameter(Mandatory)] [string] $ScriptId,
		[Parameter(Mandatory)] [string] $Result,
		[string] $OptionalResult1 = $null,
		[string] $OptionalResult2 = $null,
		[string] $OptionalResult3 = $null,
		[string] $OptionalResult4 = $null,
		[string] $ErrorCode = $null,
		[string] $ErrorDetails = $null,
		[switch] $LongStore = $false
	)

	$body = @{
		locationId      = $locationId
		locationName    = $displayName
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
	
	if ($true -eq $LongStore) {
		Invoke-RestMethod -Method Post -Uri $BreezeAddressLongStore -Body $body -ContentType 'application/json'
	} else {
		Invoke-RestMethod -Method Post -Uri $BreezeAddress -Body $body -ContentType 'application/json'
	}
}

Export-ModuleMember -Variable 'BreezeAddress','BreezeAddressLongStore' -Function 'Invoke-Breeze'