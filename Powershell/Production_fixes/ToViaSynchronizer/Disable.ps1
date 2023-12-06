$scriptVer = "0.2"
$scriptName = "TO via Synchronizer - Disable"
$scriptDescr = "Disable text overlay synchronization via EZ360ControllerSynchronizer service"
Write-Host "SCRIPT DESCRIPTION: "$scriptName "v."$scriptVer -ForegroundColor Gray
Write-Host "SCRIPT DESCRIPTION: "$scriptDescr -ForegroundColor Gray

# Variables
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ErrorActionPreference = 'Continue'

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

function executeSqlV2 {
	$query = @'
	UPDATE EZ360Controllers.[Config].[ServiceProperties]
	SET Value = NULL
	WHERE ServiceID = 122
	AND KeyPath LIKE 'SyncTextOverlayExecutionInterval'
'@
	$connectionString = 'Server=.\EZ360;Database=EZ360Controllers;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'


	try {
		Invoke-Sqlcmd -ConnectionString $connectionString -Query $query -ErrorAction Stop
	} catch {
		Write-Output("[-]  $($_.Exception.Message)")
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