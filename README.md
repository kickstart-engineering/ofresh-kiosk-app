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
  `C:\logs\last-watchdog-reboot.txt`) so a permanently dead device can't reboot-loop.

The app side of this signal lives in `ofresh-kiosk` →
`kiosk-app/src/main/picovend-mdb.ts` (`maybeRequestReboot`). Full context:
`ofresh-kiosk/docs/deployment-update-and-recovery.md` §4.

> These scripts ship to kiosks via **machine registration only** (raw pull from
> `main`), not `electron-updater` — changing them requires re-provisioning each kiosk.
