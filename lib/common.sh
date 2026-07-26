#!/usr/bin/env bash
# shellcheck disable=SC2034

# Shared output, validation, and path helpers.

AOB_EXIT_OPERATIONAL=1
AOB_EXIT_USAGE=2
AOB_EXIT_PREREQUISITE=3
AOB_EXIT_NETWORK=4

_aob_color_enabled() {
  [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]
}

_aob_color() {
  local code="$1"
  if _aob_color_enabled; then
    printf '\033[%sm' "$code"
  fi
}

_aob_reset() {
  if _aob_color_enabled; then
    printf '\033[0m'
  fi
}

aob_info() {
  _aob_color '36'; printf 'INFO '; _aob_reset
  printf '%s\n' "$*"
}

aob_ok() {
  _aob_color '32'; printf 'PASS '; _aob_reset
  printf '%s\n' "$*"
}

aob_warn() {
  _aob_color '33'; printf 'WARN '; _aob_reset
  printf '%s\n' "$*" >&2
}

aob_error() {
  _aob_color '31'; printf 'FAIL '; _aob_reset
  printf '%s\n' "$*" >&2
}

aob_die() {
  local exit_code="$1"
  shift
  aob_error "$*"
  exit "$exit_code"
}

aob_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

aob_require_file() {
  local path="$1"
  [[ -f "$path" ]] || aob_die "$AOB_EXIT_PREREQUISITE" "Required file not found: $path"
}

aob_ensure_dir() {
  local path="$1"
  mkdir -p -- "$path" || aob_die "$AOB_EXIT_OPERATIONAL" "Cannot create directory: $path"
}

aob_ensure_runtime_dirs() {
  local path
  for path in \
    "$AOB_DATA_DIR" \
    "$AOB_CACHE_DIR" \
    "$AOB_CONFIG_DIR" \
    "$AOB_WORK_DIR" \
    "$AOB_LOG_DIR" \
    "$AOB_OUTPUT_DIR" \
    "$AOB_DOWNLOAD_DIR"; do
    aob_ensure_dir "$path"
  done
}

aob_builder_dir() {
  printf '%s/builders/%s\n' "$AOB_ROOT" "$1"
}

aob_builder_exists() {
  [[ -f "$(aob_builder_dir "$1")/builder.sh" ]]
}

aob_list_builders() {
  local builder_file builder_dir builder_name
  shopt -s nullglob
  for builder_file in "$AOB_ROOT"/builders/*/builder.sh; do
    builder_dir="${builder_file%/builder.sh}"
    builder_name="${builder_dir##*/}"
    printf '%s\n' "$builder_name"
  done
  shopt -u nullglob
}

aob_print_paths() {
  cat <<EOF_PATHS
Project root : $AOB_ROOT
Config dir   : $AOB_CONFIG_DIR
Data dir     : $AOB_DATA_DIR
Cache dir    : $AOB_CACHE_DIR
Work dir     : $AOB_WORK_DIR
Log dir      : $AOB_LOG_DIR
Output dir   : $AOB_OUTPUT_DIR
Downloads    : $AOB_DOWNLOAD_DIR
Android SDK  : $AOB_ANDROID_SDK_ROOT
EOF_PATHS
}
