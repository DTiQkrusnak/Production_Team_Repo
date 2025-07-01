<#
    .SYNOPSIS
    Check if global variables are cleaned up and are no longer available

    .DESCRIPTION
    Even though this script is kind of redundant, as global variables should be removed automaticly (they are only available throughout session), 
    it might tell us that we shoud remove them as the last step during creation process.
#>

$verifyGlobalVar = @(
    "DTIQTEMPPATH"
)

function VerifyGlobalVariables($verifyGlobalVar) {
    <#
        .SYNOPSIS
        Check if GLOBAL variable is empty - desired result
    #>
    foreach ($globVar in $verifyGlobalVar) {
        if ($null -eq (Get-Variable $globVar -ErrorAction SilentlyContinue)) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "Variable is empty : `$$globVar"
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "Variable has not been emptied : " -NoNewline
            Write-Host "`$$globVar" -ForegroundColor Yellow
        }
    }
}

VerifyGlobalVariables $verifyGlobalVar