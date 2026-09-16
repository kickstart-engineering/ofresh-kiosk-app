#!/usr/bin/env bash
#
# Install the OFresh kiosk stack on Ubuntu Desktop.
#
# The Linux counterpart to setup_startup.bat, with three deliberate departures
# from it:
#
#   * Idempotent. Re-running it is safe and is the supported way to upgrade.
#     There is no interactive menu with a 10-second timeout that picks "full
#     install" for you.
#   * It never weakens the system. No equivalent of EnableLUA=0: the only
#     privileged component is a root-owned systemd unit, so the kiosk user is
#     granted nothing beyond membership of dialout.
#   * It stores no password. Autologin is configured through gdm, which needs
#     no credentials on disk, rather than writing one into the registry.
#
# Usage:
#   sudo ./install.sh [--user NAME] [--appimage PATH] [--app-path PATH] [--autologin] [--dry-run]

set -euo pipefail

KIOSK_USER=ofresh
APP_PATH=/opt/ofresh/kiosk-app/OfreshKioskApp.AppImage
APP_PATH_EXPLICIT=0
APPIMAGE_SOURCE=
CONFIGURE_AUTOLOGIN=0
DRY_RUN=0

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX=/opt/ofresh
CONF_DIR=/etc/ofresh
CONF_FILE="$CONF_DIR/kiosk.env"
STATE_DIR=/var/lib/ofresh
LOG_DIR=/var/log/ofresh
VERSION="$(cat "$SRC_DIR/../VERSION" 2>/dev/null || echo unknown)"

info()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m==> WARNING:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
run()   { if [ "$DRY_RUN" = 1 ]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

usage() {
    cat <<'EOF'
Install the OFresh kiosk stack on Ubuntu Desktop.

Usage: sudo ./install.sh [OPTIONS]

  --user NAME       Kiosk user account (default: ofresh)
  --appimage PATH   Install this AppImage at the stable self-updating path
  --app-path PATH   Application executable
                    (default: /opt/ofresh/kiosk-app/OfreshKioskApp.AppImage)
  --autologin       Configure gdm autologin for the kiosk user
  --dry-run         Print what would happen, change nothing
  -h, --help        Show this message

Safe to re-run: this is the supported way to upgrade. An existing
/etc/ofresh/kiosk.env is never overwritten.
EOF
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --user)      KIOSK_USER="${2:?--user needs a value}"; shift 2 ;;
        --appimage)  APPIMAGE_SOURCE="${2:?--appimage needs a value}"; shift 2 ;;
        --app-path)  APP_PATH="${2:?--app-path needs a value}"; APP_PATH_EXPLICIT=1; shift 2 ;;
        --autologin) CONFIGURE_AUTOLOGIN=1; shift ;;
        --dry-run)   DRY_RUN=1; shift ;;
        -h|--help)   usage ;;
        *)           die "Unknown argument: $1 (try --help)" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "Must run as root"
id "$KIOSK_USER" >/dev/null 2>&1 || die "User '$KIOSK_USER' does not exist. Create it first, or pass --user."

if [ -n "$APPIMAGE_SOURCE" ] && [ ! -f "$APPIMAGE_SOURCE" ]; then
    die "AppImage not found: $APPIMAGE_SOURCE"
fi
if [ -n "$APPIMAGE_SOURCE" ] && [ "$APP_PATH_EXPLICIT" = 1 ]; then
    die "--appimage uses the stable self-updating path and cannot be combined with --app-path"
fi

KIOSK_GROUP="$(id -gn "$KIOSK_USER")"

info "Installing OFresh kiosk stack ${VERSION} for user '${KIOSK_USER}'"

# --- Directories -------------------------------------------------------------

info "Creating directories"
run install -d -m 0755 "$PREFIX/bin"
run install -d -m 0750 -o "$KIOSK_USER" -g "$KIOSK_GROUP" "$PREFIX/kiosk-app"
run install -d -m 0755 "$CONF_DIR"
run install -d -m 0750 -o root -g "$KIOSK_GROUP" "$STATE_DIR"
run install -d -m 0755 -o "$KIOSK_USER" -g "$KIOSK_GROUP" "$LOG_DIR"

# /run is tmpfs, so the reboot-request directory has to be recreated on every
# boot. That is the point: a request cannot outlive the boot that produced it,
# which is the guarantee the Windows watchdog has to enforce in code by
# checking requestedAt against a five minute window.
info "Installing tmpfiles rule for /run/ofresh"
if [ "$DRY_RUN" = 1 ]; then
    printf '    [dry-run] write /etc/tmpfiles.d/ofresh.conf\n'
else
    cat > /etc/tmpfiles.d/ofresh.conf <<EOF
# Runtime directory for the kiosk reboot-request signal. Recreated each boot.
d /run/ofresh 0770 root $KIOSK_GROUP -
EOF
    systemd-tmpfiles --create /etc/tmpfiles.d/ofresh.conf
fi

# --- Executables and units ---------------------------------------------------

info "Installing helper scripts to $PREFIX/bin"
for script in ofresh-liveness ofresh-recovery ofresh-update; do
    run install -m 0755 "$SRC_DIR/bin/$script" "$PREFIX/bin/$script"
done

# Electron's AppImage updater unlinks the running image and moves the downloaded
# replacement into this same directory. Both the stable file and its containing
# directory therefore belong to the unprivileged kiosk user. No sudo or polkit
# permission is granted to the application.
if [ -n "$APPIMAGE_SOURCE" ]; then
    info "Installing AppImage at $APP_PATH"
    run install -m 0755 -o "$KIOSK_USER" -g "$KIOSK_GROUP" "$APPIMAGE_SOURCE" "$APP_PATH"
fi
# Remove the helper shipped by the initial Linux port. Port-level USB resets
# are deliberately not part of this supervisor.
run rm -f "$PREFIX/bin/ofresh-usb-recover"

info "Installing systemd units"
run install -m 0644 "$SRC_DIR/systemd/ofresh-kiosk.service"           /etc/systemd/user/ofresh-kiosk.service
run install -m 0644 "$SRC_DIR/systemd/ofresh-kiosk-update.service"    /etc/systemd/user/ofresh-kiosk-update.service
run install -m 0644 "$SRC_DIR/systemd/ofresh-kiosk-update.timer"      /etc/systemd/user/ofresh-kiosk-update.timer
run install -m 0644 "$SRC_DIR/systemd/ofresh-kiosk-liveness.service"  /etc/systemd/user/ofresh-kiosk-liveness.service
run install -m 0644 "$SRC_DIR/systemd/ofresh-kiosk-liveness.timer"    /etc/systemd/user/ofresh-kiosk-liveness.timer
run install -m 0644 "$SRC_DIR/systemd/ofresh-kiosk-recovery.service"  /etc/systemd/system/ofresh-kiosk-recovery.service
run install -m 0644 "$SRC_DIR/systemd/ofresh-kiosk-recovery.timer"    /etc/systemd/system/ofresh-kiosk-recovery.timer

# The unit ships with the default app path; rewrite it only if asked for
# something else, so re-running the installer does not churn the file.
if [ "$APP_PATH" != /opt/ofresh/kiosk-app/OfreshKioskApp.AppImage ]; then
    info "Pointing ofresh-kiosk.service at $APP_PATH"
    run sed -i "s|^ExecStart=.*|ExecStart=$APP_PATH|" /etc/systemd/user/ofresh-kiosk.service
fi

# --- Configuration -----------------------------------------------------------

# Never overwrite an existing config: it holds the machine's credentials.
if [ -e "$CONF_FILE" ]; then
    info "Keeping existing $CONF_FILE (delete it to start from the template)"
else
    info "Installing $CONF_FILE from template -- fill in MACHINE_ID and credentials"
    run install -m 0640 -o root -g "$KIOSK_GROUP" "$SRC_DIR/config/kiosk.env.template" "$CONF_FILE"
fi

# --- Hardware ----------------------------------------------------------------

info "Installing udev rules"
run install -m 0644 "$SRC_DIR/udev/99-ofresh-serial.rules" /etc/udev/rules.d/99-ofresh-serial.rules
run install -m 0644 "$SRC_DIR/udev/85-brltty.rules"        /etc/udev/rules.d/85-brltty.rules
run udevadm control --reload-rules
run udevadm trigger --subsystem-match=tty

info "Masking brltty, which claims CH340 adapters and makes the serial port vanish"
run systemctl mask --quiet brltty.service brltty-udev.service || warn "Could not mask brltty units (not installed?)"

info "Adding $KIOSK_USER to the dialout group"
run usermod -aG dialout "$KIOSK_USER"

# --- Desktop lockdown --------------------------------------------------------

info "Installing dconf kiosk profile"
run install -d -m 0755 /etc/dconf/db/kiosk.d/locks
run install -d -m 0755 /etc/dconf/profile
run install -m 0644 "$SRC_DIR/dconf/kiosk.d/00-ofresh-kiosk"       /etc/dconf/db/kiosk.d/00-ofresh-kiosk
run install -m 0644 "$SRC_DIR/dconf/kiosk.d/locks/00-ofresh-kiosk" /etc/dconf/db/kiosk.d/locks/00-ofresh-kiosk
run install -m 0644 "$SRC_DIR/dconf/profile-user"                  /etc/dconf/profile/user
run dconf update

info "Masking sleep, suspend and hibernate"
run systemctl mask --quiet sleep.target suspend.target hibernate.target hybrid-sleep.target

if [ "$CONFIGURE_AUTOLOGIN" = 1 ]; then
    GDM_CONF=/etc/gdm3/custom.conf

    if [ ! -f "$GDM_CONF" ]; then
        warn "$GDM_CONF not found; skipping autologin. Is gdm3 the display manager?"
    elif [ "$DRY_RUN" = 1 ]; then
        printf '    [dry-run] configure autologin for %s in %s\n' "$KIOSK_USER" "$GDM_CONF"
    else
        info "Configuring gdm autologin for $KIOSK_USER"
        cp -n "$GDM_CONF" "$GDM_CONF.ofresh-backup"

        # Drop any keys we manage, commented or not, then reinsert them under
        # [daemon]. Note gdm stores no password for this -- unlike the Windows
        # installer, which writes DefaultPassword in cleartext to the registry.
        sed -i -E '/^[[:space:]]*#?[[:space:]]*AutomaticLoginEnable[[:space:]]*=/d' "$GDM_CONF"
        sed -i -E '/^[[:space:]]*#?[[:space:]]*AutomaticLogin[[:space:]]*=/d' "$GDM_CONF"

        if grep -q '^\[daemon\]' "$GDM_CONF"; then
            sed -i "0,/^\[daemon\]/s//[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=$KIOSK_USER/" "$GDM_CONF"
        else
            printf '\n[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=%s\n' "$KIOSK_USER" >> "$GDM_CONF"
        fi
    fi
else
    info "Skipping autologin (pass --autologin to configure it)"
fi

# --- Enable ------------------------------------------------------------------

info "Enabling units"
run systemctl daemon-reload
# --global enables the user units for every user on the machine. On a
# single-purpose kiosk that is what we want, and it avoids having to reach into
# the kiosk user's session from this script.
run systemctl --global enable ofresh-kiosk.service \
                               ofresh-kiosk-update.timer \
                               ofresh-kiosk-liveness.timer
run systemctl enable --now ofresh-kiosk-recovery.timer

run install -d -m 0755 "$PREFIX"
if [ "$DRY_RUN" = 1 ]; then
    printf '    [dry-run] write %s/VERSION\n' "$PREFIX"
else
    printf '%s\n' "$VERSION" > "$PREFIX/VERSION"
fi

if [ -n "$APPIMAGE_SOURCE" ]; then
    APP_NEXT_STEP="The AppImage is installed; no separate application copy is needed."
else
    APP_NEXT_STEP="The service updater will install the latest AppImage when the service starts."
fi

cat <<EOF

$(info "Done")

  Version:  $VERSION
  User:     $KIOSK_USER
  App:      $APP_PATH
  Config:   $CONF_FILE

Next steps:

  1. Fill in $CONF_FILE (MACHINE_ID, KIOSK_SERVICE_HOST, credentials).
  2. $APP_NEXT_STEP
  3. Reboot. The group change and the dconf locks both need a fresh session.

After rebooting, check on it with:

  systemctl --user status ofresh-kiosk.service
  journalctl --user -u ofresh-kiosk -f
  systemctl status ofresh-kiosk-recovery.timer
  ls -l /dev/ofresh-mdb

EOF
