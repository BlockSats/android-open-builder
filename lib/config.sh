#!/usr/bin/env bash

# Configuration loader with environment-variable precedence and a restricted
# parser for user-controlled configuration files.

AOB_CONFIG_KEYS=(
  AOB_PROJECT_VERSION
  AOB_DEFAULT_BUILDER
  AOB_DATA_DIR
  AOB_CACHE_DIR
  AOB_CONFIG_DIR
  AOB_WORK_DIR
  AOB_LOG_DIR
  AOB_OUTPUT_DIR
  AOB_DOWNLOAD_DIR
  AOB_ANDROID_SDK_ROOT
  AOB_MIN_DISK_GIB
  AOB_MIN_RAM_MIB
  AOB_MIN_SWAP_MIB
  AOB_BUILD_JOBS
)

_aob_key_is_allowed() {
  local candidate="$1" key
  for key in "${AOB_CONFIG_KEYS[@]}"; do
    [[ "$key" == "$candidate" ]] && return 0
  done
  return 1
}

_aob_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

_aob_unquote() {
  local value="$1"
  if [[ ${#value} -ge 2 ]]; then
    if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  value="${value/#\~/$HOME}"
  value="${value//\$HOME/$HOME}"
  value="${value//\$\{HOME\}/$HOME}"
  printf '%s' "$value"
}

_aob_load_user_config() {
  local file="$1" raw line key value line_number=0
  [[ -f "$file" ]] || return 0

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    ((line_number += 1))
    line="$(_aob_trim "$raw")"
    [[ -z "$line" || "${line:0:1}" == '#' ]] && continue

    if [[ "$line" =~ ^([A-Z][A-Z0-9_]*)[[:space:]]*=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="$(_aob_trim "${BASH_REMATCH[2]}")"
    else
      aob_die "$AOB_EXIT_USAGE" "Invalid configuration line $line_number in $file"
    fi

    _aob_key_is_allowed "$key" || \
      aob_die "$AOB_EXIT_USAGE" "Unsupported configuration key '$key' in $file"

    value="$(_aob_unquote "$value")"
    printf -v "$key" '%s' "$value"
  done < "$file"
}

aob_load_config() {
  local defaults_file="$AOB_ROOT/config/defaults.conf"
  local key
  declare -A env_overrides=()

  for key in "${AOB_CONFIG_KEYS[@]}"; do
    if [[ -v "$key" ]]; then
      env_overrides["$key"]="${!key}"
    fi
  done

  aob_require_file "$defaults_file"
  # shellcheck source=../config/defaults.conf disable=SC1091
  source "$defaults_file"

  local user_config="${AOB_CONFIG:-${AOB_CONFIG_DIR}/config.conf}"
  _aob_load_user_config "$user_config"

  for key in "${!env_overrides[@]}"; do
    printf -v "$key" '%s' "${env_overrides[$key]}"
  done

  export AOB_PROJECT_VERSION AOB_DEFAULT_BUILDER
  export AOB_DATA_DIR AOB_CACHE_DIR AOB_CONFIG_DIR
  export AOB_WORK_DIR AOB_LOG_DIR AOB_OUTPUT_DIR AOB_DOWNLOAD_DIR
  export AOB_ANDROID_SDK_ROOT AOB_MIN_DISK_GIB AOB_MIN_RAM_MIB
  export AOB_MIN_SWAP_MIB AOB_BUILD_JOBS
}
