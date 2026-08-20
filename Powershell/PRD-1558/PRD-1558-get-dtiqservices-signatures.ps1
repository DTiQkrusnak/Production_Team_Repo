$exePaths = 'C:\Program Files\EZUniverse', 'C:\Program Files (x86)\EZUniverse', 'C:\Program Files (x86)\DTiQ'
$exeExclude = "unins*.exe"
$exeInclude = "*.exe"


$exes = @(
    (Get-ChildItem -Path $exePaths -Include @($exeInclude) -Exclude @($exeExclude) -Recurse) | ForEach-Object {

        [PSCustomObject]@{
            Path      = $_.DirectoryName
            Exe       = $_.Name
            Version   = $_.VersionInfo.FileVersion
            Signature = $(Get-AuthenticodeSignature $_).Status
        }
        #>
    }
)

$exes #| ConvertTo-Csv
