
function uninstallApplication {
    param (
        [string] $Name
    )

    try {
        if (Get-Package -ProviderName Programs -IncludeWindowsInstaller -Name $Name -ErrorAction Stop) {
            Uninstall-Package -Name $Name -Confirm -Force
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