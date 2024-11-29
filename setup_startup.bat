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
set "envFile=%~dp0%.env"
set "appDataEnvFile=%appDataDir%\.env"

@REM todo: uncomment
:: Check if script is running as Administrator
@REM NET SESSION >nul 2>&1
@REM if %errorlevel% NEQ 0 (
@REM     echo ========================================
@REM     echo This script requires Administrator privileges.
@REM     echo ========================================
@REM     echo Restarting with Administrator privileges...
@REM     powershell -Command "Start-Process '%~dp0%setup_startup.bat' -Verb RunAs"
@REM     exit /b
@REM )


:: Store License Key in AppData (hidden file)
echo ========================================
echo Storing app config...
echo ========================================

if not exist "%appDataDir%" (
    mkdir "%appDataDir%"
)

@echo off
setlocal enabledelayedexpansion

:: Check if .env file exists in the current directory
set "shouldPromtForVariables=false"
if exist "%envFile%" (
    echo "Found .env file in ./"
    for /f "tokens=1,2 delims==" %%i in (%envFile%) do (
        set "%%i=%%j"
    )

    @REM not working properly
    if defined MACHINE_ID if defined DWAGENT_USER if defined DWAGENT_PASS if defined LICENCESE_KEY (
        echo .env complete going to copy it
        copy "%envFile%" "%appDataEnvFile%"
        echo .env file copied to %appDataEnvFile%
    ) else (
        echo Found incomplete .env file in ./ thus promting for config vars
        set "shouldPromtForVariables=true"
    )
) else (
    echo No .env file in ./ thus promting for config vars
    set "shouldPromtForVariables=true"
)

if "%shouldPromtForVariables%" == "true" (
    set /p MACHINE_ID="Enter MACHINE_ID: "
    set /p DWAGENT_USER="Enter DWAGENT_USER: "
    set /p DWAGENT_PASS="Enter DWAGENT_PASS: "
    set /p LICENCESE_KEY="Enter LICENCESE_KEY: "
    (
        echo MACHINE_ID=!MACHINE_ID!
        echo DWAGENT_USER=!DWAGENT_USER!
        echo DWAGENT_PASS=!DWAGENT_PASS!
        echo LICENCESE_KEY=!LICENCESE_KEY!
    ) > "%appDataEnvFile%"
    echo .env file created at %appDataEnvFile%
)

@REM todo: remove
exit 0
:: Ensure Program Files directory exists
echo ========================================
echo Ensuring that the target directory exists...
echo ========================================
if not exist "%targetDir%" (
    echo Creating directory: %targetDir%
    mkdir "%targetDir%"
)


::set background to file on desktop named "wallpaper.bmp"
echo Setting wallpaper
reg add "HKCU\Control Panel\Desktop" /v Wallpaper /f /t REG_SZ /d %windir%\Desktop\wallpaper.bmp
reg add "HKCU\Control Panel\Desktop" /v WallpaperStyle /f /t REG_SZ /d 10

::set to sleepless
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0

:: %SystemRoot%\System32\RUNDLL32.EXE user32.dll, UpdatePerUserSystemParameters

:: Copy PowerShell script and batch script to Program Files
echo ========================================
echo Copying PowerShell script and batch file to %targetDir%...
echo ========================================
copy "%~dp0ensure_app_running.ps1" "%scriptPath%" /Y
copy "%~dp0setup_startup.bat" "%batchScriptPath%" /Y

:: Set Execution Policy to allow script execution
echo ========================================
echo Ensuring that PowerShell script execution is allowed...
echo ========================================
powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"

:: Create a Task Scheduler task to run at startup
echo ========================================
echo Creating Task Scheduler entry to run script at startup...
echo ========================================
schtasks /create /tn "%taskName%" ^
    /tr "%powershellExe% -ExecutionPolicy Bypass -File \"%scriptPath%\"" ^
    /sc onstart ^
    /ru "SYSTEM" ^
    /f

:: Optionally add the script to startup via the registry (fallback)
echo ========================================
echo Optionally adding registry entry for startup...
echo ========================================
reg add "%regKey%" /v "%regValue%" /t REG_SZ /d "\"%powershellExe%\" -ExecutionPolicy Bypass -File \"%scriptPath%\"" /f


:: Disable Edge Swipe Gestures
echo ========================================
echo Edge swipe gestures have been disabled
echo ========================================
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" /v AllowEdgeSwipe /t REG_DWORD /d 0 /f

:: Schedule a reboot at midnight
schtasks /create /tn "ScheduledReboot" /tr "shutdown /r /f" /sc once /st 00:00 /f
echo ========================================
if %errorlevel% neq 0 (
    echo Failed to schedule the reboot. Ensure Task Scheduler service is running.
) else (
    echo A reboot has been scheduled at midnight.
)
echo ========================================

:: Final Confirmation and Reboot Prompt
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