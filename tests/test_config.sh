#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT
mkdir -p "$TEST_HOME/.config/android-open-builder"

cat > "$TEST_HOME/.config/android-open-builder/config.conf" <<'EOF_CONFIG'
AOB_BUILD_JOBS=3
AOB_DATA_DIR=~/custom-data
EOF_CONFIG

result="$(HOME="$TEST_HOME" "$ROOT/aob" paths)"
grep -F "$TEST_HOME/custom-data" <<<"$result" >/dev/null

version="$(HOME="$TEST_HOME" AOB_BUILD_JOBS=7 bash -c '
  set -Eeuo pipefail
  export AOB_ROOT="$1"
  source "$1/lib/common.sh"
  source "$1/lib/config.sh"
  aob_load_config
  printf "%s" "$AOB_BUILD_JOBS"
' _ "$ROOT")"
[[ "$version" == '7' ]]

cat > "$TEST_HOME/bad.conf" <<'EOF_BAD'
UNSUPPORTED_KEY=value
EOF_BAD
if HOME="$TEST_HOME" AOB_CONFIG="$TEST_HOME/bad.conf" "$ROOT/aob" version >/dev/null 2>&1; then
  printf 'unsupported config key unexpectedly succeeded\n' >&2
  exit 1
fi

printf 'test_config: PASS\n'
