$auditPolicyArray = @(
    <#
        .DESCRIPTION
        this array contains proper values of audit policys; they should be set this way
    #>
    @("AuditSystemEvents", "3"),
    @("AuditLogonEvents", "3"),
    @("AuditObjectAccess", "0"),
    @("AuditPrivilegeUse", "3"),
    @("AuditPolicyChange", "3"),
    @("AuditAccountManage", "3"),
    @("AuditProcessTracking", "3"),
    @("AuditDSAccess", "0"),
    @("AuditAccountLogon", "3")
)

$secpolSettingsFile = "$DTIQTEMPPATH\secpolSettings_check.inf"
$secpolSettingsLog = "$DTIQTEMPPATH\secpolSettings_log.log"

function GetAuditPolicys($secpolSettingsFile) {
        Write-Host "Getting policies from secedit database..."
        $getPolicysProc = Start-Process "SecEdit.exe" -ArgumentList "/export", "/cfg", "$secpolSettingsFile", "/log", "$secpolSettingsLog", "/quiet"  -Wait -NoNewWindow -PassThru
        if ($getPolicysProc.ExitCode -ne "0") {
            Write-Error " [-] an ERROR occurred, please refer to logfile to see the error : $secpolSettingsLog"
        } else {
            Write-Host " [+] Policies exported"    
        }
        
}

function VerifyPolicies($secpolSettingsFile, $auditPolicyArray) {
    Write-Host "Verifying policies exactness..."
    $loadSecFileContent = Get-Content $secpolSettingsFile
    for ($i = 0; $i -lt $auditPolicyArray.Count; $i++) {
        $match = $auditPolicyArray[$i][0] + " = " + $auditPolicyArray[$i][1]
        if ($loadSecFileContent -match $match) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "$($auditPolicyArray[$i][0]) policy - properly set"
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "$($auditPolicyArray[$i][0]) policy - NOT properly set"
        }
    }
}

function clearTemp($DTIQTEMPPATH) {
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

GetAuditPolicys $secpolSettingsFile
VerifyPolicies $secpolSettingsFile $auditPolicyArray
clearTemp $DTIQTEMPPATH

