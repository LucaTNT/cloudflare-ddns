#!/bin/sh
set -eu

: "${INTERVAL_SECONDS:=300}"

if [ "${INTERVAL_SECONDS}" -lt 30 ]; then
  INTERVAL_SECONDS=30
fi

if [ ! -f /tmp/last_success ]; then
  exit 1
fi

last_success="$(cat /tmp/last_success || echo 0)"
now_epoch="$(date +%s)"
max_age=$((INTERVAL_SECONDS * 2))

if [ $((now_epoch - last_success)) -gt "${max_age}" ]; then
  exit 1
fi

exit 0
