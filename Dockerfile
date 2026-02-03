FROM alpine:3.20

RUN apk add --no-cache curl jq ca-certificates

WORKDIR /app

COPY scripts/ /app/scripts/

RUN chmod +x /app/scripts/*.sh

HEALTHCHECK --interval=1m --timeout=5s --start-period=10s CMD ["/app/scripts/healthcheck.sh"]

ENV INTERVAL_SECONDS=300 \
    IP_PROVIDER_URL=https://api.ipify.org

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
