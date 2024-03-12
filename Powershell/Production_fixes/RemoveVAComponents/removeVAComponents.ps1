$scriptVer = "1.1"
$scriptName = "remove "
$scriptDescr = "Script will check if framegrabber software is installed and uninstall it."
Write-Host "SCRIPT DESCRIPTION: "$scriptName "v."$scriptVer -ForegroundColor Gray
Write-Host "SCRIPT DESCRIPTION: "$scriptDescr -ForegroundColor Gray
Write-Host

# Variables
$PShellVer = $PSVersionTable.PSVersion.Major
$pvmSettings = @(
    "1",
    "2"
)
# Functions
function removeApp {
    $appsToRemove = @(
        'OccupancyMonitorService',
        'EntryExitMonitor',
        'GStreamer',
        'VideoFrameGrabber'
    )

    $regKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
    )

    foreach ($app in $appsToRemove) {
        
        $appinfo = $regKeys |
        Get-ChildItem |
        Get-ItemProperty |
        Where-Object { 
            $_.DisplayName -like "*$app*" 
        }
        
        #$appInfo | Select-Object DisplayName, UninstallString
        if ($null -ne $appinfo) {
            $UninstallString = 
            if ( $appInfo.Uninstallstring -match 'MsiExec.exe' ) {
                "$( $appInfo.UninstallString -replace '/I', '/X ' ) /qn /norestart"
            }
            else {
                $appInfo.UninstallString + " /S"
            }       
            Write-Host " Uninstalling app: ""$($appinfo.DisplayName)"""
            Start-Process -FilePath cmd -ArgumentList '/c', $UninstallString -NoNewWindow -Wait
            #$App.UninstallString
        }
        else {
            Write-Host " App not found : ""$app"""
        }
    }
}

function setPVMonDB {
    $query = @"
SELECT [Configuration]
FROM [EZ360Controllers].[Config].[ServiceSections]
WHERE [Name] = 'PVMConfiguration'
AND ServiceID = '290'

UPDATE [EZ360Video].[PVM].[LocationDisplays] 
SET [PVMRunModeIndex] = 0 
"@
    ###DB stuff
    $ConnectionString = 'Server=.\EZ360;Database=EZ360Controllers;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    $var = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop -QueryTimeout 300 -MaxCharLength 250000

    $JSONDB = $var.Configuration | ConvertFrom-Json
    $item = 'PVMRunModeIndex'

    if ($JSONDB.$item -in $pvmSettings) {
        Write-Host " Modifing [EZ360Controllers].[Config].[ServiceSections]..."
        $JSONDB |  Where-Object { $_.PVMRunModeIndex = 0 }
        $jsonResult = $JSONDB | ConvertTo-Json
        
        $updateQuery = @"
        UPDATE [EZ360Controllers].[Config].[ServiceSections]
        SET [Configuration] = '$jsonResult'
        WHERE Name = 'PVMConfiguration'
        AND ServiceID = '290'
"@
        
        try {
            Write-Host "    -> database updated"
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $updatequery -ErrorAction Stop -QueryTimeout 300 -MaxCharLength 250000
        }
        catch {
            $_.Exception.Message
        }
    }
    else {
        Write-Host " Wont change - PVMRunModeIndex not in premise (SoS-Customers, SoS-Cars)"
    }     
}

function setPVMonFile {
    ### file  stuff
    $configPath = 'C:\Program Files (x86)\EZUniverse\360iQPVMController\configuration.json'
    $jsonFile = Get-Content $configPath | Out-String | ConvertFrom-Json
    $item = 'PVMRunModeIndex'
    if (Test-Path $configPath) {
        if ($jsonFile.$item -in $pvmSettings) {
            Write-Host " Modyfing file..."
            $jsonFile | Where-Object { $_.PVMRunModeIndex = 0 }
            #$jsonFile.$item = 0
            try {
                Write-Host "    -> saving file"
                $jsonFile | ConvertTo-Json -Depth 32 | Set-Content $configPath
            }
            catch {
                $_.Exception.Message
            }
        }
        else {
            Write-Host " Wont change - PVMRunModeIndex not in premise (SoS-Customers, SoS-Cars)"
        }
    }
}

function executeScript {
    param(
        [int]$PShellVer
    )
    if ($PShellVer -ge 5) {
        Write-Host "Powershell.v.5 found - executing script"

        Write-Host "Removing apps :"
        removeApp
        Write-Host "Setting up values in DB :"
        setPVMonDB
        Write-Host "Setting up values in configuration file :"
        setPVMonFile
    }
    else {
        Write-Host "PowerShell.v.5 is not installed - skipping script"
    }
}

executeScript $PShellVer