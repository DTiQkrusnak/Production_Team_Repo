$setValue = 2

function scrambledata {
    <#
        .DESCRIPTION
        Function will scramble data with $setValue in: 
            * [EZ360Controllers].[Config].[ServiceSections], Configuration column
            * [EZ360Video].[PVM].[LocationDisplays], PVMRunModeIndex column
    #>
    function setPVMonDB_scramble {
        $query = @"
SELECT [Configuration]
FROM [EZ360Controllers].[Config].[ServiceSections]
WHERE [Name] = 'PVMConfiguration'
AND ServiceID = '290'

UPDATE [EZ360Video].[PVM].[LocationDisplays] 
SET [PVMRunModeIndex] = '$setValue'
"@
        ###DB stuff
        $ConnectionString = 'Server=.\EZ360;Database=EZ360Controllers;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
        $var = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop -QueryTimeout 300 -MaxCharLength 250000

        $JSONDB = $var.Configuration | ConvertFrom-Json

        Write-Host " Modifing [EZ360Controllers].[Config].[ServiceSections]..."
        $JSONDB |  Where-Object { $_.PVMRunModeIndex = $setValue }
        $jsonResult = $JSONDB | ConvertTo-Json
        
        $updateQuery = @"
        UPDATE [EZ360Controllers].[Config].[ServiceSections]
        SET [Configuration] = '$jsonResult'
        WHERE Name = 'PVMConfiguration'
        AND ServiceID = '290'
"@
        
        try {
            Write-Host "    -> database updated"
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $updatequery -ErrorAction Stop -QueryTimeout 300 -MaxCharLength 250000
        }
        catch {
            $_.Exception.Message
        }
    }  
    
    
    function setPVMonFile_scramble {
        <#
            .DESCRIPTION
            Function will scramble data with $setValue in: 
                * C:\Program Files (x86)\EZUniverse\360iQPVMController\configuration.json, PVMRunModeIndex node
        #>
        ### file  stuff
        $configPath = 'C:\Program Files (x86)\EZUniverse\360iQPVMController\configuration.json'
        $jsonFile = Get-Content $configPath | Out-String | ConvertFrom-Json
        $item = 'PVMRunModeIndex'
        if (Test-Path $configPath) {
            
            Write-Host " Modyfing file..."
            $jsonFile.$item = $setValue
            try {
                Write-Host "    -> saving file"
                $jsonFile | ConvertTo-Json -Depth 32 | Set-Content $configPath
            }
            catch {
                $_.Exception.Message
            }
        }
    }

    setPVMonDB_scramble
    setPVMonFile_scramble
}

function checkData {
    <#
        .DESCRIPTION
        Function will fetch data from
            * [EZ360Controllers].[Config].[ServiceSections], Configuration column
            * [EZ360Video].[PVM].[LocationDisplays], PVMRunModeIndex column
            * C:\Program Files (x86)\EZUniverse\360iQPVMController\configuration.json, PVMRunModeIndex node
    #>

    function getPVMonDB {
        $query = @"
    SELECT [Configuration]
    FROM [EZ360Controllers].[Config].[ServiceSections]
    WHERE [Name] = 'PVMConfiguration'
    AND ServiceID = '290'
"@

        $query2 = @"
    SELECT [PVMRunModeIndex] FROM [EZ360Video].[PVM].[LocationDisplays]
"@
        ###DB stuff
        $ConnectionString = 'Server=.\EZ360;Database=EZ360Controllers;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
        $var = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop -QueryTimeout 300 -MaxCharLength 250000
        $var2 = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query2 -ErrorAction Stop -QueryTimeout 300 -MaxCharLength 250000

        $JSONDB = $var.Configuration | ConvertFrom-Json
        $JSONDB2 = $var2.PVMRunModeIndex
        Write-Host "Database check : "
        Write-Host " PVMRunModeIndex ([EZ360Controllers].[Config].[ServiceSections]) value: " -NoNewline
        Write-Host "$($JSONDB.PVMRunModeIndex)" -ForegroundColor Green

        Write-Host " PVMRunModeIndex ([EZ360Video].[PVM].[LocationDisplays]) value: " -NoNewline
        Write-Host "$($JSONDB2)" -ForegroundColor Green
    }
    function getPVMonFile {
        ### file  stuff
        $configPath = 'C:\Program Files (x86)\EZUniverse\360iQPVMController\configuration.json'
        $jsonFile = Get-Content $configPath | Out-String | ConvertFrom-Json
        $item = 'PVMRunModeIndex'

        Write-Host "File check : "
        Write-Host " PVMRunModeIndex (configuration.json) value: " -NoNewline
        Write-Host "$($jsonFile.$item)" -ForegroundColor Green
    }
    
    getPVMonDB
    getPVMonFile
}

<#
    1. set $setValue on top with desired value
    2. Uncomment both functions ("scrambledata", "checkData") and run the script
    3. run fix using "removeVAComponents.ps1" script
    4. comment "scrambledata" function and run this script again to check if fix has been applied
#>
scrambledata
checkData