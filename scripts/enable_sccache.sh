#!/usr/bin/env bash
# Shared sccache bootstrap for build scripts.

enable_sccache() {
  if ! command -v sccache >/dev/null 2>&1; then
    return 0
  fi

  export SCCACHE_IDLE_TIMEOUT="${SCCACHE_IDLE_TIMEOUT:-0}"
  export SCCACHE_DIR="${SCCACHE_DIR:-$HOME/.cache/sccache}"

  if command -v clang >/dev/null 2>&1; then
    export CC="sccache clang"
  fi
  if command -v clang++ >/dev/null 2>&1; then
    export CXX="sccache clang++"
  fi
  if command -v rustc >/dev/null 2>&1; then
    export RUSTC_WRAPPER="sccache"
  fi

  sccache --start-server >/dev/null 2>&1 || true
  echo "⚡ sccache enabled"
}
