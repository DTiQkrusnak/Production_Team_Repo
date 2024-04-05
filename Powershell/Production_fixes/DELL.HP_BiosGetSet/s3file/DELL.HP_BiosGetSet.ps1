function getControllerInfo {
    $script:controllerVendor = (Get-CimInstance Win32_ComputerSystemProduct).Vendor
    $script:controllerName = (Get-CimInstance Win32_ComputerSystemProduct).Name

    Write-Host "Your Vendor : " $script:controllerVendor
    Write-Host "Your System : " $script:controllerName

    try {
        Write-Host "Getting controller info"
        $script:connected = Invoke-Sqlcmd -ServerInstance '.\EZ360' -Username EZ360System -Password EZ360System -Query "SELECT TOP 1 [LocationID],[DisplayAs] FROM [EZ360Objects].[Location].[Locations]"  -ErrorAction SilentlyContinue
        $script:locationIDValue = $connected.LocationID
        $script:displayASValue = $connected.DisplayAs
        Write-Host "  -> connection succesfull"
    }
    catch {
        Write-Host "  -> connection unsuccesfull"
        $script:locationIDValue = Get-ItemPropertyValue -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller -name LocationID
        $script:displayASValue = $locationIDValue
    }
}

function goDELL {
    $downloadURL = "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/BIOS_configTool/DELL_Command_Configure.msi"
    $fileName = "Command_Configure.msi"
    $downloadPathFull = "C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads\Command_Configure.msi"

    function DownloadDellCommand {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try {
            Write-Host "Downloading : $($fileName)"
            Invoke-WebRequest -Uri $downloadURL -OutFile $downloadPathFull
            Write-Host "    -> download completed"
        }
        catch {
            $_.Exception.Message
        }
    }

    function InstallDellCommand {
        try {
            Write-Host "Installing : $($filename)"
            Start-Process "msiexec.exe" -ArgumentList "/i", $downloadPathFull, "ALLUSERS=1", "ADDLOCAL=DTK", "/qn" -Wait | Out-Null
            Write-Host "    -> installation completed"    
        }
        catch {
            $_.Exception.Message
        }
    }

    function getDELLBIOSinfoBefore {
        $output = $null
        $argumentsList = @(
            '"--SysName"',    
            '"--BiosVer"',
            '"--EmbSataRaid"',
            '"--AcPwrRcvry"', # <- turn ON
            '"--BlockSleep"',
            '"--WarningsAndErr"',
            '"--Virtualization"',
            '"--AutoOn"',
            '"--AutoOnHr"',
            '"--AutoOnMn"'
        )
        try {
            Write-Host "Getting BIOS configuration info - before configuration"
            #.Net code as Star-process cmdlet is somehow not letting stroring output to variable
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe"
            $pinfo.Arguments = $argumentsList
            $pinfo.RedirectStandardError = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.UseShellExecute = $false
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null
            $p.WaitForExit()
            $output = $p.StandardOutput.ReadToEnd()
            $output += $p.StandardError.ReadToEnd()
            Write-Host "    -> BIOS info gathered"
        }
        catch {
            $_.Exception.Message
        }

        #$output | ConvertTo-Json
        #$output.GetType()
        $script:result = $output | ConvertFrom-StringData
    
    }

    function getDELLBIOSinfoAfter {
        $output = $null
        $argumentsList = @(
            '"--SysName"',    
            '"--BiosVer"',
            '"--EmbSataRaid"',
            '"--AcPwrRcvry"', # <- turn ON
            '"--BlockSleep"',
            '"--WarningsAndErr"',
            '"--Virtualization"',
            '"--AutoOn"',
            '"--AutoOnHr"',
            '"--AutoOnMn"'
        )
        try {
            Write-Host "Getting BIOS configuration info - after configuration"
            #.Net code as Star-process cmdlet is somehow not letting stroring output to variable
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe"
            $pinfo.Arguments = $argumentsList
            $pinfo.RedirectStandardError = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.UseShellExecute = $false
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null
            $p.WaitForExit()
            $output = $p.StandardOutput.ReadToEnd()
            $output += $p.StandardError.ReadToEnd()
            Write-Host "    -> BIOS info gathered"
        }
        catch {
            $_.Exception.Message
        }

        $script:optionalResult1 = $output | ConvertFrom-StringData
        #$script:optionalResult1
    
    }

    function setDELLBIOS {
        $output = $null
        $argumentsList = @(
            '"--BlockSleep=Enable"',    
            '"--AcPwrRcvry=On"',
            '"--AutoOn=Everyday"',
            '"--AutoOnHr=5"'
            #'"--EmbSataRaid=Ahci" "--WarningsAndErr=ContWrnErr" "--Virtualization=Enable"'
        )
        try {
            Write-Host "Setting up DELL BIOS configuration"
            #.Net code as Start-process cmdlet is somehow not letting storing output to variable
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe"
            $pinfo.Arguments = $argumentsList
            $pinfo.RedirectStandardError = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.UseShellExecute = $false
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null
            $p.WaitForExit()
            $output = $p.StandardOutput.ReadToEnd()
            $output += $p.StandardError.ReadToEnd()
            Write-Host "    -> BIOS configured"
        }
        catch {
            $_.Exception.Message
        }
    }

    DownloadDellCommand
    InstallDellCommand
    getDELLBIOSinfoBefore
    setDELLBIOS
    getDELLBIOSinfoAfter
}

function goHP {    
    $downloadURL = "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/BIOS_configTool/HPBIOSConfigUtility.exe"
    $fileName = "HPBIOSConfigUtility.exe"
    $downloadPathFull = "C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads\HPBIOSConfigUtility.exe"

    function DownloadHPBIOSConfigUtility {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try {
            Write-Host "Downloading : $($fileName)"
            Invoke-WebRequest -Uri $downloadURL -OutFile $downloadPathFull
            Write-Host "    -> download completed"
        }
        catch {
            $_.Exception.Message
        }
    }

    function ExtractHPBIOSConfigUtility {
        try {
            Write-Host "Extracting : $($filename)"
            Start-Process $downloadPathFull -ArgumentList "/s", "/e" -Wait | Out-Null
            Write-Host "    -> extraction completed"    
        }
        catch {
            $_.Exception.Message
        }
    }

    function getHPBIOSinfoBefore {
        
        $argumentsList = @(
            '"Product Name"',    
            '"System BIOS Version"',
            '"After Power Loss"',
            '"Verbose Boot Messages"',
            '"Virtualization Technology (VTx)"'
        )   
        $jsonObject = @{}         

        foreach ($setting in $argumentsList) {
            Write-Host "Getting BIOS configuration info - $($setting)"
            #.Net code as Start-process cmdlet is somehow not letting storing output to variable
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "C:\SWSetup\SP143621\BiosConfigUtility64.exe"
            $pinfo.Arguments = "/getvalue:$setting"
            $pinfo.RedirectStandardError = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.UseShellExecute = $false
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null
            $p.WaitForExit()
            $output = $p.StandardOutput.ReadToEnd()
            $output += $p.StandardError.ReadToEnd()
            Write-Host "    -> BIOS info gathered"

            [xml]$variable = $output #| ConvertTo-Xml   
            #($variable.BIOSCONFIG.SETTING.VALUE).'#cdata-section'
    
            $jsonObject["$($setting)"] = ($variable.BIOSCONFIG.SETTING.VALUE).'#cdata-section'
        }

        $script:result = $jsonObject
    }

    function getHPBIOSinfoAfter {
        
        $argumentsList = @(
            '"Product Name"',    
            '"System BIOS Version"',
            '"After Power Loss"',
            '"Verbose Boot Messages"',
            '"Virtualization Technology (VTx)"'
        )   
        $jsonObject = @{}         

        foreach ($setting in $argumentsList) {
            Write-Host "Getting BIOS configuration info - $($setting)"
            #.Net code as Start-process cmdlet is somehow not letting storing output to variable
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "C:\SWSetup\SP143621\BiosConfigUtility64.exe"
            $pinfo.Arguments = "/getvalue:$setting"
            $pinfo.RedirectStandardError = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.UseShellExecute = $false
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null
            $p.WaitForExit()
            $output = $p.StandardOutput.ReadToEnd()
            $output += $p.StandardError.ReadToEnd()
            Write-Host "    -> BIOS info gathered"

            [xml]$variable = $output #| ConvertTo-Xml   
            #($variable.BIOSCONFIG.SETTING.VALUE).'#cdata-section'
    
            $jsonObject["$($setting)"] = ($variable.BIOSCONFIG.SETTING.VALUE).'#cdata-section'
        }

        $script:optionalResult1 = $jsonObject
    }

    function setHPBIOS {
        $argumentsList = @(
            '"After Power Loss","Power On"',
            '"Verbose Boot Messages","Disable"',
            '"Virtualization Technology (VTx)","Enable"'

        )        

        foreach ($setting in $argumentsList) {
            Write-Host "Setting up HP BIOS configuration : $($setting)"
            #.Net code as Start-process cmdlet is somehow not letting storing output to variable
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "C:\SWSetup\SP143621\BiosConfigUtility64.exe"
            $pinfo.Arguments = "/setvalue:$setting"
            $pinfo.RedirectStandardError = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.UseShellExecute = $false
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() | Out-Null
            $p.WaitForExit()
            $output = $p.StandardOutput.ReadToEnd()
            $output += $p.StandardError.ReadToEnd()
            Write-Host "    -> BIOS configured"
        }
    }

    DownloadHPBIOSConfigUtility
    ExtractHPBIOSConfigUtility
    getHPBIOSinfoBefore
    setHPBIOS
    getHPBIOSinfoAfter
}


function InvokeBreeze {
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
        $time = (Get-Date).ToUniversalTime()
        $timeUTC = $time.ToString("yyyy-MM-dd HH:mm:ss")
    
        $body = @{
            locationId      = $locationIDValue
            locationName    = $displayASValue
            timestamp       = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            timezoneId      = Get-Date -UFormat "%Z"
            scriptName      = "BIOSsetcheck"
            scriptId        = "2"
            executionDate   = $timeUTC
            result          = $result | ConvertTo-Json
            optionalResult1 = $optionalResult1 | ConvertTo-Json
            optionalResult2 = "NULL"
            optionalResult3 = "NULL"
            optionalResult4 = "NULL"
            errorCode       = "NULL"
            errorDetails    = "NULL"
        } | ConvertTo-Json
    
        #$body
    
        ### PROD API
        Invoke-RestMethod `
            -Method Post `
            -Uri "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/ScriptExecution" `
            -Body $body `
            -ContentType 'application/json' `
            -Headers @{
            "Authorization" = $idToken 
        }    
    }
    getIdToken
    sendRestData
}


getControllerInfo
if ($controllerVendor -like "*Dell*") {
    Write-Host "Dell found executing script"
    goDELL
}
elseif (($controllerVendor -like "*HP*") -or ($controllerVendor -like "*Hewlett-Packard*")) {
    goHP
}
else {
    $script:result = 'na'
    $script:optionalResult1 = $null
    Write-Host 'Seems this is no Dell\HP'
    exit 0
}
#InvokeBreeze