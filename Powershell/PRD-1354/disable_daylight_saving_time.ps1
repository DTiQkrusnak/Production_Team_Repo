[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

[uri] $IdentityServerAddress = 'https://cognito-idp.us-east-1.amazonaws.com'
[string] $PRODUCTION_CLIENT_ID = '7nig6316ca3lt7ofs96ci24hl'

[Uri] $BreezeAddressV2 = 'https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/ScriptExecution'
[Uri] $BreezeAddressLongStoreV2 = 'https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/LongStoredScriptExecution'


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
function Disable-DaylightSavingTime() {
    # get current timezone full name
    $current_timezone = tzutil.exe /g

    if ($current_timezone -match "_dstoff") {
        return 0
    }

    # set timezone with full name and disabled (dst) daylight saving time
    tzutil.exe /s "$($current_timezone)_dstoff"
}

function Get-CurrentDaylightSavineTimeSetting() {
    $daylight_saving_reg_path = 'Registry::HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'
    $daylight_saving_reg_property = 'DynamicDaylightTimeDisabled'
    $property_does_not_exist = -1

    if (Test-Path -Path $daylight_saving_reg_path -ErrorAction SilentlyContinue) {
        return Get-ItemPropertyValue -Path $daylight_saving_reg_path `
            -Name $daylight_saving_reg_property
    }


    return $property_does_not_exist
}

function Get-LocationIdentificationData() {
    $location_data_reg_path = 'Registry::HKLM\SOFTWARE\EZUniverse\EZ360ControllerInstaller'

    if ( ! (Test-Path -Path $location_data_reg_path -ErrorAction SilentlyContinue)) {
        return -1
    }

    $location_data = @{
        locationId = Get-ItemPropertyValue -Path $location_data_reg_path -Name LocationID
        displayName =  Get-ItemPropertyValue -Path $location_data_reg_path -Name LocationName
    }

    return $location_data
}

function Disable-AutomaticTimeSync() {
    $auto_time_sync_reg_path = 'Registry::HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'
    $auto_time_sync_reg_property = 'Type'

    if (Test-Path -Path $auto_time_sync_reg_path -ErrorAction SilentlyContinue) {
        Set-ItemProperty -Path $auto_time_sync_reg_path `
            -Name $auto_time_sync_reg_property `
            -Value 'NoSync' `
            -Force
    }
}


$location_data = Get-LocationIdentificationData
$daylight_result = Get-CurrentDaylightSavineTimeSetting
$breeze_auth = Receive-BreezeV2Auth -Username 'breeze-prod' `
    -Password 'hRddjQK1VFTHM3jLTMkS!'

if (($daylight_result -eq 0) -and ($location_data -ne -1)) {
    Invoke-BreezeV2 -authObject $breeze_auth `
        -locationId $location_data.locationId `
        -displayName $location_data.displayName `
        -ScriptName 'DaylightSaving' `
        -ScriptId '337' `
        -Result $daylight_result
}

Disable-DaylightSavingTime
Disable-AutomaticTimeSync
