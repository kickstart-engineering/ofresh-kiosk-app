
# imports necessary for hinding the console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

$printAsciiCmd = @"
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&x::xX+&xxxxxx&&&Xxxx&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&xxxx&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&          X+:;;:::::              ;&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&      &&&&&&&&&&&&&&&"'
'"&&&&&+      .:.   X::x::::&X     +X&Xx     &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&X    &&&&&&&&&&&&&&&"'
'"&&&&:    +&&&&&&&&X:;:::::&&     &&&&&&   .&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&    &&&&&&&&&&&&&&&"'
'"&&&;    X&&&&&&&&&&:;::::&&&     &&&&&&&&&     ;     :&&&&+        +&&&&&.        X&&    .      :&&&&&&&"'
'"&&&    :&&&&&&&&&&&:::+x&&&&           +&&x            &x     ;;     X&:     .     x&             +&&&&&"'
'"&&&    X&&&&&&&&&&&:;&x X&&&            &&&&    ;&x   .X    &&&&&&    &    X&&&+   &&     X&&&x    &&&&&"'
'"&&&    ;&&&&&&&&&&&&    &&&&     &&&  ;&&&&&    &&&&X&&.   ++         x+      ;X&&&&&    X&&&&&    &&&&&"'
'"&&&:    &&&&&&&&&&&.    &&&&     &&&&&&&&&&&    &&&&&&&    +          &&&;        ;&&    &&&&&&    &&&&&"'
'"&&&&     &&&&&&&&&     X&&&&     &&&&&&&&&&&    &&&&&&&:   .&+&&&&&+&&&&X+&&&X:     &    &&&&&&    &&&&&"'
'"&&&&&:     ;X&&x      &&&&X+     xX&&&&&&&&&    X&&&&&&&     X&&&:   x&    X&&&X    X    X&&&&&    x&&&&"'
'"&&&&&&&:            &&&&&&         &&&&&&&        X&&&&&&;           &&.           &       &&&&:     &&&"'
'"&&&&&&&&&&&+;::;X&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&+.   ;X&&&&&&&:     +&&&&&&&&&&&&&&&&&&&$&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&                                                             &&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&       Please be patient while the app is loading...         &&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&                                                             &&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
'"&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"'
"@


# Check if the script is running with administrative privileges
if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    # Restart the script with elevated privileges
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$AgentLogsPath = "C:\logs"
$MainLogPath = "C:\logs\main.log"
$AgentLogsFile = "$AgentLogsPath\ensure_app_running_agent.log"

# Reboot-on-request channel: the kiosk app drops this JSON signal file when an
# error-31 MDB/USB fault persists past what in-app re-enumeration can recover (see
# picovend-mdb.ts -> maybeRequestReboot). The watchdog runs elevated, so it can do
# the one thing that reliably re-enumerates a CH340 stuck off the bus: reboot the PC.
$RebootRequestFile = "$AgentLogsPath\reboot-request.json"
# Persists the last watchdog-initiated reboot time across boots so a permanently
# dead device can't drive a reboot loop.
$LastRebootMarker = "$AgentLogsPath\last-watchdog-reboot.txt"
# Ignore requests older than this (stale file left by a crash or a prior boot).
$RebootRequestMaxAgeMinutes = 5
# Never reboot more than once per this window.
$MinMinutesBetweenReboots = 15
$readLogsCmd = "Get-Content -Path $AgentLogsFile -Tail 10;"

$setCursor = "[Console]::SetCursorPosition(0,26);"
$emptychar = '`0 ' * 100 + ' `n';
# $emptychar = '`0 ' *50 +'. '+' `n';
$lines = $emptychar * 12;
$trueval = '$true'
$loop = "while($trueval) {$setCursor Write-Host $lines; $setCursor $readLogsCmd Start-Sleep -Seconds 2}"
$processArgs = "$printAsciiCmd; $loop"

# Check if the log file exists, create it if it doesn't
if (-not (Test-Path $AgentLogsPath)) {
    New-Item -Path $AgentLogsPath -ItemType Directory -Force
}


if (-not (Test-Path $AgentLogsFile)) {
    New-Item -Path $AgentLogsFile -ItemType File -Force
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
    Write-Log "App not found, downloading"

    # Wait for an active internet connection
    Write-Host "Waiting for an active internet connection..."
    Write-Log -Message "Waiting for an active internet connection..."

    while (!(Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) {
        Write-Log -Message "No internet connection detected. Retrying in 5 seconds..."
        Write-Host "No internet connection detected. Retrying in 5 seconds..."
        
        Start-Sleep -Seconds 5
    }

    Write-Log -Message "Internet connection detected."
    Write-Host "Internet connection detected."
    
    Write-Log -Message "Downloading app..."
    Write-Host "Downloading app..."
    
    Invoke-WebRequest -Uri $GitHubReleaseURL -OutFile $AppExecutable
}

Hide-Console

# Function to check if main log is stale (older than 3 minutes)
function Is-Main-Log-Stale {
    if (-not (Test-Path $MainLogPath)) {
        Write-Log "Log file not found, treating as stale."
        return $true
    }

    $LastLine = Get-Content $MainLogPath -Tail 1

    # Match timestamp with optional milliseconds
    if ($LastLine -match '\[(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d{3})?)\]') {
        try {
            $LastTimestamp = [datetime]::ParseExact($matches['ts'], 'yyyy-MM-dd HH:mm:ss.fff', $null)
        } catch {
            $LastTimestamp = [datetime]::ParseExact($matches['ts'], 'yyyy-MM-dd HH:mm:ss', $null)
        }

        $Now = Get-Date
        $AgeMinutes = ($Now - $LastTimestamp).TotalMinutes

        if ($AgeMinutes -gt 3) {
            Write-Log "Last log entry is stale (older than 3 minutes)."
            return $true
        } else {
            Write-Log "Last main process log entry is $([math]::Round($AgeMinutes,2)) minutes old"
            return $false
        }
    }
    else {
        Write-Log "Could not parse timestamp from last log line, treating as stale."
        return $true
    }
}


# Reboot the PC if the app asked us to via $RebootRequestFile. Validates the
# request is fresh (not a leftover stale file) and rate-limits reboots so a
# permanently faulty device cannot cause a reboot loop. Consumes the request and
# records the reboot time before rebooting so we don't loop after coming back.
function Invoke-RebootIfRequested {
    if (-not (Test-Path $RebootRequestFile)) {
        return
    }

    Write-Log "Reboot request found at $RebootRequestFile"

    $requestedAt = $null
    $reason = "(unspecified)"
    try {
        $request = Get-Content -Path $RebootRequestFile -Raw | ConvertFrom-Json
        if ($request.requestedAt) { $requestedAt = [datetime]$request.requestedAt }
        if ($request.reason) { $reason = $request.reason }
    }
    catch {
        Write-Log "Could not parse reboot request ($($_.Exception.Message)) - ignoring and removing"
        Remove-Item -Path $RebootRequestFile -Force -ErrorAction SilentlyContinue
        return
    }

    if ($null -eq $requestedAt) {
        Write-Log "Reboot request missing requestedAt - ignoring and removing"
        Remove-Item -Path $RebootRequestFile -Force -ErrorAction SilentlyContinue
        return
    }

    $ageMinutes = ((Get-Date) - $requestedAt).TotalMinutes
    if ($ageMinutes -gt $RebootRequestMaxAgeMinutes) {
        Write-Log "Reboot request is stale ($([math]::Round($ageMinutes,1)) min old) - ignoring and removing"
        Remove-Item -Path $RebootRequestFile -Force -ErrorAction SilentlyContinue
        return
    }

    # Rate-limit: don't reboot again within $MinMinutesBetweenReboots. Leave the
    # request in place (the app keeps it fresh while still stuck) so we can act
    # once the window passes.
    if (Test-Path $LastRebootMarker) {
        try {
            $lastReboot = [datetime]((Get-Content -Path $LastRebootMarker -Raw).Trim())
            $sinceLast = ((Get-Date) - $lastReboot).TotalMinutes
            if ($sinceLast -lt $MinMinutesBetweenReboots) {
                Write-Log "Reboot requested (reason: $reason) but last reboot was $([math]::Round($sinceLast,1)) min ago (< $MinMinutesBetweenReboots) - skipping to avoid a reboot loop"
                return
            }
        }
        catch {
            # Unparseable marker - fall through and allow the reboot.
            Write-Log "Could not read last-reboot marker - allowing reboot"
        }
    }

    Write-Log "Reboot requested by app (reason: $reason, age $([math]::Round($ageMinutes,1)) min) - rebooting PC now"

    # Consume the request and record the reboot so we don't loop after coming back.
    Remove-Item -Path $RebootRequestFile -Force -ErrorAction SilentlyContinue
    Set-Content -Path $LastRebootMarker -Value (Get-Date -Format "o")

    Restart-Computer -Force
    # Restart-Computer starts an async shutdown; stop the watchdog so it does no
    # further work this cycle.
    exit
}

# Ensure app is running
function Start-App {
	$MainLogIsstale = Is-Main-Log-Stale
    if (-not (Get-Process -Name $AppName -ErrorAction SilentlyContinue) -or ($MainLogIsstale)) {
        Write-Log "Starting $AppName..."
        if ( $MainLogIsStale ) {
        	Write-Log "Found stale main log"
        }
        if (-not (Test-Path $AppRunningPath)) {
            Write-Log "App is running for the first time"
            Start-Process $AppExecutable
        }
        else {
            Write-Log "App installed already, running it"
            Start-Process $AppRunningPath
        }
    }
    else {
        Write-Log "Nothing to do here"
    }
}

# Loop to keep checking if the app is running, and restart it if necessary
while ($true) {

    # Honour an app-requested reboot first (error-31 recovery). Checked before the
    # internet wait below since the MDB/USB fault is independent of connectivity.
    Invoke-RebootIfRequested

    if (-not ($TailLogPrrocess -and (Get-Process -Id $TailLogPrrocess.Id))) {
        $TailLogPrrocess = Start-Process powershell -PassThru -ArgumentList "-NoExit -WindowStyle Maximized -Command $processArgs"
    }

    while (!(Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) {
        Write-Log -Message "No internet connection detected. Retrying in 5 seconds..."
        Start-Sleep -Seconds 5
    }

    Start-App
    
    Start-Sleep -Seconds 120  # Check every 30 seconds if the app is running

    $WShell.SendKeys("{SCROLLLOCK}");
}
