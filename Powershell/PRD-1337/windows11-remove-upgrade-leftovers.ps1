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
        if (!(Test-Path -LiteralPath $possible_iso_path -ErrorAction SilentlyContinue)) {
            Write-Output("no ISO at $possible_iso_path")
            continue
        }
        Write-Output("Removing $possible_iso_path")
        try {
            Remove-Item -Path $possible_iso_path -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Error("Cannot remove $possible_iso_path")
        }
    }
}

function Invoke-SystemDiskCleanup() {
    $5minute_timeout = 300
    $proc = Start-Process `
        -FilePath cleanmgr.exe `
        -ArgumentList ('/sagerun:1 /verylowdisk /autoclean') `
        -PassThru
    Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout $5minute_timeout

    $proc = Start-Process `
        -FilePath dism.exe `
        -ArgumentList ('/online /Cleanup-Image /StartComponentCleanup /ResetBase') `
        -PassThru
    Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout $5minute_timeout

}

if (Test-OsWin11) {
    Remove-IsoFolders
    Invoke-SystemDiskCleanup
}