function Test-OsWin11() {
    $WindowsOsVersion = (Get-ComputerInfo).OsName
    if ($WindowsOsVersion -like '*Windows 11*') {
        return $True
    }

    return $False
}

function Remove-IsoFolders() {
    $disks = Get-Partition | Where-Object {$_.Type -eq 'Basic'} | ForEach-Object {$_.DriveLetter}
    $iso_base_path = 'TEMP\Win11ISO'

    foreach ($disk in $disks) {
        $possible_iso_path = "$($disk):\$iso_base_path"
        if (!(Test-Path -LiteralPath $possible_iso_path)) {
            Write-Output("no ISO at $possible_iso_path")
            continue
        }
        Write-Output("Removing $possible_iso_path")
        Remove-Item -Path $possible_iso_path -Recurse -Force
    }
}

function Invoke-SystemDiskCleanup() {
    $proc = Start-Process `
        -FilePath cleanmgr.exe `
        -ArgumentList ('/sagerun:1 /verylowdisk /autoclean') `
        -PassThru
    Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout 180
}

if (Test-OsWin11) {
    Remove-IsoFolders
    Invoke-SystemDiskCleanup
}