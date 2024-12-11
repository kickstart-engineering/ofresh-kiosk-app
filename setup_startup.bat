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
echo Preparing setup: Please select an option
echo ========================================
echo 1: resetting the explorer for boot up
echo 2: setting the registers
echo 3: installing the app
echo 4: installing dwagent
echo 5: full install

choice /c 12345 /t 10 /d 5 >nul

set _e=%ERRORLEVEL%

if %_e%==1 (
  echo ========================================
  echo Set explorer to be used at boot up
  echo ========================================
  reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d "explorer.exe" /f
  pause
  exit /b
)

set should_setup_startup_agent=0
if %_e%==2 set should_setup_startup_agent=1
if %_e%==5 set should_setup_startup_agent=1
if %should_setup_startup_agent%==1 (
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


  echo ========================================
  echo Autologin setup - can be skipped
  echo ========================================

  
  set "should_reset_login_credentials=N"
  set /p "should_reset_login_credentials=Reset credentials for autologin user; Do you want to proceed? (y/N) [N]: "
  if /i "!should_reset_login_credentials!"=="y" (
    :: Set the username and password for auto-login
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "DefaultUserName" /d "ofresh" /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "DefaultPassword" /d "1234" /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "AutoAdminLogon" /t REG_DWORD /d "1" /f

    echo Auto-login has been configured. Please restart your computer for the changes to take effect.
  ) else (
    echo Skipping credentials reset
    exit /b
  )
)

@REM set cond=0
@REM if %_e%==3 set cond=1
@REM if %_e%==5 set cond=1
@REM if %cond%==1 (
@REM   echo ========================================
@REM   echo Install App
@REM   echo ========================================
@REM   if not exist %AppExecutable% (
@REM     echo App not found, downloading...
@REM     if not exist %AppDataPath% (
@REM       mkdir %AppDataPath%
@REM     )
@REM     powershell -Command "Invoke-WebRequest -Uri '%GitHubReleaseURL%' -OutFile '%AppExecutable%'"
@REM   )
@REM   if not exist "%AppRunningPath%" (
@REM     echo App is running first install
@REM     %AppExecutable%
@REM   )
@REM   echo App is installed
@REM )

set should_setup_dwagent=0
if %_e%==4 set should_setup_dwagent=1
if %_e%==5 set should_setup_dwagent=1
if %should_setup_dwagent%==1 (
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
    @REM echo command uses -silent user=!DWAGENT_USER! password=!DWAGENT_PASS! name=!MACHINE_ID! logpath=!DwagentLogPath!
    echo installing DwAgent...
    %DwagentDownloadPath% -silent user=!DWAGENT_USER! password=!DWAGENT_PASS! name=!MACHINE_ID! logpath=!DwagentLogPath!
  )
  echo Dwagent is set up
)

@REM if %_e%==6 (
@REM   echo .
@REM   echo Exiting due tue timeout
@REM   pause
@REM   exit /b
@REM )

if not %_e%==5 (
  echo .
  echo Thank you for installing OFresh
  pause
  exit /b
)
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
echo Policy set to never ask for admin
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f
echo to do: not allow on screen keyboard


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