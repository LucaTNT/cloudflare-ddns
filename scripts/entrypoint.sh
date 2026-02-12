#!/bin/sh
set -eu

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

run_log() {
  message="$*"
  line="$(date -u '+%Y-%m-%dT%H:%M:%SZ') ${message}"
  printf '%s\n' "${line}" | tee -a "${RUN_LOG}" >/dev/null
}

append_prefixed_file() {
  input_file="$1"
  while IFS= read -r line || [ -n "${line}" ]; do
    run_log "${line}"
  done <"${input_file}"
}

: "${INTERVAL_SECONDS:=300}"

if [ "${INTERVAL_SECONDS}" -lt 30 ]; then
  log "INTERVAL_SECONDS too low (${INTERVAL_SECONDS}); forcing to 30"
  INTERVAL_SECONDS=30
fi

log "Starting Cloudflare DDNS updater"
log "Interval: ${INTERVAL_SECONDS}s"

while true; do
  RUN_LOG="$(mktemp)"
  UPDATE_RAW_LOG="$(mktemp)"

  if [ -n "${HEALTHCHECKS_IO_URL:-}" ]; then
    curl -fsS -m 10 "${HEALTHCHECKS_IO_URL%/}/start" >/dev/null 2>&1 || true
  fi

  run_log "Update check started"
  if /app/scripts/update.sh >"${UPDATE_RAW_LOG}" 2>&1; then
    append_prefixed_file "${UPDATE_RAW_LOG}"
    run_log "Update check finished"
    healthchecks_path=""
  else
    update_status=$?
    append_prefixed_file "${UPDATE_RAW_LOG}"
    run_log "Update check failed (exit code ${update_status})"
    healthchecks_path="/fail"
  fi

  cat "${RUN_LOG}"

  if [ -n "${HEALTHCHECKS_IO_URL:-}" ]; then
    curl -fsS -m 10 \
      --data-binary "@${RUN_LOG}" \
      "${HEALTHCHECKS_IO_URL%/}${healthchecks_path}" >/dev/null 2>&1 || true
  fi

  rm -f "${RUN_LOG}" "${UPDATE_RAW_LOG}"
  sleep "${INTERVAL_SECONDS}"
done
