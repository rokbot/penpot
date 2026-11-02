# Native Penpot stack (no Docker)

Runs Penpot from this checkout with services installed on the host:

| Service | Address | Notes |
|---|---|---|
| PostgreSQL | `127.0.0.1:5432` | private cluster under `~/.local/share/penpot-native/pgdata` |
| Valkey/Redis | `127.0.0.1:6379` | |
| Backend | `127.0.0.1:6060` | `backend/scripts/start-dev` |
| shadow-cljs | `127.0.0.1:3448` | compiles `main` + `worker` into `frontend/resources/public/js` |
| nginx | `http://localhost:3449` | serves the frontend and proxies the API |

Everything machine-specific is generated, not committed:
`backend/scripts/_env.local`, `frontend/resources/public/js/config.js`,
`~/.local/share/penpot-native/` (data, logs, nginx config, PIDs).

## Requirements

### User-level tools: mise

The repository's `mise.toml` pins Node 24.22.2, pnpm 12.16.1, Temurin JDK 27,
Clojure CLI 1.12.5.1664 and just 1.58.0.

Install mise:

```bash
curl https://mise.run | sh                 # or: brew install mise
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
# zsh: ~/.zshrc    fish: mise activate fish | source
```

Then, from the repository root:

```bash
mise trust      # trust this repository's mise.toml
mise install    # Node, pnpm, JDK 27, Clojure CLI, just
```

Without shell activation, prefix commands with mise:
`mise exec -- just up`. `just` is one of the pinned tools; to install only it,
run `mise install just`, or use `brew install just`, `cargo install just`, or a
release binary from <https://github.com/casey/just>.

### System packages

mise does not manage daemons. Install these with the OS package manager:

```bash
# Debian/Ubuntu; use valkey-server instead of redis-server where packaged
sudo apt install postgresql redis-server nginx curl git
```

- PostgreSQL 14+ (`psql`, `initdb`, `pg_ctl`)
- Valkey or Redis (`redis-server`, `redis-cli`)
- nginx

### Rust (WASM build only)

`render-wasm/build` calls `rustup` directly, so install Rust with rustup rather
than mise:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32-unknown-emscripten
```

Emscripten 4.0.6 is installed by `setup.sh` into `~/emsdk` if missing.

## First run on a fresh clone

```bash
mise install    # user-level tools from mise.toml
just setup      # writes local configs, creates DB/role, installs deps, builds WASM
just up         # start everything
```

`just up` runs `setup` first, so on a new machine the two can be one step. The
first run is slow: Emscripten (~700 MB download), the WASM build, `pnpm
install`, and the first shadow-cljs compile (2-5 minutes).

Open <http://localhost:3449>.

## Accounts and renderer

The database is private to this setup, so no account exists on a fresh clone.
Either:

- register from the UI (email verification is skipped locally), or
- `just user you@example.com yourpassword "Your Name"` (backend must be running).

The machine where this was developed has `test@example.com` / `123123`.

The editor uses the SVG renderer by default. To use the WASM renderer, append
`?wasm=true` to the workspace URL, or save `:renderer :wasm` in the profile
properties. The WASM bundle (`render-wasm.js` + `render-wasm.wasm`) is built by
`just setup` / `just wasm`.

## Commands

```bash
just up                 # start (runs setup)
just down               # stop app + nginx, keep data
just down-all           # also stop PostgreSQL and Valkey
just restart
just status
just logs backend       # or postgres, valkey, shadow, assets, libs
just user EMAIL [PASS] [NAME]
just psql
just wasm               # rebuild the WASM renderer
```

## What a fresh clone needs

Tracked and sufficient: `justfile`, `mise.toml`, `scripts/native/*`, and the
normal Penpot sources. `setup.sh` generates the rest. Host packages and Rust
are the only manual steps; they need root or a separate installer, so they are
checked, not installed.

## Not included

Exporter (PNG/SVG/PDF export; `/api/export` targets `127.0.0.1:6061`), MCP
server, SMTP, LDAP, Storybook. Editor, dashboard, login, saving and the WASM
canvas work without them.
