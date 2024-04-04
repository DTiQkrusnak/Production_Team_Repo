#! VDMS only
$scriptVer = "1.0"
$scriptName = "SetRebootOnSunday"
$scriptDescr = "will modify EZSChedulers RestartWeekly job to restart DVRs on Sunday"
# take configuration of restart job from EZ360 DB and modify it so EZscheduler 
Write-Output("SCRIPT DESCRIPTION: $scriptName v.$scriptVer")
Write-Output("SCRIPT DESCRIPTION: $scriptDescr")

# Variables
$PShellVer = $PSVersionTable.PSVersion.Major   
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$connectionStringEz360Video = 'Server=.\EZ360;Database=EZ360Video;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'

function GetRestartConfig {
    $query = @"
SELECT 
    [Configuration]
FROM 
    [EZ360Controllers].[Config].[ServiceSections]
WHERE 
    [Name] = 'RestartController'
"@

    Write-Host "Fetching configuration from DB : [EZ360Controllers].[Config].[ServiceSections]..."
    $returnQuery = (Invoke-Sqlcmd -ConnectionString $connectionStringEz360Video -Query $query -QueryTimeout '120').Configuration

    if ($returnQuery.length -eq "0") {
        Write-Host "Configuration empty... skipping script"
    } else {
        return $returnQuery
    }
}

function ModifyConfiguration {
    param (
        $returnQuery,
        $weekDay
    )
    
    Write-Host "Casting fetched configuration to XML format..."
    [xml]$returnQueryXML = $returnQuery

    Write-Host "Modyfing value - set to $($weekDay)"
    $changeArguments = $returnQueryXML.ActionParameters.ActionParameter | Where-Object { $_.Name -eq 'Arguments' }
    $changeArguments.value = "-noprofile -executionpolicy bypass -file CheckWeekDayAndRestart.ps1 $($weekDay)"

    Write-Host "Saving modification..."
    $modifyConfigurationResult = $returnQueryXML.OuterXml

    return $modifyConfigurationResult
}

function UpdateRestartConfig {
    param (
        $modifyConfigurationResult
    )
    
    [bool]$changeApplied = $false
    $queryUpdate = @"
UPDATE [EZ360Controllers].[Config].[ServiceSections]
SET [Configuration] = '$modifyConfigurationResult'
WHERE [Name] = 'RestartController'
"@

    Write-Host "Updating database..."
    try {
        Invoke-Sqlcmd -ConnectionString $connectionStringEz360Video -Query $queryUpdate -QueryTimeout '120'
        $changeApplied = $true
    }
    catch {
        $changeApplied = $false
    }
    
    return $changeApplied
}

function restartMandatoryServices {
    Write-Host "Stopping services..."
    Stop-Service -Name "EZSystemWatcher" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "EZScheduler" -Force -ErrorAction SilentlyContinue
    
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

        $getRestartConfigResult = GetRestartConfig
        $modifyConfigurationResult = ModifyConfiguration $getRestartConfigResult "Sunday"
        $UpdateRestartConfigResult = UpdateRestartConfig $modifyConfigurationResult

        if ($UpdateRestartConfigResult -eq $true) {
            #restartMandatoryServices
        } else {
            Write-Host "Configuration has not been applied"
        }

    }
    else {
        Write-Output("PowerShell.v.5 is not installed - skipping script")
    }
}

executeScript $PShellVer