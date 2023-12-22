if ('Enabled' -eq (Get-WindowsOptionalFeature -Online -FeatureName 'TelnetClient').State) {
    Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
    Write-Host " Telnet Client is installed"
} else {
    Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
    Write-Host " Telnet Client is disabled "
}