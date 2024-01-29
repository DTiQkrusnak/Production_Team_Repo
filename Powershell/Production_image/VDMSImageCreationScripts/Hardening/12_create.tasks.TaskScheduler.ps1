<#
    .SYNOPSIS
    Creating tasks in Windows task scheduler
#>

# TO DO : 

function CreateConfigureVDMS {
    <#
        .NOTES
        CreateConfigureVDMS : autostart onstartup scripts
    #>
    try {
        $taskTrigger = New-ScheduledTaskTrigger -AtStartup
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell" -Argument "-NoProfile -ExecutionPolicy Bypass -File 'C:\ProgramData\DTiQ\onstartupscripts\init.ps1'" -WorkingDirectory 'C:\ProgramData\DTiQ\onstartupscripts'
        Write-Host "Creating task : ""ConfigureVDMS"""
        Register-ScheduledTask -TaskPath '\' -TaskName 'ConfigureVDMS' -Action $taskAction -Trigger $taskTrigger -User "Support" -RunLevel Highest -ErrorAction Stop | Out-Null
        Write-Host " [+] ""ConfigureVDMS"" task has been created"
        $taskObject = Get-ScheduledTask -TaskName 'ConfigureVDMS'
        $taskObject.Author = 'DTiQ'
        $taskObject | Set-ScheduledTask | Out-Null
    }
    catch {
        Write-Output " [-] $($_.Exception.Message)"
    }
}

function CreateTempLocationCleanup {
    <#
        .NOTES
        CreateTempLocationCleanup : cleanup C:\Windows\Temp\*
    #>
    try {   
        $taskTrigger = New-ScheduledTaskTrigger -Daily -At 2AM
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell" -Argument "Remove-Item -Recurse -Force ""C:\Windows\Temp\*"""
        Write-Host "Creating task : ""TemporaryLocationCleanup"""
        Register-ScheduledTask -TaskPath '\' -TaskName 'TemporaryLocationCleanup' -Action $taskAction -Trigger $taskTrigger -User "SYSTEM" -RunLevel Highest -ErrorAction Stop | Out-Null
        Write-Host " [+] ""TemporaryLocationCleanup"" task has been created"
        $taskObject = Get-ScheduledTask -TaskName 'TemporaryLocationCleanup'
        $taskObject.Author = 'DTiQ'
        $taskObject | Set-ScheduledTask | Out-Null
    }
    catch {
        Write-Output " [-] $($_.Exception.Message)"
    }
}

function CreateUpdateDefenderDefinitions {
    try {
    <#
        .NOTES
        CreateUpdateDefenderDefinitions : update Windows AntiVirus definitions
    #>
        $taskTrigger = New-ScheduledTaskTrigger -DaysOfWeek Tuesday -At 8AM -Weekly
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell" -Argument "Update-MpSignature"
        Write-Host "Creating task : ""UpdateDefenderDefinitions"""
        Register-ScheduledTask -TaskPath '\' -TaskName 'UpdateDefenderDefinitions' -Action $taskAction -Trigger $taskTrigger -User "SYSTEM" -RunLevel Highest -ErrorAction Stop | Out-Null
        Write-Host " [+] ""UpdateDefenderDefinitions"" task has been created"
        $taskObject = Get-ScheduledTask -TaskName 'UpdateDefenderDefinitions'
        $taskObject.Author = 'DTiQ'
        $taskObject | Set-ScheduledTask | Out-Null
    }
    catch {
        Write-Output " [-] $($_.Exception.Message)"
    }
}

CreateConfigureVDMS
CreateTempLocationCleanup
CreateUpdateDefenderDefinitions