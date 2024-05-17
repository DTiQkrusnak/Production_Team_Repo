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
        throw $_
    } finally {
        Pop-Location
    }
}

Export-ModuleMember -Function 'New-FileDownloadInformation', 'Invoke-DownloadAndVerify'