[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

[Uri] $BreezeAddress = 'https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/ScriptExecution'
[Uri] $BreezeAddressLongStore = 'https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/LongStoredScriptExecution'

[uri] $IdentityServerAddress = 'https://cognito-idp.us-east-1.amazonaws.com'
[string] $PRODUCTION_CLIENT_ID = '7nig6316ca3lt7ofs96ci24hl'

[Uri] $BreezeAddressV2 = 'https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/ScriptExecution'
[Uri] $BreezeAddressLongStoreV2 = 'https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/LongStoredScriptExecution'



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

function Receive-BreezeV2Auth {
	param (
		[Parameter(Mandatory)] [string] $Username,
		[Parameter(Mandatory)] [string] $Password
	)
	
	$identityAuthPayload = @{
		"AuthFlow" = "USER_PASSWORD_AUTH"
		"ClientId" = "$PRODUCTION_CLIENT_ID"
		"AuthParameters" = @{
			"USERNAME" = "$Username"
			"PASSWORD" = "$Password"
		}
	} | ConvertTo-Json

	$authResponse = Invoke-RestMethod `
        -Method POST `
        -Uri $IdentityServerAddress `
        -Body $identityAuthPayload `
        -Headers @{
			"Content-Type" = "application/x-amz-json-1.1"
			"x-amz-target" = "AWSCognitoIdentityProviderService.InitiateAuth"
		}

	return $authResponse
}

function Invoke-BreezeV2 {
	param (
		[Parameter(Mandatory)] $authObject,
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

	$authToken = $authObject.AuthenticationResult.IdToken

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
		Invoke-RestMethod -Method Post -Uri $BreezeAddressLongStoreV2 -Headers @{"Authorization" = "$authToken"} -Body $body -ContentType 'application/json'
	} else {
		Invoke-RestMethod -Method Post -Uri $BreezeAddressV2 -Headers @{"Authorization" = "$authToken"} -Body $body -ContentType 'application/json'
	}
}

Export-ModuleMember -Variable 'BreezeAddress','BreezeAddressLongStore', 'BreezeAddressV2' ,'BreezeAddressLongStoreV2' -Function 'Invoke-Breeze', 'Receive-BreezeV2Auth', 'Invoke-BreezeV2'