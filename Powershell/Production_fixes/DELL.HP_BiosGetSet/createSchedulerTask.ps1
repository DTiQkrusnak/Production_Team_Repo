function downloadScript {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "Downloading script"
        Invoke-WebRequest -Uri "https://files-us-ps2.go360iq.com/_Files/Software/Scripts/BIOS_configTool/BIOSsetAndCheck_Dell.Hp.v.1.5.ps1" -OutFile "C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads\BIOSsetAndCheck_DellHp.ps1"
        Write-Host "    -> file downloaded"
    }
    catch {
        $_.Message.Exception
    }    
}

function getControllerType {
    $query = @'
SELECT CM.Name
FROM Location.Controllers AS LC
LEFT JOIN Controller.Models AS CM
ON CM.ModelID = LC.ModelID
'@

	$connectionStringEz360Objects = 'Server=.\EZ360;Database=EZ360Objects;User Id=EZ360System;Password=EZ360System;TrustServerCertificate=True'
    $script:dvrTypeCheck = (Invoke-Sqlcmd -ConnectionString $connectionStringEz360Objects -Query $query -QueryTimeout 120).name
}

function createTask {
    param (
        $dvrTypeCheck
    )

    if ($dvrTypeCheck -eq "VDMS DTT") {
        Write-Host "Executing VDMS DTT found:"
        $user = 'dttserver'
        $pass = 'dt87sUBu'
    }
    else {
        Write-Host "Executing VDMS 360 type found:"
        $user = 'Support'
        $pass = '$t360@min'
    }

    try {
        $setTime = (get-date).AddMinutes(5).ToString("HH:mm")
        Write-Host "Creating ""SetBios"" scheduler task"
        schtasks.exe /CREATE /tn 'SetBIOS' /RU $user /RP $pass /tr "powershell.exe -ExecutionPolicy Bypass -File C:\ProgramData\EZUniverse\EZ360ControllerInstaller\Downloads\BIOSsetAndCheck_DellHp.ps1" /sc once /st $setTime /f 1>$null
        Write-Host "    -> task created"
    }
    catch {
        $_.Message.Exception
    }
}

function runTask {
    try {
        Write-Host "Running task : ""SetBios"""
        Start-Process schtasks.exe -ArgumentList '/RUN /tn "SetBIOS"' -NoNewWindow -Wait

        $timeout, $taskState = $null
        while ($taskState -ne 'Ready') {
            $TaskState = (Get-ScheduledTask -ErrorAction SilentlyContinue | Where-object { $_.TaskName -eq "SetBios" }).State  
            $timeout++

            Write-Host "Seconds : $timeout"
            
            if ($timeout -ge '60') {
                Write-Host "Breaking loop"
                break
            }

            Start-Sleep -Seconds 1
        }
    }
    catch {
        $_.Message.Exception
    }    
}

function deleteTask {
    try {
        $TaskState = (Get-ScheduledTask -ErrorAction SilentlyContinue | Where-object { $_.TaskName -eq "SetBios" }).State   
        if ($taskState -eq 'Ready') {
            Write-Host "Deleting task : ""SetBios"""
            Start-Process schtasks.exe -ArgumentList '/DELETE /TN SetBios /f' -Wait -NoNewWindow
        } else {
            Write-Error "Task still running > 60 seconds, perhaps infinite loop?"
            break
        }

    }
    catch {
        $_.Message.Exception
    }
}

getControllerType
downloadScript
createTask $dvrTypeCheck
runTask
deleteTask