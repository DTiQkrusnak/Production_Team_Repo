#! TESTING VARIABLES!
$ipAddressMask = "10.2.1.*"
$ipAddressForce = "10.2.1.196"

#! BK VARIABLES
#$ipAddressMask = "192.168.9.*"
#$ipAddressForce = "192.168.9.10"

# DONE : add breeze with status success / fail - bring feedback
# DONE : revert on failed ping after ip change // research and deploy
# TODO : @maciek ask about QA and force test for this script


# Function to get atributes and info about current netwrok configuration - needed later on to pinpoint proper adapter for cmdlets
# returns Object (ipAddress, interfaceIndex, ipAddressMask, gateway, dnsServer, isDHCP)
function Get-NetAdapterConfigFull {
    function Get-NetAdapterConfig ($ipAddressToCheck) {
        Write-Host "    -> getting basic information about the adapter with IP address $ipAddressToCheck"
        $getAdaperConfig = Get-NetIPAddress | Where-Object { $_.IPAddress -like $ipAddressMask }

        if ($getAdaperConfig) {
            Write-Host "    -> adapter in the $ipAddressToCheck subnet found: $($getAdaperConfig.ipAddress)"
            return $getAdaperConfig    
        }
        else {
            Write-Host "No adapter with such IP exists - sending breeze"
            Invoke-Breezev2 -successStatus "Failed"
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

    function Get-NetAdapterName ($adapterIndex) {
        Write-Host "    -> getting adapter name"
        $getAdapterName = Get-NetAdapter -InterfaceIndex $adapterIndex | Select-Object -ExpandProperty Name
        if ($getAdapterName) {
            Write-Host "    -> adapter name: $getAdapterName"
        }
        return $getAdapterName
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
    $getAdapterNameResult = Get-NetAdapterName -adapterIndex $getNetAdapterIndexResult
    $getNetGatewayResult = Get-NetGateway -adapterIndex $getNetAdapterIndexResult
    $getDnsServerConfigResult = Get-DnsServerConfig -adapterIndex $getNetAdapterIndexResult
    $getNetIpAssgnmentTypeResult = Get-NetIpAssignmentType -getNetAdapterIndexResult $getNetAdapterIndexResult

    function Build-NetworkObject ($adapterNetworkConfig, $adapterIndex, $gateway, $dnsServer, $adaptername) {
        try {
            $networkObject = [PSCustomObject]@{
                ipAddress      = $adapterNetworkConfig.IPAddress
                adapterName    = $adaptername
                interfaceIndex = $adapterIndex
                subnetMask     = $adapterNetworkConfig.PrefixLength
                gateway        = $gateway
                dnsServer      = $dnsServer
                isDHCP         = $getNetIpAssgnmentTypeResult
            }
            return $networkObject
        }
        catch {
            Write-Host "Error building network object: $_"
        }
    }

    Build-NetworkObject `
        -adapterNetworkConfig $getAdapterConfigResult `
        -adapterIndex $getNetAdapterIndexResult `
        -gateway $getNetGatewayResult `
        -dnsServer $getDnsServerConfigResult `
        -adaptername $getAdapterNameResult
}

# Function to change from DHCP -> Static ip 
function Set-NetAdapterConfigDHCP ($adapterConfig, $ipAddressForce) {
    try {
        Write-Host "    -> disabling DHCP on adapter with index $($adapterConfig.interfaceIndex)"
        Set-NetIPInterface `
            -InterfaceIndex $adapterConfig.interfaceIndex `
            -Dhcp Disabled

        Write-Host "    -> setting new IP address $ipAddressForce on adapter with index $($adapterConfig.interfaceIndex)"
        New-NetIPAddress `
            -interfaceIndex $adapterConfig.interfaceIndex `
            -IPAddress $ipAddressForce `
            -PrefixLength $adapterConfig.subnetMask`
            -DefaultGateway $adapterConfig.Gateway

        Write-Host "    -> setting up DNS server addresses on adapter with index $($adapterConfig.interfaceIndex)"
        Set-DnsClientServerAddress `
            -InterfaceIndex $adapterConfig.interfaceIndex `
            -ServerAddresses $adapterConfig.DnsServer

        Write-Host "IP adapter set successfully."
        Write-Host "    -> waiting for 5 seconds to ensure the changes take effect..."
        Start-Sleep -Seconds 5

        $afterNetworkFlag = "FromDHCP"
        return $afterNetworkFlag
    }
    catch {
        Write-Host "Error setting IP address: $_"
        return $_.Exception.Message
    }
}

# Function to change from Static old ip -> Static new ip 
function Set-NetAdapterConfigStatic ($adapterConfig, $ipAddressForce) {    
    Get-NetIPAddress `
    | Where-Object IPAddress -like $ipAddressMask `
    | Where-Object AddressFamily -like IPv4 `
    | Remove-NetIPAddress -PassThru -Confirm:$false `
    | New-NetIPAddress -IPAddress $ipAddressForce -PrefixLength $adapterConfig.subnetMask -Confirm:$false `
    | Out-Null

    Write-Host "    -> waiting for 5 seconds to ensure the changes take effect..."
    Start-Sleep -Seconds 5

    $afterNetworkFlag = "FromStatic"
    return $afterNetworkFlag
}

function Test-ConnectionOnChange {
    $serverName = "8.8.8.8"
    
    #Test-Connection $serverName

    Write-Host "Testing if the connection can be established..."
    #$testConnection = Test-Connection $serverName -Count 6 -ErrorVariable 
    #$testConnection = $null
    #Test-Connection -ComputerName $serverName -Count 5 | Select-Object -Last 1
    if (Test-Connection -ComputerName $serverName -Count 5 -Quiet | Select-Object -Last 1) {
        Write-Host "    -> connection check successful"
        return $true
    }
    else {
        Write-Host "    -> connection check unsuccessful - reverting back"
        return $false
    }


}
function Repair-NetworkFunction {
    param (
        $AdapterConfig,
        $AfterNetworkFlag
    )

    Write-Host "Reverting back to old IP"
    if ($AfterNetworkFlag -eq "FromDHCP") {
        #Removing gateway
        Remove-NetRoute `
            -InterfaceIndex $adapterConfig.interfaceIndex `
            -DestinationPrefix "0.0.0.0/0" `
            -Confirm:$false

        #Enable DHCP on interface
        Set-NetIPInterface `
            -InterfaceIndex $adapterConfig.interfaceIndex `
            -Dhcp Enabled

        #Remove Static IP from the interface configuration
        Get-NetIPAddress - -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.PrefixOrigin -eq "Manual" } |
        Remove-NetIPAddress -Confirm:$false |
        Out-Null

        #Reset DNSserver pool
        Set-DnsClientServerAddress `
            -InterfaceIndex $AdapterConfig.interfaceIndex `
            -ResetServerAddresses |
        Out-Null

        
    }
    elseif ($AfterNetworkFlag -eq "FromStatic") {
        # Change IP back to default
        Write-Host "Changing back to : $($AdapterConfig.ipAddress)/$($AdapterConfig.subnetMask)"
        Get-NetIPAddress `
        | Where-Object InterfaceIndex -eq $($AdapterConfig.interfaceIndex) `
        | Where-Object AddressFamily -like IPv4 `
        | Remove-NetIPAddress -PassThru -Confirm:$false `
        | New-NetIPAddress -IPAddress $AdapterConfig.ipAddress -PrefixLength $adapterConfig.subnetMask -Confirm:$false `
        | Out-Null
    }
    else {
        Write-Host "ERROR - reverting back!"
    }

}

function Restart-NetInterfaceOnSuccess ($interface) {
    Write-Host "Restarting interface : $($interface.adapterName)"
    Start-Sleep -Seconds 10
    Restart-NetAdapter -name $interface.adapterName
}

function Invoke-Breezev2 ($successStatus) {
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
    function Get-CurrentIpAddress {
        $currentip = Get-NetAdapter -Physical `
        | Where-Object Status -eq 'Up' `
        | Get-NetIPAddress -AddressFamily IPv4 `
        | Where-Object IPAddress -ne '192.168.111.50' `
        | Select-Object -ExpandProperty IPAddress
    
        if ($currentip) {
            return $currentip
        }
        else {
            $_
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
    
    
    function sendRestData ($successStatus) {
        $body = @{
            locationId      = $locationIDValue
            locationName    = $displayASValue
            timestamp       = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            timezoneId      = Get-Date -UFormat "%Z"
            scriptName      = "BK_addressChange"
            scriptId        = "61"
            executionDate   = Get-Date -UFormat "%m/%d/%Y %H:%M:%S"
            result          = Get-CurrentIpAddress
            optionalResult1 = $successStatus
            errorCode       = "NULL"
            errorDetails    = "NULL"
            #teamViewerId    = (Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\TeamViewer\).ClientID
            controllerName  = $env:computername
        } | ConvertTo-Json
    
        #$body
    
        ### PROD API
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
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
    sendRestData -successStatus $successStatus

    exit 0
}


### MAIN SCRIPT ###
Write-Host "Gathering information about system and adapter"
$getNetAdapterConfigFullResult = Get-NetAdapterConfigFull

if ($($getNetAdapterConfigFullResult.ipAddress) -eq $ipAddressForce) {
    Write-Host "Adapter is already using the forced IP address $ipAddressForce, no changes needed."
    exit 0
}
else {
    Write-Host "Checking for ip assignment type (dhcp\static)"
    if ($($getNetAdapterConfigFullResult.isDHCP) -eq "Enabled") {
        Write-Host "Adapter is using DHCP, proceeding to set static IP : $ipAddressForce "
        $returnFlag = Set-NetAdapterConfigDHCP `
            -adapterConfig $getNetAdapterConfigFullResult `
            -ipAddressForce $ipAddressForce | Select-Object -Last 1
    }
    else {
        Write-Host "Adapter is using STATIC, proceeding to set new static IP : $ipAddressForce "
        $returnFlag = Set-NetAdapterConfigStatic `
            -adapterConfig $getNetAdapterConfigFullResult `
            -ipAddressForce $ipAddressForce | Select-Object -Last 1
    }
}

###TEST CONNECTION###

<#
#testing variable
$networkObjectBypass = [PSCustomObject]@{
                ipAddress      = "10.1.1.196"
                interfaceIndex = "10"
                subnetMask     = "24"
                gateway        = "10.1.1.1"
                dnsServer      = "10.1.1.1"
                isDHCP         = "Enabled"
            }
#>
$testConnectionOnChangeResult = Test-ConnectionOnChange
if ($testConnectionOnChangeResult -eq $false) {
    Repair-NetworkFunction -AdapterConfig $getNetAdapterConfigFullResult -AfterNetworkFlag $returnFlag
    #testing variable
    #Repair-NetworkFunction -AdapterConfig $networkObjectBypass -AfterNetworkFlag "FromDHCP"
}
#>

Restart-NetInterfaceOnSuccess -interface $getNetAdapterConfigFullResult

Write-Host "Sending breeze status"
Start-Sleep -Seconds 10
Invoke-Breezev2 -successStatus "Success"