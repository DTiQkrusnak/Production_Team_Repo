using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Xml;
using System.Runtime.Remoting.Channels;

namespace createTask_nodeps
{
    class Program
    {
            static void Main(string[] args)
            {
            // Path to the PowerShell script or the command you want to execute
            //string scriptPath = @"C:\path\to\your\script.ps1";
            string scriptPath = @"
$defaultUserNameRegGet64 = ""REG QUERY 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v DefaultUserName /reg:64""
$defaultUserNameRegGet32 = ""REG QUERY 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v DefaultUserName /reg:32""

function Split-DefaultUser {
    param (
        $regUser
    )

        $userName = ($regUser | Select-String ""DefaultUserName"").Line
    try {
        $defaultUserName = $userName.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)[2]
        if ($defaultUserName -eq $null) {
            return 'false'
        } else {
            return $defaultUserName
        }
    }
    catch {
        #return 0
    }
}
######

$userName = $getAutologonUser.DefaultUserName

Write-Host $username
Write-Host $($username)



# change Invoke-DtiqAdExe to download file param(url, out) 
### download DTiQAd and .NET 4.6.2 (link in prerequiiteis MMS) 
### run .net instllation
### breeze? if easy?

function Set-DTiQdir {
    param (
        $setDir
    )
    
    if (!(Test-Path $setDir)) {
        Write-Host ""Dir not found : Creating $setDir""
        New-Item $setDir -ItemType Directory -Force | Out-Null
    }
}

function Invoke-DTiQFileDownload {
    param (
        [string] $url,
        [string] $outFile
    )
    
    if (!(Test-Path $outFile -ErrorAction SilentlyContinue)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
        Write-Host ""Downloading file : $url""
        $webClient = New-Object System.Net.WebClient  
        $webClient.DownloadFile($url, $outFile)
        $webClient.Dispose()
    }
}

function Invoke-NetUpdate {
    <#
    $NetVersionCheck = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse -ErrorAction SilentlyContinue `
    | Get-ItemProperty -Name version -EA 0 `
    | Where { $_.PSChildName -Match '^(?!S)\p{L}' -and $_.Version -like ""4.*"" } `
    | Select PSChildName, version
    #>
    try {
        Write-Host ""Installing .NET 4.6.2...""
        Start-Process -FilePath 'C:\DTiQTemp\NDP462-KB3151800-x86-x64-AllOS-ENU.exe' -ArgumentList ""/q""
        Write-Host ""    -> done""
    }
    catch {
        $_.Message.Exception
    }
}

####
function Set-ExecuteTaskFile {
    $fileBatch = @'
@echo off
taskkill /f /im ""\""DTiQAd.exe\""""
start ""\""\"""" ""\""C:\ProgramData\DTiQ\DTiQAd\DTiQAd.exe\""""
'@

    #New-Item -Path 'C:\ProgramData\DTiQ\DTiQAd' -Name DTiQAdExecutor.ps1 -Value $file -Force | Out-Null
    Write-Host ""Creating batch executor...""
    Set-Content -Path 'C:\ProgramData\DTiQ\DTiQAd\DTiQAdExecutor.bat' -Value $fileBatch -Force | Out-Null
}

function Set-TaskInScheduler {
    param (
        [string] $userName
    )
    
    # Define the task name and executable path
    $exePath = 'C:\ProgramData\DTiQ\DTiQAd\DTiQAdExecutor.bat'  # Replace with the actual path to your executable

    # get doamin\name 
    $pcObjects = Get-WmiObject -Class win32_computersystem
    $pcName = $($pcObjects.Domain) + '\' + $($userName)
    Write-Host $pcname
    Write-Host $userName

    # Check if the task exists
    $taskExists = schtasks /Query /TN 'DTiQAdNotifier' 2>$null

    if (-not $taskExists) {
        # If the task does not exist, create the task
        schtasks /Create `
            /TN 'DTiQAdNotifier' `
            /TR 'cmd.exe /C ""C:\ProgramData\DTiQ\DTiQAd\DTiQAdExecutor.bat""' `
            /RU $($userName) `
            /SC DAILY `
            /ST 08:00 `
            /F
        Write-Host ""Task DTiQAdNotifier has been created successfully.""
    }
    else {
        Write-Host ""Task DTiQAdNotifier already exists.""
    }

    Write-Host ""Starting task...""
    schtasks /run /tn DTiQAdNotifier
}


$serviceName = 'EZVideoServer'
$getService = Get-Service -name $serviceName -ErrorAction SilentlyContinue

if ($getService) {
    Write-Host 'VS found - nothing to do'
}
else {
    Write-Host 'VS not found - executing'

    # Create directory structure
    Set-DTiQdir 'C:\DTiQTemp'
    Set-DTiQdir 'C:\ProgramData\DTiQ\DTiQAd\'

    # Download all needed files
    Invoke-DTiQFileDownload -url ""http://files-us-ps2.go360iq.com/_Files/Software/Scripts/DTiQAd/DTiQAd.exe"" -outFile ""C:\ProgramData\DTiQ\DTiQAd\DTiQAd.exe""
    #Invoke-DTiQFileDownload -url ""http://files-us-ps2.go360iq.com/_Files/Software/Scripts/DTiQAd/NDP462-KB3151800-x86-x64-AllOS-ENU.exe"" -outFile 'C:\DTiQTemp\NDP462-KB3151800-x86-x64-AllOS-ENU.exe'

    # create a batch file witch will execute DTiQAd app
    Set-ExecuteTaskFile

    # create a task in windows scheduler which will start DTiQAd periodicly
    Write-Host ""Checking 32 bit""
    $regUserGet = Split-DefaultUser $defaultUserNameRegGet32
    if ($regUserGet -eq 'false') {
        Write-Host ""Checking 64 bit""
        $regUserGet = Split-DefaultUser $defaultUserNameRegGet64
    }
    Set-TaskInScheduler $regUserGet
}


# Install .NET 
#Invoke-NetUpdate
#>
";

                string powershellCommand = $"-ExecutionPolicy Bypass -Command \"{scriptPath}\"";


                // Create a ProcessStartInfo object to configure the PowerShell process
                ProcessStartInfo startInfo = new ProcessStartInfo()
                {
                    FileName = "powershell.exe", // Use PowerShell executable
                    Arguments = powershellCommand, // The command to execute
                    RedirectStandardOutput = true, // Redirect the output to read it
                    RedirectStandardError = true, // Redirect the error output to read it
                    UseShellExecute = false, // Don't use shell execute to show GUI
                    CreateNoWindow = true // Don't create a new window
                };

                try
                {
                    // Start the process and capture the output and errors
                    using (Process process = Process.Start(startInfo))
                    {
                        if (process != null)
                        {
                            // Read the standard output (result of the script)
                            string output = process.StandardOutput.ReadToEnd();
                            string error = process.StandardError.ReadToEnd();

                            // Output the results
                            Console.WriteLine("Output:");
                            Console.WriteLine(output);

                            if (!string.IsNullOrEmpty(error))
                            {
                                Console.WriteLine("Errors:");
                                Console.WriteLine(error);
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    // Handle errors starting the process
                    Console.WriteLine("Error executing PowerShell script: " + ex.Message);
                }

                Console.WriteLine("PowerShell script executed.");
            }
        }
    }
