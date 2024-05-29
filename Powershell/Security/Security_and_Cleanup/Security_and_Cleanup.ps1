<#
.SYNOPSIS
Multi purpose script that installs production tools like Atera and Wazuh
Removes Legacy components on VDMS systems
and blocks out updates that are not maintained or pushed by production team
.DESCRIPTION

#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:gatheredErrors = @()

function Install-Packages() {
	try {
		Install-PackageProvider -Name 'NuGet' -MinimumVersion 2.8.5.201 -Confirm:$false -Force -ForceBootstrap -ErrorAction Stop
		Add-PowershellDefaultRepository
		Install-Module -Name 'SqlServer' -Confirm:$false -Force -AllowClobber -ErrorAction Stop
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}
}

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

$controllerInstallerDownloadPath = 'C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads'

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

function Add-PowershellDefaultRepository() {
	<#
	.SYNOPSIS
	Set PSGallery as default repository if not present
	Add shellget.go360iq.com to repository if not present
	.DESCRIPTION
	Function checkes local powershell repository list and if PSGallery is not present it is added
	Additionally we add shellget.go360iq.com (our internal repository) to repositories for future use
	#>

	Write-Output('[i] Check powershell repositories')
	$repos = 'PSGallery', 'ShellGet'
	try {
		$missingRepos = (Compare-Object -ReferenceObject $repos -DifferenceObject (Get-PSRepository).Name -ErrorAction Stop).InputObject
		if ($null -eq $missingRepos) {
			Write-Output('[+] Repos are already registered')
			return
		}
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
		return
	}

	if ($missingRepos -contains 'PSGallery') {
		try {
			Register-PSRepository -Default -ErrorAction Stop
			Write-Output('[+] PSGallery repo has been registered')
		} catch {
			$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
			Write-Output("[-]  $($_.Exception.Message)")
		}
	}
	
	if ($missingRepos -contains 'ShellGet') {
		try {
			$repoRegistrationParameters = @{
					Name = "ShellGet"
					SourceLocation = 'https://shellget.go360iq.com/nuget'
					InstallationPolicy = 'Trusted'
					PackageManagementProvider = 'NuGet'
				}
			Register-PSRepository @repoRegistrationParameters -ErrorAction Stop
			Write-Output('[+] ShellGet repo has been registered')
		} catch {
			$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
			Write-Output("[-]  $($_.Exception.Message)")
		}
	}
}
function Disable-Windows11Upgrade() {
	<#
	.SYNOPSIS
	Blocks Windows 11 upgrade prompts and version on 21H2
	.DESCRIPTION
	Function adds registry keys to HKLM to block updates to version specified
	#>
	Write-Output('[i] Block Win11 Upgrade')

	$regPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

	try {
		# ! TO REWORK > Invalid class win32_operatingsystem
		$system = (Get-WMIObject win32_operatingsystem).Caption

		if ($system -like "*Windows*10*") {
			Write-Output('[i] blockWin11Upgrade')
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
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}
}

function Disable-WindowsUpdateIfAteraNotPresent() {
	<#
	.SYNOPSIS
	Disables Windows Update service if Atera service is not present in the system
	.DESCRIPTION
	Function is checking if service and process for AteraAgent are working.
	If not Windows Update service is disabled
	#>

	Write-Output("[i] Disable Windows Update if Atera does not exist")

	$ateraRegistryKey = $null
	$winUpdateService = $null
	$ateraService = $null

	# Check if atera is already installed with 15 second timeout
	for ($i = 0; $i -lt 30; $i++) {
		# Get registry settings for Atera Agent
		$ateraRegistryKey = Get-Item 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent' -ErrorAction SilentlyContinue

		# Get Atera service if exists
		$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue
		$ateraProcess = Get-Process -Name 'AteraAgent' -ErrorAction SilentlyContinue
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

		Write-Output("[i] Stopping windows update service")
		$winUpdateService | Stop-Service -Force -NoWait -ErrorAction SilentlyContinue

		# Wait for Windows Update service to stop with 5 seconds timeout
		for ($i = 0; $i -lt 11; $i++) {
			if ($i -eq 10) {
				$script:gatheredErrors += ('[-] Windows Update cannot be stopped, system will continue stopping it on its own, timed out (5s)')
				Write-Output('[-] Windows Update cannot be stopped, system will continue stopping it on its own, timed out (5s)')
				break
			} elseif ($winUpdateService.Status -ne 'Stopped') {
				Start-Sleep -Milliseconds 500
				$winUpdateService.Refresh()
			} else {
				Write-Output("[+] $($winUpdateService.DisplayName) service stopped")
				break
			}
		}

		Write-Output("[i] Disabling windows update service")
		$winUpdateService | Set-Service -StartupType "Disabled"
		Write-Output("[+] $($winUpdateService.DisplayName) service disabled")



		<#
		CHECK if 'BITS' and 'DoSvc' has to be disabled here as well
		#>
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}
}

function Set-Hostname() {
	<#
	.SYNOPSIS
	Sets hostname to VDMS-XXXXXXX (ControllerID), reboot required to take effect
	.DESCRIPTION

	#>

	# Get ControllerId from database EZ360Objects
	$connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'

	$getControllerIdQuery = @'
	SELECT TOP 1 *
	FROM [EZ360Objects].[Location].[Controllers]
	WHERE [Status] = 'Y'
'@

	try {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Write-Output('[i] SetHostname')

		try {
			$script:controllerId = (Get-ItemProperty -Path 'Registry::HKLM\SOFTWARE\EZUniverse\EZ360ControllerInstaller' -Name 'ControllerID' -ErrorAction SilentlyContinue).ControllerID
			if ($null -eq $script:controllerId) {
				$script:controllerId = (Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query $getControllerIdQuery -QueryTimeout 30 -ErrorAction Stop).ControllerId
			}
		} catch {
			$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
			Write-Output("[-]  $($_.Exception.Message)")
			return
		}

		# Check if hostname matches VDMS standard
		if ($env:COMPUTERNAME -eq "VDMS-$controllerId") {
			Write-Output('[+] Hostname already changed')
			return
		} else {
			$script:ISRENAMESUCCESSFUL = Rename-Computer -NewName "VDMS-$controllerID" -PassThru
			Write-Output('[+] Set hostname completed')
		}
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}
}

function Disable-Obee() {
	<#
	.SYNOPSIS
	Adds registry keys to block Windows consumer experience
	like 'Hi' and 'Get even more out of Windows' screens
	#>
	# TODO: Remove old windows prompts for new ones
	try {
		$logonAnimationPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
		if (!(Test-path $logonAnimationPath)) {
			throw [System.IO.Path] "$logonAnimationPath not found"
		}
		New-ItemProperty -Path $logonAnimationPath -Name 'SystemDefaultTlsVersions' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}

	try {
		$logonAnimationPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
		if (!(Test-path $logonAnimationPath)) {
			New-Item -Path $logonAnimationPath -Force
		}
		New-ItemProperty -Path $logonAnimationPath -Name 'EnableFirstLogonAnimation' -Value 0 -PropertyType DWord -Force | Out-Null
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}

	try {
		$privacyExperiencePath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE'
		if (!(Test-path $privacyExperiencePath)) {
			New-Item -Path $privacyExperiencePath -Force
		}
		New-ItemProperty -Path $privacyExperiencePath -Name 'DisablePrivacyExperience' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}

	try {
		$consumerFeaturesPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE'
		if (!(Test-path $consumerFeaturesPath)) {
			New-Item -Path $consumerFeaturesPath -Force
		}
		New-ItemProperty -Path $consumerFeaturesPath -Name 'DisableWindowsConsumerFeatures' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}
	# New Bing bar disable
	try {
		$logonAnimationPath = 'Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Edge'
		if (!(Test-path $logonAnimationPath)) {
			New-Item -Path $logonAnimationPath -Force
		}
		New-ItemProperty -Path $logonAnimationPath -Name 'WebWidgetIsEnabledOnStartup' -Value 0 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path $logonAnimationPath -Name 'WebWidgetAllowed' -Value 0 -PropertyType DWord -Force | Out-Null
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
	}
}

function Set-FirewallRulePingAllow() {
	<#
	.SYNOPSIS
	Create firewall rules to
	.NOTES 
	# TODO:
	#>
	Write-Output('[i] Ping Allow')
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

function Uninstall-LegacyComponents() {
	# TODO:
	Write-Output('[i] Remove Legacy Components')
	#Check migration status
	$isMigratedVS = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\EZUniverse Inc.\EZVideoServer'-ErrorAction SilentlyContinue).ConfigurationManager
	$isMigratedEH = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\EZUniverse Inc.\EZEventHandler' -ErrorAction SilentlyContinue).ConfigurationManager

	Write-Output('[i] Checking migration status')
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

	Write-Output('[i] Stopping SystemWatcher, SQLReplicator, EZSensor Server and UpdateCenters')
	Stop-Service -Force -ErrorAction SilentlyContinue -Name (
		'EZSQLReplicator','EZSystemWatcher', 'EZSensorsServer','SubwayUpdateCenter','EZUpdateCenter')

	if (Get-Service -Name 'EZSensors Server' -ErrorAction SilentlyContinue) {
		Set-Service -Name 'EZSensors Server' -Force -StartupType Disabled
		Write-Output('[+] Disabled EZSensors Server')
	}
	


	# Get MSI programs
	foreach ($name in $removeMSI) {
		Write-Output("[i] Uninstalling $($name)")
		
		$appObjects | 
		Where-Object { $_.DisplayName -match $name} | 
		Foreach-Object { 
			$path = $_.UninstallString -split ' '
			try {
				$proc = Start-Process $path[0] -ArgumentList ($path[1], '/qn') -PassThru -NoNewWindow
				Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout 10 -ErrorAction Stop
				Write-Output("[+] Uninstalled $($_.DisplayName)")
			} catch {
				$script:gatheredErrors += ("[-] $($name) Timed out")
				Write-Output("[-] $($name) Timed out")
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
				$script:gatheredErrors += ("[-] Missing file $($datFilePath), skipping")
				Write-Output("[-] Missing file $($datFilePath), skipping")
				Continue
			}
			Write-Output("[i] Uninstalling $($_.DisplayName)")

			try {
				$proc = Start-Process $path[1] -ArgumentList $($path[2..($path.Length -2)]) -PassThru -NoNewWindow
				Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout 10 -ErrorAction Stop
				Write-Output("[+] Uninstalled $($_.DisplayName)")
			} catch {
				$script:gatheredErrors += ("[-] $($path[1]) Timed out on $($proc)")
				Write-Output("[-] $($path[1]) Timed out on $($proc)")
				Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
				Get-Process -Name '*.tmp' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
			}
		}
	}

	if (Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue) {
		try {
			Stop-Service -Name 'MSSQL$SQLEXPRESS' -Force
			Set-Service -Name 'MSSQL$SQLEXPRESS' -StartupType Disabled
			Write-Output('[+] Disabled legacy SQLSERVER')
		} catch {
			$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		}
	}
	Write-Output('[+] Finished removing Legacy components')
}

function Get-DotNetFiles() {
	# TODO:
	Write-Output('[i] Get .NET files')
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	if([System.Environment]::Is64BitOperatingSystem) {
		Write-Output('[+] x64 system')

		if (!(Test-Path $controllerInstallerDownloadPath)) {
			New-Item -Force $controllerInstallerDownloadPath -ItemType Directory | Out-Null
		}
		Write-Output("[+] $controllerInstallerDownloadPath verified")

		# Gather all installed versions of .NET from registry
		[System.Version[]] $dotnetVersionsRegistry = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | Select-Object Version).Version
		$dotnetVersionsRegistry += (Get-ChildItem 'HKLM:\SOFTWARE\dotnet' -Recurse | Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | Select-Object Version).Version
		
		$jobs = @()
		foreach ($item in $dotnetVersionsToDownload) {
			[System.Version] $itemVersion = $item.Version
			$greaterVersions = $dotnetVersionsRegistry | Where-Object {$_.Major -eq $itemVersion.Major} | Where-Object {$_.Minor -eq $itemVersion.Minor} | Where-Object {$_.Build -ge $itemVersion.Build}
			if ($greaterVersions.Count -gt 0) {
				Write-Output("Greater or equal version already in system, skipping $itemVersion")
				continue
			} else {
				Write-Output("[i] Downloading $($item.Name)")
				$jobs += Start-Job -Name $($item.Name) -ScriptBlock {
					param(
						$controllerInstallerDownloadPath,
						$item
						)
					
					Set-Location -LiteralPath $controllerInstallerDownloadPath
					try {
						Invoke-RestMethod -Uri $item.Url -OutFile $item.Name
						Write-Output("[+] Download of $($item.Name) comleted")
					} catch {
						Write-Output("[-] Download of $($item.Name) failure")
					}

					if ((Get-FileHash -Algorithm SHA512 -Path $item.Name).Hash -ne $item.Checksum) {
						Remove-Item -Path $item.Name
						$script:gatheredErrors += ("[-] $($item.Name) hash not matching")
						Write-Output("[-] $($item.Name) hash not matching")
					}
				} -ArgumentList $controllerInstallerDownloadPath, $item
				continue
			}
		}
		
		# Check if any jobs were scheduled
		if ($jobs) {
			Write-Output(Get-Job)
			Wait-Job -Job $jobs
			Write-Output('[+] .Net files downloaded')
			return
		} else {
			Write-Output('[+] No version of .Net to download, finished')
			return
		}
	} else {
		Write-Output('[-] x86 system, skipping .NET installlation')
	}
}


function Install-DotNet() {
	<#
	.SYNOPSIS
	Install .Net versions downloaded in Get-DotNetFiles function.
	.DESCRIPTION
	All versions specified in variable $dotnetVersionsToDownload are run in quiet installation mode if version is not visible in system.
	TODO: Skip version 4.8 if version is higher
	#>
	Write-Output('[i] Install .NET')
	

	if (!(Test-Path $controllerInstallerDownloadPath)) {
		$script:gatheredErrors += ('[-] .Net download folder does not exist, skipping installation because of missing files')
		Write-Output('[-] .Net download folder does not exist, skipping installation because of missing files')
	}
	Write-Output("[+] $controllerInstallerDownloadPath verified")
	Set-Location -LiteralPath $controllerInstallerDownloadPath

	# Gather all installed versions of .NET from registry
	[System.Version[]] $dotnetVersionsRegistry = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | Select-Object Version).Version
	$dotnetVersionsRegistry += (Get-ChildItem 'HKLM:\SOFTWARE\dotnet' -Recurse | Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | Select-Object Version).Version
	
	foreach ($item in $dotnetVersionsToDownload) {
		[System.Version] $itemVersion = $item.Version
		$greaterVersions = $dotnetVersionsRegistry | Where-Object {$_.Major -eq $itemVersion.Major} | Where-Object {$_.Minor -eq $itemVersion.Minor} | Where-Object {$_.Build -ge $itemVersion.Build}
		if ($greaterVersions.Count -gt 0) {
			Write-Output("Greater or equal version already in system, skipping $itemVersion")
			continue
		} else {
			try {
				Write-Output("[i] Installing $($item.Name)")
				Start-Process -FilePath $($item.Name) -ArgumentList ('/q', '/norestart')
				Write-Output("[+] Installation $($item.Name) running in background")
			} catch {
				$script:gatheredErrors += ("[-] $($_.Exception.Message)")
				Write-Output("[-] $($_.Exception.Message)")
			}
			continue
		}
	}
}

function Install-Wazuh() {
	# TODO:
	Write-Output('[i] Install Wazuh')
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

	
	Write-Output('[i] Sysmon cleanup running')
	Set-Location -LiteralPath $sysmonInstallPath

	try {
		$(cmd /c '.\Sysmon64.exe -u 2>&1' > logfile.txt 2>&1) | Out-Null
	} catch {
		$script:gatheredErrors += ("[-] $($_.Exception.Message)")
		Write-Output("[-] $($_.Exception.Message)")
	}
	if (Get-Content -LiteralPath $sysmonInstallPath/logfile.txt -ErrorAction SilentlyContinue | Select-String -SimpleMatch 'Removing service files.') {
		Write-Output('[+] Sysmon cleanup successfull')
	} else {
		Write-Output('[i] Sysmon not cleaned up')
	}
	

	# Sysmon installation, Start-Process cannot accept eula
	# With this setup we can kill off process without being stuck forever on installation
	$sysmonInstallPath = 'C:\DTIQ'
	Set-Location $sysmonInstallPath

	try {
		$(cmd /c '.\Sysmon64.exe -i sysconfig.xml -accepteula 2>&1' > logfile.txt 2>&1) | Out-Null
	} catch {
		$script:gatheredErrors += ("[-] $($_.Exception.Message)")
		Write-Output("[-] $($_.Exception.Message)")
	}
	if (Get-Content -LiteralPath $sysmonInstallPath/logfile.txt -ErrorAction SilentlyContinue | Select-String -SimpleMatch 'Sysmon64 started.') {
		Write-Output('[+] Sysmon installation successfull')
	} else {
		Write-Output('[i] Sysmon installer failed')
	}
	

	if (Get-Service -Name 'Wazuh' -ErrorAction SilentlyContinue) {
		Write-Output('[+] Wazuh is already installed. Skipping')

		# Skip installation, to discus with CX as new versions might require another installation
	}

	try {
		Invoke-WebRequest -Uri 'https://dtt-it.s3.amazonaws.com/VPN/wazuh-agent.msi' -OutFile $env:tmp\wazuh-agent.msi -ErrorAction Stop
		Write-Output('[+] Wazuh download completed')
	} catch {
		$script:gatheredErrors += ("[-]  $($_.Exception.Message)")
		Write-Output("[-]  $($_.Exception.Message)")
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
			$script:gatheredErrors += ('[-] Cannot trim location name from GeoMulti.ini file')
			Write-Output('[-] Cannot trim location name from GeoMulti.ini file')
		}

		Write-Output('[+] DTT location identified, installing Wazuh')
		msiexec.exe /i $env:tmp\wazuh-agent.msi /q WAZUH_MANAGER='wzh-reg.go360iq.com' WAZUH_REGISTRATION_SERVER="wzh-reg.go360iq.com" WAZUH_REGISTRATION_PASSWORD="J4x55Mc#l" WAZUH_AGENT_NAME= ${global:NameTrimmedDTT}
		Start-Service -Name 'WazuhSvc'
	} else {
		Write-Output('[-] Neither 360 or DTT location identified')
		return
	}
	Write-Output('[+] Wazuh install finished')
}

function Push-ErrorLogs([string[]] $script:gatheredErrors) {
	if ($script:gatheredErrors.Count -eq 0) {
		Write-Output('[+] No errors to push to Breeze')
		return
	} else {
		$errors = ($script:gatheredErrors | ConvertTo-Json).ToString()
	}

	if ($null -eq $script:controllerId) {
		Write-Output('[-] ControllerID cannot be obtained with registry and SQL')
		$script:gatheredErrors += ('[-] ControllerID cannot be obtained with registry and SQL')
		$script:controllerId = 'N/A'
	}
	
    $body = @{
        locationId      = $script:controllerId
        locationName    = $script:controllerId
        timestamp       = Get-Date -UFormat "%m/%d/%Y"
        timezoneId      = Get-Date -UFormat "%Z"
        scriptName      = "Security"
        scriptId        = "503"
        executionDate   = Get-Date -UFormat "%m/%d/%Y"
        result          = $errors
        optionalResult1 = 'NULL'
        optionalResult2 = 'NULL'
        optionalResult3 = 'NULL'
        optionalResult4 = 'NULL'
        errorCode       = 'NULL'
        errorDetails    = 'NULL'
    } | ConvertTo-Json

	try {
		Invoke-RestMethod -Method Post -Uri 'https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/LongStoredScriptExecution' -Body $body -ContentType 'application/json' -ErrorAction Stop
		Write-Output('[+] Errors sent to breeze')
	} catch {
		Write-Output('[-] Errors cannot be sent to breeze')
		Write-Output("[-] $($_.Exception.Message)")
		return
	}
}

$startTime = Get-Date
Install-Packages
Get-DotNetFiles
Disable-Windows11Upgrade
Set-Hostname
# Install-Atera # ! Moved to separate file
Disable-WindowsUpdateIfAteraNotPresent
Disable-Obee
Set-FirewallRulePingAllow
Uninstall-LegacyComponents
Install-Wazuh
Install-DotNet
Push-ErrorLogs($script:gatheredErrors)

<# TODO :
VALIDATE_WINDOWS_ACCOUNTS
SET_FOLDER_TREE_ACLS
#>

Write-Output("[i] Script run time statistics in seconds : $(((Get-Date) - $startTime).TotalSeconds)")