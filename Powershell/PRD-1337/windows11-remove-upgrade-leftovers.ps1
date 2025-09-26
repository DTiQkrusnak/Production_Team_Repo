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
    Start-ProcessWithTimeout `
        -Path cleanmgr.exe `
        -Arguments ('/sagerun:1 /verylowdisk /autoclean') `
        -Timeout 900

    Start-ProcessWithTimeout `
        -Path dism.exe `
        -Arguments ('/online /Cleanup-Image /StartComponentCleanup /ResetBase') `
        -Timeout 3600
}

function Start-ProcessWithTimeout($Path, $Arguments, $Timeout) {
    try {
        $proc = Start-Process `
            -FilePath $Path `
            -ArgumentList $Arguments `
            -PassThru
        Get-Process -InputObject $proc -ErrorAction SilentlyContinue |
            Wait-Process -Timeout $Timeout -ErrorAction Stop
    } catch {
        Write-Error("$Path not started or timed out")
        Stop-Process -InputObject $proc -Force -ErrorAction SilentlyContinue
    }
}

if (Test-OsWin11) {
    Remove-IsoFolders
    Invoke-SystemDiskCleanup
}