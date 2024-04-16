function Invoke-Breezev2 {
    [Net.ServicePointManager]::SecurityProtocol = "Tls12"
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    $downloadPath = "C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads\smartctl.exe"
    $downloadUrl = "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/smartCtl_tool/smartctl.exe"
    $diskFragmentationObjects = New-Object System.Collections.Generic.List[PSCustomObject]
    
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
    function downloadSmartCtl {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
        try {
            if (!(Test-Path C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads)) {
                New-Item C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads -Force -ItemType Directory | Out-Null
            }

            Write-Host "Downloading : $downloadUrl"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
            Write-Host "    -> completed"
        }
        catch {
            $_.Exception.Message
        }
    }

    function GetSmartNvme {
        $getScan = C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads\smartctl.exe --scan -d nvme
        $getScanCharIndex = $getScan.IndexOf(" ") 
        $nvmeDrive = $getScan.Substring(0, $getScanCharIndex)

        $jsonData = C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads\smartctl.exe $nvmeDrive -a -j | ConvertFrom-Json
        #$jsonData.nvme_smart_health_information_log
    
        $datawritten = $jsonData.nvme_smart_health_information_log.data_units_written
        $datawrittenGB = ($datawritten * 500) / 1024 / 1024 / 1024
    
        $nvmeData = [PSCustomObject]@{
            Percentage_used    = $($jsonData.nvme_smart_health_information_log.percentage_used)
            Power_on_hours     = $($jsonData.nvme_smart_health_information_log.power_on_hours)
            Data_units_written = $($datawrittenGB)
        }

        return $nvmeData | ConvertTo-Json
    }

    function GetDefrag_Percent {
        $drives = Get-WmiObject -Class Win32_Volume | Where-Object { ($_.Name -notlike "\\?*") -and ($null -ne $_.FileSystem) }
        Write-Host "Getting FilePercentFragmentation... "
        
        foreach ($drive in $drives) {
            $driveLetter = $drive.DriveLetter.Replace(":", "")
            $driveData = Get-WmiObject -Class Win32_Volume | Where-Object { $_.Name -like "$($driveLetter)*" }
            $getVolumeData = Invoke-WmiMethod -InputObject $driveData -Name DefragAnalysis
            #Write-Host " $($drive.Name) -> $($getVolumeData.DefragAnalysis.FilePercentFragmentation)"
        
            $getDiskNumber = (Get-Partition -DriveLetter $($drive.driveletter -replace ":", "")).DiskNumber
            $getStorageObjects = Get-PhysicalDiskStorageNodeView | Where-Object { $_.disknumber -eq $getDiskNumber } 
            $getDiskType = Get-PhysicalDisk -InputObject $getStorageObjects.PhysicalDisk | Select-Object MediaType
            $objectDiskFrag = [PSCustomObject]@{
                DiskType      = $getDiskType.MediaType
                DriveLetter   = $($drive.Name)
                Fragmentation = $($getVolumeData.DefragAnalysis.FilePercentFragmentation)
            }
            $diskFragmentationObjects.Add($objectDiskFrag)
        }
        Write-Host "    -> completed"
        return $diskFragmentationObjects | ConvertTo-Json
    }

    function RemoveTool {
        if (Test-Path $downloadPath) {
            Write-Host "Removing : $($downloadPath)"
            Remove-Item -Path $downloadPath -Force
            Write-Host "    -> file removed"
        }    
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
            scriptName      = "getFragmentation"
            scriptId        = "8"
            executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            result          = GetSmartNvme
            optionalResult1 = GetDefrag_percent
            errorCode       = "NULL"
            errorDetails    = "NULL"
            teamViewerId    = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\TeamViewer\).ClientID
        } | ConvertTo-Json
    
        #$body
    
        ### PROD API
        [Net.ServicePointManager]::SecurityProtocol = "Tls12"
        
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
    
    DownloadSmartCtl
    
    getIdToken
    sendRestData

    RemoveTool
}

Invoke-Breezev2