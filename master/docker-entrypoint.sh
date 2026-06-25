#!/usr/bin/env bash
set -euo pipefail

CONF_ROOT="/opt/ip_sentinel_master"
MASTER_DIR="${MASTER_DIR:-$CONF_ROOT}"
DB_FILE="${DB_FILE:-${MASTER_DIR}/sentinel.db}"
CONF_FILE="${CONF_ROOT}/master.conf"
RUNTIME_MASTER="${MASTER_DIR}/tg_master.sh"

mkdir -p "$CONF_ROOT"
mkdir -p "$MASTER_DIR"

if [ ! -f "$CONF_FILE" ]; then
    if [ -z "${TG_TOKEN:-}" ]; then
        echo "ERROR: TG_TOKEN is required on first container start." >&2
        echo "Example: docker run -e TG_TOKEN=123:abc -v ip-sentinel-master:/opt/ip_sentinel_master ip-sentinel-master" >&2
        exit 1
    fi

    if [ -z "${MASTER_NODE_NAME:-}" ]; then
        MASTER_NODE_NAME="$(hostname | tr -cd 'a-zA-Z0-9' | cut -c 1-10)-MASTER"
    fi

    cat > "$CONF_FILE" <<EOF
# IP-Sentinel Master container config
MASTER_VERSION="${MASTER_VERSION:-4.3.1}"
MASTER_NODE_NAME="${MASTER_NODE_NAME}"
TG_TOKEN="${TG_TOKEN}"
DB_FILE="${DB_FILE}"
MASTER_DIR="${MASTER_DIR}"
IS_OFFICIAL_GATEWAY="${IS_OFFICIAL_GATEWAY:-false}"
ENABLE_MASTER_OTA="${ENABLE_MASTER_OTA:-false}"
EOF
    chmod 600 "$CONF_FILE"
elif [ "${UPDATE_CONFIG_FROM_ENV:-false}" = "true" ]; then
    REQUESTED_MASTER_VERSION="${MASTER_VERSION:-}"
    REQUESTED_MASTER_NODE_NAME="${MASTER_NODE_NAME:-}"
    REQUESTED_TG_TOKEN="${TG_TOKEN:-}"
    REQUESTED_IS_OFFICIAL_GATEWAY="${IS_OFFICIAL_GATEWAY:-}"
    REQUESTED_ENABLE_MASTER_OTA="${ENABLE_MASTER_OTA:-}"

    # shellcheck disable=SC1090
    source "$CONF_FILE"
    SAVED_MASTER_VERSION="${MASTER_VERSION:-4.3.1}"
    SAVED_MASTER_NODE_NAME="${MASTER_NODE_NAME:-IP-Sentinel-Master}"
    SAVED_TG_TOKEN="${TG_TOKEN:-}"
    SAVED_IS_OFFICIAL_GATEWAY="${IS_OFFICIAL_GATEWAY:-false}"
    SAVED_ENABLE_MASTER_OTA="${ENABLE_MASTER_OTA:-false}"

    tmp_conf="$(mktemp)"
    awk -F= '
        $1 == "MASTER_VERSION" || $1 == "MASTER_NODE_NAME" || $1 == "TG_TOKEN" ||
        $1 == "DB_FILE" || $1 == "MASTER_DIR" || $1 == "IS_OFFICIAL_GATEWAY" ||
        $1 == "ENABLE_MASTER_OTA" { next }
        { print }
    ' "$CONF_FILE" > "$tmp_conf"
    {
        cat "$tmp_conf"
        printf 'MASTER_VERSION="%s"\n' "${REQUESTED_MASTER_VERSION:-$SAVED_MASTER_VERSION}"
        printf 'MASTER_NODE_NAME="%s"\n' "${REQUESTED_MASTER_NODE_NAME:-$SAVED_MASTER_NODE_NAME}"
        printf 'TG_TOKEN="%s"\n' "${REQUESTED_TG_TOKEN:-$SAVED_TG_TOKEN}"
        printf 'DB_FILE="%s"\n' "$DB_FILE"
        printf 'MASTER_DIR="%s"\n' "$MASTER_DIR"
        printf 'IS_OFFICIAL_GATEWAY="%s"\n' "${REQUESTED_IS_OFFICIAL_GATEWAY:-$SAVED_IS_OFFICIAL_GATEWAY}"
        printf 'ENABLE_MASTER_OTA="%s"\n' "${REQUESTED_ENABLE_MASTER_OTA:-$SAVED_ENABLE_MASTER_OTA}"
    } > "$CONF_FILE"
    rm -f "$tmp_conf"
    chmod 600 "$CONF_FILE"
fi

sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS nodes (
    chat_id TEXT,
    node_name TEXT,
    agent_ip TEXT,
    agent_port TEXT,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    region TEXT DEFAULT 'UNKNOWN',
    node_alias TEXT,
    enable_google TEXT DEFAULT 'true',
    enable_trust TEXT DEFAULT 'true',
    enable_ota TEXT DEFAULT 'false',
    PRIMARY KEY(chat_id, node_name)
);

CREATE TABLE IF NOT EXISTS ip_trend_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_name TEXT,
    check_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    scam_score INTEGER,
    goog_status TEXT,
    nf_status TEXT,
    gpt_status TEXT
);

PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
SQL

chmod 600 "$DB_FILE"
cp /usr/local/lib/ip-sentinel/tg_master.sh "$RUNTIME_MASTER"
chmod +x "$RUNTIME_MASTER"

echo "IP-Sentinel Master container starting with state at ${MASTER_DIR}"
if [ "${IP_SENTINEL_INIT_ONLY:-false}" = "true" ]; then
    echo "IP_SENTINEL_INIT_ONLY=true, initialization complete."
    exit 0
fi

exec /bin/bash "$RUNTIME_MASTER"
