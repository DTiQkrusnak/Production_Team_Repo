function removeApp {
    param (
        [string[]] $AppsToRemove
    )

    $RegKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
    )

    $Apps = $RegKeys |
    Get-ChildItem |
    Get-ItemProperty |
    Where-Object { $AppsToRemove -contains $_.DisplayName -and $_.UninstallString }

    if (!($Apps)) {
        Write-Output('Apps not found - probably already uninstalled, exiting script')
        exit
    }

    foreach ( $App in $Apps ) {
        $UninstallString =
        if ( $App.Uninstallstring -match 'MsiExec.exe' ) {
            "$( $App.UninstallString -replace '/I', '/X ' ) /qn /norestart"
        }
        else {
            $App.UninstallString + " /S"
        }
        Write-Output("Uninstalling app: $UninstallString")
        Start-Process -FilePath cmd -ArgumentList '/c', $UninstallString -NoNewWindow -Wait
    }
}


function uninstallApplication {
    param (
        [string] $Name
    )

    try {
        if (Get-Package -ProviderName Programs -IncludeWindowsInstaller -Name $Name -ErrorAction Stop) {
            Uninstall-Package -Name $Name -Confirm -Force
            Write-Output("Removed app: $Name")
        }
        if (Get-Package -ProviderName Programs -IncludeWindowsInstaller -Name $Name -ErrorAction Stop) {
            removeApp -AppsToRemove $Name
            Write-Output("Removed app: $Name")
        }
    } catch {
        Write-Output('Application package not found')
    }
}



uninstallApplication -Name '360iQPVMController'
try {
    Rename-Item -LiteralPath "C:\Program` Files` (x86)\EZUniverse\360iQPVMController\configuration.json" -NewName 'configurationBackup.securityLocked' -ErrorAction Stop
} catch {
    Write-Output("File already renamed or does not exist")
}