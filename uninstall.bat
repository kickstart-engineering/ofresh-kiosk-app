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

:: Check if script is running as Administrator
NET SESSION >nul 2>&1
if %errorlevel% NEQ 0 (
    echo This script requires Administrator privileges.
    echo Restarting with Administrator privileges...
    powershell -Command "Start-Process '%~dp0%uninstall.bat' -Verb RunAs"
    exit /b
)


:: Remove Registry entries
echo ============================
echo Removing Registry entries
echo ============================
echo Setting explorer for boot up
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d "explorer.exe" /f
echo Edge swipe gestures have been enabled
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" /v AllowEdgeSwipe /t REG_DWORD /d 1 /f
echo Policy set to ask for admin
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f 


:: Remove files from Program Files
echo Removing files from Program Files directory...
if exist "%targetDir%" (
    rmdir /s /q "%targetDir%"
    echo Files from Program Files have been removed.
) else (
    echo No files found in Program Files to remove.
)

:: Remove AppData files (if any)
echo Removing AppData directory files...
if exist "%appDataDir%" (
    rmdir /s /q "%appDataDir%"
    echo Files from AppData have been removed.
) else (
    echo No AppData files found to remove.
)

:: Check if app uninstaller exists

set "AppDirName=ofresh-kiosk-app"
set "APP_INSTALL_PATH=%LocalAppData%\Programs\%AppDirName%"
set "APP_UNINSTALLER=%APP_INSTALL_PATH%\Uninstall %AppName%.exe"
set "APP_DATA_DIR=%AppData%\%AppDirName%"
if exist "%APP_UNINSTALLER%" (
    echo Found APP_uninstaller for %APP_NAME%. Running APP_uninstaller...
    "%UNINSTALLER%" /SILENT /NORESTART
) else (
    echo Uninstaller not found. Deleting application files manually...
    if exist "%APP_INSTALL_PATH%" (
        echo Deleting files from %APP_INSTALL_PATH%...
        rmdir /S /Q "%APP_INSTALL_PATH%"
    ) else (
        echo Application installation path not found.
    )
)


:: Check if dwagent uninstaller exists

set "DWAGENT_UNINSTALLER=C:\Program Files\DWAgent\native\Uninstall.exe"
if exist "%DWAGENT_UNINSTALLER%" (
    echo Found APP_uninstaller for %APP_NAME%. Running APP_uninstaller...
    "%UNINSTALLER%" /SILENT /NORESTART
) 
@REM else (
@REM     echo Uninstaller not found. Deleting application files manually...
@REM     if exist "%APP_INSTALL_PATH%" (
@REM         echo Deleting files from %APP_INSTALL_PATH%...
@REM         rmdir /S /Q "%APP_INSTALL_PATH%"
@REM     ) else (
@REM         echo Application installation path not found.
@REM     )
@REM )

:: Delete user data
if exist "%APP_DATA_DIR%" (
    echo Deleting user data from %APP_DATA_DIR%...
    rmdir /S /Q "%APP_DATA_DIR%"
) else (
    echo User data path not found.
)

:: Remove Registry entry for startup
echo Removing scheduled reboot startup...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d "explorer.exe" /f

:: Confirmation
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
