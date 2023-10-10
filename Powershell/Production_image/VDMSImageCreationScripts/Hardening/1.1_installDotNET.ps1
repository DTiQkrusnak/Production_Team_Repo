<#
    .SYNOPSIS
    Installing .NET packages.

    .DESCRIPTION
    Download .NET setup from microsoft page and install the package. 
    Script has been divided from the prerequisites script as those .NETs are not available as features.
    Using objects and properties to properly handle file download and installation.

    .NOTES
    version : 1.0
#>

# Define class
class FileProperties {
    [string]$name
    [string]$versionCheck
    [string]$version
    [string]$url
    [string]$checksum
    [int]$Size

    fileProperties([string]$name, [string]$versionCheck, [string]$version, [string]$url, [string]$checksum, [int]$Size) {
        $this.Name = $name
        $this.versionCheck = $versionCheck
        $this.version = $version
        $this.Url = $url
        $this.Checksum = $checksum
        $this.Size = $size
    }
}

#this package will be intalled on both x86 and x64
$ndp48 = [FileProperties]::new(
    "ndp48-x86-x64-allos-enu.exe",
    "Get-ItemProperty 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue | Test-Path",
    "4.8.03761",
    "https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe",
    "FFB6C226AF4E5C8FFA7210D5115701883ABF12A8B1CBAE6E08122FB94DD93763468BFF5B00060EABEF19C147B0A4D8063DDE318D2B928CE397C58F7949736C5F",
    "115"
)

$ndpDesktop60x64 = [FileProperties]::new(
    "windowsdesktop-runtime-6.0.15-win-x64.exe",
    "Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost' -Name Version -ErrorAction SilentlyContinue | Test-Path",
    "6.0.15",
    "https://download.visualstudio.microsoft.com/download/pr/513d13b7-b456-45af-828b-b7b7981ff462/edf44a743b78f8b54a2cec97ce888346/windowsdesktop-runtime-6.0.15-win-x64.exe",
    "62412c45ba5ebf89b0ea2c3d9dcce3a7f05198d4db368f63956f7ae58b368baa059343a2de39d24e20ffe126145f31c72131914cb2793f002921a975e69c3bb4",
    "56"
)

$ndpCore60 = [FileProperties]::new(
    "dotnet-hosting-6.0.15-win-x64.exe",
    "Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost' -Name Version -ErrorAction SilentlyContinue | Test-Path",
    "6.0.15",
    "https://download.visualstudio.microsoft.com/download/pr/e38901ef-e9ac-4331-a6aa-f2aec3b1754b/6d695fa51a4960393edaf725ce970a86/dotnet-hosting-6.0.15-win.exe",
    "0FCEC40E3D4EE131DCDF8EE606A603274E71921FBAA3C0F3A7B5FDB4A1B001CE86E46AE0840B2E58CE1A930797FF68B274A46630AB7995E01633C8A6DCEE15BA",
    "69"
)

$dotNETPackageList = @(
    $ndp48
    $ndpCore60
    $ndpDesktop60x64
)

function installNETFramework {
    <#
        .SYNOPSIS
        Install latest .NET package

        .DESCRIPTION
        Script downloads, verifies the integrity and installs selected and approved versions of .NET on local machine.
        
        .NOTES
        This .NET packages might be useful if we need to run some .NET code, as powershell might have issues or difficulties. 
    #>
    foreach ($item in $dotNETPackageList) {
        $getNETversion = Invoke-Expression $item.versionCheck
        if ($getNETversion -ne $true) {
            #downloading file
            Write-Host "Downloading file ($($item.Size)MB):" $item.Name 
            try {
                $downloadPath = Join-Path $DTIQTEMPPATH -ChildPath $item.Name
                Invoke-WebRequest -Uri $item.Url -OutFile $downloadPath
                Write-Host " [+] download completed"
            }
            catch {
                Write-Host " [-] an ERROR occurred :" -ForegroundColor Red
                Write-Error "$($_.Exception.Message)"
                exit 1
            }

            #checking hash
            Write-Host "Checking hashsum :" $item.Name
            $getHash = (Get-FileHash -Algorithm SHA512 -Path $downloadPath).hash
            if ($getHash -ne $item.checksum) {
                Write-Host " [-] an ERROR occurred :" -ForegroundColor Red
                Write-Error "$($_.Exception.Message)"
                exit 1
            }
            else {
                Write-Host " [+] checksum correct"
            }

            #installing .NET
            try {
                Write-Host "Starting process : $($item.Name)"
                Write-Progress -Activity "Installing : $($item.Name)..." -PercentComplete "0"
                Start-Process -FilePath $downloadPath -ArgumentList "/q", "/norestart" -Wait
                Write-Host " [+] process completed"  
            }
            catch {
                Write-Host " [-] an ERROR occurred :" -ForegroundColor Red
                Write-Error "$($_.Exception.Message)"
                exit 1
            }
        }
        else {
            Write-Host " [+] .NET already installed : $($item.version)"
        }
    } 
}

function clearTemp($DTIQTEMPPATH) {
    <#
        .SYNOPSIS
        Cleanup - remove downloaded setup files in this script.
    #>
    try {
        Write-Host "[CLEANUP] Removing files from directory"
        Remove-Item "$DTIQTEMPPATH\*" -Recurse -Force -Confirm:$false | Out-Null
        Write-Host " [+] Files removed"
    }
    catch {
        Write-Host " [-] an ERROR occurred :" -ForegroundColor Red
        Write-Error "$($_.Exception.Message)"  
    }
}

installNETFramework $dotNETPackageList
clearTemp