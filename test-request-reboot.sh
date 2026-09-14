#!/usr/bin/env bash
set -euo pipefail

request=/run/ofresh/reboot-request.json
umask 007
printf '{"reason":"manual systemd recovery test","requestedBy":"%s"}\n' "$(id -un)" > "$request"
printf 'Created %s; the recovery timer should reboot the computer within 30 seconds.\n' "$request"
