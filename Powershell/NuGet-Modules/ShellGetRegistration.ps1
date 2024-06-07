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

        [Int32] $Timeout = 30,

        [boolean] $SkipHashVerification = $False
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    function Test-ForExistingFile([FileDownloadInformation] $FileInfo, [string] $DownloadPath, [boolean] $SkipHashVerification) {
        if (Test-Path -Path $FileInfo.Name -PathType Leaf) {
            $FileInfo.SavedAtPath = $DownloadPath
            $downloadHash = Get-FileHash -Path $FileInfo.Name -Algorithm SHA256
            if (($downloadHash.Hash -eq $FileInfo.SHA256Hash) -or $SkipHashVerification) {
                $FileInfo.Success = $true
                return $true
            } else {
                throw "Hash mismatch for $($FileInfo.Name). Download: $($downloadHash.Hash), Expected: $($FileInfo.SHA256Hash)"
                return $false
            }
        } else {
            return $false
        }
    }

    try {
        Push-Location -LiteralPath $DownloadPath
        if (Test-ForExistingFile -FileInfo $FileInfo -DownloadPath $DownloadPath -SkipHashVerification $SkipHashVerification) {
            return
        } else {
            Invoke-WebRequest -Uri $FileInfo.Link -OutFile $FileInfo.Name -TimeoutSec $Timeout -ErrorAction Stop
            if (Test-ForExistingFile -FileInfo $FileInfo -DownloadPath $DownloadPath -SkipHashVerification $SkipHashVerification) {
                return
            } else {
                throw "Cannot download $FileInfo"
            }
        }
    } catch {
        throw $_
    } finally {
        Pop-Location
    }
}

function IsRepositoryRegistered([string] $repo_name) {
    $repo_output = ./nuget.exe sources list -Format short
    if (($null -eq $repo_output) -or ($repo_output.Length -eq 0)) {return $false}
    if ($null -eq ($repo_output | Select-String -Pattern $repo_name)){
        return $false
    } else {
        return $true
    }
}

function main() {
    [FileDownloadInformation] $nuget_file = New-FileDownloadInformation -Name 'nuget.exe' `
    -Link 'https://files-us-ps2.go360iq.com/_Files/Software/Scripts/Nuget/nuget.exe' `
    -SHA256Hash 'D9E2D4DB12FF444B684A40CBEB2775A2ADF3F65980E8A55F3C006FAEC2B89B7C'

    [string] $repo_name = 'ShellGet'
    [string] $repo_source = 'https://shellget.go360iq.com/nuget'
    [string] $dtiq_modules_path = 'C:\ProgramData\DTiQ\Powershell\ShellGet\Modules\'

    try {
        if (!(Get-PackageProvider -Name 'NuGet' -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name 'NuGet' -MinimumVersion 2.8.5.201 -Force -ForceBootstrap
        }

        if ($(Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue).Trusted -ne $True) {
            Register-PSRepository -Default -ErrorAction SilentlyContinue
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }

        if (!(Test-Path -LiteralPath $dtiq_modules_path -PathType Container)) {
            New-Item -ItemType Directory -Path $dtiq_modules_path -Force
        }
        Invoke-DownloadAndVerify -FileInfo $nuget_file -DownloadPath $dtiq_modules_path -Timeout 120 -SkipHashVerification $True -ErrorAction Stop
        $env_path = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if (!($env_path.Split(';') -contains $dtiq_modules_path)) {
            [Environment]::SetEnvironmentVariable("Path", $env_path + ";" + $dtiq_modules_path, [EnvironmentVariableTarget]::Machine)
        }

        $ps_modules_path = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
        if (!($ps_modules_path.Split(';') -contains $dtiq_modules_path)) {
            [Environment]::SetEnvironmentVariable("PSModulePath", $ps_modules_path + ";" + $dtiq_modules_path, [EnvironmentVariableTarget]::Machine)
        }
        Push-Location -LiteralPath $dtiq_modules_path
        ./nuget.exe update -self | Out-Null
        if (!(IsRepositoryRegistered($repo_name))) {
            ./nuget.exe sources add -name $repo_name -Source $repo_source  | Out-Null
        }
        
        ./nuget.exe install  Invoke-DownloadAndVerify -ExcludeVersion -DirectDownload -o ($Env:PSModulePath.Split(';') -like '*ShellGet*')

        if (!(IsRepositoryRegistered($repo_name))) {
            Write-Output('[-] Repo is not registered')
        }
    } catch {
        Write-Error('Line: ' + $_.InvocationInfo.ScriptLineNumber)
        Write-Error($_.Exception.Message)
    } finally {
        Pop-Location
    }
}

try {
    main
} catch {
    Write-Error($_)
}