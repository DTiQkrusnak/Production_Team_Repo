<#
    .SYNOPSIS
    Set proper audit policys.

    .DESCRIPTION
    Script will set proper audit policies documented in image creation checklist.
#>

# variables used in functions
$secpolSettingsFile = "$DTIQTEMPPATH\secpolSettings.inf"
$secpolSettingsLog = "$DTIQTEMPPATH\secpolSettings_log.log"
    
function SaveSecpolSettings($secpolSettingsFile, $secpolSettingsLog) {
    <#
    .SYNOPSIS
    Create file so it can be loaded by secedit application.

    .DESCRIPTION
    Script uses secedit windows app to change policys but as its very old it needs a file as input (you cant pass a variable).
    Thats why first script creates file secpolSettings.inf with $secpolSettings content 

    .NOTES
    You can check changes in secpol.msc -> "Security Settings" -> "Local Policies" -> "Audit Policy"
#>
    $secpolSettings = @'
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
    
[Event Audit]
AuditSystemEvents = 3
AuditLogonEvents = 3
AuditObjectAccess = 0
AuditPrivilegeUse = 3
AuditPolicyChange = 3
AuditAccountManage = 3
AuditProcessTracking = 3
AuditDSAccess = 0
AuditAccountLogon = 3
'@
    
    try {
        Write-Host "Creating `"secpolSettings.inf`" file with policys"
        New-Item $secpolSettingsFile -Value $secpolSettings -ItemType File -Force | Out-Null
        Write-Host " [+] Configuration file has been created : $secpolSettingsFile"
    }
    catch {
        Write-Error " [-] Configuration file has been created : $secpolSettingsFile"
        Write-Error "$($_.Exception.Message)"
    }
}
function ModifyAuditPolicys($secpolSettingsFile, $secpolSettingsLog) {
    <#
    .SYNOPSIS
    Configure Audit Policys with $secpolSettingsFile

    .DESCRIPTION
    Run the SecEdit.exe and modify the local secpol database with $secpolSettingsFile

    .NOTES
    You can check changes in secpol.msc -> "Security Settings" -> "Local Policies" -> "Audit Policy"
#>

    Write-Host "Modifying secedit.sdb with new changes"
    
    $secpolProc = Start-Process SecEdit.exe -ArgumentList "/configure", "/db", "$env:temp\secedit.sdb", "/cfg", "$secpolSettingsFile", "/overwrite", "/log", "$secpolSettingsLog", "/quiet" -Wait -PassThru -NoNewWindow  
    if ($secpolProc.ExitCode -ne 0) {
        Write-Error " [-] an ERROR occurred, please refer to logfile to see the error : $secpolSettingsLog"
        Write-Error "SecEdit.exe exited with status code $($secpolProc.ExitCode)"
        break
    }
    else {
        Write-Host " [+] Changes applied to system"
    }
}
    
function ClearTemp($DTIQTEMPPATH) {
    <#
            .SYNOPSIS
            Cleanup - remove downloaded setup files in this script.
        #>
    try {
        Write-Host "[CLEANUP] Removing files from directory"
        Remove-Item "$DTIQTEMPPATH\*" -Recurse -Force -Confirm:$false | Out-Null
        Write-Host " [+] Files removed"
    }
    catch {
        Write-Host " [-] an ERROR occurred :" -ForegroundColor Red
        Write-Error "$($_.Exception.Message)"  
    }
}
    
SaveSecpolSettings $secpolSettingsFile $secpolSettingsLog
ModifyAuditPolicys $secpolSettingsFile $secpolSettingsLog
ClearTemp $DTIQTEMPPATH