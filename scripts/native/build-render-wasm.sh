#!/usr/bin/env bash
# Build the frontend render-wasm bundle with a user-local Emscripten SDK.
#
# render-wasm/build hardcodes /opt/emsdk, so this wrapper activates EMSDK
# first and then calls the regular build environment.
#
#   scripts/native/build-render-wasm.sh

set -e -o pipefail

. "$(dirname "$0")/common.sh"

EMSDK=${EMSDK:-$HOME/emsdk}
[ -f "$EMSDK/emsdk_env.sh" ] || {
    echo "error: Emscripten not found at $EMSDK (run scripts/native/setup.sh)" >&2
    exit 1
}
# shellcheck disable=SC1091
EMSDK_QUIET=1 . "$EMSDK/emsdk_env.sh"

cd "$REPO/render-wasm"

export RENDER_TARGET=frontend
# shellcheck disable=SC1091
. ./_build_env frontend "$@"
# shellcheck disable=SC1091
. ./_build_lock

acquire_build_lock

set -x
setup
build
copy_target_artifacts
