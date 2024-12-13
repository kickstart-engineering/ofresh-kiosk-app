
# imports necessary for hinding the console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

# Check if the script is running with administrative privileges
if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    # Restart the script with elevated privileges
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$AgentLogsPath = "C:\logs"
$AgentLogsFile = "$AgentLogsPath\ensure_app_running_agent.log"
if (-not (Test-Path $AgentLogsPath)) {
    New-Item -Path $AgentLogsPath -ItemType Directory -Force
}

function Write-Log {
    param (
        [string]$Message
    )

    # Check if the log file exists, create it if it doesn't
    if (-not (Test-Path $AgentLogsFile)) {
        New-Item -Path $AgentLogsFile -ItemType File -Force
    }

    # Append the message to the log file with a timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $AgentLogsFile -Value "$timestamp - $Message"
}

function Start-TailLog {
    if (-not (Test-Path $AgentLogsFile)) {
        Write-Error "Log file not found: $AgentLogsFile"
        return
    }

    # Check if the process is already running
    $processName = "powershell"
    $processArgs = "Get-Content -Path '$AgentLogsFile' -Wait -Tail 10"
    $isRunning = Get-Process | Where-Object { $_.ProcessName -eq $processName -and $_.Path -Contains $processArgs }

    if ($isRunning) {
        Write-Log -Message "The process is already running."
    }
    else {
        Start-Process powershell -ArgumentList "-NoExit", "-Command", $processArgs
        Write-Log -Message "Started tailing the log file."
    }
}

Start-TailLog

# Your script code goes here
Write-Log -Message "Running with administrative privileges"

# Redirect input to $null to prevent TTY input
$input = $null

# Your script code goes here
Write-Log -Message "This script does not receive TTY input."

# Hiding the powershllconsole

function Hide-Console {
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0)
}

# todo: use or remove
# function Show-Console {
#     $consolePtr = [Console.Window]::GetConsoleWindow()
#     [Console.Window]::ShowWindow($consolePtr, 5)
# }

Hide-Console

# Define variables
$AppName = "OfreshKioskApp"
$AppDataPath = "$env:APPDATA\$AppName"
$AppExecutable = "$AppDataPath\$AppName.exe"
$AppRunningPath = "$env:APPDATA\..\Local\Programs\ofresh-kiosk-app\$AppName.exe"
$GitHubReleaseURL = "https://github.com/kickstart-engineering/ofresh-kiosk-app/releases/download/1.0.1/OfreshKioskApp-Setup-1.0.1.exe"

# $ConfigFile = "$AppDataPath\.env"
# $ConfigValues = Get-Content $ConfigFile | Out-String | ConvertFrom-StringData

$WShell = New-Object -Com Wscript.Shell


# Ensure the script is running with administrator privileges
if (-not (Test-Path $AppDataPath)) {
    New-Item -Path $AppDataPath -ItemType Directory -Force
}

# Check if the app executable is missing and download it if necessary
if (-not (Test-Path $AppExecutable)) {
    Write-Host "App not found, downloading"
    # Wait for an active internet connection
    Write-Log -Message "Waiting for an active internet connection..."

    while (!(Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) {
        Write-Log -Message "No internet connection detected. Retrying in 5 seconds..."
        Start-Sleep -Seconds 5
    }
    Write-Log -Message "Internet connection detected."
    Write-Host "Downloading app..."
    Invoke-WebRequest -Uri $GitHubReleaseURL -OutFile $AppExecutable
}


# Ensure app is running
function Start-App {
    if (-not (Get-Process -Name $AppName -ErrorAction SilentlyContinue)) {
        Write-Host "Starting $AppName..."
        if (-not (Test-Path $AppRunningPath)) {
            Write-Host "App is running for the first time"
            Start-Process $AppExecutable
        }
        else {
            Write-Host "App installed already, running it"
            Start-Process $AppRunningPath
        }
    }
    else {
        Write-Host "Nothing to do here..."
    }
}

Hide-Console

# Loop to keep checking if the app is running, and restart it if necessary
while ($true) {
    Start-TailLog

    Start-App
    
    Start-Sleep -Seconds 120  # Check every 30 seconds if the app is running

    $WShell.SendKeys("{SCROLLLOCK}");
}
