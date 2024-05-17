function Expand-ArchiveWithFallback {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf })]
        [ValidateScript({ (Split-Path $_ -Leaf).EndsWith('.zip')})] [string] $Path,
        [ValidateScript({Test-Path -Path $_ -PathType Container -IsValid})] [string] $DestinationPath = $null
    )

    if (!$DestinationPath) {
        $DestinationPath = $Path -replace ('.zip', '')
    }

    try {
        if (!(Test-Path -Path $DestinationPath)) {
            New-Item -Name ((Split-Path -Path $DestinationPath -Leaf) -replace ('.zip','')) -Force -ItemType Container | Out-Null
        }
        Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force
    } catch {
        try {
            Remove-Item -Path $DestinationPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            [System.IO.Compression.ZipFile]::ExtractToDirectory( $Path, $DestinationPath)
        } catch {
            throw $_
        }
    }
}

Export-ModuleMember -Function 'Expand-ArchiveWithFallback'