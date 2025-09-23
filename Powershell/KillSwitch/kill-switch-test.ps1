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
    'TeamViewer',
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
    'EZSensors Server'
)

$services_to_not_exist_custom_uninstall = @(
    @{
        Name = 'Microsoft SQL Server 2014'
        Path = 'C:\Program Files\Microsoft SQL Server\120\Setup Bootstrap\SQLServer2014\setup.exe'
        Args = '/QUIETSIMPLE=True /ACTION=Uninstall /INSTANCENAME=EZ360 /FEATURES=SQLENGINE,CONN,SSMS'
        CheckType = 'Service'
        Check = 'MSSQL$EZ360'
        Timeout = 600
    },
    @{
        Name = 'RabbitMQ'
        Path = 'C:\Program Files\RabbitMQ Server\uninstall.exe'
        Args = '/S'
        CheckType = 'Service'
        Check = 'RabbitMQ'
        Timeout = 30
    }
)

$database_services_to_not_exist = @(
    'MSSQL$EZ360'
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

# Looks for them in all drives
$db_backup_paths = @(
    ,':\MSSQL'
)

$users_to_exist = @(
    ,@{
        Username = 'Admin'
        Password = 'admin'
        IsAdmin = $true
    }
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

$database_names = @(
    'EZ360Access',
    'EZ360Applications',
    'EZ360Communication',
    'EZ360Controllers',
    'EZ360Objects',
    'EZ360System',
    'EZ360Video'
)

$installed_apps = @()
$installed_apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
$installed_apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"

$installed_apps_display_names = $installed_apps | ForEach-Object { $_.DisplayName }

function Test-Services() {
    Write-Host "ServiceRemoved:" -ForegroundColor Yellow
    foreach ($service in $services_to_not_exist) {
        $result = Get-Service -Name "*$service*" -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "  $service" -ForegroundColor Red
        }
        else {
            Write-Host "  $service" -ForegroundColor Green
        }
    }
    Write-Host "ServiceAppRemoved:" -ForegroundColor Yellow
    foreach ($app in $services_to_not_exist) {
        $result = $installed_apps_display_names -match $app
        if ($result) {
            Write-Host "  $app" -ForegroundColor Red
        }
        else {
            Write-Host "  $app" -ForegroundColor Green
        }
    }
}

function Test-Applications() {
    Write-Host "ApplicationsRemoved:" -ForegroundColor Yellow
    foreach ($app in $applications_to_not_exist) {
        $result = $installed_apps_display_names -match $app
        if ($result) {
            Write-Host "  $app" -ForegroundColor Red
        }
        else {
            Write-Host "  $app" -ForegroundColor Green
        }
    }
}

function Test-CustomApplications() {
    Write-Host "CustomApplicationsRemoved:" -ForegroundColor Yellow
    foreach ($application in $services_to_not_exist_custom_uninstall) {
        switch ($application.CheckType) {
            'Service' {
                if ($null -eq (Get-Service -Name $application.Check -ErrorAction SilentlyContinue)) {
                    Write-Host "  $($application.Name)" -ForegroundColor Green
                }
                else {
                    Write-Host "  $($application.Name)" -ForegroundColor Red
                }
            }
            'Path' {
                if ($null -eq (Test-Path -Path $application.Check -ErrorAction SilentlyContinue) ) {
                    Write-Host "  $($application.Name)" -ForegroundColor Green
                }
                else {
                    Write-Host "  $($application.Name)" -ForegroundColor Red
                }
            }
            Default { "No check executes for $($application.Name)" }
        }
    }
}

function Test-Accounts() {
    Write-Host "Accounts status:" -ForegroundColor Yellow

    Write-Host "  isRemoved:" -ForegroundColor Yellow
    foreach ($user in $users_to_not_exist) {
        $result = Get-LocalUser -Name $user -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "    $user" -ForegroundColor Red
        }
        else {
            Write-Host "    $user" -ForegroundColor Green
        }
    }

    Write-Host "  isCreated:" -ForegroundColor Yellow
    foreach ($user in $users_to_exist) {
        $result = Get-LocalUser -Name $user.Username -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "    $user" -ForegroundColor Green
        }
        else {
            Write-Host "    $user" -ForegroundColor Red
        }
    }
}

function Test-Databases() {
    Write-Host "Databases:" -ForegroundColor Yellow
    Write-Host "  ServiceRemoved:" -ForegroundColor Yellow
    foreach ($database_service in $database_services_to_not_exist) {
        $service_result = Get-Service -Name $database_service -ErrorAction SilentlyContinue
        if ($service_result) {
            Write-Host "    $database_service" -ForegroundColor Red
        }
        else {
            Write-Host "    $database_service" -ForegroundColor Green
        }
    }

    $database_data_folder_path = 'C:\Program Files (x86)\EZUniverse\EZ360Controller\Data'
    Write-Host "  DataFoldersRemoved:" -ForegroundColor Yellow
    foreach ($folder_name in $database_names) {
        $result = Test-Path -Path "$database_data_folder_path\$folder_name" -PathType Container -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "    $folder_name" -ForegroundColor Red
        }
        else {
            Write-Host "    $folder_name" -ForegroundColor Green
        }
    }

    $database_logs_folder_path = 'C:\Program Files (x86)\EZUniverse\EZ360Controller\Logs'
    Write-Host "  LogsFoldersRemoved:" -ForegroundColor Yellow
    foreach ($file_name in $database_names) {
        $result = Test-Path -Path "$database_logs_folder_path\$($file_name)_Log.ldf" -PathType Leaf -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "    $file_name" -ForegroundColor Red
        }
        else {
            Write-Host "    $file_name" -ForegroundColor Green
        }
    }

    Write-Host "  Backups:" -ForegroundColor Yellow
    $possible_locations = Get-Partition |
        Where-Object {$_.DriveLetter} |
        Sort-Object -Unique |
        ForEach-Object {
            $_.DriveLetter
        }

    foreach ($location in $possible_locations) {
        foreach ($path in $db_backup_paths) {
            if (Test-Path -Path "$location$path" -ErrorAction SilentlyContinue) {
                Write-Host "    $location$path" -ForegroundColor Red
            } else {
                Write-Host "    $location$path" -ForegroundColor Green
            }
        }
    }
}

function Test-Directories() {
    Write-Host "DirectoriesRemoved:" -ForegroundColor Yellow
    foreach ($directory in $directories_to_not_exist) {
        $result = Test-Path -Path $directory -PathType Container -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "  $directory" -ForegroundColor Red
        }
        else {
            Write-Host "  $directory" -ForegroundColor Green
        }
    }
}

Test-Services
Test-Applications
Test-CustomApplications
Test-Accounts
Test-Databases
Test-Directories
