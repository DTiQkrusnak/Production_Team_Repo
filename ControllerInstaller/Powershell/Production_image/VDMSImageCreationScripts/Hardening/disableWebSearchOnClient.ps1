<#
	.SYNOPSIS
	- Load hive of another user
		- if user is logged in use hive by sid
		- if user is not logged in, load hive

	- Create PSDrive for given hive
	- Add registry key to disable Windows 10/11 online search
	- Close hive if user was not logged in
#>


function Disable-WebSearch() {
	<#
	.SYNOPSIS
	Add registry key to client user hive to disable online search in Windows 10/11
	#>
	param (
		[Parameter(Mandatory)] [string] $RegistryHkuRoot
	)
	$key = "$RegistryHkuRoot\SOFTWARE\Policies\Microsoft\Windows\Explorer"
	if (-not (Resolve-Path $key)) {
		New-Item $key
	}

	$isPropertyPresent = Get-ItemPropertyValue -LiteralPath $key -Name 'DisableSearchBoxSuggestions'
	if (1 -eq $isPropertyPresent) {
		return
	}
	New-ItemProperty -LiteralPath $key -Name 'DisableSearchBoxSuggestions' -PropertyType Dword -Value 1 -Force
}

function Get-UserSID([string] $Username) {
	<#
	.SYNOPSIS
	Convert username to it's coresponding SID
	#>
	$sid = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
	if ($null -eq $sid) {
		return $null
	}
	return $sid.SID.Value
}

function Get-UserHive([string] $Username) {
	<#
	.SYNOPSIS
	Check if hive with provided username is already loaded (user is logged in)
	Returns: Powershell path to hive (Registry::HKU\<SID>)
	#>
	$sid = Get-UserSID -Username $Username
	if (-not($sid)) {
		throw "Cannot get $Username account SID"
		return $null
	}

	$isHiveAlreadyLoaded = Get-ChildItem -LiteralPath "Registry::\HKEY_USERS\$sid" -ErrorAction SilentlyContinue
	if (-not($isHiveAlreadyLoaded)) {
		$userHivePath = Resolve-Path "$env:USERPROFILE\..\$Username\NTUSER.DAT"
		#reg load "HKU\$sid" $userHivePath > $null 2> $null
		$out = Start-Process -FilePath 'reg' -ArgumentList 'load', "HKU\$sid", $userHivePath -PassThru
		$out.WaitForExit()
	}

	if ($out.ExitCode -eq 1) {
		throw 'User hive not loaded'
		return $null
	}

	return [string] "Registry::HKU\$sid"
}

function Close-UserHive() {
	<#
	.SYNOPSIS
	Close hive that was previously loaded, if user is logged in hive is left as is
	#>
	param (
		[Parameter(Mandatory)] [string] $Username,
		[Parameter(Mandatory)] [string] $hivePath,
		[int] $timeout = 20
	)

	if (Get-IsUserLoggedIn -Username $Username) {
		return
	}

	for ($i = 0; $i -lt $timeout; $i++) {
		[gc]::Collect()
		$out = Start-Process -FilePath 'reg' -ArgumentList 'unload', $hivePath -PassThru
		$out.WaitForExit()
		if (0 -eq $out.ExitCode) { return }
	}

	throw 'Timed out on hive closing'
}

function Get-IsUserLoggedIn() {
	<#
	.SYNOPSIS
	Return boolean if requested user is currently logged in
	#>
	param (
		[Parameter(Mandatory)] [string] $Username
	)

	$loggedInUsers = $(query user)
	$foundCount = $loggedInUsers | Select-String $Username

	if ($null -eq $foundCount) {
		return $false
	}
	return $true
}

function Start-Program() {
	$hivePath = Get-UserHive -Username '360iQClient'
	New-PSDrive -Name 'HKU_360iQClient' -PSProvider Registry -Root $hivePath | Out-Null
	Set-Location -Path 'HKU_360iQClient:'
	$userHiveRoot = Get-Location -PSDrive 'HKU_360iQClient'

	Disable-WebSearch -RegistryHkuRoot $userHiveRoot

	Set-Location -Path 'C:'
	
	Close-UserHive -Username '360iQClient' -hivePath $userHiveRoot.ProviderPath
	Remove-PSDrive -Name 'HKU_360iQClient'
}

Start-Program