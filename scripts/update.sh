#!/bin/sh
set -eu

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

url_encode() {
  jq -rn --arg v "$1" '$v|@uri'
}

curl_json() {
  # Usage: curl_json <url> [curl args...]
  url="$1"
  shift
  attempt=1
  max_attempts=4
  delay=2

  while true; do
    resp="$(curl -sS --retry 0 --connect-timeout 5 --max-time 15 "$@" "$url")" && {
      echo "${resp}"
      return 0
    }

    if [ "${attempt}" -ge "${max_attempts}" ]; then
      log "Request failed after ${attempt} attempts: ${url}"
      return 1
    fi

    log "Request failed (attempt ${attempt}); retrying in ${delay}s"
    sleep "${delay}"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

require_env() {
  var_name="$1"
  eval "var_value=\"\${${var_name}:-}\""
  if [ -z "${var_value}" ]; then
    log "Missing required env var: ${var_name}"
    exit 2
  fi
}

require_env CF_API_TOKEN
require_env CF_RECORD_NAME

: "${IP_PROVIDER_URL:=https://api.ipify.org}"

now_epoch="$(date +%s)"
echo "${now_epoch}" >/tmp/last_attempt 2>/dev/null || true

# Determine zone id by matching the record name to the longest zone name suffix
CF_ZONE_ID=""
CF_ZONE_NAME=""
page=1
per_page=50

while true; do
  zones_resp="$(curl_json \
    "https://api.cloudflare.com/client/v4/zones?per_page=${per_page}&page=${page}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json")" || exit 3

  if [ "$(echo "${zones_resp}" | jq -r '.success // false')" != "true" ]; then
    log "Failed to list zones: $(echo "${zones_resp}" | jq -c '.errors')"
    exit 3
  fi

  zone_count="$(echo "${zones_resp}" | jq -r '.result | length')"
  if [ "${zone_count}" -eq 0 ]; then
    break
  fi

  for zone_name in $(echo "${zones_resp}" | jq -r '.result[].name'); do
    case "${CF_RECORD_NAME}" in
      *."${zone_name}"|${zone_name})
        if [ -z "${CF_ZONE_NAME}" ] || [ "${#zone_name}" -gt "${#CF_ZONE_NAME}" ]; then
          CF_ZONE_NAME="${zone_name}"
        fi
        ;;
    esac
  done

  total_pages="$(echo "${zones_resp}" | jq -r '.result_info.total_pages // 1')"
  if [ "${page}" -ge "${total_pages}" ]; then
    break
  fi
  page=$((page + 1))
done

if [ -n "${CF_ZONE_NAME}" ]; then
  zone_resp="$(curl_json \
    "https://api.cloudflare.com/client/v4/zones?name=$(url_encode "${CF_ZONE_NAME}")" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json")" || exit 3
  if [ "$(echo "${zone_resp}" | jq -r '.success // false')" != "true" ]; then
    log "Failed to look up zone id: $(echo "${zone_resp}" | jq -c '.errors')"
    exit 3
  fi
  CF_ZONE_ID="$(echo "${zone_resp}" | jq -r '.result[0].id // empty')"
fi

if [ -z "${CF_ZONE_ID}" ]; then
  log "Could not determine zone id for ${CF_RECORD_NAME}. Check Cloudflare zones and token permissions."
  exit 3
fi

log "Resolved zone ${CF_ZONE_NAME} (${CF_ZONE_ID}) for ${CF_RECORD_NAME}"

# Determine record id for A record
log "Looking up record id for ${CF_RECORD_NAME} (A) in zone ${CF_ZONE_ID}"
lookup_resp="$(curl_json \
  "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=$(url_encode "${CF_RECORD_NAME}")" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json")" || exit 4

if [ "$(echo "${lookup_resp}" | jq -r '.success // false')" != "true" ]; then
  log "Record lookup failed: $(echo "${lookup_resp}" | jq -c '.errors')"
  exit 4
fi

CF_RECORD_ID="$(echo "${lookup_resp}" | jq -r '.result[0].id // empty')"

if [ -z "${CF_RECORD_ID}" ]; then
  log "Could not find DNS record id. Check CF_RECORD_NAME."
  exit 4
fi

# Fetch public IP
current_ip="$(curl -fsS "${IP_PROVIDER_URL}")"

if [ -z "${current_ip}" ]; then
  log "Failed to fetch public IP"
  exit 4
fi

# Fetch existing record content
record_resp="$(curl_json \
  "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD_ID}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json")" || exit 5
if [ "$(echo "${record_resp}" | jq -r '.success // false')" != "true" ]; then
  log "Failed to read DNS record details: $(echo "${record_resp}" | jq -c '.errors')"
  exit 5
fi

record_name="$(echo "${record_resp}" | jq -r '.result.name // empty')"
record_content="$(echo "${record_resp}" | jq -r '.result.content // empty')"
record_type="$(echo "${record_resp}" | jq -r '.result.type // empty')"

if [ -z "${record_name}" ] || [ -z "${record_type}" ]; then
  log "Failed to read DNS record details"
  exit 5
fi

if [ "${record_type}" != "A" ]; then
  log "Record type is ${record_type}, but this updater only supports A records"
  exit 6
fi

if [ "${record_content}" = "${current_ip}" ]; then
  log "No change: ${record_name} already set to ${current_ip}"
  exit 0
fi

update_payload=$(jq -n \
  --arg type "A" \
  --arg name "${record_name}" \
  --arg content "${current_ip}" \
  --argjson ttl 1 \
  --argjson proxied false \
  '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')

update_resp="$(curl_json \
  "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD_ID}" \
  -X PUT \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "${update_payload}")" || exit 7

success="$(echo "${update_resp}" | jq -r '.success // false')"

if [ "${success}" != "true" ]; then
  log "Update failed: $(echo "${update_resp}" | jq -c '.errors')"
  exit 7
fi

log "Updated ${record_name} from ${record_content} to ${current_ip}"
echo "$(date +%s)" >/tmp/last_success 2>/dev/null || true
