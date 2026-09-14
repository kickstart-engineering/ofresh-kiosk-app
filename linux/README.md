# OFresh kiosk — Linux

The Linux counterpart to the Windows scripts in the repository root, targeting
Ubuntu Desktop to match the provisioning flow in `ofresh-kiosk` PR #21.

The guiding idea of this port is that **most of `ensure_app_running.ps1` should
not be translated — it should be deleted.** Roughly 150 of its 226 lines
reimplement supervision, restart backoff, log capture, rotation and
network-ordering, all of which systemd already provides. What is left is small
enough to read in one sitting.

## Install

```sh
sudo ./install.sh --user ofresh --autologin
```

Re-running is safe and is the supported way to upgrade. An existing
`/etc/ofresh/kiosk.env` is never overwritten. `--dry-run` prints every action
without taking any.

Then fill in `/etc/ofresh/kiosk.env`, install the application at
`/opt/ofresh/kiosk-app/`, and reboot — the `dialout` group change and the dconf
locks both need a fresh session.

Removal: `sudo ./uninstall.sh` (add `--purge` to drop config, state and logs).

## What runs

| Unit | Scope | Job |
|---|---|---|
| `ofresh-kiosk.service` | user | The app. `Restart=always`, `RestartSec=5`, `StartLimitIntervalSec=0`. |
| `ofresh-kiosk-liveness.timer` | user, 60 s | Restarts the app when its log goes stale — the hung-but-alive case. |
| `ofresh-kiosk-recovery.timer` | **system**, 30 s | Consumes the reboot request and reboots the computer. |

Only the recovery unit is privileged. Because it runs as root, the kiosk user
needs no reboot right of its own: no polkit rule, no sudoers entry, and nothing
resembling the machine-wide `EnableLUA=0` the Windows installer applies.

## The escalation ladder

The recovery sequence is intentionally limited to application supervision and
computer reboot. USB port resets remain the application's responsibility:

1. The app re-enumerates USB internally (`ofresh-kiosk` PR #9).
2. **`systemctl restart`** — atomic, ~5 s. Cannot produce two instances fighting
   over the serial port, which the Windows script could (see PR #2).
3. Reboot the computer, rate-limited to once per 15 minutes and stamped in
   `/var/lib/ofresh`.

## Liveness, in two phases

**Now:** `ofresh-liveness` compares the mtime of `main.log` against a 180 s
threshold — the same signal and the same budget as the Windows watchdog, minus
the regex. It restarts only if the app is active *and* outside a 300 s grace
period after a start we initiated, so an app that never logs is not killed on
every pass. This works against today's application unmodified.

**Next:** once the Electron main process calls `sd_notify(WATCHDOG=1)` — a
change in the `ofresh-kiosk` repo, roughly fifteen lines using `dgram` against
`$NOTIFY_SOCKET`, no native module — switch `ofresh-kiosk.service` to
`Type=notify`, uncomment `WatchdogSec=180`, and set `OFRESH_LIVENESS_ENABLED=0`.
systemd then supervises liveness directly and the timer stands down. The units
ship ready for this; it is a config flip, not a rewrite.

## How this maps to the Windows scripts

| Windows | Linux |
|---|---|
| `Winlogon\Shell` = the watchdog | gdm autologin + systemd user unit |
| `while ($true) { Start-App }` | `Restart=always` |
| `main.log` last line older than 3 min | log mtime, then `WatchdogSec` |
| `Test-Connection 8.8.8.8` in the loop | nothing — restarts never wait on the network |
| `Invoke-WebRequest` of a pinned release | packaged app under `/opt/ofresh` |
| `SendKeys("{SCROLLLOCK}")` | dconf `idle-delay=0` + masked sleep targets |
| `powercfg /change standby-timeout-*` | `systemctl mask sleep.target …` |
| `AllowEdgeSwipe=0` | dconf lockdown profile with locks |
| `EnableLUA=0` | nothing — privilege stays split |
| `DefaultPassword` in the registry | gdm autologin, no password stored |
| `C:\logs\*.log`, no rotation | journald |
| `CH34x_Install_Windows_v3_4.EXE` | in-kernel `ch341` + udev rules |
| `pnputil` re-enumeration | sysfs unbind/bind |
| `reboot-request.json` + `requestedAt` | same file on tmpfs — see below |

One nice consequence of the move: the reboot request lives in `/run/ofresh`,
which is tmpfs. It cannot survive a boot, so the "ignore a request left over
from a previous boot" guarantee that PR #1 has to enforce in code comes for
free from where the file is kept.

## Troubleshooting

**The serial port appears at boot and vanishes seconds later.** This is
`brltty`, the braille daemon Ubuntu installs by default. It claims CH340
adapters because they share a VID:PID with braille hardware, and it is the most
common way a CH340 project fails on modern Ubuntu. The symptom looks exactly
like the USB fault behind error-31. `install.sh` handles it by shadowing
brltty's udev rules and masking its units; `sudo apt-get purge brltty` is the
belt-and-braces version.

**`/dev/ofresh-mdb` points at the wrong adapter.** The MDB board and the door
lock are probably both `1a86:7523`, so the shipped rule matches both and the
symlink lands on whichever enumerated last. Pin them by serial or by physical
port — `linux/udev/99-ofresh-serial.rules` carries both recipes and the
`udevadm` command to get the values off a real machine.

**Where are the logs?**

```sh
journalctl --user -u ofresh-kiosk -f          # the app
journalctl --user -u ofresh-kiosk-liveness    # restart decisions
journalctl -u ofresh-kiosk-recovery           # computer reboot requests
```

## Known gaps

- **Not yet run on real kiosk hardware.** Units verify under
  `systemd-analyze`, scripts pass shellcheck, and every branch of the recovery
  logic has been exercised, but no CH340 has been rebound and no fridge has
  been booted from this.
- **`main.log`'s Linux path is a guess.** `/var/log/ofresh/main.log` is a
  proposal; the app decides, and it is one variable in `kiosk.env` when it does.
- **No integration with the Ubuntu autoinstall** in `ofresh-kiosk` PR #21 yet.
- **Application packaging is out of scope.** These units expect something
  executable at `/opt/ofresh/kiosk-app/`; producing it is the app repo's job.
