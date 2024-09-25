class FileDownloadInformation {
    [ValidateNotNullOrEmpty()][string] $Name
    [ValidateNotNullOrEmpty()][string] $Link
    [ValidateNotNullOrEmpty()][string] $SHA256Hash
    [boolean] $Success = $false
    [string] $SavedAtPath = $null
}
function New-FileDownloadInformation {
    param (
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $Name,
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $Link,
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $SHA256Hash
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
                Write-Error("Hash mismatch for $($FileInfo.Name). Download: $($downloadHash.Hash), Expected: $($FileInfo.SHA256Hash)")
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
                Write-Error("Cannot download $FileInfo")
            }
        }
    } catch {
        Write-Error($_)
    } finally {
        Pop-Location
    }
}

$Security_script_file = New-FileDownloadInformation `
    -Name 'Security_and_Cleanup.ps1' `
    -Link 'https://files-us-ps2.go360iq.com/_Files/Software/Scripts/SecurityScripts/Security_and_Cleanup.ps1' `
    -SHA256Hash 'f77f2d1c7e754131e7b4cc1955a30dc4eff021ad31373ffa49a00671a93d1f95'

if ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\EZUniverse\EZ360ControllerInstaller' -Name ControllerModel).ControllerModel -eq 'VDMS DTT') {
    $plainPassword = 'Qi29TctBdis!'
    $Password = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
    $params = @{
        Name        = 'dtiquser'
        Password    = $Password
        FullName    = 'DTiQ Client user'
        Description = 'DTiQ Client user'
    }
    if ($null -eq (Get-LocalUser -Name 'dtiquser' -ErrorAction SilentlyContinue)) {
        New-LocalUser @params -UserMayNotChangePassword -PasswordNeverExpires
    }

    # Autologon
    $RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty $RegistryPath 'AutoAdminLogon' -Value "1" -Type String
    Set-ItemProperty $RegistryPath 'DefaultUsername' -Value "dtiquser" -type String
    Set-ItemProperty $RegistryPath 'DefaultPassword' -Value "$plainPassword" -type String

    $StartUpPath = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp'
    #! Add FOLDER CREATION IF DOES NOT EXIST
    if ($False -eq (Test-Path -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp' -ErrorAction SilentlyContinue)) {
        New-Item -ItemType Directory -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs' -Name 'StartUp' -Force
    }
    New-Item -ItemType SymbolicLink -Path $StartUpPath -Name '360iQPVMController.lnk' -Value 'C:\Program Files (x86)\EZUniverse\360iQPVMController\360iQPVMController.exe' -ErrorAction SilentlyContinue
}

Remove-Item -Path 'C:\DTIQ\Security_and_Cleanup\*' -Force -Exclude 'log.*' -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path 'C:\DTIQ\Security_and_Cleanup\' -Force

Invoke-DownloadAndVerify -DownloadPath 'C:\DTIQ\Security_and_Cleanup\' -FileInfo $Security_script_file

Start-Process -FilePath 'cmd.exe' -ArgumentList '/c START /B powershell.exe -File C:\DTIQ\Security_and_Cleanup\Security_and_Cleanup.ps1 > C:\DTIQ\Security_and_Cleanup\log.txt' -WindowStyle Hidden