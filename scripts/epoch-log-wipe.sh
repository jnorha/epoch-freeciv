#!/usr/bin/env bash
# Truncates the freeciv-web container's Docker log file.
# Belt-and-suspenders daily reset on top of the size-based rotation configured
# in docker-compose.yml (logging.options.max-size). Intended to run once a day
# via cron so troubleshooting logs never accumulate past a day and never grow
# unbounded even if the size cap logic misbehaves.
#
# Usage: run directly, or via cron:
#   0 0 * * * /opt/epoch/scripts/epoch-log-wipe.sh >> /var/log/epoch-log-wipe.log 2>&1

set -e

CONTAINER="${1:-freeciv-web}"
LOGPATH=$(docker inspect --format='{{.LogPath}}' "${CONTAINER}" 2>/dev/null || true)

if [ -z "${LOGPATH}" ] || [ ! -f "${LOGPATH}" ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) no log file found for container '${CONTAINER}', skipping"
  exit 0
fi

: > "${LOGPATH}"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) wiped log for '${CONTAINER}' (${LOGPATH})"
