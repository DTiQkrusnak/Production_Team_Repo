<#
    .SYNOPSIS
    Set BrinkPOS configuration so POS operates properly.

    .DESCRIPTION
    Script sets:  
        1. EnableLocalLiveTextOverlay and EnableLocalHistoricalTextOverlay to true if attribute does not exists it creates one.
        2. Forces the proper BrinkPOS config configuration file by overwriting current file.
        3. Sets firewall inbound rule for RestEventGrabber (TCP 5378)
#>

$scriptVer = "1.0"
$scriptName = "Set-BrinkPOS"
$scriptDescr = "Set propper BrinkPOS configuration by setting up attributes, config file and opening firewall port."
Write-Output("SCRIPT DESCRIPTION: $scriptName v.$scriptVer")
Write-Output("SCRIPT DESCRIPTION: $scriptDescr")

# Variables
$PShellVer = $PSVersionTable.PSVersion.Major

# Functions
function Set-PreparserConfig {
    param(
        $PreparserConfigPath = 'C:\Program Files (x86)\EZUniverse\EZ360Controller\EZ360PreParser\configuration.json',
                
        [ValidateSet("EnableLocalLiveTextOverlay", "EnableLocalHistoricalTextOverlay")]
        [string] $Attribute,
        [ValidateSet($true, $false)]
        [bool] $Value
    )

    Write-Host "Reading file : $PreparserConfigPath"
    $json = Get-Content $preparserConfigPath | ConvertFrom-Json


   
   
    if ($json.PSObject.Properties.Name -contains $Attribute) {
        if ($($json.$Attribute) -ne $Value) {
            # Property exists and wrong value, update it
            $json.$Attribute = $Value
            Write-Host "  -> updated existing property '$Attribute' to '$Value'"

        }
        else {
            Write-Host "  -> property already with proper value : '$Attribute' = '$Value'"
            return
        }
    }
    else {
        # Property doesn't exist, create it
        $json | Add-Member -NotePropertyName $Attribute -NotePropertyValue $Value
        Write-Host "  -> added new property '$Attribute' with value '$Value'"
    }

    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $PreparserConfigPath
    Write-Host "  -> file saved : $PreparserConfigPath"
    #>
}
function Set-CustomFirewallRules {
    param (
        [string] $ServiceExePath,
        [string] $Servicename,
        [string] $Port,
        [string] $Protocol
    )


    #$firewallRuleName = "$Servicename" + " " + "$Protocol" + " " + "$Port"
    $params = @($Servicename, $Protocol, $Port)
    $firewallRuleName = $params -join \" \"




    Write-Host \"Checking if rule already exists : $firewallRuleName\"
    $getFWRule = Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue

    if (($getFWRule.Name -eq 'RestEventGrabber.Service TCP 5378') `
            -and ($getFWRule.DisplayName -eq 'RestEventGrabber.Service TCP 5378') `
            -and ($getFWRule.DisplayGroup -eq 'DTiQ services')) {
        Write-Host '  -> firewall rule found - removing to set it up properly'
        $getFWRule | Remove-NetFirewallRule | Out-Null

    }

    Write-Host \"  -> creating firewall rule : $firewallRuleName\"
    New-NetFirewallRule `
        -Name \"$firewallRuleName\" `
        -Group 'DTiQ services' `
        -DisplayName \"$firewallRuleName\" `
        -Direction Inbound `
        -Program \"$ServiceExePath\" `
        -Protocol \"$Protocol\" `
        -LocalPort \"$Port\" `
        -Action Allow `
        -Profile Any | Out-Null
    #>
}

function Set-JsonRestFile {
    param (
        [string] $Path
    )
    
    $config = @'
{
  "ProcessId": 1035712,
  "Input": {
    "Host": null,
    "PortList": [
      {
        "Port": 5378,
        "Enabled": true
      },
    ]
  },
  "Outputs": {
    "MaxQueueLength": 100,
    "DefaultParserClass": "CopyInputString",
    "Dvrguid": "9569ce9f-02ec-447d-bc35-a3de5a0e7e27",
    "Postypeid": 18,
    "DefaultCameraNumber": 1,
    "DBOutput": {
      "LocalDBOutputs": [
        {
          "Type": "PARORDEREVENTAPI",
          "ConnectionString": "Data Source = .\\EZ360; User ID = EZ360System; Password = EZ360System; Initial Catalog = EZ360Communication;",
          "ProcedureName": "IN.RawData_Add",
          "Name": "Local",
          "ParserClass": "CopyInputString",
          "Enabled": true
        }
      ],
      "Name": "Local",
      "ParserClass": null,
      "AcceptedPatterns": [
      ],
      "Enabled": true
    }
  }
}
'@
    Write-Host "Saving file : $Path"
    $config | Set-Content -Path $Path -Force -Confirm:$false
    Write-Host "  -> file saved : $Path"
}

function executeScript {
    param(
        [int]$PShellVer
    )
    if ($PShellVer -ge 5) {
        Write-Output("Powershell.v.5 found - executing script")
        ##### Execute function

        Set-PreparserConfig -Attribute EnableLocalLiveTextOverlay -Value $true
        Set-PreparserConfig -Attribute EnableLocalHistoricalTextOverlay -Value $true

        Set-JsonRestFile -Path 'C:\Program Files (x86)\EZUniverse\DTIQ360RestEventGrabber\Config.json'

        Set-CustomFirewallRules `
            -ServiceExePath 'C:\Program Files (x86)\EZUniverse\DTIQ360RestEventGrabber\RestEventGrabber.Service.exe' `
            -Servicename 'RestEventGrabber.Service' `
            -Protocol TCP `
            -Port '5378'
    }
    else {
        Write-Output("PowerShell.v.5 is not installed - skipping script ")
    }
}

executeScript $PShellVer
