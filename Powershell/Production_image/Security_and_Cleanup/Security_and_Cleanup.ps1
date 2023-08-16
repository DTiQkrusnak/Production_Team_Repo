$script:errorArray = @()
function blockWin11Upgrade () {
	<#
    .DESCRIPTION Blocks Windows 11 upgrade prompts and blocks version on 21H2
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
	$ateraRegistryKey = $winUpdateService = $null
	$ateraRegistryKey = Get-Item "registry::HKEY_LOCAL_MACHINE\SOFTWARE\ATERA Networks\AlphaAgent" -ErrorAction SilentlyContinue
	$ateraService = Get-Service -Name 'AteraAgent' -ErrorAction SilentlyContinue
    
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
	} 
}