
# imports necessary for hinding the console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
## todos
# rename within electron app: OfreshKioskApp
# either (add release url auth & remove license key) |   
# deplyment script has to rename .exe using "-" for whatspaces


# Define variables
# $AppName = "Autoupdater app"
$AppName = "OfreshKioskApp"
#  TODO: REMPLACE USING AppName
$AppDataPath = "$env:APPDATA\OfreshKioskApp"
$AppExecutable = "$AppDataPath\OfreshKioskApp.exe"
$LicenseKeyFile = "$AppDataPath\license.key"
$GitHubReleaseURL = "https://github.com/kickstart-engineering/ofresh-kiosk-app/releases/download/1.0.1/OfreshKioskApp-Setup-1.0.1.exe"

$WShell = New-Object -Com Wscript.Shell

# Disable Edge Swipe Gestures
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" -Name "AllowEdgeSwipe" -Value 0 -Force
# Notify user
Write-Host "Edge swipe gestures have been disabled."

# Wait for an active internet connection
Write-Output "========================================"
Write-Output "Waiting for an active internet connection..."
Write-Output "========================================"

while (!(Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) {
    Write-Output "No internet connection detected. Retrying in 5 seconds..."
    Start-Sleep -Seconds 5
}
Write-Output "Internet connection detected."


# Ensure the script is running with administrator privileges
if (-not (Test-Path $AppDataPath)) {
    New-Item -Path $AppDataPath -ItemType Directory -Force
}

# Check if the app executable is missing and download it if necessary
if (-not (Test-Path $AppExecutable)) {
    Write-Host "App not found, downloading..."
    Invoke-WebRequest -Uri $GitHubReleaseURL -OutFile $AppExecutable
}

# Function to validate if the license key exists or if we need to prompt for one
function Get-LicenseKey {
    if (Test-Path $LicenseKeyFile) {
        return Get-Content $LicenseKeyFile
    } else {
        $licenseKey = Read-Host "Enter your license key"
        Set-Content -Path $LicenseKeyFile -Value $licenseKey
        return $licenseKey
    }
}

# Ensure license key is set up
$licenseKey = Get-LicenseKey

# Hiding the powershllconsole
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)

# Ensure app is running
function Start-App {
    if (-not (Get-Process -Name $AppName -ErrorAction SilentlyContinue)) {
        Write-Host "Starting $AppName..."
        Start-Process $AppExecutable
    } else {
        Write-Host "Nothing to do here..."
    }
}

# Loop to keep checking if the app is running, and restart it if necessary
while ($true) {
    Start-App
    Start-Sleep -Seconds 15  # Check every 30 seconds if the app is running

    $WShell.SendKeys("{SCROLLLOCK}");
}
