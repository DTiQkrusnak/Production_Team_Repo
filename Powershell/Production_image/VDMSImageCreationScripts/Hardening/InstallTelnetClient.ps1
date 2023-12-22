try {
    Enable-WindowsOptionalFeature -Online -FeatureName 'TelnetClient' -NoRestart -All -ErrorAction Stop
} catch {
    Write-Output($_.Exception.Message)
    Write-Output("Line: $($_.InvocationInfo.ScriptLineNumber)")
}