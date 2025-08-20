$scriptVer = '0.2'
$scriptName = 'TO via Synchronizer - Enable'
$scriptDescr = 'Enables text overlay synchronization via EZ360ControllerSynchronizer service'
Write-Host 'SCRIPT DESCRIPTION: '$scriptName 'v.'$scriptVer -ForegroundColor Gray
Write-Host 'SCRIPT DESCRIPTION: '$scriptDescr -ForegroundColor Gray

# Variables
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ErrorActionPreference = 'Continue'

function checkDBconnection {
	$DBServer = ".\\EZ360"
	$databasename = "EZ360Controllers"
	$Connection = New-Object system.data.sqlclient.sqlconnection
	$Connection.ConnectionString = "server=$DBServer;database=$databasename;uid=EZ360System;password=EZ360System;TrustServerCertificate=True"

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
	UPDATE [EZ360Controllers].[Config].[ServiceProperties]
	SET Value = 60
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
function forceStopSynchronizer {
	try {
		$synchronizerService = Get-Service -Name 'EZ360ControllerSynchronizer' -ErrorAction Stop
	} catch {
		$_.Exception.Message
	}

	$synchronizerService.Stop()
	$synchronizerService.WaitForStatus('Stopped', '00:00:30')
	if ($synchronizerService.Status -ne 'Stopped') {
		$synchronizerService.Close()
		taskkill /f /im EZ360ControllerSynchronizer.Service.exe
	}
}

$connectionBool = checkDBconnection

#if connection = true - download file
if ($connectionBool) {
	executeSqlV2
}
else {
	Write-Host "Connection couldnt be established."
	return
}

forceStopSynchronizer