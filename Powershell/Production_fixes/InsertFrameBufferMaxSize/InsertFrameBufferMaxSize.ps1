$scriptVer = "1.1"
$scriptName = "InsertFrameBufferMaxSize"
$scriptDescr = "will set frameBufferMaxSize to 800k for each camera"
Write-Output("SCRIPT DESCRIPTION: $scriptName v.$scriptVer")
Write-Output("SCRIPT DESCRIPTION: $scriptDescr")

<#
    .VERSION_1.1
    - stop EZVideoServer to reload configuration
    
    .VERSION_1.0
    - initial release
#>

# Variables
$PShellVer = $PSVersionTable.PSVersion.Major

function setBufferMaxSizeDB {
    $setbufforsQuery = @"
MERGE EZ360Objects.[Device].[DeviceChannelStreamProperties] [TARGET]
USING (SELECT DISTINCT ChannelStreamID, 'frameBufferMaxSize' KeyPath, '800000' [Value], GETUTCDATE() CreatedOn, 1 CreatedBy, null ModifiedOn, null ModifiedBy
FROM EZ360Objects.[Device].[DeviceChannelStreamProperties] 
WHERE ChannelStreamID in 
( SELECT ChannelStreamID  FROM EZ360Objects.[Device].[ChannelStreamTypes]  WHERE StreamTypeID in (0,1) )) [SOURCE]
ON [TARGET].ChannelStreamID = [SOURCE].ChannelStreamID AND [TARGET].KeyPath = [SOURCE].KeyPath
WHEN MATCHED
THEN UPDATE
SET [TARGET].[Value] = [SOURCE].[Value], [TARGET].[ModifiedOn] = GETUTCDATE(), [TARGET].[ModifiedBy] = 1
WHEN NOT MATCHED
THEN INSERT (ChannelStreamID, KeyPath, [Value], CreatedOn, CreatedBy, ModifiedOn, ModifiedBy)
VALUES([SOURCE].ChannelStreamID, [SOURCE].KeyPath, [SOURCE].[Value], [SOURCE].CreatedOn, [SOURCE].CreatedBy, [SOURCE].ModifiedOn, [SOURCE].ModifiedBy);
"@

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'    

    try {
        Write-Host "Inovoking sql command:"
        Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query $setbufforsQuery -ErrorAction SilentlyContinue -MaxCharLength '100000' -QueryTimeout '120'    
        Write-Host "    -> sqlcmd finished succesfully"
    }
    catch {
        $_.Exception.Message
    }    
}

function StopMandatoryService {
    param (
        $servicename
    )
    $serviceData = Get-Service -DisplayName $serviceName
    Write-Host "Stopping service : $($serviceData.DisplayName)"
    Stop-Service -InputObject $serviceData -ErrorAction SilentlyContinue
    Write-Host "    -> Stopped"
}

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

        setBufferMaxSizeDB
        StopMandatoryService 'EZSystemWatcher'
        StopMandatoryService 'EZVideoServer'
    }
    else {
        Write-Output("PowerShell.v.5 is not installed - skipping script ")
    }
}

executeScript $PShellVer
