#Requires -Modules NTFSSecurity

$pathsToDenyAccessForClient = @(
    "C:\VIDEO",
    "C:\DBCAMERA",
    "C:\EZVideoPlayerMovies",
    "C:\Program` Files` (x86)\EZUniverse",
    "C:\Program` Files\EZUniverse",
    "C:\onstartup",
    "C:\InfluxDB"
)

$listOfPossibleClientAccounts = @(
    '360iQClient'
    , 'Subway'
    #,'dtiquser'# TEMPORARILY DISABLED
)

#------- FUNCTIONS SETUP -------
function Get-ClientAccount {
    # Find all active users that match provided list, useful for finding multiple admin or client accounts
    param (
        <#
            PARAMETERS
            _______
            Users | All account names to look for in enabled accounts list
        #>
        [Parameter(Mandatory, ValueFromPipeline)] [string[]] $Users
    )

    process {
        $foundUsers = @()
        $enabledUserNames = (Get-LocalUser | Where-Object Enabled -eq $True).Name
        foreach ($user in $Users) {
            if ($enabledUserNames.Contains($user)) {
                $foundUsers += $user
            }
        }
        return $foundUsers
    }
}

$clientAccount = Get-ClientAccount -Users $listOfPossibleClientAccounts

foreach($path in $pathsToDenyAccessForClient) {
    if (!(Test-Path -Path $path)) {
        Write-Host " [NOT FOUND] " -NoNewline -ForegroundColor Yellow
        Write-Host " Path does not exist: $path "
        continue
    }

    if ($null -ne (Get-NTFSAccess -Path $path -Account $clientAccount)) {
        Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
        Write-Host " Deny rule on path: $path"
    } else {
        Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
        Write-Host " Deny rule not present on path: $path" -NoNewline
    }
}