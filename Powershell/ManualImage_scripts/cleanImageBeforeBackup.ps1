$onstartupscriptsPath = "C:\ProgramData\DTiQ\onstartupscripts\"
$getonstartupscriptsLogs = Get-ChildItem "$onstartupscriptsPath\logs\"
$amIadmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$getModelinfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue

# TODO: OnstartupScriptsCleanup :  check if file exists if exists then remove
# TODO: DefineControllerType :  check if key and value already exists, swap (force) and\or notify that it has been changed

## functions
function OnstartupScriptsCleanup {
    Write-host "Executing OnstartupScriptsCleanup"
    if ($getonstartupscriptsLogs) {
        Write-Host " Removing log files:"
        foreach ($file in ($getonstartupscriptsLogs).Name) {    
            try {
                Write-Host "    -> [i] File removed : $file"
                Remove-Item "$onstartupscriptsPath\logs\$file" -Force -Confirm:$false -ErrorAction SilentlyContinue

            }
            catch {
                Write-Host "    -> [e] Couldnt remove file: $file"
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

function CleanFiles {
    $folderPath = @(
        "C:\Users\Support\Downloads\*",
        "C:\ProgramData\EZUniverse\EZ360ControllerInstaller",
        "C:\Program Files (x86)\EZUniverse\EZ360Controller\360iQControllerInstaller\Raport.log"
    )

    Write-Host "Removing contents of : "
    foreach ($path in $folderPath) {
        Write-Host "    -> [i] $path"
        Remove-Item -Path $path -Recurse -Force -Confirm:$false
    }
}

function CleanEventLogs {
    Write-Host " Cleaning Eventlogs"
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
        Write-Host " Edit ImageVer.txt : add new version and changes..."
        Start-Process -FilePath "notepad.exe" -ArgumentList "C:\ProgramData\DTiQ\ImageVer.txt" -Wait
        Write-Host "    -> [i] C:\ProgramData\DTiQ\ImageVer.txt - saved"
    }
    catch {
        Write-Error "    -> [e] Failed to save : C:\ProgramData\DTiQ\ImageVer.txt"
    }
}

function DefineControllerType {
    Write-Host " Defining controller type"

    $VDMSliteModels = @(
        "Virtual Machine"
    )

        if ($getModelinfo.Model -in $VDMSliteModels) {
            $temp = "VDMSLite"
            Write-Host "    -> [i] Model : ""$($getModelinfo.Model)"" --> setting it as : " -NoNewline
            Write-Host $temp -ForegroundColor Green
            New-ItemProperty Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller -Name "ImageDefaultModel" -Value $temp -Force | Out-Null
        } else {
            Write-Host "Model not defined - setting it as VDMS 360iQ" -ForegroundColor Yellow
            
            $temp = "VDMS 360iQ"
            Write-Host " -> [i] Model : ""$($getModelinfo.Model)"" --> setting it as : " -NoNewline
            Write-Host $temp -ForegroundColor Green
            New-ItemProperty Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EZUniverse\EZ360ControllerInstaller -Name "ControllerModel" -Value $temp -Force | Out-Null
        } 
    }


## main script
if ($amIadmin -eq $false) {
    Write-Host "Please run with adminstrator privileges"
}
else {
    OnstartupScriptsCleanup
    CleanFiles
    CleanEventLogs
    ChangeImageVerFile
    #DefineControllerType
}