$ipAddressMask = "10.1.1.*"
$ipAddressForce = "10.1.1.196"


#$ipAddressMask = "192.168.9.*"
#$ipAddressForce = "192.168.9.10"

# TODO : add breeze with status success / fail - bring feedback
# TODO : @maciek ask about QA and force test for this script
function Invoke-Breezev2 {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'

    function CheckDatabaseState {
        try {
            $connected = Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query "SELECT TOP 1 [LocationID],[DisplayAs] FROM [EZ360Objects].[Location].[Locations]" -ErrorAction SilentlyContinue
            if ($connected) {
                $script:locationIDValue = $connected.LocationID
                $script:displayASValue = $connected.DisplayAs
            }
        }
        catch {
            Write-Output("  -> connection unsuccesfull")
            #Write-Host $_.Exception.Message
            exit 0
        }
    }
    
    ## === FUNCTION SPACE START ===
    function Get-PreParserConfig {
        $path = "C:\Program Files (x86)\EZUniverse\EZ360Controller\EZ360PreParser\configuration.json"
        $loadPreparserConf = Get-Content -Path $path #| ConvertFrom-Json
        
        return $loadPreparserConf
    }

    function Get-PreParserAttribute {
        param (
            $PreparserConfig,
            $Attribute
        )

        if (@($PreparserConfig.$Attribute) -contains $true) {
            return $true
        }
        else {
            return $false
        }
        
    }

    ## === END OF FUNCTIONS SPACE ===
    function getIdToken {    
        $json = 
        @{
            "AuthFlow"       = "USER_PASSWORD_AUTH"
            "AuthParameters" = @{
                "PASSWORD" = 'hRddjQK1VFTHM3jLTMkS!'
                "USERNAME" = "breeze-prod"
            }
            "ClientId"       = '7nig6316ca3lt7ofs96ci24hl'
        } | ConvertTo-Json
    
        $var = Invoke-RestMethod `
            -Method POST `
            -Uri "https://cognito-idp.us-east-1.amazonaws.com/" `
            -Body $json `
            -Headers @{
            "Content-Type" = "application/x-amz-json-1.1"
            "x-amz-target" = "AWSCognitoIdentityProviderService.InitiateAuth" 
        }
    
        #$var.AuthenticationResult
        $script:idToken = $var.AuthenticationResult.IdToken #expires every 3600s/1hr 
    }
    
    
    function sendRestData {

        if ($breezeError) 
        { "$breezeError" } else { $breezeError = "NULL" }

        $body = @{
            locationId      = $locationIDValue
            locationName    = $displayASValue
            timestamp       = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            timezoneId      = Get-Date -UFormat "%Z"
            scriptName      = "BK_change_ip"
            scriptId        = "21"
            executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            result          = Get-NetAdapterConfigFull | ConvertTo-Json
            optionalResult1 = $breezeError
            errorCode       = "NULL"
            errorDetails    = "NULL"
            #teamViewerId    = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\TeamViewer\).ClientID
            controllerName  = $env:computername
        } | ConvertTo-Json
    
        $body
    
        ### PROD API
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        <#
        Invoke-RestMethod `
            -Method Post `
            -Uri "https://p13fqdhy8i.execute-api.us-east-1.amazonaws.com/prod/v2/ScriptExecution" `
            -Body $body `
            -ContentType 'application/json' `
            -Headers @{
            "Authorization" = $idToken
        }
        #>
    }

    CheckDatabaseState
    
    getIdToken
    sendRestData
}


function Get-NetAdapterConfigFull {
    function Get-NetAdapterConfig ($ipAddressToCheck) {
        Write-Host "    -> getting basic information about the adapter with IP address $ipAddressToCheck"
        $getAdaperConfig = Get-NetIPAddress | Where-Object { $_.IPAddress -like $ipAddressMask }

        if ($getAdaperConfig) {
            Write-Host "    -> adapter in the $ipAddressToCheck subnet found: $($getAdaperConfig.ipAddress)"
            return $getAdaperConfig    
        }
        else {
            Write-Host "No adapter with such IP exists - closing"
            $breezeError = "No adapter with subnet IP $ipAddressMask exists"
            return $breezeError 
        }
    }

    function Get-NetAdapterIfIndex ($adapterConfig) {
        Write-Host "    -> getting interface index for found adapter"
        $getAdapterifIndex = $adapterConfig | Select-Object -ExpandProperty ifIndex
        if ($getAdapterifIndex) {
            Write-Host "    -> interface index found: $getAdapterifIndex"

        }
        return $getAdapterifIndex
    }

    function Get-NetGateway ($adapterIndex) {
        Write-Host "    -> getting default gateway for adapter with index $adapterIndex"
        $DefautGateway = Get-NetRoute -InterfaceIndex $adapterIndex -DestinationPrefix "0.0.0.0/0" | Select-Object NextHop
        if ($DefautGateway) {
            Write-Host "    -> default gateway found: $($DefautGateway.NextHop)"

        }
        return $DefautGateway.NextHop
    }
    function Get-NetIpAssignmentType ($getNetAdapterIndexResult) {
        Write-Host "    -> getting IP assignment type for adapter with index $getNetAdapterIndexResult"
        $getAdapterAssignmentType = Get-NetIPInterface -InterfaceIndex $getNetAdapterIndexResult -AddressFamily IPv4 | Select-Object -ExpandProperty Dhcp
        if ($getAdapterAssignmentType) {
            Write-Host "    -> IP assignment type found: $getAdapterAssignmentType"
        }
        return $getAdapterAssignmentType
    }
    function Get-DnsServerConfig ($adapterIndex) {
        Write-Host "    -> getting DNS server configuration for adapter with index $adapterIndex"
        $DnsServerConfig = Get-DnsClientServerAddress -InterfaceIndex $getNetAdapterIndexResult -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses
        if ($DnsServerConfig) {
            Write-Host "    -> DNS server addresses found: $($DnsServerConfig -join ', ')"
        }
        return $DnsServerConfig
    }

    Write-Host "Getting information about the adapter with IP address $ipAddressMask"
    $getAdapterConfigResult = Get-NetAdapterConfig -ipAddressToCheck $ipAddressMask
    $getNetAdapterIndexResult = Get-NetAdapterIfIndex -adapterConfig $getAdapterConfigResult
    $getNetGatewayResult = Get-NetGateway -adapterIndex $getNetAdapterIndexResult
    $getDnsServerConfigResult = Get-DnsServerConfig -adapterIndex $getNetAdapterIndexResult
    $getNetIpAssgnmentTypeResult = Get-NetIpAssignmentType -getNetAdapterIndexResult $getNetAdapterIndexResult

    function Build-NetworkObject ($adapterNetworkConfig, $adapterIndex, $gateway, $dnsServer) {
        try {
            $networkObject = [PSCustomObject]@{
                ipAddress      = $adapterNetworkConfig.IPAddress
                interfaceIndex = $adapterIndex
                ipAddressMask  = $adapterNetworkConfig.PrefixLength
                AdapterIndex   = $adapterIndex
                Gateway        = $gateway
                DnsServer      = $dnsServer
                isDHCP         = $getNetIpAssgnmentTypeResult
            }
            return $networkObject
        }
        catch {
            Write-Host "Error building network object: $_"
        }
    }

    Build-NetworkObject -adapterNetworkConfig $getAdapterConfigResult -adapterIndex $getNetAdapterIndexResult -gateway $getNetGatewayResult -dnsServer $getDnsServerConfigResult
}



function Set-NetAdapterConfig ($adapterConfig, $ipAddressForce) {
    try {
        Write-Host "    -> disabling DHCP on adapter with index $($adapterConfig.interfaceIndex)"
        Set-NetIPInterface `
            -InterfaceIndex $adapterConfig.interfaceIndex `
            -Dhcp Disabled
        
        <#
        Write-Host "    -> removing existing IP address $($adapterConfig.IPAddress) from adapter with index $($adapterConfig.interfaceIndex)"
        Remove-NetIPAddress `
            -InterfaceIndex $adapterConfig.interfaceIndex `
            -Confirm:$false
        #>

        Write-Host "    -> setting new IP address $ipAddressForce on adapter with index $($adapterConfig.interfaceIndex)"
        New-NetIPAddress `
            -interfaceIndex $adapterConfig.interfaceIndex `
            -IPAddress $ipAddressForce `
            -PrefixLength $adapterConfig.ipAddressMask `
            -DefaultGateway $adapterConfig.Gateway

        Write-Host "    -> setting up DNS server addresses on adapter with index $($adapterConfig.interfaceIndex)"
        Set-DnsClientServerAddress `
            -InterfaceIndex $adapterConfig.interfaceIndex `
            -ServerAddresses $adapterConfig.DnsServer

        Write-Host "IP adapter set successfully."
        Write-Host "    -> waiting for 5 seconds to ensure the changes take effect..."
        Start-Sleep -Seconds 5

        return $true
    }
    catch {
        Write-Host "Error setting IP address: $_"
        return $_.Exception.Message
    }
}

function Restart-NetAdapterOnSuccess ($adapterIndex) {
    Write-Host "Restarting network adapter after successful configuration"
    try {
        Restart-NetAdapter -InterfaceIndex $adapterIndex -Confirm:$false
    }
    catch {
        Write-Host "Error restarting network adapter: $_"
        exit 1
    }
}











Write-Host "Checking for ip assignment type (dhcp\static)"
$getnetIpAssignmentTypeResult = Get-netIpAssignmentType -adapterConfig $getAdapterConfigResult

if ($getnetIpAssignmentTypeResult -eq "Enabled") {
    Write-Host "Adapter is using DHCP, proceeding to set static IP"

    Write-Host "Building network object with gathered information"
    $adapterNetworkObject = Build-NetworkObject -adapterNetworkConfig $getAdapterConfigResult -adapterIndex $getNetAdapterIndexResult -gateway $getNetGatewayResult -dnsServer $getDnsServerConfigResult

    Write-Host "Setting new IP address $ipAddressForce on the adapter"
    $setAdapterConfigResult = Set-NetAdapterConfig -adapterConfig $adapterNetworkObject -ipAddressForce $ipAddressForce

    if ($setAdapterConfigResult) {
        Write-Host "Network adapter configuration updated successfully."
        Restart-NetAdapterOnSuccess -adapterIndex $getNetAdapterIndexResult
    }
    else {
        Write-Host "Failed to update network adapter configuration."
    }
}
else {
    Write-Host "Adapter is already using static IP, checking if it matches the forced IP address $ipAddressForce"

    if ($($getAdapterConfigResult).IPAddress -eq $ipAddressForce) {
        Write-Host "Adapter is already using the forced IP address $ipAddressForce, no changes needed."
        exit 0  
    }
    else {
        Write-Host "Adapter is not using the forced IP address $ipAddressForce, proceeding to change it on interface $getNetAdapterIndexResult."

        #$setipstatic = New-NetIPAddress -InterfaceIndex $getNetAdapterIndexResult -IPAddress $ipAddressForce -PrefixLength $getAdapterConfigResult.PrefixLength | Out-null
        $setipstatic = Get-NetIPAddress `
        | Where-Object IPAddress -like $ipAddressMask `
        | Where-Object AddressFamily -like IPv4 `
        | Remove-NetIPAddress -PassThru -Confirm:$false `
        | New-NetIPAddress -IPAddress $ipAddressForce -PrefixLength $getAdapterConfigResult.PrefixLength -Confirm:$false
        
        Write-Host "    -> waiting for 5 seconds to ensure the changes take effect..."
        Start-Sleep -Seconds 5

        if ($setipstatic) {
            Write-Host "    -> IP address changed successfully to $ipAddressForce"
            Restart-NetAdapterOnSuccess -adapterIndex $getNetAdapterIndexResult
        }
        else {
            Write-Host "Failed to change IP address to $ipAddressForce"
        }
    }
} 

Invoke-Breezev2
#>