$query = @"
SELECT 
    [Configuration]
FROM 
    [EZ360Controllers].[Config].[ServiceSections]
WHERE 
    [Name] = 'RestartController'
"@

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$connectionStringEz360Video = 'Server=.\EZ360;Database=EZ360Video;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'

Write-Host "Fetching configuration from DB : [EZ360Controllers].[Config].[ServiceSections]..." -NoNewline
$returnQuery = (Invoke-Sqlcmd -ConnectionString $connectionStringEz360Video -Query $query -QueryTimeout '120').Configuration
Write-Host " SUCCESS" -ForegroundColor Green

Write-Host "Casting fetched configuration to XML format..."
[xml]$returnQueryXML = $returnQuery
Write-Host "    -> SUCCESS"

Write-Host "Modyfing value..."
$changeArguments = $returnQueryXML.ActionParameters.ActionParameter | Where-Object { $_.Name -eq 'Arguments' }
$changeArguments.value = '-noprofile -executionpolicy bypass -file CheckWeekDayAndRestart.ps1 Sunday'
Write-Host "    -> SUCCESS"

Write-Host "Saving modification..."
$updateXML = $returnQueryXML.OuterXml
Write-Host "    -> SUCCESS"

$queryUpdate = @"
UPDATE
    [EZ360Controllers].[Config].[ServiceSections]
SET 
    [Configuration] = '$updateXML'
WHERE 
    [Name] = 'RestartController'
"@

Write-Host "Updating database..."
Invoke-Sqlcmd -ConnectionString $connectionStringEz360Video -Query $queryUpdate -QueryTimeout '120'
Write-Host "    -> SUCCESS"