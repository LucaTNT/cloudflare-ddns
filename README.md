# cloudflare-ddns (Alpine)

Simple Alpine-based container that updates a Cloudflare DNS record at a fixed interval.

## Environment variables
Required:
- `CF_API_TOKEN`: Cloudflare API token with DNS edit permissions
- `CF_RECORD_NAME`: Full record name (e.g. `home.example.com`)

Optional:
- `INTERVAL_SECONDS`: update interval in seconds (default: `300`)
- `IP_PROVIDER_URL`: URL returning your public IP (default: `https://api.ipify.org`)
- `HEALTHCHECKS_IO_URL`: healthchecks.io URL (optional). When set, the container pings `/start`, `/` on success, and `/fail` on failures.

## Build

```
docker build -t cloudflare-ddns .
```

## Run

```
docker run --rm \
  -e CF_API_TOKEN=... \
  -e CF_RECORD_NAME=home.example.com \
  -e INTERVAL_SECONDS=300 \
  cloudflare-ddns
```

## Docker Compose example

```yaml
services:
  cloudflare-ddns:
    image: cloudflare-ddns
    build: .
    restart: unless-stopped
    environment:
      CF_API_TOKEN: "..."
      CF_RECORD_NAME: "home.example.com"
      INTERVAL_SECONDS: "300"
      HEALTHCHECKS_IO_URL: "https://hc-ping.com/your-uuid"
```
