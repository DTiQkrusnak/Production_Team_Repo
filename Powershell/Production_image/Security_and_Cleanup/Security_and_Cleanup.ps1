[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function checkPowershellDefaultRepository() {
	<#
	.SYNOPSIS
	.NOTES
	#>
	# TODO:

	Write-Output('[*] Check powershell repository')
	if (!(Get-PSRepository | Where-Object { $_.Name -eq 'PSGallery'})) {
		Register-PSRepository -Default
	}
}
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
		Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
	}
}

function DisableWinUpdateIfAteraNotExists () {
	<#
	.SYNOPSIS
	Disables Windows Update service if Atera service is not present in the system
	#>
	# TODO:

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
		$ateraProcess = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue
		if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService) -and ($null -ne $ateraProcess)) {
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
		Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
	}
}

function AteraInstall () {
	<#
	.SYNOPSIS
	Installs Atera service when VDMS-XXXXXXX hostname matches
	#>
	# TODO:
	Write-Output("[*] Atera Install")
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	$foldersHashTable = @{
		'1011' = '7'; '1001' = '8'; '1002' = '9'; '1003' = '10';'1004' = '11';'1005' = '12';'1006' = '13';'1007' = '14';
		'1008' = '15';'1009' = '16';'1010' = '17';'1012' = '18';'1013' = '19';'1014' = '20';'1015' = '21';'1016' = '22';
		'1017' = '23';'1018' = '24';'1019' = '25';'1020' = '26';'1021' = '27';'1022' = '28';'1023' = '29';'1024' = '30';
		'1025' = '31';'1026' = '32';'1027' = '33';'1028' = '34';'1029' = '35';'1030' = '36';'1031' = '37';'1032' = '38';
		'1033' = '39';'1034' = '40';'1035' = '41';'1036' = '42';'1037' = '43';'1038' = '44';'1039' = '45';'1040' = '46';
		'1041' = '47';'1042' = '48';'1043' = '49';'1044' = '50';'1045' = '51';'1080' = '52';
		}

	try {
		$ateraRegistryKey = $null
		$ateraService = $null

		# Get registry settings for Atera Agent
		$ateraRegistryKey = Get-Item 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent' -ErrorAction SilentlyContinue

		# Get Atera service if exists
		$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue
		
		$ateraExecutablePresentBool = Test-Path -LiteralPath 'C:\Program Files (x86)\ATERA Networks\AteraAgent\AteraAgent.exe'

		if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService) -and $ateraExecutablePresentBool -and ($ateraService.Status -eq 'Running')) {
			Write-Output("[+] Atera detected - nothing to do.")
			Write-Output("[+] Registery keys check : $ateraRegistryKey")
			return
		}
		elseif (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService) -and !$ateraExecutablePresentBool -and ($ateraService.Status -eq 'Stopped')) {
			Write-Output('[*] Broken Atera installation detected, wiping config')
			Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\ATERA Networks\AteraAgent' -Name 'CompanyId' -Force -ErrorAction SilentlyContinue
			Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\ATERA Networks\AteraAgent' -Name 'FolderId' -Force -ErrorAction SilentlyContinue
			Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\ATERA Networks\AteraAgent' -Name 'ServerName' -Force -ErrorAction SilentlyContinue
			Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\ATERA Networks\AteraAgent' -Name 'DisabledRemote' -Force -ErrorAction SilentlyContinue
			if ($PSVersionTable.PSVersion.Major -eq 7) {
				Write-Output('[*] PS 7 detected, removing AteraAgent service with builtin cmdlet')
				Get-Service -DisplayName 'AteraAgent' -ErrorAction SilentlyContinue | Remove-Service -ErrorAction SilentlyContinue
			}
			if (Get-Service -DisplayName 'AteraAgent' -ErrorAction SilentlyContinue) {
				$ateraServiceController = [System.ServiceProcess.ServiceController]::new('AteraAgent')
				if ($ateraServiceController.Name -ne 'AteraAgent') {
					Write-Output('[-] Atera service controller cannot be created, deleting with sc.exe')
					# Kept as fallback
					sc.exe delete AteraAgent
				} else {
					$serviceInstaller = [System.ServiceProcess.ServiceInstaller]::new()
					$serviceInstaller.ServiceName = 'AteraAgent'
					$serviceInstaller.Context = [System.Configuration.Install.InstallContext]::new($null, $null)
					$serviceInstaller.Uninstall($null)
				}
			}
		}

		# Get ControllerId from database EZ360Objects
		$getControllerIdQuery = @'
		SELECT TOP 1 *
		FROM [EZ360Objects].[Location].[Controllers]
		WHERE [Status] = 'Y'
'@
		if ($PSVersionTable.PSVersion.Major -eq 7){
			$controllerId = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerIdQuery -QueryTimeout 30 -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System' -TrustServerCertificate).ControllerId
		} else {
			$controllerId = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerIdQuery -QueryTimeout 30 -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System').ControllerId
		}
		[System.Data.SqlClient.SqlConnection]::ClearAllPools()

		# Get Controller Model from database EZ360Objects
		$getControllerModelQuery = @'
		SELECT CM.Name
		FROM Location.Controllers AS LC
		LEFT JOIN Controller.Models AS CM
		ON CM.ModelID = LC.ModelID
		WHERE LC.Status = 'Y'
'@
		if ($PSVersionTable.PSVersion.Major -eq 7){
			$controllerModel = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerModelQuery -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System' -QueryTimeout 30 -TrustServerCertificate).name
		} else {
			$controllerModel = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerModelQuery -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System' -QueryTimeout 30).name
		}

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
			if ($controllerId.ToString().Length -lt 7) {
				$AteraFolderIndex = 1001
			} else {
				$AteraFolderIndex = [math]::Truncate($controllerId / 1000) + 1
			}

			if ($null -eq $foldersHashTable[$AteraFolderIndex.ToString()]) {
				$foldersHashTable[$AteraFolderIndex.ToString()] = '52'
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
				msiexec /i atera.msi /qn  IntegratorLogin=Atera.Update@dtiq.com CompanyId=22 AccountId=0013z00002tEY2hAAG FolderId=$($foldersHashTable[$AteraFolderIndex.ToString()])
			}

			# Post check if atera is installed with 15 second timeout
			# kill leftover process if found
			for ($i = 0; $i -lt 30; $i++) {
				# Get registry settings for Atera Agent
				$ateraRegistryKey = Get-Item 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent' -ErrorAction SilentlyContinue

				# Get Atera service if exists
				$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue
				$ateraProcess = Get-Process -Name 'AteraAgent' -ErrorAction SilentlyContinue
				if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService) -and $ateraExecutablePresentBool -and ($ateraService.Status -eq 'Running') -and ($null -ne $ateraProcess)) {
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
		Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
	}
}

function SetHostname () {
	<#
	.SYNOPSIS
	Sets hostname to VDMS-XXXXXXX, reboot required to take effect
	#>
	# TODO:
	try {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Write-Output('[*] SetHostname')

		# Get ControllerId from database EZ360Objects
		$getControllerIdQuery = @'
		SELECT TOP 1 *
		FROM [EZ360Objects].[Location].[Controllers]
		WHERE [Status] = 'Y'
'@

		if ($PSVersionTable.PSVersion.Major -eq 7){
			$controllerId = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerIdQuery -QueryTimeout 30 -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System' -TrustServerCertificate).ControllerId
		} else {
			$controllerId = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerIdQuery -QueryTimeout 30 -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System').ControllerId
		}
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
		Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
	}
}

function DisableOBEE () {
	<#
	.SYNOPSIS
	Adds registry keys to block Windows consumer experience
	like 'Hi' and 'Get even more out of Windows' screens
	#>
	# TODO: Remove old windows prompts for new ones
	try {
		$logonAnimationPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
		if (!(Test-path $logonAnimationPath)) {
			New-Item -Path $logonAnimationPath -Force
		}
		New-ItemProperty -Path $logonAnimationPath -Name 'EnableFirstLogonAnimation' -Value 0 -PropertyType DWord -Force | Out-Null
	} catch {
		Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
	}

	try {
		$privacyExperiencePath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE'
		if (!(Test-path $privacyExperiencePath)) {
			New-Item -Path $privacyExperiencePath -Force
		}
		New-ItemProperty -Path $privacyExperiencePath -Name 'DisablePrivacyExperience' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
	}

	try {
		$consumerFeaturesPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE'
		if (!(Test-path $consumerFeaturesPath)) {
			New-Item -Path $consumerFeaturesPath -Force
		}
		New-ItemProperty -Path $consumerFeaturesPath -Name 'DisableWindowsConsumerFeatures' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
	}
}

function pingAllow () {
	<#
	.SYNOPSIS
	Create firewall rules to
	.NOTES 
	# TODO:
	#>
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
	# TODO:
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
		Set-Service -Name 'EZSensors Server' -Force -StartupType Disabled
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
				$proc = Start-Process $path[0] -ArgumentList ($path[1], '/qn') -PassThru -NoNewWindow
				Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout 10
				Write-Output("[+] Uninstalled $($_.DisplayName)")
			} catch {
				Write-Error("[-] $($name) Timed out")
				Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Stop-Process -Force
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
				Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout 10
				Write-Output("[+] Uninstalled $($_.DisplayName)")
			} catch {
				Write-Error("[-] $($path[1]) Timed out on $($proc)")
				Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Stop-Process -Force
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
			Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
		}
	}
	Write-Output('[+] Finished removing Legacy components')
}

function installDotNet () {
	# TODO:
	Write-Output('[*] Install .NET')
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	if([System.Environment]::Is64BitOperatingSystem) {
		Write-Output('[+] x64 system')

		$dotnetDownloadPath = 'C:\ProgramData\DTiQ'
		if (!(Test-Path $dotnetDownloadPath)) {
			New-Item -Force $dotnetDownloadPath -ItemType Directory | Out-Null
		}
		Write-Output("[+] $dotnetDownloadPath verified")
		class FileProperties {
			[string]$name
			[string]$version
			[string]$url
			[string]$checksum
		
			fileProperties([string]$name, [string]$version, [string]$url, [string]$checksum) {
				$this.Name = $name
				$this.version = $version
				$this.Url = $url
				$this.Checksum = $checksum
			}
		}
		
		$dotnetVersionsToDownload = [FileProperties]::new(
			"ndp48-x86-x64-allos-enu.exe",
			"4.8.03761",
			"https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe",
			"FFB6C226AF4E5C8FFA7210D5115701883ABF12A8B1CBAE6E08122FB94DD93763468BFF5B00060EABEF19C147B0A4D8063DDE318D2B928CE397C58F7949736C5F"
		), [FileProperties]::new(
			"windowsdesktop-runtime-6.0.15-win-x64.exe",
			"6.0.15",
			"https://download.visualstudio.microsoft.com/download/pr/513d13b7-b456-45af-828b-b7b7981ff462/edf44a743b78f8b54a2cec97ce888346/windowsdesktop-runtime-6.0.15-win-x64.exe",
			"62412c45ba5ebf89b0ea2c3d9dcce3a7f05198d4db368f63956f7ae58b368baa059343a2de39d24e20ffe126145f31c72131914cb2793f002921a975e69c3bb4"
		)

		# Gather all installed versions of .NET from registry
		$dotnetVersionsRegistry = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | Select-Object Version).Version
		$dotnetVersionsRegistry += (Get-ChildItem 'HKLM:\SOFTWARE\dotnet' -Recurse | Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | Select-Object Version).Version
		Set-Location -LiteralPath $dotnetDownloadPath
		foreach ($item in $dotnetVersionsToDownload) {
			if ($dotnetVersionsRegistry -contains $item.version) {
				Continue
			}
			Write-Output("[*] Downloading $($item.Name)")
			try {
				Invoke-RestMethod -Uri $item.Url -OutFile $item.Name
				Write-Output("[+] Download of $($item.Name) comleted")
			} catch {
				Write-Output("[-] Download of $($item.Name) failure")
			}
			
			if ((Get-FileHash -Algorithm SHA512 -Path $item.Name).Hash -ne $item.Checksum) {
				Remove-Item -Path $item.Name
				Write-Error("[-] $($item.Name) hash not matching")
				continue
			}

			try {
				Write-Output("[*] Installing $($item.Name)")
				Start-Process -FilePath $item.Name -ArgumentList ('/q', '/norestart')
				Write-Output("[+] Installation $($item.Name) running in background")
			} catch {
				Write-Error("[-] $($item.Name) installation error")
				Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Stop-Process -Force
				continue
			}
		}
	} else {
		Write-Output('[-] x86 system, skipping .NET installlation')
	}
}

function installWazuh () {
	# TODO:
	Write-Output('[*] Install Wazuh')
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$sysmonInstallPath = 'C:\DTIQ'

	if (!(Test-Path -LiteralPath $sysmonInstallPath)) {
		New-Item -ItemType Directory -Force -Path $sysmonInstallPath
	}

	try {
		Invoke-WebRequest -Uri 'https://dtt-it.s3.amazonaws.com/VPN/Sysmon.zip' -Outfile "$sysmonInstallPath\Sysmon.zip" -ErrorAction Stop
		Write-Output('[+] Sysmon download complete')
	} catch {
		Write-Output('[-] Cannot download archive')
	}

	try {
		Expand-Archive -LiteralPath "$sysmonInstallPath\Sysmon.zip" -Force -DestinationPath $sysmonInstallPath -ErrorAction Stop
		Write-Output('[+] Sysmon extraction complete')
	} catch {
		Write-Output('[-] Cannot expand archive')
	}

	
	Write-Output('[*] Sysmon cleanup running')
	Set-Location -LiteralPath $sysmonInstallPath

	$(cmd /c '.\Sysmon64.exe -u 2>&1' > logfile.txt 2>&1) | Out-Null
	if (Get-Content -LiteralPath $sysmonInstallPath/logfile.txt | Select-String -SimpleMatch 'Removing service files.') {
		Write-Output('[+] Sysmon cleanup successfull')
	} else {
		Write-Output('[*] Sysmon not cleaned up')
	}
	

	# Sysmon installation, Start-Process cannot accept eula
	# With this setup we can kill off process without being stuck forever on installation
	$sysmonInstallPath = 'C:\DTIQ'
	Set-Location $sysmonInstallPath
	$(cmd /c '.\Sysmon64.exe -i sysconfig.xml -accepteula 2>&1' > logfile.txt 2>&1) | Out-Null
	if (Get-Content -LiteralPath $sysmonInstallPath/logfile.txt | Select-String -SimpleMatch 'Sysmon64 started.') {
		Write-Output('[+] Sysmon installation successfull')
	} else {
		Write-Output('[*] Sysmon installer failed')
	}
	

	if (Get-Service -Name 'Wazuh' -ErrorAction SilentlyContinue) {
		Write-Output('[+] Wazuh is already installed. Skipping')

		# Skip installation, to discus with CX as new versions might require another installation
	}

	try {
		Invoke-WebRequest -Uri 'https://dtt-it.s3.amazonaws.com/VPN/wazuh-agent.msi' -OutFile $env:tmp\wazuh-agent.msi -ErrorAction Stop
		Write-Output('[+] Wazuh download completed')
	} catch {
		Write-Error("[-]  $($_.InvocationInfo.PositionMessage)")
		return
	}

	if ($locationNameValue = (Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller' -ErrorAction SilentlyContinue).LocationName) {
		Write-Output('[+] 360 location identified, installing Wazuh')
		$displayAsValue = $locationNameValue -Replace '[^a-zA-Z0-9]', ''
		msiexec.exe /i $env:tmp\wazuh-agent.msi /q WAZUH_MANAGER='wzh-reg.go360iq.com' WAZUH_REGISTRATION_SERVER='wzh-reg.go360iq.com' WAZUH_REGISTRATION_PASSWORD='J4x55Mc#l' WAZUH_AGENT_NAME=$displayAsValue
	} elseif (Test-Path 'C:\Windows\GeoMulti.ini') {
		try {
			$iniData = Get-Content -Path 'C:\Windows\GeoMulti.ini' -ErrorAction Stop | Where-Object { $_ -match 'Location=' }
			$DTTLocationName = $iniData[0].Split('=')[1]
			$NameTrimmedDTT = $DTTLocationName -replace '[^a-zA-Z0-9]', ''
		} catch {
			Write-Error('[-] Cannot trim location name from GeoMulti.ini file')
		}

		Write-Output('[+] DTT location identified, installing Wazuh')
		msiexec.exe /i $env:tmp\wazuh-agent.msi /q WAZUH_MANAGER='wzh-reg.go360iq.com' WAZUH_REGISTRATION_SERVER="wzh-reg.go360iq.com" WAZUH_REGISTRATION_PASSWORD="J4x55Mc#l" WAZUH_AGENT_NAME= ${global:NameTrimmedDTT}
	} else {
		Write-Output('[-] Neither 360 or DTT location identified')
		return
	}
	Write-Output('[+] Wazuh install finished')
}

blockWin11Upgrade
SetHostname
AteraInstall
DisableWinUpdateIfAteraNotExists
DisableOBEE
pingAllow
removeLegacyComponents
installWazuh
#installDotNet

# TODO
# validateWindowsAccounts
# setTreeACLS
