function Get-UserSID([string] $Username) {
	$sid = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
	if ($null -eq $sid) {
		return $null
	}
	return $sid.SID.Value
}

function Get-UserHive([string] $Username) {
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
	param (
		[Parameter(Mandatory)] [string] $Username,
		[Parameter(Mandatory)] [string] $hivePath,
		[int] $timeout = 20
	)

	if (Get-IsUserLoggedIn -Username $Username) {
		return
	}

	for ($i = 0; $i -lt $timeout; $i++) {
		$out = Start-Process -FilePath 'reg' -ArgumentList 'unload', $hivePath -PassThru
		$out.WaitForExit()
		if (0 -eq $out.ExitCode) { return }
	}

	throw 'Timed out on hive closing'
}

function Get-IsUserLoggedIn() {
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

function Start-Verification() {
    # OPENING
    $hivePath = Get-UserHive -Username '360iQClient'
	New-PSDrive -Name 'HKU_360iQClient' -PSProvider Registry -Root $hivePath | Out-Null
	Set-Location -Path 'HKU_360iQClient:'
	$userHiveRoot = Get-Location -PSDrive 'HKU_360iQClient'

    # VERIFICATION
    $key = "$userHiveRoot\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    $isKeyPresent = Get-ItemPropertyValue -LiteralPath $key -Name 'DisableSearchBoxSuggestions'
    if(1 -eq $isKeyPresent) {
        Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
        Write-Host " DisableSearchBoxSuggestions exists"
    } else {
        Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
        Write-Host "DisableSearchBoxSuggestions does not exist"
    }

    # CLOSURE
    Set-Location -Path 'C:'
	Close-UserHive -Username '360iQClient' -hivePath $userHiveRoot.ProviderPath
	Remove-PSDrive -Name 'HKU_360iQClient'
}

Start-Verification