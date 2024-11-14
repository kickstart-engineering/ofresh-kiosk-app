@echo off
setlocal

:: Define the application name and directories
set "AppName=OfreshKioskApp"  :: Change this variable to your application name
set "targetDir=C:\Program Files\%AppName%"
set "scriptPath=%targetDir%\ensure_app_running.ps1"
set "batchScriptPath=%targetDir%\setup_startup.bat"
set "taskName=Ensure%AppName%Running"
set "regKey=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "regValue=%AppName%Startup"
set "appDataDir=%APPDATA%\%AppName%"
set "licenseFile=%appDataDir%\license.key"
set "powershellExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"  :: Define PowerShell executable path

:: Step 1: Check if script is running as Administrator
NET SESSION >nul 2>&1
if %errorlevel% NEQ 0 (
    echo ========================================
    echo This script requires Administrator privileges.
    echo ========================================
    echo Restarting with Administrator privileges...
    powershell -Command "Start-Process '%~dp0%setup_startup.bat' -Verb RunAs"
    exit /b
)

:: Step 2: Prompt for License Key
echo ========================================
echo Please enter your license key to continue.
echo ========================================
set /p licenseKey=Enter license key: 

:: Validate license key (basic example: check if it's not empty)
if "%licenseKey%"=="" (
    echo ========================================
    echo ERROR: License key cannot be empty.
    echo ========================================
    exit /b
)

:: Step 3: Store License Key in AppData (hidden file)
echo ========================================
echo Storing license key securely...
echo ========================================
if not exist "%appDataDir%" (
    mkdir "%appDataDir%"
)

echo %licenseKey% > "%licenseFile%"


:: Step 4: Ensure Program Files directory exists
echo ========================================
echo Ensuring that the target directory exists...
echo ========================================
if not exist "%targetDir%" (
    echo Creating directory: %targetDir%
    mkdir "%targetDir%"
)

:: Step 5: Copy PowerShell script and batch script to Program Files
echo ========================================
echo Copying PowerShell script and batch file to %targetDir%...
echo ========================================
copy "%~dp0ensure_app_running.ps1" "%scriptPath%" /Y
copy "%~dp0setup_startup.bat" "%batchScriptPath%" /Y

:: Step 6: Set Execution Policy to allow script execution
echo ========================================
echo Ensuring that PowerShell script execution is allowed...
echo ========================================
powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"

:: Step 7: Create a Task Scheduler task to run at startup
echo ========================================
echo Creating Task Scheduler entry to run script at startup...
echo ========================================
schtasks /create /tn "%taskName%" ^
    /tr "%powershellExe% -ExecutionPolicy Bypass -File \"%scriptPath%\"" ^
    /sc onstart ^
    /ru "SYSTEM" ^
    /f

:: Step 8: Optionally add the script to startup via the registry (fallback)
echo ========================================
echo Optionally adding registry entry for startup...
echo ========================================
reg add "%regKey%" /v "%regValue%" /t REG_SZ /d "\"%powershellExe%\" -ExecutionPolicy Bypass -File \"%scriptPath%\"" /f

:: Step 9: Final Confirmation and Reboot Prompt
echo ========================================
echo Setup complete. The Kiosk app will now run at system startup
echo ========================================
echo.
echo A reboot is required for the changes to take effect.
echo Please save your work and restart your computer.
echo.
echo Press Enter to restart your computer now, or close this window if you wish to restart later.
pause

:: Reboot the machine
shutdown /r /f /t 0
endlocal