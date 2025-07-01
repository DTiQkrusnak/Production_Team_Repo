### v3
function Invoke-Breezev2 {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'

    function CheckDatabaseState {
        try {
            $connected = Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query "SELECT TOP 1 [LocationID],[DisplayAs] FROM [EZ360Objects].[Location].[Locations]" -ErrorAction SilentlyContinue
            if ($connected) {
                #Write-Host "Connected..."
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
    function Get-AllDrivesSmartData {
        # Initialize variable to hold all drive data
        $allSmartData = @()

        # Get list of drives detected by smartctl
        $drives = & smartctl --scan | ForEach-Object {
    ($_ -split " ")[0]
        }

        # Loop through each drive and collect SMART data
        foreach ($drive in $drives) {
            $smartData = & smartctl -a $drive --json
            $allSmartData += $smartData | ConvertFrom-Json
        }

        return $allSmartData
    }

    function Get-SystemDrive {
        param (
            $data
        )
        $isSystemDrive = Get-Disk | Where-Object { $_.IsSystem -eq $true }
        return $isSystemDrive
    }

    function Get-NotSystemDrive {
        param (
            $data
        )

        $isNotSystemDrive = Get-Disk | Where-Object { ($_.IsSystem -eq $false) }
        return $isNotSystemDrive
    }

    function Get-JsonData {
        param (
            $data,
            $drive
        )

        $drivedata = [PSCustomObject]@{
            issystem  = $isSystem
            diskName  = $name
            nvmeSMART = $nvmeSMART
            ataSmart  = $ataSMART
            scsiSMART = $scsiSMART
        }


        $selectedData = $data | Where-Object { $_.model_name -eq $($drive.FriendlyName) } #| ConvertTo-Json -depth 10

        if ($drive.BusType -eq 'NVMe') {
            #Write-Host "Disk is NVMe"
            $drivedata = [PSCustomObject]@{
                issystem  = $drive.IsSystem
                diskName  = ($selectedData | Select-Object 'model_name').model_name
                nvmeSMART = ($selectedData | Select-Object 'nvme_smart_health_information_log').nvme_smart_health_information_log
            }
            return $drivedata
        }
        elseif ($drive.BusType -eq 'SATA') {
            #Write-Host "Disk is ATA"
            $drivedata = [PSCustomObject]@{
                issystem = $drive.IsSystem
                diskName = ($selectedData | Select-Object 'model_name').model_name
                ataSmart = ($selectedData | Select-Object 'ata_smart_attributes').ata_smart_attributes.table 

            }
            return $drivedata
        }
        elseif ($drive.BusType -eq 'SCSI') {
            #Write-Host "Disk is SCSI"
            $drivedata = [PSCustomObject]@{
                issystem  = $drive.IsSystem
                diskName  = ($selectedData | Select-Object 'model_name').model_name
                scsiSMART = ($selectedData | Select-Object 'scsi_grown_defect_list').ata_smart_attributes.table
            }
            return $drivedata
        }
        else {
            #Write-Host "Bus type unknown"
        }
    }

    $isSystem = $null
    $isNotSystem = $null

    $allSmartData = Get-AllDrivesSmartData
    $isSystem = Get-SystemDrive $allSmartData
    $isNotSystem = Get-NotSystemDrive $allSmartData

    if ($isSystem.count -lt 1) {
        $Script:result = Get-JsonData $allSmartData $isSystem | ConvertTo-Json -Depth 10
        $Script:optionalresult = "NULL"
        $Script:optionalresult2 = "NULL"
        $Script:optionalresult3 = "NULL"
        $Script:optionalresult4 = "NULL"
    }
    elseif ($isSystem.count -eq 1) {

        $Script:result = Get-JsonData $allSmartData $isSystem | ConvertTo-Json -Depth 10
        if ($isNotSystem.count -lt 1) {
            $Script:optionalresult = "NULL"
            $Script:optionalresult2 = "NULL"
            $Script:optionalresult3 = "NULL"
            $Script:optionalresult4 = "NULL"
        }
        else {
            if ($null -ne $isNotSystem[0]) {
                $Script:optionalresult = Get-JsonData $allSmartData $isNotSystem[0] | ConvertTo-Json -Depth 10
            }
            else {
                $Script:optionalresult = "NULL"
            }

            if ($null -ne $isNotSystem[1]) {
                $Script:optionalresult2 = Get-JsonData $allSmartData $isNotSystem[1] | ConvertTo-Json -Depth 10
            }
            else {
                $Script:optionalresult2 = "NULL"
            }

            if ($null -ne $isNotSystem[2]) {
                $Script:optionalresult3 = Get-JsonData $allSmartData $isNotSystem[2] | ConvertTo-Json -Depth 10
            }
            else {
                $Script:optionalresult3 = "NULL"
            }

            if ($null -ne $isNotSystem[3]) {
                $Script:optionalresult4 = Get-JsonData $allSmartData $isNotSystem[3] | ConvertTo-Json -Depth 10
            }
            else {
                $Script:optionalresult4 = "NULL"
            }
        }
    }
    ## === END OF FUNCTIONS SPACE ===
    function getIdToken {    
        $json = 
        @{
            "AuthFlow"       = "USER_PASSWORD_AUTH"
            "AuthParameters" = @{
                "PASSWORD" = 'hRddjQK1VFTHM3jLTMkS!'
                "USERNAME" = "breeze-prod"
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
    
        $script:idToken = $var.AuthenticationResult.IdToken #expires every 3600s/1hr 
    }
    
    
    function sendRestData {
        $body = @{
            locationId      = $locationIDValue
            locationName    = $displayASValue
            timestamp       = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            timezoneId      = Get-Date -UFormat "%Z"
            scriptName      = "FetchSMART"
            scriptId        = "19"
            executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            result          = $Script:result #| ConvertTo-Json -Compress
            optionalResult1 = $Script:optionalresult #| ConvertTo-Json -Compress
            optionalResult2 = $Script:optionalresult2
            optionalResult3 = $Script:optionalresult3
            optionalResult4 = $Script:optionalresult4
            errorCode       = "NULL"
            errorDetails    = "NULL"
            controllerName  = $env:computername
        } | ConvertTo-Json
    
        #$body
    
        ### PROD API
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        Invoke-RestMethod `
            -Method Post `
            -Uri "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/ScriptExecution" `
            -Body $body `
            -ContentType 'application/json' `
            -Headers @{
            "Authorization" = $idToken
        }
        #>
    }
    
    CheckDatabaseState
    
    getIdToken
    sendRestData
}

Invoke-Breezev2