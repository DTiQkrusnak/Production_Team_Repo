<#
    .SYNOPSIS
    Global variables dictionary

    .DESCRIPTION
    This file should contain a definition of global variables which can be used 

    .NOTES
    https://blog.enterprisedna.co/powershell-global-variable/

#>

$global:DTIQTEMPPATH = 'C:\DTiQ_temp\' #directory to store any file downloaded from web


function execute_DTIQTEMPPATH {
    <#
        .SYNOPSIS
        Create directory for storing files downloaded from the web.

        .DESCRIPTION
        In this directory we should store any files during any download function.

        .NOTES
        $DTIQTEMPPATH is a global variable and it can be used outside function

    #>
    if (!(Test-Path $DTIQTEMPPATH)) {
        try {
            Write-Host "Creating directory"
            New-Item -Path $DTIQTEMPPATH -ItemType Directory -Force | Out-Null
            Write-Host " [+] Directory created : $DTIQTEMPPATH"
        }
        catch {
            Write-Error " [-] $($_.Exception.Message)"
            exit 1
        }
    }
}

execute_DTIQTEMPPATH