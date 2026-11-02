# Native (no Docker) Penpot development stack for this machine.
#
# Usage, from the repository root:
#     mise install    # toolchain from mise.toml (Node, pnpm, JDK, Clojure, just)
#     just setup      # one-time (or after a clean checkout): config, DB, deps, WASM
#     just up         # start everything
#     just status
#     just logs backend
#     just down
#
# The scripts live in scripts/native/ and keep all machine state outside the
# repo, under ~/.local/share/penpot-native. See scripts/native/README.md for
# prerequisites and how a fresh clone is handled.
#
# This file is not part of upstream Penpot.

default:
    @just --list

# Prepare the checkout: configs, database, frontend deps, WASM renderer.
setup:
    scripts/native/setup.sh

# Start the full stack (runs setup first; idempotent).
up: setup
    scripts/native/start.sh

# Stop the app (backend, watchers, nginx); data is kept.
down:
    scripts/native/stop.sh

# Stop everything, including PostgreSQL and Valkey.
down-all:
    scripts/native/stop.sh --all

# Restart the app processes.
restart: down
    scripts/native/start.sh

# Rebuild the WASM renderer (Emscripten + Rust).
wasm:
    scripts/native/build-render-wasm.sh

# Create a profile: just user you@example.com [password] [fullname]
user email password="123123" fullname="Test User":
    scripts/native/create-profile.py "{{email}}" "{{password}}" "{{fullname}}"

# Open a psql shell on the local database.
psql:
    PGPASSWORD=penpot psql -h 127.0.0.1 -U penpot -d penpot

# Show the state of every service.
status:
    #!/usr/bin/env bash
    set -u
    base="$HOME/.local/share/penpot-native"
    probe() { printf '%-10s %s\n' "$1" "$2"; }
    if curl -sf -o /dev/null http://127.0.0.1:6060/readyz; then
        probe backend up; else probe backend DOWN; fi
    if pg_isready -h 127.0.0.1 -p 5432 -q 2>/dev/null; then
        probe postgres up; else probe postgres DOWN; fi
    if redis-cli -h 127.0.0.1 -p 6379 ping >/dev/null 2>&1; then
        probe valkey up; else probe valkey DOWN; fi
    if curl -sf -o /dev/null http://localhost:3449/; then
        probe nginx up; else probe nginx DOWN; fi
    for name in shadow assets libs; do
        pidfile="$base/run/$name.pid"
        if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
            probe "$name" "up (pid $(cat "$pidfile"))"
        else
            probe "$name" DOWN
        fi
    done
    echo "App: http://localhost:3449"

# Follow a service log: just logs backend|postgres|valkey|shadow|assets|libs
logs service="backend":
    tail -f "$HOME/.local/share/penpot-native/logs/{{service}}.log"
