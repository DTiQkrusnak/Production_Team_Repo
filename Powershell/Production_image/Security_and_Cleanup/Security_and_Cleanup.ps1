[Net.ServicePointManager]::SecurityProtocol = 'TLS12', 'SSL3'
4
function blockWin11Upgrade () {
	<#
	.SYNOPSIS
	Blocks Windows 11 upgrade prompts and version on 21H2
	#>

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
			Write-Output("[-] Script is executing fix only on Windows 10, your Windows : $system")
		}
	} catch {
		Write-Error "[-] $($_.Exception.Message)"
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
		Write-Error "[-] $($_.Exception.Message)"
	}
}

function AteraInstall () {
	<#
	.SYNOPSIS
	Installs Atera service when VDMS-XXXXXXX hostname matches
	#>
	Write-Output("[*] Atera Install")
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
		# Download files
		Invoke-WebRequest -Uri "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/ateraInstall/atera.exe" -OutFile "$ateraDownloadPath\atera.exe" -TimeoutSec 30
		Invoke-WebRequest -Uri "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/ateraInstall/setup_final.msi" -OutFile "$ateraDownloadPath\setup_final.msi" -TimeoutSec 30
		Write-Output("[+] Atera files downloaded")


		# Check if hostname is set to VDMS standard
		if ($env:COMPUTERNAME -eq "VDMS-$controllerId") {
			Set-Location -Path $ateraDownloadPath
			if ($controllerModel -eq "VDMS Summit") {
				#Start Atera installer with site ID 12 "VDMS-Summit" site
				& '.\atera.exe' '12'
			} else {
				# Start Atera installer with site ID 1 "general" site
				& '.\atera.exe' '1'
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
					Stop-Process -Name 'atera' -Force -ErrorAction Continue
					return
				}
				Start-Sleep -Milliseconds 500
			}
		} else {
			Write-Error -Message "[-] Hostname not set to VDMS standard"
		}
	} catch {
		Write-Error "[-] $($_.Exception.Message)"
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
			Rename-Computer -NewName "VDMS-$controllerID"
			Write-Output('[+] Set hostname completed')
		}
	} catch {
		Write-Error "[-] $($_.Exception.Message)"
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
		Write-Error "[-] $($_.Exception.Message)"
	}

	try {
		$privacyExperiencePath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE'
		if (!(Test-path $privacyExperiencePath)) {
			New-Item -Path $privacyExperiencePath -Force
		}
		New-ItemProperty -Path $privacyExperiencePath -Name 'DisablePrivacyExperience' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		Write-Error "[-] $($_.Exception.Message)"
	}

	try {
		$consumerFeaturesPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE'
		if (!(Test-path $consumerFeaturesPath)) {
			New-Item -Path $consumerFeaturesPath -Force
		}
		New-ItemProperty -Path $consumerFeaturesPath -Name 'DisableWindowsConsumerFeatures' -Value 1 -PropertyType DWord -Force | Out-Null
	} catch {
		Write-Error "[-] $($_.Exception.Message)"
	}
}

blockWin11Upgrade
SetHostname
AteraInstall
DisableWinUpdateIfAteraNotExists
DisableOBEE

# TODO
# validateWindowsAccounts
# setTreeACLS
