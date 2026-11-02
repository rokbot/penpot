#!/usr/bin/env bash
# Stop the native Penpot stack. Data is preserved.
#
#   scripts/native/stop.sh          # app processes + nginx
#   scripts/native/stop.sh --all    # also PostgreSQL and Valkey

set -euo pipefail

. "$(dirname "$0")/common.sh"

stop_pidfile() {
    local name=$1
    local pidfile="$RUN_DIR/$name.pid"
    pid_running "$pidfile" || { rm -f "$pidfile"; return; }
    local pid
    pid=$(cat "$pidfile")
    echo "$name: stopping (pid $pid)"
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
    rm -f "$pidfile"
}

stop_pidfile shadow
stop_pidfile assets
stop_pidfile libs
stop_pidfile backend

if pid_running "$NGINX_DIR/nginx.pid"; then
    echo "nginx: stopping"
    nginx -p "$NGINX_DIR" -c "$NGINX_DIR/nginx.conf" -s stop 2>/dev/null || true
fi

if [ "${1:-}" = "--all" ]; then
    if pg_isready -h "$PG_HOST" -p "$PG_PORT" -q 2>/dev/null; then
        echo "postgres: stopping"
        pg_ctl -D "$PGDATA" stop -m fast
    fi
    if redis-cli -h 127.0.0.1 -p "$VALKEY_PORT" ping >/dev/null 2>&1; then
        echo "valkey: stopping"
        redis-cli -h 127.0.0.1 -p "$VALKEY_PORT" shutdown nosave || true
    fi
fi

echo "stopped"
