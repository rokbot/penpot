#!/usr/bin/env bash
# Start the native (no Docker) Penpot stack.
#
#   scripts/native/start.sh
#
# Idempotent: services that already answer are left alone. Run
# scripts/native/setup.sh first on a fresh checkout.
#
# Components: PostgreSQL, Valkey, backend (:6060), shadow-cljs watchers,
# nginx (http://localhost:3449).

set -euo pipefail

. "$(dirname "$0")/common.sh"

[ -f "$RUNTIME_ENV" ] || {
    echo "error: run scripts/native/setup.sh first" >&2
    exit 1
}

PG_OPTS="-p $PG_PORT -k ${TMPDIR:-/tmp} -c listen_addresses=127.0.0.1 -c max_connections=160 -c shared_buffers=256MB"

start_pg() {
    if pg_isready -h "$PG_HOST" -p "$PG_PORT" -q 2>/dev/null; then
        echo "postgres: already running"
    else
        echo "postgres: starting"
        pg_ctl -D "$PGDATA" -l "$LOG_DIR/postgres.log" -o "$PG_OPTS" start
    fi
}

start_valkey() {
    if redis-cli -h 127.0.0.1 -p "$VALKEY_PORT" ping >/dev/null 2>&1; then
        echo "valkey: already running"
    else
        echo "valkey: starting"
        redis-server --port "$VALKEY_PORT" --bind 127.0.0.1 \
            --save '' --appendonly no --dir "$VALKEY_DIR" \
            --logfile "$LOG_DIR/valkey.log" --daemonize yes
    fi
}

start_backend() {
    if curl -sf -o /dev/null "http://127.0.0.1:$BACKEND_PORT/readyz" 2>/dev/null; then
        echo "backend: already running"
        # Adopt a backend started outside this script so `just down` can stop it.
        if [ ! -f "$RUN_DIR/backend.pid" ]; then
            local pid
            pid=$(ss -ltnp "sport = :$BACKEND_PORT" 2>/dev/null \
                | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' | head -1)
            if [ -n "$pid" ]; then echo "$pid" > "$RUN_DIR/backend.pid"; fi
        fi
    else
        echo "backend: starting (log: $LOG_DIR/backend.log)"
        (cd "$REPO/backend" && nohup ./scripts/start-dev \
            > "$LOG_DIR/backend.log" 2>&1 & echo $! > "$RUN_DIR/backend.pid")
    fi
}

start_nginx() {
    local conf="$NGINX_DIR/nginx.conf"
    if pid_running "$NGINX_DIR/nginx.pid"; then
        echo "nginx: already running"
    else
        [ -f "$conf" ] || render_nginx_conf
        echo "nginx: starting on $PUBLIC_URI"
        nginx -p "$NGINX_DIR" -c "$conf"
    fi
}

start_wasm_once() {
    if [ -f "$REPO/frontend/resources/public/js/render-wasm.wasm" ]; then
        echo "render-wasm: already built"
    elif [ "${PENPOT_NATIVE_SKIP_WASM:-0}" = 1 ]; then
        echo "render-wasm: skipped (PENPOT_NATIVE_SKIP_WASM=1)"
    else
        echo "render-wasm: building (one time)"
        "$REPO/scripts/native/build-render-wasm.sh"
    fi
}

start_watcher() {
    local name=$1; shift
    local pidfile="$RUN_DIR/$name.pid"
    if pid_running "$pidfile"; then
        echo "$name: already running"
        return
    fi
    echo "$name: starting (log: $LOG_DIR/$name.log)"
    (cd "$REPO/frontend" && nohup "$@" > "$LOG_DIR/$name.log" 2>&1 & echo $! > "$pidfile")
}

start_pg
start_valkey
start_backend
start_wasm_once
start_nginx
start_watcher shadow clojure -M:dev:shadow-cljs watch main worker
start_watcher assets pnpm run watch:app:assets

# The libs bundle needs target/index.js, which shadow-cljs writes during its
# first compile. Wait for it (bounded) instead of racing esbuild.
for _ in $(seq 1 150); do
    [ -f "$REPO/frontend/target/index.js" ] && break
    sleep 2
done
if [ ! -f "$REPO/frontend/target/index.js" ]; then
    echo "warning: target/index.js not found after 5 minutes; start libs manually" >&2
else
    start_watcher libs pnpm run watch:app:libs
fi

cat <<EOF

Penpot is starting.
  App:  $PUBLIC_URI
  Logs: $LOG_DIR
Open the app once the backend answers on /readyz and shadow-cljs finishes its
first compile.
EOF
