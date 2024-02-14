<#
    .SYNOPSIS
    Verification scripts for "1.0_installPrerequisites.ps1"
#>

$listOfModules = @(
    "Nuget",
    "SqlServer",
    "NTFSSecurity"
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
    "IIS-ASPNET",
    "TelnetClient"
)




function VerifyModulesExist($listOfModules) {
    <#
        .SYNOPSIS
        Verifies if modules in $listofmodules are existing on the system
    #>
    Write-Host "Checking existance of modules on the system : $($listOfModules -join "; ")"
    foreach ($module in $listOfModules) {
        if (Get-Module -ListAvailable -Name $module) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "Module exists : $module" 
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "Module does not exist : " -NoNewline
            Write-Host "$module" -ForegroundColor Yellow
        }
    }
}

function VerifyFeaturesExist($listOfWindowsFeatures) {
    <#
        .SYNOPSIS
        Verifies if features in $listOfWindowsFeatures are installed on the system
    #>
    Write-Host "Checking existance of features on the system : $($listOfWindowsFeatures -join "; ")"
    foreach ($feature in $listOfWindowsFeatures) {
        if ((Get-WindowsOptionalFeature -FeatureName $feature -online).State -eq 'Enabled') {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "Feature is enabled : $feature"
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "Feature is not enabled : " -NoNewline
            Write-Host "$feature" -ForegroundColor Yellow
        }
    }
}

VerifyModulesExist $listOfModules
VerifyFeaturesExist $listOfWindowsFeatures