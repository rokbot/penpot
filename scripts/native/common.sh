#!/usr/bin/env bash
# Shared configuration for the native (no Docker) Penpot stack.
# Sourced by the other scripts in this directory; do not run directly.
#
# Everything machine-specific lives outside the repository:
#   $PENPOT_NATIVE_HOME (default ~/.local/share/penpot-native)
#     pgdata/  valkey/  nginx/  logs/  run/  runtime.env

set -euo pipefail

_NATIVE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$_NATIVE_DIR/../.." && pwd)

BASE=${PENPOT_NATIVE_HOME:-$HOME/.local/share/penpot-native}
PGDATA="$BASE/pgdata"
RUN_DIR="$BASE/run"
LOG_DIR="$BASE/logs"
VALKEY_DIR="$BASE/valkey"
NGINX_DIR="$BASE/nginx"
RUNTIME_ENV="$BASE/runtime.env"

APP_PORT=${PENPOT_APP_PORT:-3449}
PUBLIC_URI=${PENPOT_PUBLIC_URI:-http://localhost:$APP_PORT}

BACKEND_PORT=6060
SHADOW_PORT=3448
NGINX_PORT=$APP_PORT

PG_HOST=127.0.0.1
PG_PORT=${PENPOT_PG_PORT:-5432}
PG_DB=penpot
PG_TEST_DB=penpot_test
PG_USER=penpot
PG_PASSWORD=penpot

VALKEY_PORT=${PENPOT_VALKEY_PORT:-6379}

# shellcheck disable=SC1090
if [ -f "$RUNTIME_ENV" ]; then
    . "$RUNTIME_ENV"
fi
if [ -n "${NODE_BIN:-}" ]; then
    case ":$PATH:" in
        *":$NODE_BIN:"*) ;;
        *) export PATH="$NODE_BIN:$PATH" ;;
    esac
fi
if [ -n "${JAVA_HOME:-}" ]; then
    export JAVA_HOME
    case ":$PATH:" in
        *":$JAVA_HOME/bin:"*) ;;
        *) export PATH="$JAVA_HOME/bin:$PATH" ;;
    esac
fi
export SHADOW_SERVER_URL=${SHADOW_SERVER_URL:-ws://localhost:$APP_PORT}

mkdir -p "$RUN_DIR" "$LOG_DIR" "$VALKEY_DIR" "$NGINX_DIR"

have() { command -v "$1" >/dev/null 2>&1; }

pid_running() {
    [ -n "${1:-}" ] && [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null
}

java_major() {
    local home=${1:-${JAVA_HOME:-}}
    local bin=java
    [ -n "$home" ] && bin="$home/bin/java"
    "$bin" -version 2>&1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p' | head -1
}

# Write the nginx config for this checkout (repo paths are absolute).
render_nginx_conf() {
    local template="$REPO/scripts/native/nginx.conf.in"
    local target="$NGINX_DIR/nginx.conf"
    sed -e "s|@REPO@|$REPO|g" \
        -e "s|@BASE@|$BASE|g" \
        -e "s|@PORT@|$NGINX_PORT|g" \
        "$template" > "$target.tmp"
    mv "$target.tmp" "$target"
}
