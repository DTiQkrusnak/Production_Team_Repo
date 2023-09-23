[Net.ServicePointManager]::SecurityProtocol = 'TLS12', 'SSL3'
function blockWin11Upgrade () {
	<#
	.SYNOPSIS
	Blocks Windows 11 upgrade prompts and version on 21H2
	#>
	Write-Output('[*] Block Win11 Upgrade')

	$regPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

	try {
		$system = (Get-WMIObject win32_operatingsystem).Caption

		if ($system -like "*Windows*10*") {
			Write-Output('[*] blockWin11Upgrade')
			if (!(Test-path $regPath)) {
				New-Item -Path $regPath -Force
			}

			New-ItemProperty -Path $regPath -Name "ProductVersion" -value "Windows 10" -PropertyType String -Force | Out-Null
			New-ItemProperty -Path $regPath -Name "TargetReleaseVersion" -value 1 -PropertyType DWord -Force | Out-Null
			New-ItemProperty -Path $regpath -Name "TargetReleaseVersionInfo" -value "21H2" -PropertyType String -Force | Out-Null
			Write-Output('[+] block Windows 11 completed')
		}
		else {
			Write-Output("[-] function is executing fix only on Windows 10, your Windows : $system")
		}
	} catch {
		Write-Error("[-] $($_.Exception.Message)")
	}
}

function DisableWinUpdateIfAteraNotExists () {
	<#
	.SYNOPSIS
	Disables Windows Update service if Atera service is not present in the system
	#>

	Write-Output("[*] Disable Windows Update if Atera does not exist")

	$ateraRegistryKey = $null
	$winUpdateService = $null
	$ateraService = $null

	# Check if atera is already installed with 15 second timeout
	for ($i = 0; $i -lt 30; $i++) {
		# Get registry settings for Atera Agent
		$ateraRegistryKey = Get-Item 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent' -ErrorAction SilentlyContinue

		# Get Atera service if exists
		$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue

		if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService)) {
			Write-Output("[+] Atera detected - nothing to do.")
			Write-Output("[+] Registery keys check : $ateraRegistryKey")
			return
		}
		Start-Sleep -Milliseconds 500
	}
	try {
		Write-Output("[!] ALERT : ATERA NOT FOUND!! DISABLING WINDOWSUPDATE SERVICE!!!")
		$winUpdateService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue

		Write-Output("[*] Stopping windows update service")
		$winUpdateService | Stop-Service -Force -ErrorAction SilentlyContinue
		Write-Output("[+] $($winUpdateService.DisplayName) service stopped")

		Write-Output("[*] Disabling windows update service")
		$winUpdateService | Set-Service -StartupType "Disabled"
		Write-Output("[+] $($winUpdateService.DisplayName) service disabled")



		<#
		CHECK if 'BITS' and 'DoSvc' has to be disabled here as well
		#>
	} catch {
		Write-Error("[-] $($_.Exception.Message)")
	}
}

function AteraInstall () {
	<#
	.SYNOPSIS
	Installs Atera service when VDMS-XXXXXXX hostname matches
	#>
	Write-Output("[*] Atera Install")

	$foldersHashTable = @{
		'4011' = '7'; '4001' = '8'; '4002' = '9'; '4003' = '10';'4004' = '11';'4005' = '12';'4006' = '13';'4007' = '14';
		'4008' = '15';'4009' = '16';'4010' = '17';'4012' = '18';'4013' = '19';'4014' = '20';'4015' = '21';'4016' = '22';
		'4017' = '23';'4018' = '24';'4019' = '25';'4020' = '26';'4021' = '27';'4022' = '28';'4023' = '29';'4024' = '30';
		'4025' = '31';'4026' = '32';'4027' = '33';'4028' = '34';'4029' = '35';'4030' = '36';'4031' = '37';'4032' = '38';
		'4033' = '39';'4034' = '40';'4035' = '41';'4036' = '42';'4037' = '43';'4038' = '44';'4039' = '45';'4040' = '46';
		'4041' = '47';'4042' = '48';'4043' = '49';'4044' = '50';'4045' = '51';'4080' = '52';
		}

	try {
		$ateraRegistryKey = $null
		$ateraService = $null

		# Check if atera is already installed with 15 second timeout
		for ($i = 0; $i -lt 30; $i++) {
			# Get registry settings for Atera Agent
			$ateraRegistryKey = Get-Item 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent' -ErrorAction SilentlyContinue

			# Get Atera service if exists
			$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue

			if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService)) {
				Write-Output("[+] Atera detected - nothing to do.")
				Write-Output("[+] Registery keys check : $ateraRegistryKey")
				return
			}
			Start-Sleep -Milliseconds 500
		}

		# Get ControllerId from database EZ360Objects
		$getControllerIdQuery = @'
		SELECT TOP 1 *
		FROM [EZ360Objects].[Location].[Controllers]
		WHERE [Status] = 'Y'
'@
		$controllerId = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerIdQuery -QueryTimeout 30 -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System').ControllerId
		[System.Data.SqlClient.SqlConnection]::ClearAllPools()

		# Get Controller Model from database EZ360Objects
		$getControllerModelQuery = @'
		SELECT CM.Name
		FROM Location.Controllers AS LC
		LEFT JOIN Controller.Models AS CM
		ON CM.ModelID = LC.ModelID
		WHERE LC.Status = 'Y'
'@
		$controllerModel = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerModelQuery -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System' -QueryTimeout 30).name

		# Set .NET TLS for Atera
		$dotnetTlsVersionPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
		$getKey = Get-ItemProperty -Path $dotnetTlsVersionPath -Name SystemDefaultTlsVersions -ErrorAction SilentlyContinue
		if ($null -ne $getKey) {
			Set-ItemProperty -Path $dotnetTlsVersionPath -Name SystemDefaultTlsVersions -Value "00000001" -Force | Out-Null
		}
		else {
			New-ItemProperty -Path $dotnetTlsVersionPath -Name SystemDefaultTlsVersions -PropertyType "DWord" -Value "00000001" -Force | Out-Null
		}

		$systemDefPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
		$getKey = Get-ItemProperty -Path $systemDefPath -Name SystemDef -ErrorAction SilentlyContinue
		if ($null -ne $getKey) {
			Set-ItemProperty -Path $systemDefPath -Name SystemDef -Value $null | Out-Null
		}
		else {
			New-ItemProperty -Path $systemDefPath -Name SystemDef | Out-Null
		}

		# Check if folder for downloads exists
		Set-Location C:
		$ateraDownloadPath = 'C:\ProgramData\DTiQ\TaskScheduler\ateraInstall'

		if ((Test-Path $ateraDownloadPath) -eq $false) {
			Write-Output("[*] Creating directory : $($ateraDownloadPath)")
			New-Item $ateraDownloadPath -ItemType Directory -Force | Out-Null
			Write-Output('[+] Directory created')
		} else {
			Write-Output('[+] Download path exists.')
		}

		# Check if hostname is set to VDMS standard
		if ($env:COMPUTERNAME -eq "VDMS-$controllerId") {
			Set-Location -Path $ateraDownloadPath
			# Get CCS hub ID
			$ccsHubAddress = (Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller' -ErrorAction SilentlyContinue).ControllerInterfaceURL
			if ($null -ne $ccsHubAddress) {
				$ccsHubId = ([regex]::Matches($ccsHubAddress, '(\d\d\d\d)')).Value
			}


			if ($controllerModel -eq 'VDMS Summit') {
				# Download files
				Invoke-WebRequest -Uri "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/ateraInstall/ateraSummit.msi" -OutFile "$ateraDownloadPath\ateraSummit.msi" -TimeoutSec 30
				$ateraSha256Hash = '8C180892A856A89A7EB43B76F1AB51690B5FC1B4839E09A6D26E8DFB53C8DDF7'
				if ((Get-FileHash -Algorithm SHA256 -LiteralPath "$ateraDownloadPath\atera.exe").Hash -ne $ateraSha256Hash) {
					Remove-Item -LiteralPath "$ateraDownloadPath\ateraSummit.msi"
					Write-Error('[-] ateraSummit.msi hash not matching')
					return
				}
				Write-Output('[+] Atera files downloaded')
				#Start Atera installer with site ID 12 "VDMS-Summit" site
				msiexec /i setup.msi /qn  IntegratorLogin=Atera.Update@dtiq.com CompanyId=12 AccountId=0013z00002tEY2hAAG
			} else {
				# Download files
				Invoke-WebRequest -Uri "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/ateraInstall/atera.msi" -OutFile "$ateraDownloadPath\atera.msi" -TimeoutSec 30
				$ateraSha256Hash = '1CB36D8A6F037813FE22237AD027EEED7951F1510774D773CCCC6D5A6AA8EF62'
				if ((Get-FileHash -Algorithm SHA256 -LiteralPath "$ateraDownloadPath\atera.msi").Hash -ne $ateraSha256Hash) {
					Remove-Item -LiteralPath "$ateraDownloadPath\atera.msi"
					Write-Error('[-] atera.msi hash not matching')
					return
				}
				Write-Output("[+] Atera files downloaded")
				# Start Atera installer with site ID 22 "PRODUCTION" site
				msiexec /i atera.msi /qn  IntegratorLogin=Atera.Update@dtiq.com CompanyId=22 AccountId=0013z00002tEY2hAAG FolderId=$($foldersHashTable[$ccsHubId])
			}

			# Post check if atera is installed with 15 second timeout
			# kill leftover process if found
			for ($i = 0; $i -lt 30; $i++) {
				# Get registry settings for Atera Agent
				$ateraRegistryKey = Get-Item 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent' -ErrorAction SilentlyContinue

				# Get Atera service if exists
				$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue

				if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService)) {
					Write-Output('[+] Atera installed')
					Get-Process -Name 'atera'  -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Continue
					Get-Process -Name 'msiexec' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Continue
					return
				}
				Start-Sleep -Milliseconds 500
			}
		} elseif ($null -ne $script:isRenameSuccessful) {
			if ($script:isRenameSuccessful.NewComputerName -eq "VDMS-$controllerId") {
				Write-Output('[*] Restart required to set hostname before installing Atera')
			} else {
				Write-Error('[-] Cannot verify if SetHostname succeded')
			}
		} else {
			Write-Error('[-] Hostname not set to VDMS standard')
		}
	} catch {
		Write-Error("[-] $($_.Exception.Message)")
	}
}

function SetHostname () {
	<#
	.SYNOPSIS
	Sets hostname to VDMS-XXXXXXX, reboot required to take effect
	#>
	try {
		Write-Output('[*] SetHostname')

		# Get ControllerId from database EZ360Objects
		$getControllerIdQuery = @'
		SELECT TOP 1 *
		FROM [EZ360Objects].[Location].[Controllers]
		WHERE [Status] = 'Y'
'@
		$controllerId = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerIdQuery -QueryTimeout 30 -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System').ControllerId
		[System.Data.SqlClient.SqlConnection]::ClearAllPools()

		# Check if hostname matches VDMS standard
		if ($env:COMPUTERNAME -eq "VDMS-$controllerId") {
			Write-Output('[+] Hostname already changed')
			return
		} else {
			$script:isRenameSuccessful = Rename-Computer -NewName "VDMS-$controllerID" -PassThru
			Write-Output('[+] Set hostname completed')
		}
	} catch {
		Write-Error("[-] $($_.Exception.Message)")
	}
}

function DisableOBEE () {
	<#
	.SYNOPSIS
	Adds registry keys to block Windows consumer experience
	like 'Hi' and 'Get even more out of Windows' screens
	#>
	try {
		$logonAnimationPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
		if (!(Test-path $logonAnimationPath)) {
			New-Item -Path $logonAnimationPath -Force
		}
		New-ItemProperty -Path $logonAnimationPath -Name 'EnableFirstLogonAnimation' -Value 0 -PropertyType DWord -Force | Out-Null
	} catch {
		Write-Error("[-] $($_.Exception.Message)")
	}

	try {
		$privacyExperiencePath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE'
		if (!(Test-path $privacyExperiencePath)) {
			New-Item -Path $privacyExperiencePath -Force
		}
		New-ItemProperty -Path $privacyExperiencePath -Name 'DisablePrivacyExperience' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		Write-Error("[-] $($_.Exception.Message)")
	}

	try {
		$consumerFeaturesPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE'
		if (!(Test-path $consumerFeaturesPath)) {
			New-Item -Path $consumerFeaturesPath -Force
		}
		New-ItemProperty -Path $consumerFeaturesPath -Name 'DisableWindowsConsumerFeatures' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		Write-Error("[-] $($_.Exception.Message)")
	}
}

function pingAllow () {
	Write-Output('[*] Ping Allow')
	try {
		Set-NetFirewallRule -DisplayName 'Network Discovery (NB-Datagram-Out)' -Action Allow -ErrorAction Stop
		Set-NetFirewallRule -DisplayName 'Network Discovery (NB-Name-Out)' -Action Allow -ErrorAction Stop
		Set-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -Profile Any -ErrorAction Stop
	} catch {
		$firewallRulesAction = @(
			"Network Discovery (NB-Datagram-Out)",
			"Network Discovery (NB-Name-Out)"
		)

		$firewallRulesProfile = @(
			"File and Printer Sharing (Echo Request - ICMPv4-In)"
		)

		netsh advfirewall firewall set rule name=$($firewallRulesAction[0]) new action=Deny
		netsh advfirewall firewall set rule name=$($firewallRulesAction[1]) new action=Allow
		netsh advfirewall firewall set rule name=$($firewallRulesProfile[0]) new profile=Any
	}
	Write-Output('[+] Ping Allow completed')
}

function removeLegacyComponents () {
	Write-Output('[*] Remove Legacy Components')
	#Check migration status
	$isMigratedVS = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\EZUniverse Inc.\EZVideoServer'-ErrorAction SilentlyContinue).ConfigurationManager
	$isMigratedEH = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\EZUniverse Inc.\EZEventHandler' -ErrorAction SilentlyContinue).ConfigurationManager

	Write-Output('[*] Checking migration status')
	if (($isMigratedVS -eq 1) -and ($isMigratedEH -eq 1)) {}
	else {
		Write-Output('[-] Site is not migrated skipping removal of Legacy components.')
		return
	}

	# Initialize function if migrated
	$xmlRuntimeToRemove = @(
		'EZController', #Includes EZController.SystemSetup and .Registration
		'EZConnect', #Includes EZConnect.SystemVerification
		'360iQ.v.3.3',
		'Subway Controller',
		'SubwaySurveilance'
	)

	$appsToRemove = @(
		'EZController.Registration',
		'StretchDiagnosticTool',
		'EZConnect.SystemVerification',
		'EZVideoPlayer',
		'ECM',
		'EZController.SystemSetup'
	)

	$servicesToRemove = @(
		'EZUpdateCenter',
		'EZCSNetwork',
		'EZSQLReplicator',
		'EZMessageLog',
		'SubwayUpdateCenter'
	)

	# EZSensors Server is installed per User (Support) and cannot be uninstalled from SYSTEM context
	# We have decided to just disable service
	
	$removeMSI = @(
		'EZSensors Server'
	)

	$allApplications = $xmlRuntimeToRemove + $appsToRemove + $servicesToRemove
	# Get All app packages that have Quiet Uninstall string
	$RegKeys = @(
		'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
		'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
	)
	
	# Get regular programs
	$appObjects = $RegKeys |
	Get-ChildItem |
	Get-ItemProperty

	Write-Output('[*] Stopping SystemWatcher, SQLReplicator, EZSensor Server and UpdateCenters')
	Stop-Service -Force -ErrorAction SilentlyContinue -Name (
		'EZSQLReplicator','EZSystemWatcher', 'EZSensorsServer','SubwayUpdateCenter','EZUpdateCenter')

	if (Get-Service -Name 'EZSensors Server' -ErrorAction SilentlyContinue) {
		Set-Service -Name 'EZSensors Server' -StartupType Disabled
		Write-Output('[+] Disabled EZSensors Server')
	}
	


	# Get MSI programs
	foreach ($name in $removeMSI) {
		Write-Output("[*] Uninstalling $($name)")
		
		$appObjects | 
		Where-Object { $_.DisplayName -match $name} | 
		Foreach-Object { 
			$path = $_.UninstallString -split ' '
			try {
				Start-Process $path[0] -ArgumentList ($path[1], '/qn') -Wait -NoNewWindow -ErrorAction Stop
				Write-Output("[+] Uninstalled $($_.DisplayName)")
			} catch {
				Write-Error("[-] $($name) Timed out")
				Get-Process -Name 'msiexec.exe' -ErrorAction SilentlyContinue | Stop-Process -Force
			}
		}
	}

	foreach ($name in $allApplications) {
		$appObjects | 
		Where-Object { $_.DisplayName -match $name} | 
		Foreach-Object { 
			$path = $_.QuietUninstallString -split '\"'
			# ARGUMENTS EXPLANATION
			# $path[1] # Get path from QuietUninstallString
			# $($path[2..($path.Length -2)])) # Get arguments from QuietUninstallString

			# Skip already removed applications
			if (-not(Test-Path -LiteralPath $path[1])) {
				Write-Output("[+] $($_.DisplayName) already removed")
				Continue
			}
			# Skip applications with missing .dat file
			$datFilePath = $path[1]
            $datFilePath = $datFilePath.Replace('.exe', '.dat')
			if (-not(Test-Path -LiteralPath $datFilePath)) {
				Write-Error("[-] Missing file $($datFilePath), skipping")
				Continue
			}
			Write-Output("[*] Uninstalling $($_.DisplayName)")

			try {
				$proc = Start-Process $path[1] -ArgumentList $($path[2..($path.Length -2)]) -PassThru -NoNewWindow
				$proc | Wait-Process -Timeout 10 -ErrorAction Stop
				Write-Output("[+] Uninstalled $($_.DisplayName)")
			} catch {
				Write-Error("[-] $($path[1]) Timed out on $($proc)")
				$proc | Stop-Process -Force
				Get-Process -Name '*.tmp' -ErrorAction SilentlyContinue | Stop-Process -Force
			}
		}
	}

	if (Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue) {
		try {
			Stop-Service -Name 'MSSQL$SQLEXPRESS' -Force
			Set-Service -Name 'MSSQL$SQLEXPRESS' -StartupType Disabled
			Write-Output('[+] Disabled legacy SQLSERVER')
		} catch {
			Write-Error("[-] $($_.Exception.Message)")
		}
	}
	Write-Output('[+] Finished removing Legacy components')
}

function installDotNet () {

}

blockWin11Upgrade
SetHostname
AteraInstall
DisableWinUpdateIfAteraNotExists
DisableOBEE
pingAllow
removeLegacyComponents
installDotNet

# TODO
# validateWindowsAccounts
# setTreeACLS
