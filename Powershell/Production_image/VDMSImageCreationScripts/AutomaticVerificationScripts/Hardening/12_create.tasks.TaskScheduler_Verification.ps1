<#
    .SYNOPSIS
    Verification scripts for "1.2_create.tasks.TaskScheduler.ps1"

    .NOTES
    I decided to go the class way, as future tasks might have different options
#>

# Define class
class TaskProperties {
    [string]$name
    [string]$action
    [string]$trigger
    [string]$triggerStartTime
    [string]$triggerDayInterval
    [string]$triggerMonthInterval
    [string]$path
    [string]$user
    [string]$runlevel
    [string]$author

    taskProperties(
        [string]$taskname, 
        [string]$taskaction, 
        [string]$tasktrigger, 
        [string]$tasktriggerStartTime,
        [string]$tasktriggerDayInterval,
        [string]$tasktriggerMonthInterval,
        [string]$taskpath, 
        [string]$taskuser,
        [string]$taskrunlevel,
        [string]$taskauthor
    ) {
        $this.name = $taskname
        $this.action = $taskaction
        $this.trigger = $tasktrigger
        $this.triggerStartTime = $tasktriggerstarttime
        $this.triggerDayInterval = $tasktriggerDayInterval
        $this.triggerMonthInterval = $tasktriggerMonthInterval
        $this.path = $taskpath
        $this.user = $taskuser
        $this.runlevel = $taskrunlevel
        $this.author = $taskauthor
    }
}

$ConfigureVDMSTask = [TaskProperties]::new(
    "ConfigureVDMS",
    "-NoProfile -ExecutionPolicy Bypass -File 'C:\ProgramData\DTiQ\onstartupscripts\init.ps1'",
    "At system start up",
    "",
    "",
    "",
    "\",
    "Support",
    "Highest",
    "DTiQ"
)

$temporaryLocationCleanupTask = [TaskProperties]::new(
    "TemporaryLocationCleanup",
    "Remove-Item -Recurse -Force ""C:\Windows\Temp\*""",
    "Daily",
    "2:00:00 AM",
    "Every 1 day(s)",
    "",
    "\",
    "SYSTEM",
    "Highest",
    "DTiQ"
)

$UpdateDefenderDefinitionsTask = [TaskProperties]::new(
    "UpdateDefenderDefinitions",
    "Update-MpSignature",
    "Weekly",
    "",
    "TUE",
    "Every 1 week(s)",
    "\",
    "SYSTEM",
    "Highest",
    "DTiQ"
)


function GetTaskSchedule_SCHTASKS {
    <#
        .SYNOPSIS
        Gathers task data using schtask.exe as Get-ScheduledTask cmdlet doenst have all the data (i.e. "AtStartup" trigger)
    #>
    param (
        [Parameter(Mandatory)] [TaskProperties] $taskProperties
    )
    
    $task = SCHTASKS /query /TN $taskProperties.name /FO LIST /V
    
    <# get schedule type#>
    [string]$taskEditSchType = $task | Select-String -Pattern "Schedule Type:"
    $indexOfColon = $taskEditSchType.IndexOf(":")
    $schTypeResult = $taskEditSchType.Substring($indexOfColon + 1).Trim() #* resultOne

    <# get start time#>
    [string]$taskEditStartTime = $task | Select-String -Pattern "Start Time:"
    $indexOfColon = $taskEditStartTime.IndexOf(":")
    $startTimeResult = $taskEditStartTime.Substring($indexOfColon + 1).Trim() #* resultTwo
    
    <# get days#>
    [string]$taskEditDays = $task | Select-String -Pattern "Days:"
    $indexOfColon = $taskEditDays.IndexOf(":")
    $daysResult = $taskEditDays.Substring($indexOfColon + 1).Trim() #* resultThree

    [string]$taskEditMonths = $task | Select-String -Pattern "Months:"
    $indexOfColon = $taskEditMonths.IndexOf(":")
    $monthsResult = $taskEditMonths.Substring($indexOfColon + 1).Trim() #* resultFour

    $resultObj = [PSCustomObject]@{
        schtype   = $schTypeResult
        starttime = $startTimeResult
        days      = $daysResult
        months    = $monthsResult
    }

    return $resultObj
}

function VerifyTaskProperties {
    <#
        .SYNOPSIS
        Main function that compares TaskProperties objects with the actual state of tasks
    #>
    param (
        [Parameter(Mandatory)] [TaskProperties] $taskProperties
    )
    Write-Host "Checking : $($taskProperties.name)"
    $getTaskInfo = Get-ScheduledTask -TaskName $taskProperties.name -ErrorAction SilentlyContinue
    #$getTaskInfo.Triggers | select -Property *

    if ($getTaskInfo) {
        
        Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
        Write-Host "TaskName OK : $($taskProperties.name)"

        if ($getTaskInfo.Actions.Arguments -eq $taskProperties.action) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "TaskAction OK : $($taskProperties.action)"
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "Action not proper, expected : " -NoNewline
            Write-Host "$($taskProperties.action)" -ForegroundColor Yellow
        }
        
        if ($getTaskInfo.TaskPath -eq $taskProperties.path) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "Task path OK : $($taskProperties.path)"
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "Task path not proper, expected : " -NoNewline
            Write-Host "$($taskProperties.path)" -ForegroundColor Yellow
        }

        if ($getTaskInfo.Principal.UserId -eq $taskProperties.user) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "User OK : $($taskProperties.user)"
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "User not proper, expected : " -NoNewline
            Write-Host "$($taskProperties.user)" -ForegroundColor Yellow
        }

        if ($getTaskInfo.Principal.RunLevel -eq $taskProperties.runlevel) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "Runlevel OK : $($taskProperties.runlevel)"
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "Runlevel not proper, expected : " -NoNewline
            Write-Host "$($taskProperties.runlevel)" -ForegroundColor Yellow
        }

        if ($getTaskInfo.Author -eq $taskProperties.author) {
            Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
            Write-Host "Author OK : $($taskProperties.author)"
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "Author not proper, expected : " -NoNewline
            Write-Host "$($taskProperties.author)" -ForegroundColor Yellow
        }

        $getTypeResult = GetTaskSchedule_SCHTASKS $taskProperties 
        if ($getTypeResult.schtype -eq "Daily") {
            if ($getTypeResult.schtype -eq $taskProperties.trigger) {
                Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
                Write-Host "Schedule type OK : $($taskProperties.trigger)"
            }
            else {
                Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
                Write-Host "Schedule type not proper, expected : " -NoNewline
                Write-Host "$($taskProperties.trigger)" -ForegroundColor Yellow
            }

            if ($getTypeResult.starttime -eq $taskProperties.triggerStartTime) {
                Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
                Write-Host "Start time type OK : $($taskProperties.triggerStartTime)"
            }
            else {
                Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
                Write-Host "Start time not proper, expected : " -NoNewline
                Write-Host "$($taskProperties.triggerStartTime)" -ForegroundColor Yellow
            }

            if ($getTypeResult.days -eq $taskProperties.triggerDayInterval) {
                Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
                Write-Host "Start time type OK : $($taskProperties.triggerDayInterval)"
            }
            else {
                Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
                Write-Host "Start time not proper, expected : " -NoNewline
                Write-Host "$($taskProperties.triggerDayInterval)" -ForegroundColor Yellow
            }

            
        }
        elseif ($getTypeResult.schtype -eq "At system start up") {
            if ($getTypeResult.schtype -eq $taskProperties.trigger) {
                Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
                Write-Host "Schedule type OK : $($taskProperties.trigger)"
            }
            else {
                Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
                Write-Host "Schedule type not proper, expected : " -NoNewline
                Write-Host "$($taskProperties.trigger)" -ForegroundColor Yellow
            }
        }
        elseif ($getTypeResult.schtype -eq "Weekly") {
            if ($getTypeResult.days -eq $taskProperties.triggerDayInterval) {
                Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
                Write-Host "Start time type OK : $($taskProperties.triggerDayInterval)"
            }
            else {
                Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
                Write-Host "Start time not proper, expected : " -NoNewline
                Write-Host "$($taskProperties.triggerDayInterval)" -ForegroundColor Yellow
            }

            if ($getTypeResult.months -eq $taskProperties.triggerMonthInterval) {
                Write-Host " [PASSED] " -NoNewline -ForegroundColor Green
                Write-Host "Month interval OK : $($taskProperties.triggerMonthInterval)"
            }
            else {
                Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
                Write-Host "Month interval not proper, expected : " -NoNewline
                Write-Host "$($taskProperties.triggerMonthInterval)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host " [FAILED] " -NoNewline -ForegroundColor Red
            Write-Host "Task not found, expected : " -NoNewline
            Write-Host "$($taskProperties.name)" -ForegroundColor Yellow
            Write-Host " Cannot gather task properties - ignoring task properties check for : $($taskProperties.name)" -ForegroundColor Yellow
        }
    }
}

VerifyTaskProperties $temporaryLocationCleanupTask
VerifyTaskProperties $ConfigureVDMSTask
VerifyTaskProperties $UpdateDefenderDefinitionsTask