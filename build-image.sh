#!/bin/sh
set -eu

usage() {
  cat <<'USAGE'
Usage: scripts/build-image.sh [tag ...]

Environment:
  IMAGE_NAME   Image name/repo (default: cloudflare-ddns)
  PLATFORMS    Target platforms (default: linux/amd64,linux/arm64)

Examples:
  IMAGE_NAME=ghcr.io/you/cloudflare-ddns scripts/build-image.sh latest
  scripts/build-image.sh latest 1.2.3
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

: "${IMAGE_NAME:=cloudflare-ddns}"
: "${PLATFORMS:=linux/amd64,linux/arm64}"

if [ "$#" -eq 0 ]; then
  echo "Error: provide at least one tag" >&2
  usage >&2
  exit 2
fi

set -- "$@"

tag_args=""
for tag in "$@"; do
  tag_args="$tag_args --tag ${IMAGE_NAME}:${tag}"
done

# Use buildx multi-arch builder and push to registry
# Note: requires docker buildx and a logged-in registry.
docker buildx build \
  --platform "${PLATFORMS}" \
  --push \
  ${tag_args} \
  .
