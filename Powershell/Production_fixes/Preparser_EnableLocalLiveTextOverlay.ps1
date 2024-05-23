function GetPreparserVersion {
    $preparserExePath = 'C:\Program Files (x86)\EZUniverse\EZ360Controller\EZ360PreParser\EZ360PreParserService.exe'

    [system.version]$preparserExeVersion = (Get-item $preparserExePath).VersionInfo.FileVersion
    return $preparserExeVersion
}

function SetPreparserConfig {
    $preparserConfigPath = 'C:\Program Files (x86)\EZUniverse\EZ360Controller\EZ360PreParser\configuration.json'
    $json = Get-Content $preparserConfigPath | ConvertFrom-Json

    try {
        if ($json.EnableLocalLiveTextOverlay -eq $true) {
            Write-Host "Nothing to do - closing script."
            exit 0
        }
        elseif ($json.EnableLocalLiveTextOverlay -eq $false) {
            Write-Host "Modifying ""EnableLocalLiveTextOverlay"" to True"
            $json.EnableLocalLiveTextOverlay = $true
            Write-Host "  -> value modified"

            $json | ConvertTo-Json -Depth 32 | Set-Content $preparserConfigPath
        }
        elseif (!($json.EnableLocalLiveTextOverlay)) {
            Write-Host "Creating ""EnableLocalLiveTextOverlay"" "
            $json | Add-Member -NotePropertyName 'EnableLocalLiveTextOverlay' -NotePropertyValue $true
            Write-Host "  -> Atribute created : EnableLocalLiveTextOverlay = true"
            $json | ConvertTo-Json -Depth 32 | Set-Content $preparserConfigPath
        }
    }
    catch {
        $_.Exception
    }
}

function GetRegisterInfo {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    $query = @"
    SELECT * FROM [EZ360Objects].[Register].[Registers]
"@
    $getRegisterInfo = Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query $query -ErrorAction SilentlyContinue
    return $getRegisterInfo

}


$preparserExeVersionResult = GetPreparserVersion
$getRegisterInfoResult = GetRegisterInfo

if ($preparserExeVersionResult.Major -eq 3) { 
    if (($getRegisterInfoResult.ModelID -eq 12) -and ($getRegisterInfoResult.Status -eq "Y")) {
        SetPreparserConfig
    }
    else {
        Write-Error "Active Sicom not found"
    }
} 