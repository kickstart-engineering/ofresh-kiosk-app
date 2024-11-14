@echo off
setlocal

:: Define the application name and directories
set "AppName=OfreshKioskApp"
set "targetDir=C:\Program Files\%AppName%"
set "scriptPath=%targetDir%\ensure_app_running.ps1"
set "batchScriptPath=%targetDir%\setup_startup.bat"
set "taskName=Ensure%AppName%Running"
set "regKey=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "regValue=%AppName%Startup"
set "appDataDir=%APPDATA%\%AppName%"

:: Step 0: Check if script is running as Administrator
NET SESSION >nul 2>&1
if %errorlevel% NEQ 0 (
    echo This script requires Administrator privileges.
    echo Restarting with Administrator privileges...
    powershell -Command "Start-Process '%~dp0%uninstall.bat' -Verb RunAs"
    exit /b
)

:: Step 1: Remove Task Scheduler entry
echo Removing Task Scheduler entry: %taskName%...
schtasks /delete /tn "%taskName%" /f

:: Step 2: Remove Registry entry for startup
echo Removing registry entry for startup...
reg delete "%regKey%" /v "%regValue%" /f

:: Step 3: Remove files from Program Files
echo Removing files from Program Files directory...
if exist "%targetDir%" (
    rmdir /s /q "%targetDir%"
    echo Files from Program Files have been removed.
) else (
    echo No files found in Program Files to remove.
)

:: Step 4: Remove AppData files (if any)
echo Removing AppData directory files...
if exist "%appDataDir%" (
    rmdir /s /q "%appDataDir%"
    echo Files from AppData have been removed.
) else (
    echo No AppData files found to remove.
)

:: Step 5: Confirmation
echo ========================================
echo Uninstallation complete. All files, registry entries, and scheduled tasks have been removed.
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
