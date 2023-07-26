$scriptVer = "0.1"
$scriptName = "Get_Drive_E_SQL_Error"
$scriptDescr = "Get breeze from all locations that try to load SQL project path instead of production path for master"
Write-Output("SCRIPT DESCRIPTION: $scriptName v.$scriptVer")
Write-Output("SCRIPT DESCRIPTION: $scriptDescr")

function CheckDatabaseState {
  try {
    $script:connected = Invoke-Sqlcmd -ServerInstance '.\EZ360' -Username EZ360System -Password EZ360System -Query 'SELECT TOP 1 [LocationID],[DisplayAs] FROM [EZ360Objects].[Location].[Locations]'  -ErrorAction SilentlyContinue
    $script:locationIDValue = $connected.LocationID
    $script:displayASValue = $connected.DisplayAs
    Write-Output('  -> connection succesfull')
    $script:result = 'DBConnected'
  }
  catch {
    Write-Output('  -> connection unsuccesfull')
    $script:locationIDValue = Get-ItemPropertyValue -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller -name LocationID
    $script:displayASValue = $locationIDValue
    $script:result = 'DBnotConnected'
  }
}

function resultFunction {
    # Get all ERRORLOG Files paths
    $errorLogPath = "C:\Program` Files\Microsoft` SQL` Server\MSSQL12.EZ360\MSSQL\Log\*"
    $errorlogFiles = Get-ChildItem -Path $errorLogPath -Include 'ERRORLOG*'

    # Scan content of all of errors: 17204, 5120, 17207, 945 and paths
    # E:\sql12_main_t.obj.x86Release\sql\mkmastr\databases\mkmastr.proj\model.mdf
    # E:\sql12_main_t.obj.x86Release\sql\mkmastr\databases\mkmastr.proj\modellog.ldf
    foreach ($path in $errorlogFiles) {
        $foundLines = Select-String -LiteralPath $path.FullName -Pattern ('Error: 17204','Error: 5120', 'Error: 17207', 'Error: 945', 'E:\\sql12_main_t.obj.x86Release')
    }

    # Write result to $script:result
    if ($foundLines.Matches.Count -gt 0) {
        $script:result = "E Path Error found"
    } else {
        $script:result = "Clean"
    }
    $script:result
}
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
    scriptName      = "Get_Drive_E_SQL_Error"
    scriptId        = "Esql"
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


