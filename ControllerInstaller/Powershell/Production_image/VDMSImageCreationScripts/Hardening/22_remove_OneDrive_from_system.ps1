param(
    [switch] $Deploy,
    [switch] $Verify
)

function Start-Deploy {
    if (!(Get-StartApps -Name OneDrive)) {
        return
    }

    $onedrive_setup_path = Resolve-Path -Path 'C:\Users\*\AppData\Local\Microsoft\Onedrive\*\OneDriveSetup.exe' -ErrorAction SilentlyContinue
    if ($onedrive_setup_path.Length -eq 0) {
        Write-Host 'OneDriveSetup.exe not found' -ForegroundColor Yellow
        return
    }

    $onedrive_uninstall_process = Start-Process -FilePath $onedrive_setup_path[0] -ArgumentList '/Uninstall' -PassThru
    $onedrive_uninstall_process | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue -ErrorVariable timeouted
    if ($timeouted) {
        Write-Host 'OneDriveSetup process killed after timeout' -ForegroundColor Yellow
        $onedrive_uninstall_process | Stop-Process -ErrorAction Continue
    }
}

function Start-Verify {
    $retry_count = 10
    while ($retry_count -gt 0) {
        if (!(Get-StartApps -Name OneDrive)) {
            Write-Host 'OneDrive removed' -ForegroundColor Green
            return
        }
        Start-Sleep -Seconds 1
        $retry_count = $retry_count - 1
    }
    Write-Host 'OneDrive still present in system' -ForegroundColor Red
}

if ($Deploy.IsPresent -and $Verify.IsPresent) {
    Start-Deploy
    Start-Verify
} elseif ($Deploy.IsPresent) {
    Start-Deploy
} elseif ($Verify.IsPresent) {
    Start-Verify
} else {
    Start-Deploy
    Start-Verify
}