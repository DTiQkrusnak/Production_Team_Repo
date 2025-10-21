
function Set-OssStatuses() {
    # 2025-10-19 includes all files created on 19 as well
    $connection_string_EZ360 = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    $reset_oss_files_query = @'
UPDATE [EZ360Video].[OSS].[Files]
SET StatusID = 1
WHERE CreatedOn > '2025-10-19'
AND StatusID = -3
'@

    [Net.ServicePointManager]::SecurityProtocol = "Tls12"
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()

    try {
        Invoke-Sqlcmd -ConnectionString $connection_string_EZ360 `
            -Query $reset_oss_files_query `
            -QueryTimeout 30 `
            -ErrorAction Stop
    }
    catch {
        $_
    }
}

Set-OssStatuses