<#
    .SYNOPSIS
    Verification scripts for "1.1_installDotNET.ps1"
#>

# Define class
class FileProperties {
    [string]$name
    [string]$versionCheck
    [string]$version

    fileProperties([string]$name, [string]$versionCheck, [string]$version) {
        $this.name = $name
        $this.versionCheck = $versionCheck
        $this.version = $version
    }
}
#this package will be intalled on both x86 and x64
$ndp48 = [FileProperties]::new(
    "ndp48-x86-x64-allos-enu.exe",
    "Get-ItemProperty 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue | Test-Path",
    "runtime_4.8.03761"
)

$ndpDesktop60x64 = [FileProperties]::new(
    "windowsdesktop-runtime-6.0.15-win-x64.exe",
    "Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost' -Name Version -ErrorAction SilentlyContinue | Test-Path",
    "runtime_6.0.15"
)

$ndpCore60 = [FileProperties]::new(
    "dotnet-hosting-6.0.15-win-x64.exe",
    "Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost' -Name Version -ErrorAction SilentlyContinue | Test-Path",
    "hosting_6.0.15"
)

$dotNETPackageList = @(
    $ndp48
    $ndpDesktop60x64
    $ndpCore60
)

function VerifyIfDOTNetInstalled($dotNETPackageList) {
    Write-Host "Checking if .NET is installed : $($dotNETPackageList.version -join "; ")"   
    foreach ($item in $dotNETPackageList) {
        if ($(Invoke-Expression $item.VersionCheck) -eq $true) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host ".NET installed : $($item.Version)" 
        } else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host ".NET is not installed on system : " -NoNewline
            Write-Host "$($item.Version)" -ForegroundColor DarkYellow
        }
    }
}

VerifyIfDOTNetInstalled $dotNETPackageList