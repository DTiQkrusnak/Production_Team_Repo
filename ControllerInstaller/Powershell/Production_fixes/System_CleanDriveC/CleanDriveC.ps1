[System.Data.SqlClient.SqlConnection]::ClearAllPools()
[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'

# Can be changed if new version of zip is uploaded
[string] $pathPrefix = 'C:/ProgramData/EZUniverse/EZ360ControllerInstaller/Downloads/'
[string] $flirZip = 'flir-1.7.0.9.zip'
[string] $flirFolder = 'flir-1.7.0.9'
[string] $flirLogFile = 'flir-1.7.0.9.log'
[string] $foundAdminAccount = $null

[string[]] $listOfPossibleAdminAccounts = @(
    'dttserver',
    'Support'
)


[string] $queryForVDMS = @('
USE EZ360Objects;

UPDATE [EZ360Objects].[Controller].[Disks]
SET DedicatedForVideo = 0,
IsEnabled = 0
WHERE IsSystem = 1
')

[string] $queryForLegacy = @('
USE ezCamera;

UPDATE [ezCamera].[dbo].[Disks]
SET DedicatedForVideo = 0,
IsEnabled = 0
WHERE IsSystem = 1
')

[string[]] $pathsToDelete = @(
'C:\VIDEO\DBCAMERA',
'C:\DTiQTemp',
'C:\DttTemp',
'C:\DTTDVR',
'C:\Users\dttserver\Downloads',
'C:\Users\Administrator\TECH',
'C:\DualServer\log')

# hashtable that controls what files are deleted base on int value (days)
[hashtable] $pathsToDeleteWithDate = @{
    "C:\Program` Files\Microsoft` SQL` Server\MSSQL12.EZ360\MSSQL\Log" = -2;
    "C:\Program` Files` (x86)\EZUniverse\EZ360Controller\EZ360OffsiteStorageService\Logs" = -30;
    "C:\Program` Files\Microsoft` SQL` Server\120\Setup` Bootstrap\Log" = -2;
}

function CheckPowershellVersion {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Write-Output('Powershell version 5 verified')
    }
    else {
        throw 'Powershell 5 is not installed, exiting'
        exit -999
    }
}

function CheckControllerModelInDatabase {
    $connectionString ='Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    $getModelQuery = 'SELECT ModelId FROM [EZ360Objects].[Location].[Controllers]'

    try {
        $result = Invoke-Sqlcmd -ConnectionString $connectionString -Query $getModelQuery -ErrorAction Stop
    }
    catch {
        Write-Output('Cannot read model from EZ360 DB')
        $_
        exit -1
    }
    finally {
        [System.Data.SqlClient.SqlConnection]::ClearAllPools()

    }
    return $result.ModelId
}

function ExecuteQueryOnDatabase {
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateSet('Legacy', 'VDMS')]
        [string] $system,

        [string] $query
    )

    Write-Output("$system system found")

    if ($system -eq 'Legacy') {
        $hotConnectionString = 'Server=.\SQLEXPRESS;Database=master;User Id=sa;Password=universe;TrustServerCertificate=True'  
    }

    if ($system -eq 'VDMS') {
        $hotConnectionString = 'Server=.\EZ360;Database=master;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'  
    }

    try {
        Invoke-Sqlcmd -ConnectionString $hotConnectionString -Query $query -ErrorAction Stop
        return
    } catch {
        Write-Output('SQL query error', $_.Exception.Message)
        Write-Output('trying sqlcmd')
    }
    try {
        sqlcmd -S $SqlServer -U $SqlAuthLogin -P $SqlAuthPw -Q $query
        return
    } catch {
        Write-Output('Cannot disable drive C from video recording')
        return
    }

    #Possibly can be called in finally to clear all connections on error as well
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()
    Write-Output('Query executed')
}

function CheckAdminUsers {
    $users = Get-LocalUser
    foreach ($user in $listOfPossibleAdminAccounts) {
        if ($users.Name.Contains($user)) {
            return $user
            break
        } else {
            continue
        }
    }
}

function removeReadOnlyAttribute ([string] $Path) {
    try {
        if ((Get-ItemPropertyValue -Path $Path -Name IsReadOnly) -eq $False) {
            return
        } else {
            Set-ItemProperty -Path $Path -Name IsReadOnly -Value $False -ErrorAction Stop
        }
        
    } catch {
        Write-Output('Cannot remove read-only attribute from file', $Path)
    }
}

function changeAclOnFile([string] $Path, [string] $User) {
    try{
        # Get current file ACL and modify it so Builtin\Administrators group has ownership and full control over it
        $NewAcl = Get-Acl -Path $Path -ErrorAction Stop
        $identity = $env:computername + "\" + $User
        $fileSystemRights = 'FullControl'
        $type = 'Allow'

        $fileSystemAccessRuleArgumentList = $identity, $fileSystemRights, $type
        $fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $fileSystemAccessRuleArgumentList
        $Group = New-Object System.Security.Principal.NTAaccount('Builtin', 'Administrators')
        
        $NewAcl.SetAccessRuleProtection($false, $false)
        $NewAcl.SetAccessRule($fileSystemAccessRule)
        $NewAcl.SetOwner($Group)
        Set-Acl -Path $Path -AclObject $NewAcl -ErrorAction Stop
        $Path.Delete()
        removeReadOnlyAttribute($Path)
        return
    } catch {
        Write-Output("Cannot modify ACL on $Path")
        return
    }
    
}

function DeleteFiles {
    param (
        [Parameter(Mandatory)]
        [string] $path, 
        
        [int] $deleteUpToDays = 0
    )

    $date = (Get-Date).AddDays($deleteUpToDays)

    if ((Test-Path -Path $path) -eq $False) {continue}
    Push-Location $path
    if ((Test-Path -Path "$path\*") -eq $False) {
        Pop-Location
        return
    }
    try {
        $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Output("cannot get files list: $path")
        Pop-Location
        return
    }

    foreach ($file in $files) {
        if ((Get-ItemPropertyValue -Path $file.FullName -Name LastAccessTime) -gt $date) {
            continue
        }

        try {
            removeReadOnlyAttribute($file.FullName)
            $file.Delete()
            if ((Test-Path -Path $file.FullName) -eq $False) {continue}
        } catch {
            Write-Output('Path still exists: ', $file.FullName)
        }
        try {
            changeAclOnFile -Path $file.FullName -User $foundAdminAccount
            $file.Delete()
            if ((Test-Path -Path $file.FullName) -eq $False) {continue}
        } catch {
            Write-Output('Cannot remove with ACL method', $file.FullName)
        }
    }
    Write-Output("Removed: $path")
    Pop-Location
}

function CleanRecycleBin {
    try{
        Set-Location -Path 'C:' -ErrorAction Stop
        Clear-RecycleBin -DriveLetter 'C:' -Confirm:$false -ErrorAction Stop
        Write-Output("Recycle bin emptied")
    } catch {
        Write-Output("Cannot empty recycle bin")
    }
}

function DownloadFlir {
    Write-Output('Downloading Flir files')
    Set-Location -Path $pathPrefix
    try {
        Invoke-WebRequest -Uri 'https://files-us-ps2.go360iq.com/_Files/Software/FLIR/flir-1.7.0.9.zip' -OutFile $flirZip
        Write-Output('FLIR Files downloaded')
    }
    catch {
        $_
    }
}

function ExtractFlirZip {
    Write-Output('Unzipping downloaded Flir archive file')
    try {
        Expand-Archive -Path $flirZip -DestinationPath $flirFolder -Force
        Write-Output('Unzipping successfull')
    }
    catch {
        $_
    }
}

function RunFlir {
    [string[]]$flirArguments = '-f', '--f-clean-unlinked-files', '--f-clean-expired-files', '--f-clean-not-existing-files'

    try {
        # Run flir with parameters
        Start-Process -FilePath "$flirFolder\\flir.exe" -ArgumentList $flirArguments -RedirectStandardOutput $flirLogFile -NoNewWindow -Wait
        Write-Output('Flir successfully deployed')
    }
    catch {
        $_
    }
    Write-Output('FLIR Finished')
}

function PostFlirCleanup {
    $flirPathExtensions = @(
        $flirZip,
        $flirFolder,
        $flirLogFile
    )

    try {
        # Cleanup files after actions
        foreach ($path in $flirPathExtensions) {
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Recurse -Force
            }
        }
        Write-Output('FLIR Files removed')
    }
    catch {
        $_
    }
}

function RunDiskCleaner {
    try {
        Start-Process -FilePath 'cleanmgr' -ArgumentList @('/sagerun:1', '/VeryLowDisk', '/SETUP', '/AUTOCLEAN') -WorkingDirectory 'C:'
        Write-Output('Disk cleanup finished')
    }
    catch {
        $_
    }
}

# Main flow
CheckPowershellVersion
$model = CheckControllerModelInDatabase
if ($model -ge 4) { ExecuteQueryOnDatabase -system 'VDMS' -query $queryForVDMS }
if ($model -le 2) { ExecuteQueryOnDatabase -system 'Legacy' -query $queryForLegacy }

$foundAdminAccount = CheckAdminUsers
if($null -eq $foundAdminAccount) { exit -20}

foreach ($path in $pathsToDelete) {
    DeleteFiles -path $path
}

foreach ($path in $pathsToDeleteWithDate.GetEnumerator()) {
    DeleteFiles -path $path.Name -deleteUpToDays $path.Value
}

CleanRecycleBin
DownloadFlir
ExtractFlirZip
RunFlir
PostFlirCleanup
#RunDiskCleaner