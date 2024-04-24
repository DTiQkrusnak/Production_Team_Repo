$ErrorActionPreference = 'Stop'

$controllerDownloadPath = 'C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads'
$script:connectionStringSqlexpress = 'Server=.\SQLEXPRESS;Database=EZController;User Id=sa;Password=universe;TrustServerCertificate=True'
$script:connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
$script:RemoveDaysLessThan = 30

$hotfixesLegacy = [FileDownloadInformation]@{
    Name = 'hotfix_90.sql'
    Link = 'https://files-us-ps2.go360iq.com/_Files/Software/Hotfix/0090/patch.sql'
    Hash = '02F8EAB9FCC5095C9B84A209C9E40FAB4D5D66CD51630FCA7D72B2599BA6B31E'
}, [FileDownloadInformation]@{
    Name = 'hotfix_91.sql'
    Link = 'https://files-us-ps2.go360iq.com/_Files/Software/Hotfix/0091/patch.sql'
    Hash = '47A977000453151669D38A8990AB1AD55C07CF8EBE1AB6DD079D8F975932886F'
}

$hotfixesVDMS = [FileDownloadInformation]@{
    Name = 'vdms_hotfix.sql'
    Link = 'https://files-us-ps2.go360iq.com/_Files/Software/Scripts/VDMS_GDPR/vdms_gdpr.sql'
    Hash = '6A36961A08A7DCE60C79792A0B3AAC29CA90607C2E9621B14A486E8C995ADD6F'
}

$flirFiles = [FileDownloadInformation]@{
    Name = 'flir-1.7.0.9.zip'
    Link = 'https://s3.amazonaws.com/files-us-ps2.go360iq.com/_Files/Software/FLIR/flir-1.7.0.9.zip'
    Hash = '4EB6B5B32FF3A1685DE137592A595F1E77F5D9034913DD9D259234AB9605F0D8'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function DownloadAndVerify([FileDownloadInformation] $fileInfo) {
    Invoke-WebRequest -Uri $fileInfo.Link -OutFile $fileInfo.Name -ErrorAction Continue
    if (Test-Path $fileInfo.Name) {
        $downloadHash = Get-FileHash -Path $fileinfo.Name -Algorithm SHA256
        if ($downloadHash -eq $fileInfo.Hash) {
            $fileInfo.Success = $true
            Write-Output("$($fileInfo.Name) downloaded")
        }
        Write-Output("$($fileInfo.Name) hash is not matching")
        Write-Output("Download: $($downloadHash)")
        Write-Output("Expected: $($fileInfo.Hash)")
        return
    }
    Write-Output("Cannot download: $($fileInfo.Name)")
}

function ExecuteSql([FileDownloadInformation] $fileinfo, [string] $connectionString) {
    try {
        Invoke-Sqlcmd -ConnectionString $connectionString -InputFile $fileinfo.Name -QueryTimeout 10
    } catch {
        Install-Module -Name SqlServer -AllowClobber -Confirm:$false -Force
        Import-Module -Name SqlServer
        Invoke-Sqlcmd -ConnectionString $connectionString -InputFile $fileinfo.Name -QueryTimeout 10
    }
    Write-Output("$($fileInfo.Name) executed")
}

class FileDownloadInformation {
    [ValidateNotNullOrEmpty()][string] $Name
    [ValidateNotNullOrEmpty()][string] $Link
    [ValidateNotNullOrEmpty()][string] $Hash
    [boolean] $Success = $false
}

function Get-DvrType() {
    $ControllerInformation = Get-Item 'Registry::HKLM\SOFTWARE\EZUniverse\EZ360ControllerInstaller' -Force
    return $ControllerInformation.GetValue('ControllerModel')
}

function DownloadAndExecuteSqlHotfix([FileDownloadInformation[]] $hotfixes, [string] $connectionString) {
    foreach ($hotfix in $hotfixes) {
        DownloadAndVerify $hotfix
        if ($hotfix.Success) {
            ExecuteSql $hotfix $connectionString
        }
    }
}

function Get-DateWithParameterOffset($offset = 0) {
    $dateWithOffset = (Get-Date).AddDays(-$offset)
    return $dateWithOffset
}

function BuildFootageResetQuery([string] $Database,[datetime] $Date) {
    $rawQueryCameraFile = @"
    UPDATE [$($Database)].[dbo].[CameraFile]
    SET MarkedForDeletion = NULL
    WHERE [Date] < '$($Date.ToString('yyyy-MM-dd'))'
"@
    $rawQueryCameraFileDisks = @"
    UPDATE [$($Database)].[dbo].[CameraFileDisks]
    SET MarkedForDeletion = 0, ValidTo = NULL
"@

    return ($rawQueryCameraFile, $rawQueryCameraFileDisks)
}

function ExecuteFootageResetSqlQuery([string] $Database, [datetime] $offset, [string] $connectionString) {
    $queries = BuildFootageResetQuery -Database $Database -Date $offset
    foreach ($query in $queries) {
        Invoke-SqlCmd -Query $query -ConnectionString $connectionString -QueryTimeout 10 -ErrorAction SilentlyContinue
    }
}

function checkIfToBeRemoved([string] $folderName, [DateTime] $dateToRemove) {
    $folderDate = [datetime]::ParseExact($folderName, 'yyyyMMdd', $null)
    if ($folderDate -lt $dateToRemove) {
        return $True
    }
    else {
        return $False
    }
}

function CleanDrivesFromFootage([DateTime] $dateToRemove) {
    $drives = Get-PSDrive -PSProvider FileSystem
    $videoPaths = @()

    foreach ($drive in $drives) {
        if (Test-Path -LiteralPath "$($drive):\VIDEO\DBCAMERA") {
            $videoPaths += "$($drive):\VIDEO\DBCAMERA"
        }
    }

    foreach ($videoPath in $videoPaths) {
        try {
            $folders = Get-Item "$($videoPath)\*"
            foreach ($folder in $folders) {
                if ($folder.Name -eq 'TEMP') { continue }
                $doWeRemove = checkIfToBeRemoved $folder.Name $dateToRemove
                if ($doWeRemove) {
                    Remove-Item -Path $folder -Recurse -Force
                    Write-Output("[+] Removed $($folder.FullName)")
                }
            }
        } catch {
            continue
        }
    }
    Write-Output('[+] footage cleaned from drives')
}

function ExecuteFlir() {
    DownloadAndVerify $flirFiles
    Expand-Archive $flirFiles.Name -Force
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/c START /B .\flir-1.7.0.9\flir.exe -f --f-clean-unlinked-files --f-clean-expired-files --f-clean-not-existing-files > C:\DTIQ\log.txt' -WindowStyle Hidden
    Write-Output('[+] Flir executed')
}

function mainExecution() {
    $dateWithOffset = Get-DateWithParameterOffset($script:RemoveDaysLessThan)
    $dvrType = Get-DvrType
    
    if (-not (Test-Path $controllerDownloadPath)) {
        New-Item -Path $controllerDownloadPath -Force -ItemType Directory | Out-Null
    }
    
    Push-Location $controllerDownloadPath
    
    try {
        if ($dvrType -like '*VDMS*') {
            Write-Output('[i] Executing VDMS procedure:')
            DownloadAndExecuteSqlHotfix $hotfixesVDMS $script:connectionStringEz360
            ExecuteFootageResetSqlQuery 'EZ360Video' $dateWithOffset $script:connectionStringEz360
        }
        elseif ($dvrType -like '*Legacy*') {
            Write-Output('[i] Executing Legacy procedure:')
            DownloadAndExecuteSqlHotfix $hotfixesLegacy $script:connectionStringSqlexpress
            ExecuteFootageResetSqlQuery 'EZCamera' $dateWithOffset $script:connectionStringSqlexpress
        }
        else {
            Write-Output('[i] System unknown - skipping')
        }
    } catch {
        Write-Output("[-] query execution not successfull")
    }
    CleanDrivesFromFootage $dateWithOffset
    ExecuteFlir
    Pop-Location
}

try {
    mainExecution
} catch {
    Write-Output("[-] $($_.Exception.Message)")
}