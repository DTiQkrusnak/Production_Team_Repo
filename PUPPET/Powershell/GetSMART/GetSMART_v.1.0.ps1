
<#
    .VERSION_1.0
    - new algorithm of getting smart data from drives
#>

function Invoke-Breezev2 {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'

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
    $smartCtlPath = 'C:\Program Files\smartmontools\bin\smartctl.exe'

    $getNvmDrives = @(& $smartCtlPath --scan -d nvme | ForEach-Object { ($_ -split " ")[0] })
    $getAtaDrives = @(& $smartCtlPath --scan -d ata  | ForEach-Object { ($_ -split " ")[0] })
    
    $getCtlDrives = $getNvmDrives + $getAtaDrives

    $getSystemDisk = Get-Disk | Where-Object { $_.IsSystem -eq $true }
    $driveSmart = [PSCustomObject]@{
        issystem   = $isSystem
        diskName   = $name
        driveSmart = $driveSmart
    }

    function Get-SystemDriveData {
        param (
            $getCtlDrives,
            $selectedDisk
        )
    
        foreach ($drive in $getCtlDrives) {
            $smartData += @(& $smartCtlPath -a $drive --json | ConvertFrom-Json)
        }

        foreach ($device in $smartData) {

            if (
                ($selectedDisk | Where-Object { ($_.SerialNumber -like "*$($device.serial_number)*") }) -or
                ($selectedDisk | Where-Object { ($_.AdapterSerialNumber -like "*$($device.serial_number)*") })
            ) {
                $driveSmart = [PSCustomObject]@{
                    issystem   = $selectedDisk.issystem
                    diskName   = $selectedDisk.FriendlyName
                    driveSmart = $device
                }
                return $driveSmart
            }
        } 
    }

    function Get-ParseSmartData {
        param (
            $smartData
        )

        $drivedata = [PSCustomObject]@{
            issystem = $isSystem
            diskName = $name
            smart    = $smart
            info     = $info
            #nvmeSMART = $nvmeSMART
            #ataSmart  = $ataSMART
            #scsiSMART = $scsiSMART
        }

        if ($smartData.driveSmart.device.type -eq 'NVMe') {
            #Write-Host "Disk is NVMe"
            $drivedata = [PSCustomObject]@{
                issystem = $smartData.IsSystem
                diskName = $smartData.diskName
                smart    = ($smartData.driveSmart | Select-Object 'nvme_smart_health_information_log').nvme_smart_health_information_log
                info     = "NULL"
            }
            return $drivedata
        }
        elseif ($smartData.driveSmart.device.type -eq 'SATA') {
            #Write-Host "Disk is ATA"
            $drivedata = [PSCustomObject]@{
                issystem = $drive.IsSystem
                diskName = ($selectedData | Select-Object 'model_name').model_name
                smart    = ($selectedData | Select-Object 'ata_smart_attributes').ata_smart_attributes.table 
                info     = "NULL"
            }
            return $drivedata
        }
        elseif ($smartData.driveSmart.device.type -eq 'SCSI') {
            #Write-Host "Disk is SCSI"
            $drivedata = [PSCustomObject]@{
                issystem = $drive.IsSystem
                diskName = ($selectedData | Select-Object 'model_name').model_name
                smart    = ($selectedData | Select-Object 'scsi_grown_defect_list').ata_smart_attributes.table
                info     = "NULL"
            }
            return $drivedata
        }
        else {
            Write-Host "Different cattegory"
            $drivedata = [PSCustomObject]@{
                issystem = "NULL"
                diskName = "NULL"
                smart    = "NULL"
                info     = "Unsupported RAID or USB volume"
            }
            return $drivedata
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
    
        #$var.AuthenticationResult
        $script:idToken = $var.AuthenticationResult.IdToken #expires every 3600s/1hr 
    }
    
    
    function sendRestData {
        $body = @{
            locationId      = $locationIDValue
            locationName    = $displayASValue
            timestamp       = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            timezoneId      = Get-Date -UFormat "%Z"
            scriptName      = "SMARTDATA"
            scriptId        = "21"
            executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            result          = $smartBreeze.issystem
            optionalResult1 = "$($smartBreeze.diskName)"
            optionalResult2 = $smartBreeze.smart | ConvertTo-Json
            optionalResult3 = $smartBreeze.info
            errorCode       = "NULL"
            errorDetails    = "NULL"
            #teamViewerId    = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\TeamViewer\).ClientID
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
    
    $returnedSmart = Get-SystemDriveData -getCtlDrives $getCtlDrives -selectedDisk $getSystemDisk
    $smartBreeze = Get-ParseSmartData -smartData $returnedSmart

    getIdToken
    sendRestData
}

Invoke-Breezev2