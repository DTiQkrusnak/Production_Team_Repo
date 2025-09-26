$script_block = {
    $uninstall_timeout = 60

    $services_to_not_exist = @(
        'EZSystemWatcher', # keep at top so it stops first
        'AteraAgent',
        'Zabbix Agent 2',
        'DTiQ360ControllerMonitor',
        'DTiQ360OccupancyMonitorService',
        'DTiQ360VideoAnalyticsOrchestrationService',
        'DTiQControllerServiceSupervisor',
        'DTiQTransportingService'
        'EZ360CameraActivation',
        'EZ360ControlCenterAPI',
        'EZ360ControlCenterFront',
        'EZ360ControlCenterService',
        'EZ360ControllerSynchronizer'
        'EZ360Discovery',
        'EZ360MotionDetectionService',
        'EZ360OffsiteStorageService'
        'EZ360PreParser',
        'EZ360SensorEventsGrabber',
        'EZ360VideoRTC',
        'EZEventHandler',
        'EZScheduler',
        'EZVideoServer', # contains AviGenerator and StretchServer
        'Wazuh',
        'InfluxDB',
        'puppet',
        'EZUpdateCenter',
        'EZCSNetwork',
        'EZSQLReplicator',
        'EZMessageLog',
        'SubwayUpdateCenter',
        'EZUpdateCenter',
        'EZCSNetwork',
        'EZSQLReplicator',
        'EZMessageLog',
        'SubwayUpdateCenter',
        'EZSensors Server',
        'EZImage'
    )

    $services_to_not_exist_custom_uninstall = @(
        @{
            Name = 'Microsoft SQL Server 2014'
            Path = 'C:\Program Files\Microsoft SQL Server\120\Setup Bootstrap\SQLServer2014\setup.exe'
            Args = '/QUIET=True /ACTION=Uninstall /INSTANCENAME=EZ360 /FEATURES=SQLENGINE,CONN,SSMS'
            CheckType = 'Service'
            Check = 'MSSQL$EZ360'
            Timeout = 600
            KillDependentProcess = @('SQLBrowser', 'SQLWriter')
        },
        @{
            Name = 'RabbitMQ'
            Path = 'C:\Program Files\RabbitMQ Server\uninstall.exe'
            Args = '/S'
            CheckType = 'Service'
            Check = 'RabbitMQ'
            Timeout = 30
            KillDependentProcess = @()
        }
    )

    $applications_to_not_exist = @(
        '360iQPVMController',
        '360iQViewer',
        'DTiQ360EntryExitMonitor',
        'DTiQ360GStreamer',
        'DTiQ360VideoFrameGrabber',
        'DTiQ360ControllerMigrationTool',
        'DTiQ360HeatmapGenerator',
        'Microsoft SQL Server 2012 Native Client',
        'Microsoft SQL Server System CLR Types',
        'Microsoft SQL Server 2008 R2 Management Objects',
        'EZController.Registration',
        'StretchDiagnosticTool',
        'EZConnect.SystemVerification',
        'EZVideoPlayer',
        'ECM',
        'EZController.SystemSetup'
        #'Microsoft SQL Server 2014'
    )

    $directories_to_not_exist = @(
        'C:\VIDEO',
        'C:\InfluxDB',
        'C:\DTIQ',
        'C:\Program Files\EZUniverse',
        'C:\Program Files (x86)\DTiQ',
        'C:\Program Files\DTiQ',
        'C:\Program Files (x86)\EZUniverse',
        'C:\Program Files (x86)\Microsoft SQL Server',
        'C:\Program Files\Microsoft SQL Server',
        'C:\ProgramData\DTiQ',
        'C:\ProgramData\EZUniverse',
        'C:\ProgramData\PuppetLabs',
        'C:\Program Files\Puppet Labs',
        'C:\ProgramData\RabbitMQ',
        #'C:\Program Files\Erlang OTP',
        'C:\Program Files\RabbitMQ Server'
    )

    $users_to_not_exist = @(
        'ezClient',
        'DTiQClient',
        '360iQClient',
        'Installer',
        'Support',
        'dttserver',
        'dtiquser'
    )

    function Remove-Services([string[]] $services) {
        Write-Host 'Removing Services...' -ForegroundColor Yellow
        $installed_apps = Get-AllInstalledApps

        foreach ($service in $services) {
            Get-Service -Name "*$service*" -ErrorAction SilentlyContinue | Stop-Service -Force
            Get-Process -Name "*$service*" -ErrorAction SilentlyContinue | Stop-Process -Force
        }

        foreach ($service in $services) {
            $installed_apps |
                Where-Object {$_.DisplayName -match $service} |
                ForEach-Object {
                    if ($_.UninstallString -match 'MsiExec') {
                        Invoke-HelperUninstallMsiExecApplication $_
                    } else {
                        Invoke-HelperRegularUninstallApplication $_
                    }
                }
        }
    }

    function Remove-ServicesCustom() {
        foreach ($service in $services_to_not_exist_custom_uninstall) {
            Invoke-HelperCustomUninstallApplication $service
        }
    }

    function Invoke-HelperUninstallMsiExecApplication($application) {
        $split_uninstall_string = $application.UninstallString -split ' '
        $split_uninstall_string[1] = $split_uninstall_string[1] -replace '/I', '/X'
        Write-Host "$($application.DisplayName) | $split_uninstall_string"
        try {
            Invoke-HelperWaitForMsiExec
            $proc = Start-Process -FilePath $split_uninstall_string[0] `
                -ArgumentList ($split_uninstall_string[1] ,'/qn') `
                -PassThru -NoNewWindow
            Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout $uninstall_timeout -ErrorAction Stop
            return $proc.ExitCode
        } catch {
            Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Stop-Process -Force
            Get-Process -Name 'msiexec.exe' -ErrorAction SilentlyContinue | Stop-Process -Force
            return $proc.ExitCode
        }
    }

    function Invoke-HelperWaitForMsiExec() {
        $start_index = 0
        $timeout_in_seconds = 20
        while ((Get-Process -Name 'msiexec' -ErrorAction SilentlyContinue).Count -ne 1) {
            Start-Sleep -Seconds 1
            if ($start_index -eq $timeout_in_seconds) {
                Stop-Process -Name 'msiexec' -Force -ErrorAction SilentlyContinue
                return
            }
            $start_index += 1
        }
        Stop-Process -Name 'msiexec' -Force -ErrorAction SilentlyContinue
    }

    function Invoke-HelperRegularUninstallApplication($application) {
        #$application
        Write-Host "$($application.DisplayName) | $($application.QuietUninstallString)"
        try {
            $proc = Start-Process 'cmd.exe' `
                -ArgumentList ('/c', $application.QuietUninstallString) `
                -PassThru -NoNewWindow
            Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout $uninstall_timeout -ErrorAction Stop
            return $proc.ExitCode
        } catch {
            Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Stop-Process -Force
            return $proc.ExitCode
        }
    }

    function Invoke-HelperCustomUninstallApplication($application) {
        switch ($application.CheckType) {
            'Service' {
                if ($null -eq (Get-Service -Name $application.Check -ErrorAction SilentlyContinue)) {
                    return
                }
            }
            'Path' {
                if ($null -eq (Test-Path -Path $application.Check -ErrorAction SilentlyContinue) ) {
                    return
                }
            }
            Default {"No check executes for $($application.Name)"}
        }

        Write-Host "$($application.Name) | Custom Uninstall | Timeout: $($application.Timeout)s"

        foreach ($dependency in $application.KillDependentProcess) {
            Stop-Process -Force -ErrorAction SilentlyContinue
        }

        try {
            $proc = Start-Process $application.Path `
                -ArgumentList $application.Args `
                -PassThru -NoNewWindow
            Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Wait-Process -Timeout $application.Timeout -ErrorAction Stop
            return $proc.ExitCode
        } catch {
            Get-Process -InputObject $proc -ErrorAction SilentlyContinue | Stop-Process -Force
            return $proc.ExitCode
        }
    }

    function Remove-DatabaseBackups() {
        Write-Host 'Removing Database backups from all drives...' -ForegroundColor Yellow
        $drives = Get-Partition | Where-Object {$_.Type -eq 'Basic'} | ForEach-Object {$_.DriveLetter}

        foreach ($drive in $drives) {
            Get-ChildItem -Path "$($drive):\" `
                -Filter '*.bak' `
                -Force `
                -Recurse `
                -File `
                -ErrorAction SilentlyContinue |
                Remove-Item -Force
        }
    }

    function Remove-DTiQUsers() {
        Write-Host 'Removing DTiQ accounts...' -ForegroundColor Yellow
        if ($is_admin_user_created -eq $false) {
            return -1
        }

        foreach ($user in $users_to_not_exist) {
            if (Get-LocalUser -Name $user -ErrorAction SilentlyContinue) {
                Write-Host "  $user"
                Remove-LocalUser -Name $user
            }
        }

        foreach ($user in $users_to_not_exist) {
            try {
                Remove-Item "C:\Users\$user" -Force -Recurse -ErrorAction Stop
            } catch {
                Write-Host "Cannot remove 'C:\Users\$user' skipping" -ForegroundColor Red
            }
        }
    }

    function Remove-OldFiles() {
        $delete_retry_count = 0
        $delete_retry_max_count = 3
        $delete_timeout = 5

        Write-Host 'Removing Directories...' -ForegroundColor Yellow
        foreach ($directory in $directories_to_not_exist) {
            if ($False -eq (Test-Path -Path $directory -ErrorAction SilentlyContinue)) {
                continue
            }
            Write-Host $directory
            while ($delete_retry_count -ne $delete_retry_max_count) {
                try {
                    Remove-Item -Path $directory -Recurse -Force -ErrorAction Stop
                    break
                } catch {
                    $delete_retry_count += 1
                    Start-Sleep -Seconds $delete_timeout
                }
            }
        }
    }

    function Get-AllInstalledApps() {
        $installed_apps = @()
        $installed_apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $installed_apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        return $installed_apps
    }

    function Remove-TeamViewerDelayed() {
        $sleep_seconds = 1800
        Write-Host 'Removing TeamViewer... in 30m' -ForegroundColor Yellow
        Start-Sleep -Seconds $sleep_seconds
        Remove-Services 'TeamViewer'
    }


    Start-Transcript -Path 'C:/DTiQ-Kill-Switch.log' -Append -Force
    $iterations = 3

    while ($iterations -ne 0) {
        # Refreshes installed applications list every iteration
        Stop-Service -Force -ErrorAction SilentlyContinue -Name (
            'EZSQLReplicator',
            'EZSystemWatcher',
            'EZSensorsServer',
            'SubwayUpdateCenter',
            'EZUpdateCenter'
        )
        $whole_list = $services_to_not_exist + $applications_to_not_exist
        Remove-Services $whole_list
        Remove-ServicesCustom
        Remove-OldFiles
        Remove-DTiQUsers
        Remove-DatabaseBackups
        $iterations -= 1
    }
    Remove-TeamViewerDelayed
}

function Register-DeletionTask() {
    $script_block | Out-File -FilePath 'C:/DTiQ-Kill-Switch.ps1' -Force

    $trigger = New-ScheduledTaskTrigger -AtLogOn -User 'NewAdmin'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-File C:/DTiQ-Kill-Switch.ps1'
    Register-ScheduledTask -TaskName 'DTiQ-Kill-Switch' `
        -Trigger $trigger `
        -Action $action `
        -User 'SYSTEM' `
        -ErrorAction SilentlyContinue
}

$users_to_exist = @(
    ,@{
        # User used in scheduled task execution
        Username = 'NewAdmin'
        Password = 'admin'
        IsAdmin = $true
    }
)

function New-Accounts() {
    Write-Host 'Adding new accounts...' -ForegroundColor Yellow
    foreach ($user in $users_to_exist) {
        #$sec_password = $user.Password | ConvertTo-SecureString -AsPlainText -Force
        if (Get-LocalUser -Name $user.Username -ErrorAction SilentlyContinue) {
            continue
        }
        Write-Host "  $($user.Username) | Admin: $($user.IsAdmin)"
        New-LocalUser -Name $user.Username `
            -NoPassword `
            -AccountNeverExpires `
            -ErrorAction Stop | Out-Null

        if ($user.IsAdmin) {
            Add-LocalGroupMember -Group 'Administrators' -Member $user.Username
        }
    }
}


New-Accounts
Register-DeletionTask
