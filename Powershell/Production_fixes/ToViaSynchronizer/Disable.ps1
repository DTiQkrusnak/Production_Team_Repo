$scriptVer = "0.2"
$scriptName = "TO via Synchronizer - Disable"
$scriptDescr = "Disable text overlay synchronization via EZ360ControllerSynchronizer service"
Write-Host "SCRIPT DESCRIPTION: "$scriptName "v."$scriptVer -ForegroundColor Gray
Write-Host "SCRIPT DESCRIPTION: "$scriptDescr -ForegroundColor Gray

# Variables
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ErrorActionPreference = 'Continue'

$folderName = "HOTFIXSyncTOOff"
$path = "C:\\ProgramData\\EZUniverse\\EZ360ControllerInstaller\\Downloads\\$folderName"
$output = "$path\\$foldername.sql"

$patchLinks = 'https://files-us-ps2.go360iq.com/_Files/Software/Scripts/TO_Legacy_migration/EZ360Syncronizer_TO_Execution_Disable.sql'

function checkDBconnection {
	$DBServer = ".\\EZ360"
	$databasename = "EZ360Controllers"
	$Connection = New-Object system.data.sqlclient.sqlconnection
	$Connection.ConnectionString = "server=$DBServer;database=$databasename;uid=EZ360System;password=EZ360System;"

	try {
		$Connection.Open()
		Write-Host "Connection to database successful." -ForegroundColor green -BackgroundColor black
		$connection.Close()
		return $true
	}
	catch {
		Write-Error($_.Exception.Message)
		return $false
	}
}

function downloadFile {
	try {
		#create dir
		if (-not (Test-Path $path)) {
			New-Item -Path $path -ItemType Directory | Out-Null
		}
		Invoke-WebRequest -Uri $patchLinks -OutFile $output -ErrorAction Stop
		Write-Host 'File downloaded : ' $patchLinks
	}
	catch {
		Write-Error($_.Exception.Message)
		return
	}
}

function executeSqlV2 {
	try {
		Invoke-Sqlcmd -ServerInstance '.\EZ360' -Username 'EZ360System' -Password 'EZ360System' -Query $output -ErrorAction Stop
		Write-Host 'Patch executed successfully' -ForegroundColor green -BackgroundColor black
	} catch {
		Write-Error($_.Exception.Message)
		return
	}
}


# General function to check if Synchronizer is running on target system
function CheckIfSynchronizerIsRunning {
	try {
		if ((Get-Service -Name "EZ360ControllerSynchronizer").Status -eq 'Running') {
			return $True
		}
		else {
			return $False
		}
	} catch {
		return $False
	}
}

function restartSynchronizer {
	# Multiple ways to restart Synchronizer after script execution
	Restart-Service -Name 'EZ360ControllerSynchronizer' -ErrorAction SilentlyContinue
	if (CheckIfSynchronizerIsRunning -eq $False) {
		Write-Output('Restarted Synchronizer')
		exit 0
	}
	Restart-Service -Name 'EZ360ControllerSynchronizer' -Force -ErrorAction SilentlyContinue
	if (CheckIfSynchronizerIsRunning -eq $False) {
		Write-Output('Restarted Synchronizer with force parameter')
		exit 0
	}
	try {
		$processId = (Get-Process -Name 'EZ360ControllerSynchronizer.Service' -ErrorAction SilentlyContinue).Id 
		Stop-Process -Id $processId -Force -ErrorAction Stop
		Start-Service -Name 'EZ360ControllerSynchronizer' -ErrorAction SilentlyContinue
	} catch {
		Write-Output('Cannot stop Synchronizer process')
	}
	if (CheckIfSynchronizerIsRunning -eq $False) {
		Write-Output('Restarted Synchronizer with process stopping and service start')
		exit 0
	}
	if (CheckIfSynchronizerIsRunning -eq $True) {
		try {
			$status = taskkill /f /im 'EZ360ControllerSynchronizer.Service'
			if ($status.Contains('SUCCESS')) {
				Write-Output('Killed Synchronizer, service was not reponding to restart signal')
				exit 0
			}
			else {
				throw 'Cannot kill Synchronizer service'
				exit -10
			}
		}
		catch {
			Write-Error($_.Exception.Message)
			exit -10
		}
	}
}

$connectionBool = checkDBconnection

#if connection = true - download file
if ($connectionBool) {
	downloadFile
	executeSqlV2
}
else {
	Write-Host "Connection couldnt be established."
	return
}

restartSynchronizer