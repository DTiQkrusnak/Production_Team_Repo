$ErrorActionPreference = 'Stop'

[string] $script:controllerDownloadPath = 'C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads'
[string] $script:GdprDownloadPath = 'C:\DTIQ\EU-GDPR'
[string] $script:connectionStringSqlexpress = 'Server=.\SQLEXPRESS;Database=EZController;User Id=sa;Password=universe;TrustServerCertificate=True'
[string] $script:connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
$script:RemoveDaysLessThan = 30

class FileDownloadInformation {
    [ValidateNotNullOrEmpty()][string] $Name
    [ValidateNotNullOrEmpty()][string] $Link
    [ValidateNotNullOrEmpty()][string] $SHA256Hash
    [boolean] $Success = $false
    [string] $SavedAtPath = $null
}

$hotfixesLegacy = [FileDownloadInformation]@{
    Name = 'hotfix_90.sql'
    Link = 'https://files-us-ps2.go360iq.com/_Files/Software/Hotfix/0090/patch.sql'
    SHA256Hash = '02F8EAB9FCC5095C9B84A209C9E40FAB4D5D66CD51630FCA7D72B2599BA6B31E'
}, [FileDownloadInformation]@{
    Name = 'hotfix_91.sql'
    Link = 'https://files-us-ps2.go360iq.com/_Files/Software/Hotfix/0091/patch.sql'
    SHA256Hash = '47A977000453151669D38A8990AB1AD55C07CF8EBE1AB6DD079D8F975932886F'
}

$hotfixesVDMS = [FileDownloadInformation]@{
    Name = 'vdms_hotfix.sql'
    Link = 'https://files-us-ps2.go360iq.com/_Files/Software/Scripts/VDMS_GDPR/vdms_gdpr.sql'
    SHA256Hash = '6A36961A08A7DCE60C79792A0B3AAC29CA90607C2E9621B14A486E8C995ADD6F'
}

$flirFiles = [FileDownloadInformation]@{
    Name = 'flir-1.7.0.9.zip'
    Link = 'https://s3.amazonaws.com/files-us-ps2.go360iq.com/_Files/Software/FLIR/flir-1.7.0.9.zip'
    SHA256Hash = '4EB6B5B32FF3A1685DE137592A595F1E77F5D9034913DD9D259234AB9605F0D8'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Invoke-DownloadAndVerify {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [string] $DownloadPath,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [FileDownloadInformation] $FileInfo,

        [Int32] $Timeout = 30
    )

    function Test-ForExistingFile([FileDownloadInformation] $FileInfo, [string] $DownloadPath ) {
        if (Test-Path -Path $FileInfo.Name -PathType Leaf) {
            $FileInfo.SavedAtPath = $DownloadPath
            $downloadHash = Get-FileHash -Path $FileInfo.Name -Algorithm SHA256
            if ($downloadHash.Hash -eq $FileInfo.SHA256Hash) {
                $FileInfo.Success = $true
                return $true
            } else {
                Write-Error("Hash mismatch for $($FileInfo.Name). Download: $($downloadHash.Hash), Expected: $($FileInfo.SHA256Hash)")
                return $false
            }
        } else {
            return $false
        }
    }

    try {
        Push-Location -LiteralPath $DownloadPath
        if (Test-ForExistingFile -FileInfo $FileInfo -DownloadPath $DownloadPath) {
            return
        } else {
            Invoke-WebRequest -Uri $FileInfo.Link -OutFile $FileInfo.Name -TimeoutSec $Timeout -ErrorAction Stop
            if (Test-ForExistingFile -FileInfo $FileInfo -DownloadPath $DownloadPath) {
                return
            } else {
                Write-Error("Cannot download $FileInfo")
            }
        }
    } catch {
        throw $_
    } finally {
        Pop-Location
    }
}

function Expand-ArchiveWithFallback {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf })]
        [ValidateScript({ (Split-Path $_ -Leaf).EndsWith('.zip')})] [string] $Path,
        [ValidateScript({Test-Path -Path $_ -PathType Container -IsValid})] [string] $DestinationPath = $null
    )

    if (!$DestinationPath) {
        $DestinationPath = $Path -replace ('.zip', '')
    }

    try {
        if (!(Test-Path -Path $DestinationPath)) {
            New-Item -Name ((Split-Path -Path $DestinationPath -Leaf) -replace ('.zip','')) -Force -ItemType Container | Out-Null
        }
        Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force
    } catch {
        try {
            Remove-Item -Path $DestinationPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            [System.IO.Compression.ZipFile]::ExtractToDirectory( $Path, $DestinationPath)
        } catch {
            throw $_
        }
    }
}

function Invoke-ExecuteSql {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        ParameterSetName="With query")]
        [ValidateNotNullOrEmpty()]
        [string] $Query,

        [Parameter(Mandatory=$true,
        ParameterSetName="With input file")]
        [ValidateNotNullOrEmpty()]
        [string] $InputFile,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConnectionString,

        [int] $QueryTimeout = 10
    )

    try {
        if ($Query) {
            $data = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $Query -QueryTimeout $QueryTimeout -ErrorAction Stop
        } else {
            $data = Invoke-Sqlcmd -ConnectionString $ConnectionString -InputFile $InputFile -QueryTimeout $QueryTimeout -ErrorAction Stop
        }
        return $data
    } catch {
        try {
            [System.Data.SqlClient.SqlConnection]::ClearAllPools()
            $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection -ArgumentList $ConnectionString
            if ($connection.State -ne 'Open') {
                $connection.Open()
            }

            if ($InputFile) {
                $Query = Get-Content -Path $InputFile -Raw -Force
            }
            $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
            $command.CommandText = $Query
            $command.Connection = $connection
            $command.CommandTimeout = $QueryTimeout

            $adp = New-Object System.Data.SqlClient.SqlDataAdapter $sqlcmd
            $adp.SelectCommand = $command
            $data = New-Object System.Data.DataSet
            $adp.Fill($data) | Out-Null

            return $data.Tables
        } catch {
            Write-Error($_)
        } finally {
            if ($connection.State -eq 'Open') {
                $connection.Close()
            }
        }
    }
}

function Get-DvrType() {
    $ControllerInformation = Get-Item -LiteralPath 'Registry::HKLM\SOFTWARE\EZUniverse\EZ360ControllerInstaller' -Force
    return $ControllerInformation.GetValue('ControllerModel')
}

function DownloadAndExecuteSqlHotfix {
    param (
        [FileDownloadInformation] $Hotfix,
        [string] $ConnectionString
    )
    Invoke-DownloadAndVerify -DownloadPath $script:controllerDownloadPath -FileInfo $Hotfix
    if ($Hotfix.Success) {
        try {
            Push-Location -LiteralPath $Hotfix.SavedAtPath
            Invoke-ExecuteSql -InputFile $Hotfix.Name -ConnectionString $ConnectionString
        } catch {
            Write-Error("[-] $_")
        } finally {
            Pop-Location
        }
    } else {
        Write-Error("[-] $($Hotfix) not downloaded")
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

function ExecuteFootageResetSqlQuery([string] $Database, [datetime] $Offset, [string] $ConnectionString) {
    $queries = BuildFootageResetQuery -Database $Database -Date $Offset
    foreach ($query in $queries) {
        Invoke-ExecuteSql -Query $query -ConnectionString $ConnectionString -ErrorAction SilentlyContinue
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

function ExecuteFlir {
    try {
        if (!(Test-Path -Path $script:GdprDownloadPath -PathType Container)) {
            New-Item -Path $script:GdprDownloadPath -ItemType Container -Force | Out-Null
        }
        Push-Location -Path $script:GdprDownloadPath
    } catch {
        Write-Error('Path for GDPR cannot be created.')
    }

    try {
        Invoke-DownloadAndVerify $script:GdprDownloadPath $flirFiles -ErrorAction SilentlyContinue

        if (!$flirFiles.Success) {
            Write-Output('[-] Flir not downloaded')
            return
        }
        Expand-ArchiveWithFallback -Path (Join-Path -Path $flirFiles.SavedAtPath -ChildPath $flirFiles.Name)
    } catch {
        Pop-Location
        Write-Error($_)
    }

    try {
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/c START /B .\flir-1.7.0.9\flir.exe -f --f-clean-unlinked-files --f-clean-expired-files --f-clean-not-existing-files > C:\DTIQ\log.txt' -WindowStyle Hidden -ErrorAction Stop
        Write-Output('[+] Flir executed')
    } catch {
        Write-Error('[-] Cannot start flir')
    } finally {
        Pop-Location
    }
}

function mainExecution() {
    $dateWithOffset = Get-DateWithParameterOffset($script:RemoveDaysLessThan)
    $dvrType = Get-DvrType

    if (-not (Test-Path $script:controllerDownloadPath)) {
        New-Item -Path $script:controllerDownloadPath -Force -ItemType Directory | Out-Null
    }

    Push-Location $script:controllerDownloadPath

    try {
        if ($dvrType -like '*VDMS*') {
            Write-Output('[i] Executing VDMS procedure')
            foreach ($hotfix in $hotfixesVDMS) {
                DownloadAndExecuteSqlHotfix -Hotfix $hotfix -ConnectionString $script:connectionStringEz360
            }
            ExecuteFootageResetSqlQuery -Database 'EZ360Video' -Offset $dateWithOffset -ConnectionString $script:connectionStringEz360
            Write-Output('[+] VDMS procedure completed')
        }
        elseif ($dvrType -like '*Legacy*') {
            Write-Output('[i] Executing Legacy procedure')
            foreach ($hotfix in $hotfixesLegacy) {
                DownloadAndExecuteSqlHotfix -Hotfix $hotfix -ConnectionString $script:connectionStringSqlexpress
            }
            ExecuteFootageResetSqlQuery -Database 'EZCamera' -Offset $dateWithOffset -ConnectionString $script:connectionStringSqlexpress
            Write-Output('[+] Legacy procedure completed')
        }
        else {
            Write-Output('[i] System unknown - skipping')
        }
    } catch {
        Write-Output("[-] query execution not successfull")
    }
    CleanDrivesFromFootage $dateWithOffset
    ExecuteFlir -ErrorAction SilentlyContinue
    Pop-Location
}

try {
    mainExecution
} catch {
    Write-Output($_)
}