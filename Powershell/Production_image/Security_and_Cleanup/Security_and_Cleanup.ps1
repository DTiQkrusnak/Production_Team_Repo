[Net.ServicePointManager]::SecurityProtocol = 'TLS12', 'SSL3'
$script:errorArray = @()


function blockWin11Upgrade () {
	<#
    .DESCRIPTION
	Blocks Windows 11 upgrade prompts and blocks version on 21H2
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
			Write-Output("Script is executing fix only on Windows 10, your Windows : $system")
		}
	} catch {
		Write-Error "[-] $($_.Exception.Message)"
	}
}

function DisableWinUpdateIfAteraNotExists () {
	<#
	.DESCRIPTION
	Disable Windows Update service if Atera service is not present in the system
	#>
	$ateraRegistryKey = $winUpdateService = $null
	# Get registry settings for Atera Agent
	$ateraRegistryKey = Get-Item "registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent" -ErrorAction SilentlyContinue
	# Get Atera servive if exists
	$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue
	try {
		# Checking if atera is present
		if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService)) {
			Write-Output("[+] Atera detected - nothing to do.")
			Write-Output("[+] Registery keys check : $ateraRegistryKey")
		}
		else {
			Write-Output("[*] ALERT : ATERA NOT FOUND!! DISABLING WINDOWSUPDATE SERVICE!!!")
			$winUpdateService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue

			Write-Output("[*] Disabling windows update service")
			$winUpdateService | Set-Service -StartupType "Disabled"
			Write-Output("[+] $($winUpdateService.DisplayName) service disabled")

			Write-Output("[*] Stopping windows update service")
			$winUpdateService | Stop-Service -Force -ErrorAction SilentlyContinue
			Write-Output("[+] $($winUpdateService.DisplayName) service stopped")

			<#
			CHECK if 'BITS' and 'DoSvc' has to be disabled here as well
			#>
		}
	} catch {
		Write-Error "[-] $($_.Exception.Message)"
	}
}

function AteraInstall () {
	Write-Output("[*] Atera Install")
	try {
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
			Write-Output('[+] Atera installed')
		} else {
			Write-Error -Message "[-] Hostname not set to VDMS standard"
		}
	} catch {
		Write-Error "[-] $($_.Exception.Message)"
	}
}

function SetHostname () {
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

blockWin11Upgrade
SetHostname
AteraInstall
DisableWinUpdateIfAteraNotExists
