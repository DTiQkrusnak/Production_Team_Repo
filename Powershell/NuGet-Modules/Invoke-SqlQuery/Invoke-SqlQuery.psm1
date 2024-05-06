function Invoke-SqlQuery {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        ParameterSetName="With query")]
        [ValidateNotNullOrEmpty()]
        [string] $Query,

        [Parameter(Mandatory=$true,
        ParameterSetName="With input file")]
        [ValidateNotNullOrEmpty()]
        [string] $InputFile,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConnectionString,

        [int] $QueryTimeout = 10
    )

    try {
        if ($Query) {
            $data = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $Query -QueryTimeout $QueryTimeout -ErrorAction Stop
        } else {
            $data = Invoke-Sqlcmd -ConnectionString $ConnectionString -InputFile $InputFile -QueryTimeout $QueryTimeout -ErrorAction Stop
        }
        return $data
    } catch {
        try {
            [System.Data.SqlClient.SqlConnection]::ClearAllPools()
            $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection -ArgumentList $ConnectionString
            if ($connection.State -ne 'Open') {
                $connection.Open()
            }

            if ($InputFile) {
                $Query = Get-Content -Path $InputFile -Raw -Force
            }
            $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
            $command.CommandText = $Query
            $command.Connection = $connection
            $command.CommandTimeout = $QueryTimeout

            $adp = New-Object System.Data.SqlClient.SqlDataAdapter $sqlcmd
            $adp.SelectCommand = $command
            $data = New-Object System.Data.DataSet
            $adp.Fill($data) | Out-Null

            return $data.Tables
        } catch {
            throw $_
        } finally {
            if ($connection.State -eq 'Open') {
                $connection.Close()
            }
        }
    }
}