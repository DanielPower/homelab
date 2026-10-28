#!/bin/bash
# Runs in the pgbackrest sidecar: full backup on Sundays, diff otherwise, at BACKUP_HOUR.
set -uo pipefail

ping() {
    [ -n "${HEALTHCHECK_URL:-}" ] && curl -fsS -m 10 --retry 3 -o /dev/null "${HEALTHCHECK_URL}$1"
    true
}

until pg_isready -q -h /var/run/postgresql; do sleep 5; done
pgbackrest --stanza=main stanza-create
pgbackrest --stanza=main check

while true; do
    now=$(date +%s)
    next=$(date -d "${BACKUP_HOUR:-3}:00" +%s)
    [ "$next" -le "$now" ] && next=$((next + 86400))
    sleep $((next - now))

    type=diff
    [ "$(date +%u)" = 7 ] && type=full
    ping /start
    if pgbackrest --stanza=main --type="$type" backup; then
        ping ""
    else
        ping /fail
    fi
done
