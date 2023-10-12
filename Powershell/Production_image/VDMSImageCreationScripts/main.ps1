$ErrorActionPreference = 'Stop'

$scriptsLocation = $PSScriptRoot + "\scripts"
$logsLocation = $PSScriptRoot + "\scripts\logs\"
$scriptsCollection = Get-ChildItem -Path $scriptsLocation\*.ps1 | Sort-Object -Property Name


function New-LogsDir {
	if (!(Test-Path $logsLocation)) {
		New-Item -Path $scriptsLocation -ItemType Directory -Name logs | Out-Null
		if (!(Test-Path $logsLocation\main.log)) {
			New-Item -Path $scriptsLocation\logs -ItemType File -Name main.log | Out-Null
		}
	}
}
function Invoke-Scripts {
	foreach ($script in $scriptsCollection) {
		Write-output "$(Get-Date -format 'u') - ========> Log start : $script" | Tee-Object -Append $scriptsLocation\logs\main.log
		powershell -noprofile -executionpolicy bypass -file $script | Tee-Object -Append $scriptsLocation\logs\main.log
		Write-output "$(Get-Date -format 'u') - ========> Log end : $script" | Tee-Object -Append $scriptsLocation\logs\main.log
		Write-output "" | Tee-Object -Append $scriptsLocation\logs\main.log
		#$script
	}
}

if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Output('[+] Script is running with administrator priviledges') | Tee-Object -Append $scriptsLocation\logs\main.log
	New-LogsDir
	Invoke-Scripts
}