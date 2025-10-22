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
    # NOTE: Windows 11 systems consider cleanmgr deprecated and moved to new System Settings -> Storage -> Temporary Files
    # Storage Sense have to be configured per user registry hive in order to clean Downloads, Temp and other user paths
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

function Remove-TempFolders() {
    $profile_temp_folders = Get-ChildItem -Path 'C:\Users' -Directory | ForEach-Object {
        if (Test-Path "$($_.FullName)\AppData\Local\Temp") {
            "$($_.FullName)\AppData\Local\Temp"
        }

        if (Test-Path "$($_.FullName)\Downloads") {
            "$($_.FullName)\Downloads"
        }
    }

    foreach ($path in $profile_temp_folders) {
        $size = (Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum /1024/1024
        $rounded = [math]::Round($size, 2)
        Write-Host "$rounded MB | $path"

        Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Remove-DesktopScriptFiles() {
    $profile_desktop_folders = Get-ChildItem -Path 'C:\Users' -Directory | ForEach-Object {
        if (Test-Path "$($_.FullName)\Desktop") {
            "$($_.FullName)\Desktop"
        }
    }

    foreach ($path in $profile_desktop_folders) {
        Get-ChildItem -Path $path -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue | `
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function  Remove-BreezeTask {
    $taskList = @(
        'W10W11Upgrade',
        'UpdateWindows'
    )
    foreach ($taskName in $taskList) {
        $taskExists = Get-ScheduledTask -TaskName $taskName -TaskPath "\" -ErrorAction SilentlyContinue
        if ($taskExists) {
            try {
                Write-Host "Removing Task..."
                Unregister-ScheduledTask -TaskName $taskName -TaskPath "\" -Confirm:$false | Out-Null
            }
            catch {
                $_.Exception.Message
            }
        }
    }
}

function Remove-Files {
    $filePathList = @(
        'C:\ProgramData\DTiQ\W10W11Upgrade\Breeze_W10W11Upgrade.ps1'
    )
    foreach ($itemPath in $filePathList) {
        if (Test-Path $itemPath -ErrorAction SilentlyContinue) {
            try {
                Write-Host " -> Removing file : $itemPath"
                Remove-Item -Path $itemPath -Force -Confirm:$false #| Out-Null
                Write-Host "   -> removed"
            }
            catch {
                $_.Exception.Message
            }
        }
        else {
            Write-Host " -> Not found : $itemPath"
        }
    }
}




if (Test-OsWin11) {
    Remove-IsoFolders
    Invoke-SystemDiskCleanup
    Remove-TempFolders
    Remove-DesktopScriptFiles
    Remove-BreezeTask
    Remove-Files
}
