#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"
export AOB_DATA_DIR="$TEST_HOME/data"
export AOB_CACHE_DIR="$TEST_HOME/cache"
export AOB_CONFIG_DIR="$TEST_HOME/config"

"$ROOT/aob" version | grep -F 'Android Open Builder 0.1.0-dev' >/dev/null
"$ROOT/aob" help | grep -F 'doctor' >/dev/null
"$ROOT/aob" list | grep -F 'retroarch' >/dev/null
"$ROOT/aob" info retroarch | grep -F 'status=scaffold' >/dev/null
"$ROOT/aob" paths | grep -F "$TEST_HOME/data" >/dev/null

if "$ROOT/aob" unknown-command >/dev/null 2>&1; then
  printf 'unknown command unexpectedly succeeded\n' >&2
  exit 1
fi

printf 'test_cli: PASS\n'
