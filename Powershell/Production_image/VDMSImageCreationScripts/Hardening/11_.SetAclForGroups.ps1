#Requires -Modules NTFSSecurity
#Requires -RunAsAdministrator

$available_drives = (Get-PSDrive -PSProvider 'FileSystem' | Where-Object {$_.Used -ne ''}).Root

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

$pathsToDenyAccessForClient = @(
    "C:\VIDEO",
    "C:\DBCAMERA",
    "C:\EZVideoPlayerMovies",
    "C:\Program` Files` (x86)\EZUniverse",
    "C:\Program` Files\EZUniverse",
    "C:\onstartup",
    "C:\InfluxDB"
)
foreach($path in $pathsToDenyAccessForClient) {
    if (!(Test-Path -Path $path)) { continue }
    Get-ChildItem -Recurse -Path $path | Get-NTFSInheritance | Where-Object { -not $_.InheritanceEnabled } | Enable-NTFSAccessInheritance -RemoveExplicitAccessRules

    try {
        Add-NTFSAccess -AccessRights FullControl -Account $clientAccount -Path $path -AccessType Deny
    } catch {
        Write-Error($_)
    }
}

foreach ($drive in $available_drives) {
    if ($drive -eq 'C:\') {
        continue
    } else {
        try {
            Add-NTFSAccess -AccessRights FullControl -Account $clientAccount -Path $drive -AccessType Deny
        } catch {
            Write-Error($_)
        }
    }
}

$recycleBins = $available_drives | ForEach-Object {"$_`$Recycle.Bin"}
foreach ($recycleBin in $recycleBins) {
    if ((Test-Path -LiteralPath $recycleBin) -eq $True) {
        Remove-Item -LiteralPath $recycleBin -Recurse -Force
    }
}

$pathsToWhitelistForClient = @(
    "C:\Program` Files` (x86)\EZUniverse\360iQViewer",
    "C:\Program` Files` (x86)\EZUniverse\360iQPVMController"
)
foreach($path in $pathsToWhitelistForClient) {
    if (!(Test-Path -Path $path)) { continue }
    Get-ChildItem -Recurse -Path $path | Get-NTFSInheritance | Where-Object { -not $_.InheritanceEnabled } | Enable-NTFSAccessInheritance -RemoveExplicitAccessRules

    try {
        Disable-NTFSAccessInheritance -Path $path
        Add-NTFSAccess -AccessRights Modify -Account $clientAccount -Path $path -AccessType Allow
    } catch {
        Write-Error($_)
    }
}