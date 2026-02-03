#!/bin/sh
set -eu

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

: "${INTERVAL_SECONDS:=300}"

if [ "${INTERVAL_SECONDS}" -lt 30 ]; then
  log "INTERVAL_SECONDS too low (${INTERVAL_SECONDS}); forcing to 30"
  INTERVAL_SECONDS=30
fi

log "Starting Cloudflare DDNS updater"
log "Interval: ${INTERVAL_SECONDS}s"

while true; do
  if [ -n "${HEALTHCHECKS_IO_URL:-}" ]; then
    curl -fsS -m 10 "${HEALTHCHECKS_IO_URL%/}/start" >/dev/null 2>&1 || true
  fi

  if /app/scripts/update.sh; then
    log "Update check finished"
    if [ -n "${HEALTHCHECKS_IO_URL:-}" ]; then
      curl -fsS -m 10 "${HEALTHCHECKS_IO_URL%/}" >/dev/null 2>&1 || true
    fi
  else
    log "Update check failed"
    if [ -n "${HEALTHCHECKS_IO_URL:-}" ]; then
      curl -fsS -m 10 "${HEALTHCHECKS_IO_URL%/}/fail" >/dev/null 2>&1 || true
    fi
  fi
  sleep "${INTERVAL_SECONDS}"
done
