#Remove-NetFirewallRule
$RulesVar = Get-NetFirewallRule

function GetFirewallRules ($RulesVar) {
    <#
        .SYNOPSIS
        Script will check if rules IN\OUT have been deleted.
        
        .NOTES
        During tests it came to attention that after a brief time some rules are being automaticly created
        - in else if statement i just chose 10 as the max rules that might appear without users interaction.
    #>
    if (($RulesVar).Count -eq '0') {
        Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
        Write-Host "Rules completely removed"
    }
    elseif ((($RulesVar).Count -ge '1') -and (($RulesVar).Count -lt '10')) {
        # 10 is just a number i thought of
        Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
        Write-Host "Rules removed, but some of them have been created automaticly, number of existing rules : $(($RulesVar).Count)"
        Write-Warning " [+] most likely rules have been created autoamticaly (i.e. TaskScheduler) - after a period :" 
        foreach ($rule in $RulesVar) {
            Write-Warning "   -> $($rule.DisplayName) | ($($rule.Group))"
        }
    }
    else {
        Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
        Write-Host "more than 10 rules exist as firewall policies"
    }
}

GetFirewallRules $RulesVar