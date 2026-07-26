#!/usr/bin/env bash

# Read-only host inspection helpers.

aob_os_id() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    printf '%s' "${ID:-unknown}"
  elif [[ -n "${TERMUX_VERSION:-}" ]]; then
    printf 'termux'
  else
    printf 'unknown'
  fi
}

aob_os_version() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    printf '%s' "${VERSION_ID:-unknown}"
  else
    printf 'unknown'
  fi
}

aob_arch() {
  uname -m
}

aob_cpu_count() {
  if aob_command_exists nproc; then
    nproc
  else
    getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1\n'
  fi
}

aob_mem_total_mib() {
  awk '/^MemTotal:/ {printf "%d\n", $2 / 1024}' /proc/meminfo 2>/dev/null || printf '0\n'
}

aob_swap_total_mib() {
  awk '/^SwapTotal:/ {printf "%d\n", $2 / 1024}' /proc/meminfo 2>/dev/null || printf '0\n'
}

aob_disk_available_gib() {
  local path="$1" existing="$path"
  while [[ ! -e "$existing" && "$existing" != '/' ]]; do
    existing="${existing%/*}"
    [[ -n "$existing" ]] || existing='/'
  done
  df -Pk "$existing" | awk 'NR==2 {printf "%d\n", $4 / 1024 / 1024}'
}
