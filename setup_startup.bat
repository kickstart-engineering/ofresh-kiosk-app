@echo off
setlocal enabledelayedexpansion
setlocal

:: Define the application name and directories
set AppName=OfreshKioskApp
set "targetDir=C:\Program Files\%AppName%"
set "scriptPath=%targetDir%\ensure_app_running.ps1"
set AppRunningPath=%APPDATA%\..\Local\Programs\ofresh-kiosk-app\%AppName%.exe

@REM  app
set AppDataPath=%APPDATA%\%AppName%
set AppExecutable=%AppDataPath%\%AppName%.exe
set GitHubReleaseURL=https://github.com/kickstart-engineering/ofresh-kiosk-app/releases/download/1.0.1/OfreshKioskApp-Setup-1.0.1.exe

set powershellExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell
set ConfigFile=%~dp0%.env

@REM Dwagent
set DwagentExecutable=C:\Program Files\DWAgent\native\dwaglnc.exe
set DwagentDownloadPath=%~dp0%dwagent.exe
set DwagentLogPath=%~dp0%install_dwagent.log
set DownloadURL=https://www.dwservice.net/download/dwagent_x86.exe

:: Check if script is running as Administrator
NET SESSION >nul 2>&1
if %errorlevel% NEQ 0 (
    echo ========================================
    echo This script requires Administrator privileges.
    echo ========================================
    echo Restarting with Administrator privileges...
    powershell -Command "Start-Process '%~dp0%setup_startup.bat' -Verb RunAs"
    exit /b
)

::choose type of setup
echo ========================================
echo Preparing types of setup...
echo ========================================
echo For resetting the explorer for boot up, type 1
echo For setting the registers, type 2
echo For installing the app, type 3
echo For installing dwagent, type 4
echo For full install, type 5
echo Timeout or type 6

choice /c 123456 /t 5 /d 6 >nul

set _e=%ERRORLEVEL%

if "%_e%"==1 (
  echo ========================================
  echo Set explorer to be used at boot up
  echo ========================================
  reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d "explorer.exe" /f
  pause
  exit /b
)

if "%_e%"==2 || "%_e%"==5 (
  echo ========================================
  echo Setting up bootup with PowerShell script instead of explorer
  echo ========================================
  echo Copy PowerShell script to %targetDir%
  if not exist "%targetDir%" (
    echo Creating directory: %targetDir%
    mkdir "%targetDir%"
  )
  copy "%~dp0ensure_app_running.ps1" "%scriptPath%" /Y

  echo Ensuring that PowerShell script execution is allowed...
  powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"
  
  echo RegEdit Boot up using the script
  reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d "\"%powershellExe%\" -ExecutionPolicy Bypass -File \"%scriptPath%\"" /f
)

if "%_e%"==3 || "%_e%"==5 (
  echo ========================================
  echo Install App
  echo ========================================
  if not exist %AppExecutable% (
    echo App not found, downloading...
    powershell -Command "Invoke-WebRequest -Uri '%GitHubReleaseURL%' -OutFile '%AppExecutable%'"
  )
  if not exist "%AppRunningPath%" (
    echo App is running first install
    %AppExecutable%
  )
  else
  (
    echo App is already installed
  )
)

if "%_e%"==4 || "%_e%"==5 (
  echo ========================================
  echo Dwagent setup
  echo ========================================
  @REM if not installed, check if dld
  if not exist "%DwagentExecutable%" (
    echo Dwagent not found in path '%DwagentExecutable%', looking for dld file in '%DwagentDownloadPath%'
    if not exist "%DwagentDownloadPath%" (
      echo Dwagent downloading...
      powershell -Command "Invoke-WebRequest -Uri '%DownloadURL%' -OutFile '%DwagentDownloadPath%'"
    )
    echo Dwagent downloaded, running installation
    @REM get .env vars
    for /f "tokens=1,2 delims==" %%A in (%ConfigFile%) do (
      if "%%A"=="MACHINE_ID" set %%A=%%B
      if "%%A"=="DWAGENT_USER" set %%A=%%B
      if "%%A"=="DWAGENT_PASS" set %%A=%%B
    )
    echo command uses -silent user=!DWAGENT_USER! password=!DWAGENT_PASS! name=!MACHINE_ID! logpath=!DwagentLogPath!
    %DwagentDownloadPath% -silent user=!DWAGENT_USER! password=!DWAGENT_PASS! name=!MACHINE_ID! logpath=!DwagentLogPath!
  )
  echo Dwagent is set up
)

if "%_e%"!=5 exit /b

:: Store License Key in AppData (hidden file)
echo ========================================
echo Storing app config...
echo ========================================
if not exist "%AppDataPath%" (
    mkdir "%AppDataPath%"
)


::set to sleepless
echo ========================================
echo Setting sleepless...
echo ========================================
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0


:: Disable Edge Swipe Gestures
echo ========================================
echo Other RegEdit settings
echo ========================================
echo Edge swipe gestures have been disabled
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" /v AllowEdgeSwipe /t REG_DWORD /d 0 /f


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