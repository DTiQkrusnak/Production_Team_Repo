$onstartupscriptsPath = "C:\ProgramData\DTiQ\onstartupscripts\"
$getonstartupscriptsLogs = Get-ChildItem "$onstartupscriptsPath\logs\"
$amIadmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)


## functions
function OnstartupScriptsCleanup {
    Write-host "Executing OnstartupScriptsCleanup"
    if ($getonstartupscriptsLogs) {
        Write-Host " Removing log files:"
        foreach ($file in ($getonstartupscriptsLogs).Name) {    
            try {
                Write-Host "    -> [i] File removed : $file"
                Remove-Item "$onstartupscriptsPath\logs\$file" -Force-Confirm:$false
            }
            catch {
                Write-Error "    -> [e] Couldnt remove file: $file"
            }
        }
    } 
    
    Write-Host " Removing a.flag"
    if (Get-ChildItem $onstartupscriptsPath -Filter "a.flag") {
        try {
            Write-Host "    -> [i] File removed : a.flag"
            Remove-Item "$onstartupscriptsPath\a.flag" -Force -Recurse -Confirm:$false
        }
        catch {
            Write-Error "    -> [e] Couldnt remove file: a.flag"
        }
    }
}

function CleanEventLogs {
    Write-Host "Cleaning Eventlogs"
    foreach ($eventLog in (Get-EventLog -LogName *)) {
        try {
            Write-Host "    -> [i] cleaning eventlog : $($eventlog.Log)"
            Clear-EventLog -LogName $eventLog.Log -Confirm:$false
        }
        catch {
            Write-Error "   -> [e] Failed to remove eventlog : $($eventlog.Log)" -ErrorAction Continue
        }   
    }
    
}

function ChangeImageVerFile {
    try {
        Write-Host "Edit ImageVer.txt : add new version and changes..."
        Start-Process -FilePath "notepad.exe" -ArgumentList "C:\ProgramData\DTiQ\ImageVer.txt" -Wait    
        Write-Host "    -> [i] C:\ProgramData\DTiQ\ImageVer.txt - saved"
    }
    catch {
        Write-Error "    -> [e] Failed to save : C:\ProgramData\DTiQ\ImageVer.txt"
    }
}



## main script
if ($amIadmin -eq $false) {
    Write-Host "Please run with adminstrator privileges"
}
else {
    OnstartupScriptsCleanup
    CleanEventLogs
    ChangeImageVerFile
}