# ofresh-kiosk-app

Provisioning and watchdog scripts for the OFresh kiosk machines. This is the
layer that keeps the kiosk application running, starts it at boot, and recovers
the MDB USB interface when it drops — the application itself lives in
[`ofresh-kiosk`](https://github.com/kickstart-engineering/ofresh-kiosk).

These scripts reach kiosks by raw pull from `main` at machine-registration
time, **not** through `electron-updater`. A change here lands on a machine only
when it is re-provisioned.

## Windows

Files in the repository root. The current production path.

| File | Purpose |
|---|---|
| `setup_startup.bat` | Installer: boot shell, autologin, power settings, DWAgent |
| `ensure_app_running.ps1` | Watchdog: starts the app at boot and supervises it |
| `uninstall.bat` | Reverses the installer |
| `CH34x_Install_Windows_v3_4.EXE` | CH340/CH341 USB-serial driver for the MDB board |

Run `setup_startup.bat` as Administrator and pick option 5 for a full install.

## Linux

Files under [`linux/`](linux/), targeting Ubuntu Desktop. Systemd replaces the
PowerShell supervision loop, and adds two recovery steps between "restart the
app" and "reboot the machine" that the Windows watchdog does not have.

```sh
sudo linux/install.sh --user ofresh --autologin
```

See [`linux/README.md`](linux/README.md) for the architecture, the mapping from
the Windows scripts, and troubleshooting.

## Configuration

Both platforms read the same keys. Copy `.env.template`, fill it in, and keep
it out of git — `.gitignore` covers `.env` and `*.env`.
