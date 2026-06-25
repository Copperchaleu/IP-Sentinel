FROM debian:bookworm-slim

ARG MASTER_VERSION=4.3.1

LABEL org.opencontainers.image.title="IP-Sentinel Master"
LABEL org.opencontainers.image.description="Containerized IP-Sentinel Master command center"
LABEL org.opencontainers.image.source="https://github.com/hotyue/IP-Sentinel"

ENV MASTER_VERSION="${MASTER_VERSION}" \
    MASTER_DIR="/opt/ip_sentinel_master" \
    DB_FILE="/opt/ip_sentinel_master/sentinel.db" \
    IS_OFFICIAL_GATEWAY="false" \
    ENABLE_MASTER_OTA="false"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        jq \
        openssl \
        procps \
        sqlite3 \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY master/tg_master.sh /usr/local/lib/ip-sentinel/tg_master.sh
COPY master/docker-entrypoint.sh /usr/local/bin/ip-sentinel-master-entrypoint

RUN chmod +x /usr/local/lib/ip-sentinel/tg_master.sh /usr/local/bin/ip-sentinel-master-entrypoint \
    && mkdir -p /opt/ip_sentinel_master

VOLUME ["/opt/ip_sentinel_master"]

ENTRYPOINT ["/usr/local/bin/ip-sentinel-master-entrypoint"]
