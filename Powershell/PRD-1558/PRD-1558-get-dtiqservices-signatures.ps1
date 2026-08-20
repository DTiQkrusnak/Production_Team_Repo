$exePaths = 'C:\Program Files\EZUniverse', 'C:\Program Files (x86)\EZUniverse', 'C:\Program Files (x86)\DTiQ', 'C:\Program Files\DTiQ'
$exeExclude = "unins*.exe"
$exeInclude = "*.exe"


$exes = @(
    (Get-ChildItem -Path $exePaths -Include @($exeInclude) -Exclude @($exeExclude) -Recurse) | ForEach-Object {
        $signature = Get-AuthenticodeSignature $_ | Select-Object *
        
        [PSCustomObject]@{
            Path      = $_.DirectoryName
            Exe       = $_.Name
            Version   = $_.VersionInfo.FileVersion
            Signature = $signature.Status
            NotBefore = $signature.SignerCertificate.NotBefore
            NotAfter  = $signature.SignerCertificate.NotAfter
        }
        #>
    }
)

$exes | Format-Table
