
# imports necessary for hinding the console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
## todos
# (3) enrolment flow using api

# Check if the script is running with administrative privileges
if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    # Restart the script with elevated privileges
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Your script code goes here
Write-Output "Running with administrative privileges"

# todo: uncomment
# Hiding the powershllconsole
# $consolePtr = [Console.Window]::GetConsoleWindow()
# [Console.Window]::ShowWindow($consolePtr, 0)


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
  Write-Output "Waiting for an active internet connection..."

  while (!(Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) {
      Write-Output "No internet connection detected. Retrying in 5 seconds..."
      Start-Sleep -Seconds 5
  }
  Write-Output "Internet connection detected."
  Write-Host "Downloading app..."
  Invoke-WebRequest -Uri $GitHubReleaseURL -OutFile $AppExecutable
}



# Function to validate if the license key exists or if we need to prompt for one
function Get-LicenseKey {
    if (Test-Path $LicenseKeyFile) {
        return Get-Content $LicenseKeyFile
    }
    else {
        $licenseKey = Read-Host "Enter your license key"
        Set-Content -Path $LicenseKeyFile -Value $licenseKey
        return $licenseKey
    }
}

# Ensure license key is set up
# todo: (1) read from $ConfigFile 
#       (2) throw if any missing
# $MACHINE_ID = $ConfigValues.MACHINE_ID
# $DWAGENT_USER = $ConfigValues.DWAGENT_USER
# $DWAGENT_PASS = $ConfigValues.DWAGENT_PASS
# $LICENCESE_KEY = $ConfigValues.LICENCESE_KEY

# Ensure app is running
function Start-App {
    if (-not (Get-Process -Name $AppName -ErrorAction SilentlyContinue)) {
        Write-Host "Starting $AppName..."
        if(-not (Test-Path $AppRunningPath)) {
          Write-Host "App is running for the first time"
          Start-Process $AppExecutable
        }
        else
        {
          Write-Host "App installed already, running it"
          Start-Process $AppRunningPath
        }
    }
    else {
        Write-Host "Nothing to do here..."
    }
}


# Loop to keep checking if the app is running, and restart it if necessary
while ($true) {
    Start-App
    Start-Sleep -Seconds 15  # Check every 30 seconds if the app is running

    $WShell.SendKeys("{SCROLLLOCK}");
}
