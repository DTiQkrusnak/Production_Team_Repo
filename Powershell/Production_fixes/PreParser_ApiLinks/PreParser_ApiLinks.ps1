function Invoke-Breezev2 {

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    $faultyLinksObjects = New-Object System.Collections.Generic.List[PSCustomObject]
    $preparserConfigPath = 'C:\Program Files (x86)\EZUniverse\EZ360Controller\EZ360PreParser*\configuration.json'
    
    class PreParserPropertyInformation {
        [string] $propertyName
        [string] $propertyLink
    
        preparserPropertyInformation([string]$propertyName, [string]$propertyLink ) {
            $this.propertyName = $propertyName
            $this.propertyLink = $propertyLink
        }
    }
    
    $propertiesVar =
    [PreParserPropertyInformation]::new(
        "TransactionWebservice",
        "https://data-us-ps1.go360iq.com/PS1/EZ360DataInterface/Api/Transactions"
    ),    
    [PreParserPropertyInformation]::new(
        "ActionWebservice",
        "https://data-us-ps1.go360iq.com/PS1/EZ360DataInterface/Api/Actions"
    ),    
    [PreParserPropertyInformation]::new(
        "CashOperationWebservice",
        "https://data-us-ps1.go360iq.com/PS1/EZ360DataInterface/Api/CashOperations"
    ),
    [PreParserPropertyInformation]::new(
        "TimeClockWebservice",
        "https://data-us-ps1.go360iq.com/PS1/EZ360DataInterface/Api/TimeClocks"
    ),
    [PreParserPropertyInformation]::new(
        "DataWebservice",
        "https://data-us-ps1.go360iq.com/PS1/EZ360DataInterface/Api/Data"
    ),
    [PreParserPropertyInformation]::new(
        "ReportWebservice",
        "https://data-us-ps1.go360iq.com/PS1/EZ360DataInterface/Api/Reports"
    ),
    [PreParserPropertyInformation]::new(
        "VersionWebService",
        "https://data-us-ps1.go360iq.com/PS1/EZ360DataInterface/Api/LocationSoftware/SetServiceVersions"
    )
    

    function CheckDatabaseState {
        try {
            $connected = Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query "SELECT TOP 1 [LocationID],[DisplayAs] FROM [EZ360Objects].[Location].[Locations]" -ErrorAction SilentlyContinue
            if ($connected) {
                $script:locationIDValue = $connected.LocationID
                $script:displayASValue = $connected.DisplayAs
            }
        }
        catch {
            Write-Output("  -> connection unsuccesfull")
            #Write-Host $_.Exception.Message
            exit 0
        }
    }
    
    ## === FUNCTION SPACE START ===
    function LoadPreparserConfiguration {
        param (
            [string]$preparserConfigPath
        )
        
        $getpreParserConfigurationJson = Get-Content -Path $preparserConfigPath -Raw | ConvertFrom-Json
        return $getPreParserConfigurationJson
    }

    function CheckPreParserProperties {
        param (
            $preparserConfigurationJson,
            $propertiesVar
        )
        
        foreach ($property in $propertiesVar) {
            #Write-Host "Validating property: $($property.propertyName)"
            
            if ((Compare-Object -ReferenceObject $preparserConfigurationJson.($property.propertyName) -DifferenceObject $property.propertyLink -IncludeEqual).SideIndicator -ne "==") {
                Write-Host "Bad link found for property: $($property.propertyName)"
                Write-Host "    -> $($preparserConfigurationJson.($property.propertyName))"
                
                $objectBadLinks = [PSCustomObject]@{
                    PropertyName = $property.propertyName
                    FaultyLink   = $preparserConfigurationJson.($property.propertyName)
                }
                $faultyLinksObjects.Add($objectBadLinks)
            }         
        } 
        #$faultyLinksObjectsJson = $faultyLinksObjects | ConvertTo-Json

        return $faultyLinksObjects
    }
    
    function FixFaultyLink {
        param (
            $preparserConfigurationJson,
            $propertiesVar,
            $faultyLinks
        )
    
        
        if ($null -eq $faultyLinks) {
            Write-Host "Nothing to do - links are proper"
            exit 0
        }
        else {
            foreach ($faultyProperty in $faultyLinks) {
                Write-Host "Fixing : $($faultyProperty.propertyName)"
                $preparserConfigurationJson.($faultyProperty.propertyName) = ($propertiesVar | Where-Object { $_.propertyName -eq $($faultyProperty.PropertyName)}).propertyLink
                Write-Host "    -> Link replaced"
            }
            Write-Host "Saving File : $preparserConfigPath"
            $preparserConfigurationJson| ConvertTo-Json -Depth 32 | Set-Content $preparserConfigPath
        }
    }

    function RestartMandatoryService {
        param (
            $servicename
        )
        $watcherCheck = Get-Service -DisplayName "EZSystemWatcher" -ErrorAction SilentlyContinue

        if ($watcherCheck.Status -eq 'Running') {
            Stop-Service -InputObject $watcherCheck -ErrorAction SilentlyContinue
        }
        
        $serviceData = Get-Service -DisplayName $serviceName
        Write-Host "Restarting service : $($serviceData.DisplayName)"
        Restart-Service -InputObject $serviceData -ErrorAction SilentlyContinue
    }
    
    ## === END OF FUNCTIONS SPACE ===
    function getIdToken {    
        $json = 
        @{
            "AuthFlow"       = "USER_PASSWORD_AUTH"
            "AuthParameters" = @{
                "PASSWORD" = 'yIw5(:hk;.YrzcDXQWD['
                "USERNAME" = "dbochon"
            }
            "ClientId"       = '7nig6316ca3lt7ofs96ci24hl'
        } | ConvertTo-Json
    
        $var = Invoke-RestMethod `
            -Method POST `
            -Uri "https://cognito-idp.us-east-1.amazonaws.com/" `
            -Body $json `
            -Headers @{
            "Content-Type" = "application/x-amz-json-1.1"
            "x-amz-target" = "AWSCognitoIdentityProviderService.InitiateAuth" 
        }
    
        #$var.AuthenticationResult
        $script:idToken = $var.AuthenticationResult.IdToken #expires every 3600s/1hr 
    }
    
    
    function sendRestData {
        $body = @{
            locationId      = $locationIDValue
            locationName    = $displayASValue
            timestamp       = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            timezoneId      = Get-Date -UFormat "%Z"
            scriptName      = "apiLinksPreParser"
            scriptId        = "3"
            executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            result          = $faultyLinks | ConvertTo-Json
            optionalResult1 = "NULL"
            errorCode       = "NULL"
            errorDetails    = "NULL"
            teamViewerId    = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\TeamViewer\).ClientID
            controllerName  = $env:computername

        } | ConvertTo-Json
    
        #$body
    
        ### PROD API
        [Net.ServicePointManager]::SecurityProtocol = "Tls12"

        Invoke-RestMethod `
            -Method Post `
            -Uri "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/LongStoredScriptExecution" `
            -Body $body `
            -ContentType 'application/json' `
            -Headers @{
            "Authorization" = $idToken
        }
        #>
    }
    CheckDatabaseState
    
    $preparserConfigurationJson = LoadPreparserConfiguration $preparserConfigPath 
    $faultyLinks = CheckPreParserProperties $preparserConfigurationJson $propertiesVar

    if ($null -eq $faultyLinks) {
        Write-Host "Nothing to do"
    } else {
        #FixFaultyLink $preparserConfigurationJson $propertiesVar $faultyLinks
        #RestartMandatoryService 'EZ360PreParser'
        getIdToken
        sendRestData
    }
    
}

Invoke-Breezev2