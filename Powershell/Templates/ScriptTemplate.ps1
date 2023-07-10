<#
Exit code dictonary:
	exit 10 - sql EZ360 instance not present
	exit 666 - powershel v.5 is not installed
	...
#>

$scriptVer = "0.1"
$scriptName = "Template"
$scriptDescr = "This is a template which will be used as a future base for scripts"
Write-Output("SCRIPT DESCRIPTION: $scriptName v.$scriptVer")
Write-Output("SCRIPT DESCRIPTION: $scriptDescr")

# Variables
$PShellVer = $PSVersionTable.PSVersion.Major




function executeScript {
	param(
		[int]$PShellVer
	)
	if ($PShellVer -ge 5) {
		Write-Output("Powershell.v.5 found - executing script")
	}
	else {
		Write-Output("PowerShell.v.5 is not installed - skipping script ")
	}
}

executeScript $PShellVer
