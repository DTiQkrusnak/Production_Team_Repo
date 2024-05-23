function Remove-Application {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $True)]
		[string] $Pattern,

		[int32] $Timeout = 30
	)

	$registry_keys = @(
		'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
		'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
	)
	
	# Get regular programs
	$uninstall_objects = $registry_keys |
	Get-ChildItem |
	Get-ItemProperty

	$uninstall_objects | Where-Object {$_.DisplayName -like $Pattern} | ForEach-Object {
		try {
			if ($_.UninstallString -like 'MsiExec.exe*') {
                if ($_.UninstallString -like 'MsiExec.exe /I{*') {
                    $_.UninstallString = $_.UninstallString -replace ('/I{', '/X{')
                }
				$process = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/C', $_.UninstallString, '/qn') -PassThru -NoNewWindow
			} else {
				$process = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/C', $_.QuietUninstallString) -PassThru -NoNewWindow
			}
            if ($null -eq $process) {
                continue
            }
			Get-Process -InputObject $process -ErrorAction Stop | Wait-Process -Timeout $Timeout -ErrorAction Stop
		} catch {
			Write-Error($_)
			continue
		}
	}
}

Export-ModuleMember -Function 'Remove-Application'