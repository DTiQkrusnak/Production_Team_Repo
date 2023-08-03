$scriptVer = "0.1"
$scriptName = "Template"
$scriptDescr = "This is a template which will be used as a future base for scripts"
Write-Output("SCRIPT DESCRIPTION: $scriptName v.$scriptVer")
Write-Output("SCRIPT DESCRIPTION: $scriptDescr")

function CheckDatabaseState {
  try {
    $script:connected = Invoke-Sqlcmd -ServerInstance '.\EZ360' -Username EZ360System -Password EZ360System -Query "SELECT TOP 1 [LocationID],[DisplayAs] FROM [EZ360Objects].[Location].[Locations]"  -ErrorAction SilentlyContinue
    $script:locationIDValue = $connected.LocationID
    $script:displayASValue = $connected.DisplayAs
    Write-Output("  -> connection succesfull")
    $script:result = "DBConnected"
  }
  catch {
    Write-Output("  -> connection unsuccesfull")
    $script:locationIDValue = Get-ItemPropertyValue -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller -name LocationID
    $script:displayASValue = $locationIDValue
    $script:result = "DBnotConnected"
  }
}

#function resultFunction {}
#function optionalResultOneFunction {}
#function optionalResultTwoFunction {}
#function optionalResultThreeFunction {}
#function optionalResultTwoFunction {}

function sendRestData {
  $body = @{
    locationId      = $locationIDValue
    locationName    = $displayASValue
    timestamp       = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
    timezoneId      = Get-Date -UFormat "%Z"
    scriptName      = "name"
    scriptId        = "number"
    executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
    result          = $result
    optionalResult1 = "NULL"
    optionalResult2 = "NULL"
    errorCode       = "NULL"
    errorDetails    = "NULL"
  } | ConvertTo-Json
    
  #$body

  ### PROD API
  [Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"
  Invoke-RestMethod -Method Post -Uri https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/ScriptExecution -Body $body -ContentType 'application/json'
	
  ### DEV API
  #Invoke-RestMethod -Method Post -Uri https://j9xry23713.execute-api.us-east-1.amazonaws.com/dev/ScriptExecution -Body $body
}

Write-Output("Checking state of database :")
CheckDatabaseState
Write-Output("Executing functions :")
resultFunction
#optionalResultOneFunction
Write-Output("Sending data to endpoint :")
sendRestData


