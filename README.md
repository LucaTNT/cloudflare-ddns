# cloudflare-ddns (Alpine)

Simple Alpine-based container that updates a Cloudflare DNS record at a fixed interval to the current public IP.

**NOTE:** This is the result of experimenting with [ChatGPT Codex](https://chatgpt.com/codex), beware of AI slop!

## Environment variables
Required:
- `CF_API_TOKEN`: Cloudflare API token with DNS edit permissions
- `CF_RECORD_NAME`: Full record name (e.g. `home.example.com`)

Optional:
- `INTERVAL_SECONDS`: update interval in seconds (default: `300`)
- `IP_PROVIDER_URL`: URL returning your public IP (default: `https://api.ipify.org`)
- `HEALTHCHECKS_IO_URL`: healthchecks.io URL (optional). When set, the container pings `/start` at run start, then sends a single timestamp-prefixed log payload to `/` on success or `/fail` on failure.

## Build

```
docker build -t cloudflare-ddns .
```

## Build + Push (multi-arch)

```
IMAGE_NAME=ghcr.io/you/cloudflare-ddns ./build-image.sh latest 1.2.3
```

## Run

Pull the prebuilt image from GitHub Container Registry:

```bash
docker pull ghcr.io/lucatnt/cloudflare-ddns:latest
```

Then run it:

```
docker run --rm \
  -e CF_API_TOKEN=... \
  -e CF_RECORD_NAME=home.example.com \
  -e INTERVAL_SECONDS=300 \
  ghcr.io/lucatnt/cloudflare-ddns:latest
```

## Docker Compose example

```yaml
services:
  cloudflare-ddns:
    image: ghcr.io/lucatnt/cloudflare-ddns:latest
    restart: unless-stopped
    environment:
      CF_API_TOKEN: "..."
      CF_RECORD_NAME: "home.example.com"
      INTERVAL_SECONDS: "300"
      HEALTHCHECKS_IO_URL: "https://hc-ping.com/your-uuid"
```
