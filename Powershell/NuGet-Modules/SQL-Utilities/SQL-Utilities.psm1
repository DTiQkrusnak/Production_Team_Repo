function Invoke-SqlQuery {
    param (
        [Parameter(Mandatory)] [string] $Server,
        [Parameter(Mandatory)] [string] $Username,
        [Parameter(Mandatory)] [Securestring] $Password,
        [Parameter(Mandatory)] [string] $Query,
        [int] $Timeout = 10
    )

    # Clear possible connections that are still open to ensure that Invoke-Sqlcmd  succeeds
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()
    try {
        $result = Invoke-Sqlcmd -ServerInstance $Server -Username $Username -Password $Password -Query $Query -TrustServerCertificate -ConnectionTimeout $Timeout -ErrorAction Stop
        # Clear connection that was made with Invoke-Sqlcmd
        [System.Data.SqlClient.SqlConnection]::ClearAllPools()
        return $result
    } catch {
        return $_
    }
}
Export-ModuleMember -Function * -Alias *