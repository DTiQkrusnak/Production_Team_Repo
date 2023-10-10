<#
    .SYNOPSIS
    Installing prerequisites needed for IMAGE and SAK scripts.

    .DESCRIPTION
    Script is intended to be run as the first script, it should handle the installation of all necessary components
    which will be needed through out the installation i.e. powershell modules, Windows Features or software.

    .NOTES
    version : 1.0
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$listOfModules = @(
    "Nuget",
    "SqlServer"
)

$listOfWindowsFeatures = @(
    "NetFx3",
    
    "MSMQ-container",
    "MSMQ-server",
    "MSMQ-triggers",
    "MSMQ-adintegration",
    "MSMQ-HTTP",
    "MSMQ-multicast",
    "MSMQ-DCOMProxy",

    "IIS-HttpRedirect",
    "IIS-ApplicationDevelopment",
    "IIS-NetFxExtensibility45",
    "IIS-HealthAndDiagnostics",
    "IIS-HttpLogging",
    "IIS-LoggingLibraries",
    "IIS-RequestMonitor",
    "IIS-HttpTracing",
    "IIS-Security",
    "IIS-RequestFiltering",
    "IIS-Performance",
    "IIS-WebServerManagementTools",
    "IIS-IIS6ManagementCompatibility",
    "IIS-Metabase",
    "IIS-ManagementConsole",
    "IIS-BasicAuthentication",
    "IIS-WindowsAuthentication",
    "IIS-StaticContent",
    "IIS-DefaultDocument",
    "IIS-WebSockets",
    "IIS-ApplicationInit",
    "IIS-NetFxExtensibility45",
    "IIS-ASPNET45",
    "IIS-ISAPIExtensions",
    "IIS-ISAPIFilter",
    "IIS-HttpCompressionStatic",
    "IIS-ASPNET" 
)

function InstallModules($listOfModules) {
    <#
        .SYNOPSIS
        Install powershell modules.

        .DESCRIPTION
        Add modules to the powershell local environment.
        
        .PARAMETER listOfModules
        Defines what modules to install.

        .NOTES
        $listOfModules - add modules to the list, function will take care of the installation.
    #>
    Write-Host "Installing modules function :"
    foreach ($moduleName in $listOfModules) {
        Write-Host " [*] Installing module : $moduleName"
        try {
            Install-Module -Name $moduleName -Force -Confirm:$false -WarningAction:SilentlyContinue -ErrorAction:Stop
            Import-Module -Name $moduleName -Force -WarningAction:SilentlyContinue -ErrorAction:Stop
            Write-Host " [+] $moduleName module installed successfully"
        }
        catch {
            Write-Host " [-] an ERROR occurred :" -ForegroundColor Red
            Write-Error "$($_.InvocationInfo.PositionMessage)"
            exit 1
        }
    }
    Write-Host "All modules installed."
}

function InstallWindowsFeature($listOfWindowsFeatures) {
    <#
        .SYNOPSIS
        Install Windows features.

        .DESCRIPTION
        Install Windows features in the local environment.
        
        .PARAMETER listOfWindowsFeatures
        Defines what features to install.

        .NOTES
        $listOfWindowsFeatures - add features to the list, function will take care of the installation. 
        Use "(Get-WindowsOptionalFeature -online).FeatureName" cmdlet to see the availability of features.
    #>
    Write-Host "Installing Windows features function :"
    foreach ($featureName in $listOfWindowsFeatures) {
        Write-Host " [*] Installing module : $featureName"
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart -WarningAction:SilentlyContinue -ErrorAction:Stop | Out-Null
            Write-Host " [+] $featureName feature installed successfully"
        }
        catch {
            Write-Host " [-] an ERROR occurred :" -ForegroundColor Red
            Write-Error "$($_.InvocationInfo.PositionMessage)"
            #Write-Error "$($_.Exception.Message)"
            exit 1
        }
    }
    Write-Host "All features installed"
}

### Execute functions
InstallModules $listOfModules
InstallWindowsFeature $listOfWindowsFeatures
