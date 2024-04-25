$scriptVer = "1.3"
$scriptName = "pvm_showControlsFix"
$scriptDescr = "insert ShowControls depending on json configuration"
Write-Output("SCRIPT DESCRIPTION: $scriptName v.$scriptVer")
Write-Output("SCRIPT DESCRIPTION: $scriptDescr")

<#
    .VERSION_1.3
    - added TLS 1.2 protocol so the SQLServer module can be downloaded
    
    .VERSION_1.2
    - fixed database configuration check, now it will properly detect that configuration in db is absent
    - new approach on reinstaling sqlserver module
    
    .VERSION_1.1
    - added import SQLserver module to update legacy systems, related with "-connectionstring" param not available
    
    .VERSION_1.0
    - initial release
#>

#### Variables
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$PShellVer = $PSVersionTable.PSVersion.Major
$indexControllsObject = New-Object System.Collections.Generic.List[PSCustomObject]
Import-Module "SQLServer" -Force -ErrorAction SilentlyContinue
$sqlModuleName = Get-Module -Name "SQLServer" -ErrorAction SilentlyContinue
$sqlModuleVersion = "22.2.0"
$getPSGalleryRepo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue

### install module
if (!$getPSGalleryRepo) {
    Write-Host "Registering PSGallery repo..."
    Register-PSRepository -Default
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

if ($sqlModuleName.Version -lt $sqlModuleVersion) {
    Uninstall-Module -Name SQLServer -AllVersions -Force -ErrorAction SilentlyContinue
    
    Write-Host "Installing $($sqlModuleName.Name) module..."    
    Install-Module -Name SQLServer -AllowClobber -Confirm:$false -Force
    Import-Module -Name SQLServer -ErrorAction SilentlyContinue
} else {
    Write-Host "Module in correct version, nothing to do - skipping installation"
}

### functions
function breezeGetPVMVersion {
    Write-Host "Checking PVM version"
    $pvmPath = "C:\Program Files (x86)\EZUniverse\360iQPVMController\360iQPVMController.exe"
    if (Test-Path $pvmPath) {
        $getversion = Get-Item $pvmPath -ErrorAction SilentlyContinue
        $script:itemVersion = ($getversion).VersionInfo | Select-Object -Property  InternalName, FileVersion
        Write-Host "    -> PVM ver: $($itemVersion.FileVersion)"     
    }
    else {
        Write-Host "    -> PVM not found"
    }
    return $itemVersion
}

function getPVMConfigurationDB {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    
    $queryGetPVMJSON = @"
    SELECT Configuration
    FROM [EZ360Controllers].[Config].[ServiceSections]
    WHERE ServiceID = 290
"@
    Write-Host "Getting PVM configuration from database"
    $PVMJSON = (Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query $queryGetPVMJSON -ErrorAction SilentlyContinue -MaxCharLength 100000 -QueryTimeout 120).Configuration
    if ($PVMJSON.Length -eq 0) {
        Write-Host "    -> configuration or table not found"
        exit 0
    }
    else {
        Write-Host "    -> configuration found"
        return $PVMJSON
    }
}

function parsePVMConfigurationDB {
    param (
        $PVMJSON
    )    
    $json = $PVMJSON | ConvertFrom-Json
    
    Write-Host "Parsing PVM configuration"
    for ($i = 0; $i -lt $json.Index.Count; $i++) {    
        $object = [PSCustomObject]@{
            Index           = $json.Index[$i]
            ShowControls    = $json.ShowControls[$i]
            ShowControlsBit =  
            if ($json.ShowControls[$i] -eq $false) {
                "0"
            }
            elseif ($json.ShowControls[$i] -eq $true) {
                "1"
            }    
        }
        $indexControllsObject.add($object)
    }
    Write-Host "    -> config parsed"
    return $indexControllsObject | Out-Null
}

function setPVMConfigurationDB {
    param (
        $indexControllsObject
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    foreach ($element in $indexControllsObject) {
        $querySetPVM = @"
            UPDATE [EZ360Video].[PVM].[LocationDisplays]
            SET [ShowControls] = $($element.ShowControlsBit)
            WHERE [Index] = $($element.Index)
"@
        Write-Host "Setting : [ShowControlls] = $($element.ShowControlsBit) WHERE [Index] = $($element.Index)"
        Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query $querySetPVM -ErrorAction SilentlyContinue -QueryTimeout '120'        
    }
}

function BreezeCheckShowControlls {
    param (
        $indexControllsObject
    )
    [bool]$bitcheckisOne = $false

    if ($indexControllsObject.ShowControlsBit -contains 1) {
        $bitcheckisOne = $true
    }
    else {
        $bitcheckisOne = $false
    }

    return $bitcheckisOne
}

function Invoke-Breezev2 {
    [Net.ServicePointManager]::SecurityProtocol = "Tls12"
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    
    function CheckDatabaseState {
        try {
            $connected = Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query "SELECT TOP 1 [LocationID],[DisplayAs] FROM [EZ360Objects].[Location].[Locations]"  -ErrorAction SilentlyContinue -QueryTimeout '120'
            $script:locationIDValue = $connected.LocationID
            $script:displayASValue = $connected.DisplayAs
        }
        catch {
            Write-Output("  -> connection unsuccesfull")
            Write-Error $_.Exception.Message
        }
    }
    
    ## === END OF FUNCTIONS SPACE ===
    function getIdToken {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $jsonBreeze = 
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
            -Body $jsonBreeze `
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
            scriptName      = "VRTC"
            scriptId        = "7"
            executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            result          = "$($itemVersion.FileVersion)"
            optionalresult1 = $getPVMjson | ConvertTo-Json
            errorCode       = "NULL"
            errorDetails    = "NULL"
            teamViewerId    = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\TeamViewer\).ClientID
        } | ConvertTo-Json
    
        #$body
    
        ### PROD API
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Invoke-RestMethod `
            -Method Post `
            -Uri "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/LongStoredScriptExecution" `
            -Body $body `
            -ContentType 'application/json' `
            -Headers @{
            "Authorization" = $idToken 
        }
        
    }
    CheckDatabaseState
    
    getIdToken
    sendRestData
}

### Script
function executeScript {
    param(
        [int]$PShellVer
    )
    if ($PShellVer -ge 5) {
        Write-Output("Powershell.v.5 found - executing script")
        if ($null -eq (Get-PSRepository -name ShellGet -ErrorAction SilentlyContinue)) {
            Register-PSRepository -Name 'ShellGet' -SourceLocation 'https://shellget.go360iq.com/nuget' -InstallationPolicy Trusted -ErrorAction Stop
        }
        else {
            Write-Output('Repository already added')
        }
		
        $PVMVersionCheck = breezeGetPVMVersion
        $PVMShowControllsCheck = BreezeCheckShowControlls $indexControllsObject
        $getPVMjson = getPVMConfigurationDB

        if (($PVMShowControllsCheck -eq $false) -and ((([version]$PVMVersionCheck.FileVersion).Major -eq 1) -and (([version]$PVMVersionCheck.FileVersion).Minor -eq 1))) {
            Write-Host "Invoking breeze"
            Invoke-Breezev2
        }
        else {
            Write-Host "Not invoking breeze"
        }

        parsePVMConfigurationDB $getPVMjson
        setPVMConfigurationDB $indexControllsObject

    }
    else {
        Write-Output("PowerShell.v.5 is not installed - skipping script ")
    }
}

executeScript $PShellVer