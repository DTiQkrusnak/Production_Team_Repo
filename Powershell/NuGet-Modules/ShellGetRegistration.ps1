[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

class FileDownloadInformation {
    [ValidateNotNullOrEmpty()][string] $Name
    [ValidateNotNullOrEmpty()][string] $Link
    [ValidateNotNullOrEmpty()][string] $SHA256Hash
    [boolean] $Success = $false
    [string] $SavedAtPath = $null
}

function New-FileDownloadInformation {
    param (
        [ValidateNotNullOrEmpty()][string] $Name,
        [ValidateNotNullOrEmpty()][string] $Link,
        [ValidateNotNullOrEmpty()][string] $SHA256Hash
    )
    $tempFileDownloadInformationObject = [FileDownloadInformation]::new()
    $tempFileDownloadInformationObject.Name = $Name
    $tempFileDownloadInformationObject.Link = $Link
    $tempFileDownloadInformationObject.SHA256Hash = $SHA256Hash
    return $tempFileDownloadInformationObject
}

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

function IsRepositoryRegistered([string] $repo_name) {
    if ($null -eq (./nuget.exe sources list -Format short | Select-String -Pattern $repo_name)){
        return $false
    } else {
        return $true
    }
}

Register-PSRepository -Default -ErrorAction SilentlyContinue
if ($(Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue).Trusted -ne $True) {
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
}

[FileDownloadInformation] $nuget_file = New-FileDownloadInformation -Name 'nuget.exe' `
    -Link 'https://files-us-ps2.go360iq.com/_Files/Software/Scripts/Nuget/nuget.exe' `
    -SHA256Hash 'D9E2D4DB12FF444B684A40CBEB2775A2ADF3F65980E8A55F3C006FAEC2B89B7C'

[string] $repo_name = 'ShellGet'
[string] $repo_source = 'https://shellget.go360iq.com/nuget'
[string] $modules_path = 'C:\ProgramData\DTiQ\Powershell\ShellGet\Modules'

try {
    if (!(Test-Path -LiteralPath $modules_path -PathType Container)) {
        New-Item -ItemType Directory -Path $modules_path -Force | Out-Null
    }
    Invoke-DownloadAndVerify -FileInfo $nuget_file -DownloadPath $modules_path
    Push-Location -LiteralPath $modules_path
    ./nuget.exe update -self
    if (!(IsRepositoryRegistered($repo_name))) {
        ./nuget.exe sources add -name $repo_name -Source $repo_source | Out-Null
    }
    
    if (!(IsRepositoryRegistered($repo_name))) {
        Write-Output('[-] Repo is not registered')
        return
    }
} catch {
    Write-Output($_)
} finally {
    Pop-Location
}