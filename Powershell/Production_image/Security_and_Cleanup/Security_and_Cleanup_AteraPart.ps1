function Install-Atera() {
	<#
	.SYNOPSIS
	Installs Atera service when VDMS-XXXXXXX hostname matches
	.DESCRIPTION
	Function detects if Atera is installed and if it is broken or not. If it is installed it completely skip whole function.
	If it is broken it removes registry values that are not identifying the location on website and uninstalls Windows Service AteraAgent in preparation for reinstallation.
	Later the normal flow is happening with calculation, download and installation.
	
	If Atera is not installed it creates path for download and based on model it downloads Summit or Production version of Atera.
	Production version of Atera is split between folders on website based on ControllerID calculation (FolderID is obtained from hash $foldersHashTable
	and it is calculated with following formula [foldersHashTableKey = ControllerId / 1000])
	
	FolderId = 52 works as fallback, in situation when hash cannot be found after calculation it will assign this ID
	#>
	# TODO:
	Write-Output("[i] Atera Install")
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	$foldersHashTable = @{
		'1011' = '7'; '1001' = '8'; '1002' = '9'; '1003' = '10';'1004' = '11';'1005' = '12';'1006' = '13';'1007' = '14';
		'1008' = '15';'1009' = '16';'1010' = '17';'1012' = '18';'1013' = '19';'1014' = '20';'1015' = '21';'1016' = '22';
		'1017' = '23';'1018' = '24';'1019' = '25';'1020' = '26';'1021' = '27';'1022' = '28';'1023' = '29';'1024' = '30';
		'1025' = '31';'1026' = '32';'1027' = '33';'1028' = '34';'1029' = '35';'1030' = '36';'1031' = '37';'1032' = '38';
		'1033' = '39';'1034' = '40';'1035' = '41';'1036' = '42';'1037' = '43';'1038' = '44';'1039' = '45';'1040' = '46';
		'1041' = '47';'1042' = '48';'1043' = '49';'1044' = '50';'1000' = '51';'1080' = '52';
		}

	try {
		$ateraRegistryKey = $null
		$ateraService = $null

		# Get registry settings for Atera Agent
		$ateraRegistryKey = Get-Item 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent' -ErrorAction SilentlyContinue

		# Get Atera service if exists
		$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue
		
		# Check both x86 and x64 paths for Atera executable
		$ateraResolvedPath = Resolve-Path -Path 'C:\Program Files*\ATERA Networks\AteraAgent\AteraAgent.exe' -ErrorAction SilentlyContinue
		if ($null -eq $ateraResolvedPath) {
			$ateraExecutablePresentBool = $false
		} else {
			$ateraExecutablePresentBool = Test-Path -LiteralPath $ateraResolvedPath
		}

		if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService) -and $ateraExecutablePresentBool -and ($ateraService.Status -eq 'Running')) {
			Write-Output("[+] Atera detected - nothing to do.")
			Write-Output("[+] Registery keys check : $ateraRegistryKey")
			return
		}
		elseif (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService) -and !$ateraExecutablePresentBool -and ($ateraService.Status -eq 'Stopped')) {
			Write-Output('[i] Broken Atera installation detected, wiping config')
			Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\ATERA Networks\AteraAgent' -Name 'CompanyId' -Force -ErrorAction SilentlyContinue
			Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\ATERA Networks\AteraAgent' -Name 'FolderId' -Force -ErrorAction SilentlyContinue
			Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\ATERA Networks\AteraAgent' -Name 'ServerName' -Force -ErrorAction SilentlyContinue
			Remove-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\ATERA Networks\AteraAgent' -Name 'DisabledRemote' -Force -ErrorAction SilentlyContinue

			# Powershell 7 support for Atera removal
			if ($PSVersionTable.PSVersion.Major -eq 7) {
				Write-Output('[i] PS 7 detected, removing AteraAgent service with builtin cmdlet')
				Get-Service -DisplayName 'AteraAgent' -ErrorAction SilentlyContinue | Remove-Service -ErrorAction SilentlyContinue
			}

			# In case powershell 7 cannot remote Atera or powershell 5 is present only follow removal with below
			if (Get-Service -DisplayName 'AteraAgent' -ErrorAction SilentlyContinue) {
				$ateraServiceController = [System.ServiceProcess.ServiceController]::new('AteraAgent')
				if ($ateraServiceController.Name -eq 'AteraAgent') {
					$serviceInstaller = [System.ServiceProcess.ServiceInstaller]::new()
					$serviceInstaller.ServiceName = 'AteraAgent'
					$serviceInstaller.Context = [System.Configuration.Install.InstallContext]::new($null, $null)
					$serviceInstaller.Uninstall($null)
				} else {
					Write-Output('[-] Atera service controller cannot be created, deleting with sc.exe')
					# Kept as fallback
					sc.exe delete AteraAgent
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
			Write-Output("[i] Creating directory : $($ateraDownloadPath)")
			New-Item $ateraDownloadPath -ItemType Directory -Force | Out-Null
			Write-Output('[+] Directory created')
		} else {
			Write-Output('[+] Download path exists.')
		}

		# Check if hostname is set to VDMS standard
		if ($env:COMPUTERNAME -eq "VDMS-$controllerId") {
			Set-Location -Path $ateraDownloadPath
			# Calculate FolderId key
			if ($controllerId.ToString().Length -lt 7) {
				$AteraFolderIndex = 1000
			} else {
				$AteraFolderIndex = [math]::Truncate($controllerId / 1000)
			}

			# If value from key cannot be obtained this portion of code creates new key with fallback value
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
		} elseif ($null -ne $script:ISRENAMESUCCESSFUL) {
			if ($script:ISRENAMESUCCESSFUL.NewComputerName -eq "VDMS-$controllerId") {
				Write-Output('[i] Restart required to set hostname before installing Atera')
			} else {
				Write-Error('[-] Cannot verify if SetHostname succeded')
			}
		} else {
			Write-Error('[-] Hostname not set to VDMS standard')
		}
	} catch {
		Write-Error("[-]  $($_.Exception.Message)")
	}
}
