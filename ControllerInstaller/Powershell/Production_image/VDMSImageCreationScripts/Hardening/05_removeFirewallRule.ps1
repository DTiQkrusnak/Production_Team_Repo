<#
    .SYNOPSIS
    Script will remove all firewall rules (incoming\outgoing)
#>

Write-Host "Deleting rules in firewall"
try {
    Remove-NetFirewallRule -All
    Write-Host " [+] rules deleted succesfully"    
}
catch {
    Write-Host " [-] an ERROR occurred :" -ForegroundColor Red
    Write-Error "$($_.Exception.Message)"
    exit 1
}
