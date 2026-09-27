#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Replaces the installed OFresh watchdog and optionally restarts the computer.

.DESCRIPTION
    Copies a local ensure_app_running.ps1, validates it with the PowerShell parser,
    keeps a timestamped backup, and atomically replaces the installed file.
    Pass -Restart to reboot after installation so Winlogon starts the new watchdog.

.EXAMPLE
    .\update_watchdog.ps1 -Restart

.EXAMPLE
    .\update_watchdog.ps1 -SourcePath D:\updates\ensure_app_running.ps1 -Restart
#>

[CmdletBinding()]
param(
    [string]$SourcePath,

    [ValidateNotNullOrEmpty()]
    [string]$TargetPath = 'C:\Program Files\OfreshKioskApp\ensure_app_running.ps1',

    [switch]$Restart
)

$ErrorActionPreference = 'Stop'
$LogDirectory = 'C:\logs'
$LogPath = Join-Path $LogDirectory 'watchdog-update.log'
$WinlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

function Write-UpdateLog {
    param([Parameter(Mandatory)][string]$Message)

    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $LogPath -Value $line
    Write-Host $line
}

function Test-WatchdogScript {
    param([Parameter(Mandatory)][string]$Path)

    if ((Get-Item -Path $Path).Length -lt 1000) {
        throw "Replacement watchdog is unexpectedly small: $Path"
    }

    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null

    if ($parseErrors.Count -gt 0) {
        $details = ($parseErrors | ForEach-Object {
            "line $($_.Extent.StartLineNumber): $($_.Message)"
        }) -join '; '
        throw "Replacement watchdog has PowerShell syntax errors: $details"
    }

    $content = Get-Content -Path $Path -Raw
    $requiredText = @(
        'function Invoke-RebootIfRequested',
        '$RebootRequestFile',
        'Restart-Computer -Force -ErrorAction Stop'
    )

    foreach ($text in $requiredText) {
        if (-not $content.Contains($text)) {
            throw "Replacement watchdog is missing required text: $text"
        }
    }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'This updater only supports Windows.'
}

$SourcePath = if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    Join-Path $PSScriptRoot 'ensure_app_running.ps1'
} else {
    [System.IO.Path]::GetFullPath($SourcePath)
}
$TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
$TargetDirectory = Split-Path -Parent $TargetPath

if (-not (Test-Path -Path $SourcePath -PathType Leaf)) {
    throw "Replacement watchdog not found at $SourcePath"
}

if (-not (Test-Path -Path $TargetPath -PathType Leaf)) {
    throw "Installed watchdog not found at $TargetPath. Use setup_startup.bat for a new installation."
}

$temporaryPath = Join-Path $TargetDirectory (
    '.ensure_app_running.{0}.tmp' -f [guid]::NewGuid().ToString('N')
)
$backupPath = '{0}.bak.{1}' -f $TargetPath, (Get-Date -Format 'yyyyMMdd-HHmmss')
$replacementInstalled = $false
$installationVerified = $false

try {
    $resolvedSource = (Resolve-Path -Path $SourcePath).Path
    Write-UpdateLog "Copying watchdog from $resolvedSource"
    Copy-Item -Path $resolvedSource -Destination $temporaryPath -Force

    Test-WatchdogScript -Path $temporaryPath

    $currentHash = (Get-FileHash -Path $TargetPath -Algorithm SHA256).Hash
    $replacementHash = (Get-FileHash -Path $temporaryPath -Algorithm SHA256).Hash

    if ($currentHash -eq $replacementHash) {
        $installationVerified = $true
        Write-UpdateLog "Installed watchdog already matches the requested version ($replacementHash)"
    } else {
        Write-UpdateLog "Replacing watchdog. Current SHA-256: $currentHash. New SHA-256: $replacementHash"
        [System.IO.File]::Replace($temporaryPath, $TargetPath, $backupPath)
        $replacementInstalled = $true

        $installedHash = (Get-FileHash -Path $TargetPath -Algorithm SHA256).Hash
        if ($installedHash -ne $replacementHash) {
            throw "Installed watchdog hash mismatch. Expected $replacementHash, got $installedHash"
        }

        $installationVerified = $true
        Write-UpdateLog "Watchdog installed. Backup: $backupPath"
    }

    $shellValue = (Get-ItemProperty -Path $WinlogonPath -Name Shell).Shell
    if ($shellValue -notlike "*$TargetPath*") {
        $message = "Winlogon Shell does not reference $TargetPath. Current value: $shellValue"
        if ($Restart) {
            throw "$message. Refusing to restart."
        }
        Write-Warning $message
        Write-UpdateLog $message
    }

    if ($Restart) {
        Write-UpdateLog 'Update complete. Restarting the computer in five seconds.'
        Start-Sleep -Seconds 5
        Restart-Computer -Force -ErrorAction Stop
    } else {
        Write-UpdateLog 'Update staged. The running watchdog still uses the previous code until the next restart.'
        Write-Host 'Run this script again with -Restart, or restart Windows manually, to complete the transition.'
    }
}
catch {
    $failure = $_.Exception.Message

    if ($replacementInstalled -and -not $installationVerified -and (Test-Path $backupPath)) {
        try {
            Copy-Item -Path $backupPath -Destination $TargetPath -Force
            Write-UpdateLog "Update failed and the previous watchdog was restored from $backupPath"
        }
        catch {
            Write-UpdateLog "CRITICAL: update failed and rollback also failed ($($_.Exception.Message))"
        }
    }

    Write-UpdateLog "Watchdog update failed: $failure"
    throw
}
finally {
    if (Test-Path $temporaryPath) {
        Remove-Item -Path $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}
