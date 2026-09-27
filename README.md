# ofresh-kiosk-app

Built kiosk-app releases (consumed by `electron-updater`) plus the provisioning and
watchdog scripts run on each kiosk PC.

## `ensure_app_running.ps1` — the watchdog

Runs as the boot shell (admin). Keeps `OfreshKioskApp.exe` alive and, on each loop:

- Restarts the app if its process is down or `C:\logs\main.log` is stale.
- **Reboots the PC on request** (`Invoke-RebootIfRequested`): the kiosk app drops
  `C:\logs\reboot-request.json` when an MDB/USB **error-31** fault persists past what
  in-app USB re-enumeration can fix (the app may not be elevated for `pnputil`; the
  watchdog is). A full reboot is the only reliable way to re-enumerate a CH340 stuck
  off the bus. The request is validated for freshness (`$RebootRequestMaxAgeMinutes`)
  and reboots are rate-limited (`$MinMinutesBetweenReboots`, persisted in
  `C:\logs\last-watchdog-reboot.txt`) to prevent rapid repeated reboots. The watchdog
  checks requests while offline and retains the request if Windows rejects the restart.

The app side of this signal lives in `ofresh-kiosk` →
`kiosk-app/src/main/picovend-mdb.ts` (`maybeRequestReboot`). Full context:
`ofresh-kiosk/docs/deployment-update-and-recovery.md` §4.

> These scripts ship to kiosks via **machine registration only** (raw pull from
> `main`), not `electron-updater` — changing them requires re-provisioning each kiosk.

## Updating an existing Windows kiosk

`update_watchdog.ps1` replaces the watchdog without rerunning the full provisioning
flow. Run it from an elevated Windows PowerShell 5.1 prompt.

After this PR merges, download the updater, install the watchdog from `main`, and
restart Windows:

```powershell
$updater = Join-Path $env:TEMP 'update_watchdog.ps1'
Invoke-WebRequest `
  -Uri 'https://github.com/kickstart-engineering/ofresh-kiosk-app/raw/refs/heads/main/update_watchdog.ps1' `
  -OutFile $updater -UseBasicParsing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $updater -Restart
```

To test this PR before merge, download the updater from the PR branch and select the
same branch as the watchdog source:

```powershell
$ref = 'claude/ofresh-kiosk-error-31-restart-xt3lpd'
$updater = Join-Path $env:TEMP 'update_watchdog.ps1'
Invoke-WebRequest `
  -Uri "https://github.com/kickstart-engineering/ofresh-kiosk-app/raw/refs/heads/$ref/update_watchdog.ps1" `
  -OutFile $updater -UseBasicParsing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $updater `
  -GitRef claude/ofresh-kiosk-error-31-restart-xt3lpd -Restart
```

For an offline machine, copy both scripts to removable storage and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\update_watchdog.ps1 `
  -SourcePath .\ensure_app_running.ps1 -Restart
```

The updater validates the replacement with the PowerShell parser, stores a timestamped
backup beside the installed script, replaces it atomically, and verifies the installed
SHA-256 hash. It writes its log to `C:\logs\watchdog-update.log`.

Without `-Restart`, the updater only stages the file. The running PowerShell process
continues to use the previous watchdog code until Windows restarts.
