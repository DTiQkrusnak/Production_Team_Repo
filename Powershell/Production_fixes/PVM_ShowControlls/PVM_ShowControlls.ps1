#! dont execute script if : 
#!  [EZ360Video].[PVM].[LocationDisplays] notexist or [EZ360Video].[PVM].[LocationDisplays] - configuraitn does not exist

[Net.ServicePointManager]::SecurityProtocol = "Tls12"
$connectionStringEz360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
$indexControllsObject = New-Object System.Collections.Generic.List[PSCustomObject]

$queryGetPVMJSON = @"
SELECT Configuration
  FROM [EZ360Controllers].[Config].[ServiceSections]
  WHERE ServiceID = 290
"@

$PVMJSON = (Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query $queryGetPVMJSON -ErrorAction SilentlyContinue -MaxCharLength '100000').Configuration
#$PVMJSON = "C:\Users\karol.rusnak\Desktop\config.json"
$json = $PVMJSON | ConvertFrom-Json
#$json.ShowControls
#$json = Get-Content $PreParcfgPath | Out-String | ConvertFrom-Json


for ($i = 0; $i -lt $json.Index.Count; $i++) {    
    $object = [PSCustomObject]@{
        Index           = $json.Index[$i]
        ShowControls    = $json.ShowControls[$i]
        ShowControlsBit = if ($json.ShowControls[$i] -eq $false) {
            "0"
        }
        elseif ($json.ShowControls[$i] -eq $true) {
            "1"
        }
    }
    $indexControllsObject.add($object)
}

$indexControllsObject
Start-Sleep -Seconds 2
Write-Host ""


foreach ($element in $indexControllsObject) {
    $querySetPVM = @"
UPDATE [EZ360Video].[PVM].[LocationDisplays]
SET [ShowControls] = $($element.ShowControlsBit)
WHERE [Index] = $($element.Index)
"@
    
    #Write-Host "Setting ShowControlls : $($element.ShowControls) where Index : $($element.Index)"
    #Invoke-Sqlcmd -ConnectionString $connectionStringEz360 -Query $querySetPVM -ErrorAction SilentlyContinue   
    Write-Host $querySetPVM -ForegroundColor Green
    Write-Host ""
}

