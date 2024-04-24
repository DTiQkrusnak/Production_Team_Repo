<#
Exit code dictonary:
	exit 10 - sql EZ360 instance not present
	exit 666 - powershel v.5 is not installed
	...
#>

$scriptVer = "1.0"
$scriptName = "setTime_NTP_script"
$scriptDescr = "will set ntp on system, will disable current ntp config in ezscheduler"
Write-Output("SCRIPT DESCRIPTION: $scriptName v.$scriptVer")
Write-Output("SCRIPT DESCRIPTION: $scriptDescr")

# Variables
$PShellVer = $PSVersionTable.PSVersion.Major
$controllerModel = (Get-ItemProperty 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller' -Name 'ControllerModel').ControllerModel
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function EnableWindowsTime {
    $serviceInfoWT = Get-Service -DisplayName 'Windows Time'
    
    if ($serviceInfoWT.StartType -eq 'Disabled') {
        Write-Host "Enabling service : $($serviceInfoWT.DisplayName)"
        Set-Service -InputObject $serviceInfoWT -StartupType Manual
    }
}

function RemoveTimeSync_VDMS {
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    $modifyEnabledQuery = @"
    UPDATE [EZ360Controllers].[Config].[ServiceSectionProperties]
    SET Value = 'false'
    WHERE SectionPropertyID =
        (
            SELECT DISTINCT SSP.SectionPropertyID
            FROM [EZ360Controllers].[Config].[ServiceSections] AS SS
            INNER JOIN [EZ360Controllers].[Config].[ServiceSectionProperties] AS SSP
                ON SSP.ServiceSectionID = SS.ServiceSectionID
            WHERE Name = 'FixAndUpdateLocalTime' 
            AND KeyPath = 'enabled'
        )
"@

    try {
        Write-Host "    -> modifing database"
        #[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query $modifyEnabledQuery -ErrorAction SilentlyContinue -QueryTimeout 30 #-WhatIf
        Write-Host "    -> completed"
    }
    catch {
        $_.Exception.Message
    }
}

function RemoveTimeSync_Legacy {
    $itemPath = 'C:\onstartup\scripts\everyrun\20_check_time_server.ps1'
    try {
        if (Test-Path -Path $itemPath) {
            Write-Host "    -> removing script: $itempath"
            Remove-Item $itemPath -Confirm:$false -Force
            Write-Host "    -> script removed"
        }
        else {
            Write-Host "File not found, nothing to do"
        }
    }
    catch {
        $_.Exception.Message
    }
}
function setNTPservers {
    # set time peers
    Write-Host "Setting up peers"
    w32tm /config /manualpeerlist:"time.windows.com time.nist.gov time.aws.com pool.ntp.org"

    Write-Host "Setting up interval for time.aws.com and pool.ntp.org"
    $valueMinPoll = '12'
    Set-ItemProperty 'registry::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\W32Time\Config' -Name 'MinPollInterval' -Value $valueMinPoll -Force
    # update  w32tm configuration
    w32tm /config /update

    Write-Host "Restarting Time service"
    Restart-Service -DisplayName 'Windows Time'
}

function executeScript {
    param(
        [int]$PShellVer
    )
    if ($PShellVer -ge 5) {
        Write-Output("Powershell.v.5 found - executing script")
        if ($controllerModel -like "Legacy*") {
            Write-Host "Legacy system found - executing legacy procedure"
            RemoveTimeSync_Legacy
        }
        elseif ($controllerModel -like "VDMS*") {
            Write-Host "VDMS system found - executing VDMS procedure..."
            RemoveTimeSync_VDMS
        }
        else {
            Write-Host "Controller Type not supported"
            exit 0
        }

        EnableWindowsTime
        setNTPservers

        Stop-Service -Name 'EZSystemWatcher' -Force -ErrorAction SilentlyContinue
        Stop-Service -Name 'EZScheduler' -ErrorAction SilentlyContinue


    }
    else {
        Write-Output("PowerShell.v.5 is not installed - skipping script ")
    }
}

executeScript $PShellVer