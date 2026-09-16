#!/usr/bin/env bash
#
# Remove the OFresh kiosk stack.
#
# The counterpart to uninstall.bat, and it actually removes things -- see
# PR #2, where both uninstaller calls in the batch script turned out to expand
# to nothing and had never run.
#
# Configuration and state are kept unless --purge is given, so that an
# uninstall/reinstall cycle does not lose a machine's credentials.

set -euo pipefail

KIOSK_USER=ofresh
PURGE=0
DRY_RUN=0

PREFIX=/opt/ofresh
CONF_DIR=/etc/ofresh
STATE_DIR=/var/lib/ofresh
LOG_DIR=/var/log/ofresh

info() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

usage() {
    cat <<'EOF'
Remove the OFresh kiosk stack.

Usage: sudo ./uninstall.sh [OPTIONS]

  --user NAME   Kiosk user account (default: ofresh)
  --purge       Also delete /etc/ofresh, /var/lib/ofresh and /var/log/ofresh
  --dry-run     Print what would happen, change nothing
  -h, --help    Show this message
EOF
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --user)    KIOSK_USER="${2:?--user needs a value}"; shift 2 ;;
        --purge)   PURGE=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage ;;
        *)         die "Unknown argument: $1 (try --help)" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "Must run as root"

info "Removing OFresh kiosk stack"

info "Disabling units"
run systemctl disable --now ofresh-kiosk-recovery.timer || warn "recovery timer was not enabled"
run systemctl --global disable ofresh-kiosk.service \
                                    ofresh-kiosk-update.timer \
                                    ofresh-kiosk-liveness.timer || warn "user units were not enabled"

info "Removing systemd units"
run rm -f /etc/systemd/user/ofresh-kiosk.service \
          /etc/systemd/user/ofresh-kiosk-update.service \
          /etc/systemd/user/ofresh-kiosk-update.timer \
          /etc/systemd/user/ofresh-kiosk-liveness.service \
          /etc/systemd/user/ofresh-kiosk-liveness.timer \
          /etc/systemd/system/ofresh-kiosk-recovery.service \
          /etc/systemd/system/ofresh-kiosk-recovery.timer
run systemctl daemon-reload

info "Restoring sleep, suspend and hibernate"
run systemctl unmask --quiet sleep.target suspend.target hibernate.target hybrid-sleep.target

info "Restoring brltty"
run rm -f /etc/udev/rules.d/85-brltty.rules
run systemctl unmask --quiet brltty.service brltty-udev.service || warn "brltty units were not masked"

info "Removing udev rules"
run rm -f /etc/udev/rules.d/99-ofresh-serial.rules
run udevadm control --reload-rules

info "Removing dconf kiosk profile"
run rm -f /etc/dconf/db/kiosk.d/00-ofresh-kiosk \
          /etc/dconf/db/kiosk.d/locks/00-ofresh-kiosk
# /etc/dconf/profile/user is only ours if nothing else added to it. Leave it if
# it has been edited, rather than breaking another profile on the way out.
if [ ! -f /etc/dconf/profile/user ]; then
    : # never installed, or already removed
elif ! grep -qv -e '^#' -e '^$' -e '^user-db:user$' -e '^system-db:kiosk$' /etc/dconf/profile/user; then
    run rm -f /etc/dconf/profile/user
else
    warn "/etc/dconf/profile/user has been modified; leaving it in place"
fi
run dconf update

info "Restoring gdm autologin"
GDM_CONF=/etc/gdm3/custom.conf
if [ -f "$GDM_CONF.ofresh-backup" ]; then
    run mv "$GDM_CONF.ofresh-backup" "$GDM_CONF"
elif [ -f "$GDM_CONF" ]; then
    run sed -i -E '/^[[:space:]]*AutomaticLoginEnable[[:space:]]*=/d' "$GDM_CONF"
    run sed -i -E "/^[[:space:]]*AutomaticLogin[[:space:]]*=[[:space:]]*$KIOSK_USER\$/d" "$GDM_CONF"
fi

info "Removing helper scripts"
run rm -rf "$PREFIX/bin"
run rm -f "$PREFIX/VERSION"
run rm -f /etc/tmpfiles.d/ofresh.conf
run rm -rf /run/ofresh

info "Removing $KIOSK_USER from the dialout group"
if id "$KIOSK_USER" >/dev/null 2>&1; then
    run gpasswd -d "$KIOSK_USER" dialout || warn "$KIOSK_USER was not in dialout"
else
    warn "User '$KIOSK_USER' does not exist; skipping group change"
fi

if [ "$PURGE" = 1 ]; then
    info "Purging configuration, state and logs"
    run rm -rf "$CONF_DIR" "$STATE_DIR" "$LOG_DIR"
else
    info "Keeping $CONF_DIR, $STATE_DIR and $LOG_DIR (pass --purge to remove)"
fi

cat <<EOF

$(info "Done")

The application itself at $PREFIX/kiosk-app was not touched.
A reboot is recommended so the desktop returns to its stock configuration.

EOF
