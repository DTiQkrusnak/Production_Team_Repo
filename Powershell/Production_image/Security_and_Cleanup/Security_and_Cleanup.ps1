[Net.ServicePointManager]::SecurityProtocol = 'TLS12', 'SSL3'
$script:errorArray = @()


function blockWin11Upgrade () {
	<#
    .DESCRIPTION
	Blocks Windows 11 upgrade prompts and blocks version on 21H2
    #>

	$regPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
	$system = (Get-WMIObject win32_operatingsystem).Caption

	if ($system -like "*Windows*10*") {
		Write-Output("Executing fix")
		if (!(Test-path $regPath)) {
			New-Item -Path $regPath -Force
		}

		New-ItemProperty -Path $regPath -Name "ProductVersion" -value "Windows 10" -PropertyType String -Force | Out-Null
		New-ItemProperty -Path $regPath -Name "TargetReleaseVersion" -value 1 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path $regpath -Name "TargetReleaseVersionInfo" -value "21H2" -PropertyType String -Force | Out-Null
	}
	else {
		Write-Output("Script is executing fix only on Windows 10, your Windows : $system")
	}
}

function DisableWinUpdateIfAteraNotExists () {
	<#
	.DESCRIPTION
	Disable Windows Update service if Atera service is not present in the system
	#>
	$ateraRegistryKey = $winUpdateService = $null
	$ateraRegistryKey = Get-Item "registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent" -ErrorAction SilentlyContinue
	$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue

	# Checking if atera is present
	if (($null -ne $ateraRegistryKey) -and ($null -ne $ateraService)) {
		Write-Output("Atera installed - nothing to do.")
		Write-Output("Registery keys check : $ateraRegistryKey")
	}
	else {
		Write-Output("ALERT : ATERA NOT FOUND!! DISABLING WINDOWSUPDATE SERVICE!!!")
		$winUpdateService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue

		Write-Output("Disabling windows update service")
		$winUpdateService | Set-Service -StartupType "Disabled"
		Write-Output("    -> $($winUpdateService.DisplayName) service disabled")

		Write-Output("Stopping windows update service")
		$winUpdateService | Stop-Service -Force -ErrorAction SilentlyContinue
		Write-Output("    -> $($winUpdateService.DisplayName) service stopped")
		
		<#
		CHECK if 'BITS' and 'DoSvc' has to be disabled here as well
		#>
	}
}

function AteraInstall () {
	Write-Output("ATERA INSTALL")
	# Check if folder for downloads exists
	$path = 'C:\ProgramData\DTiQ\TaskScheduler\ateraInstall'
	if ((Test-Path $path) -eq $false) {
        Write-Output("Creating directory : $($path)")
        New-Item $path -ItemType Directory -Force | Out-Null
        Write-Output("    -> done")
    } else {
		Write-Output("Download path exists.")
	}
	
	# Download files
	$path = 'C:\ProgramData\DTiQ\TaskScheduler\ateraInstall'
	Invoke-WebRequest -Uri "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/ateraInstall/atera.exe" -OutFile "$path\atera.exe" -Verbose
	Invoke-WebRequest -Uri "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/ateraInstall/setup_final.msi" -OutFile "$path\setup_final.msi" -Verbose
	Write-Output("Files downloaded")

	# Get ControllerId from database EZ360Objects
	$getControllerIdQuery = @'
	SELECT TOP 1 *
	FROM [EZ360Objects].[Location].[Controllers]
	WHERE [Status] = 'Y'
'@
	$contrllerId = (Invoke-Sqlcmd -server '.\EZ360' -Query $getControllerIdQuery -QueryTimeout 30 -Database 'EZ360Objects' -Username 'EZ360System' -Password 'EZ360System').ControllerId
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

}