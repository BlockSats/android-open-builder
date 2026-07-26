#!/usr/bin/env bash
set -Eeuo pipefail

AOB_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/common.sh disable=SC1091
source "$AOB_ROOT/lib/common.sh"
# shellcheck source=../lib/config.sh disable=SC1091
source "$AOB_ROOT/lib/config.sh"
# shellcheck source=../lib/platform.sh disable=SC1091
source "$AOB_ROOT/lib/platform.sh"
aob_load_config

passes=0
warnings=0
failures=0

pass() { ((passes += 1)); aob_ok "$*"; }
warn() { ((warnings += 1)); aob_warn "$*"; }
fail() { ((failures += 1)); aob_error "$*"; }

check_command() {
  local command_name="$1" label="${2:-$1}"
  if aob_command_exists "$command_name"; then
    pass "$label: $(command -v "$command_name")"
  else
    fail "$label is missing"
  fi
}

check_optional_command() {
  local command_name="$1" label="${2:-$1}"
  if aob_command_exists "$command_name"; then
    pass "$label: $(command -v "$command_name")"
  else
    warn "$label is not installed"
  fi
}

show_help() {
  cat <<'EOF_HELP'
Usage: ./aob doctor [--strict]

Read-only diagnostics for the Debian build host. By default, warnings do not
cause failure. With --strict, warnings also produce a non-zero exit status.
EOF_HELP
}

strict=0
while (($#)); do
  case "$1" in
    --strict) strict=1 ;;
    -h|--help) show_help; exit 0 ;;
    *) aob_die "$AOB_EXIT_USAGE" "Unknown doctor option: $1" ;;
  esac
  shift
done

printf 'Android Open Builder doctor (%s)\n\n' "$AOB_PROJECT_VERSION"

os_id="$(aob_os_id)"
os_version="$(aob_os_version)"
arch="$(aob_arch)"

if [[ "$os_id" == 'debian' && "$os_version" == '12' ]]; then
  pass "Host OS: Debian 12"
elif [[ "$os_id" == 'termux' ]]; then
  warn "Host OS: Termux is supported as a control client, not as the primary build host"
else
  fail "Host OS: unsupported or untested ($os_id $os_version); Debian 12 is the initial target"
fi

if [[ "$arch" == 'x86_64' ]]; then
  pass "Architecture: x86_64"
elif [[ "$arch" == 'aarch64' ]]; then
  warn "Architecture: aarch64; the initial build host target is x86_64"
else
  fail "Architecture: unsupported ($arch)"
fi

cpu_count="$(aob_cpu_count)"
mem_mib="$(aob_mem_total_mib)"
swap_mib="$(aob_swap_total_mib)"
disk_gib="$(aob_disk_available_gib "$AOB_DATA_DIR")"

if ((cpu_count >= 2)); then pass "CPU threads: $cpu_count"; else warn "CPU threads: $cpu_count; builds will be slow"; fi
if ((mem_mib >= AOB_MIN_RAM_MIB)); then pass "RAM: ${mem_mib} MiB"; else warn "RAM: ${mem_mib} MiB; recommended minimum is ${AOB_MIN_RAM_MIB} MiB"; fi
if ((swap_mib >= AOB_MIN_SWAP_MIB)); then pass "Swap: ${swap_mib} MiB"; else warn "Swap: ${swap_mib} MiB; recommended minimum is ${AOB_MIN_SWAP_MIB} MiB"; fi
if ((disk_gib >= AOB_MIN_DISK_GIB)); then
  pass "Available disk: ${disk_gib} GiB near $AOB_DATA_DIR"
elif ((disk_gib >= 10)); then
  warn "Available disk: ${disk_gib} GiB; recommended minimum is ${AOB_MIN_DISK_GIB} GiB"
else
  fail "Available disk: ${disk_gib} GiB; at least 10 GiB is required"
fi

printf '\nCore tools\n'
for command_name in bash git curl wget unzip zip tar xz sha256sum jq python3 make gcc g++ cmake ninja pkg-config; do
  check_command "$command_name"
done
check_optional_command shellcheck 'ShellCheck'
check_optional_command gh 'GitHub CLI'

if aob_command_exists bash; then
  bash_major="${BASH_VERSINFO[0]}"
  if ((bash_major >= 5)); then pass "Bash version: $BASH_VERSION"; else fail "Bash 5 or newer is required (found $BASH_VERSION)"; fi
fi

printf '\nJava and Android toolchain\n'
if aob_command_exists java; then
  java_line="$(java -version 2>&1 | head -n 1)"
  if [[ "$java_line" =~ \"17([\.\"]|$) ]]; then pass "Java: $java_line"; else warn "Java 17 is expected; found $java_line"; fi
else
  fail "Java is missing"
fi

if [[ -d "$AOB_ANDROID_SDK_ROOT" ]]; then
  pass "Android SDK directory: $AOB_ANDROID_SDK_ROOT"
  if [[ -x "$AOB_ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
    pass "sdkmanager is available"
  else
    fail "sdkmanager is missing under $AOB_ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
  fi
  if [[ -d "$AOB_ANDROID_SDK_ROOT/ndk" ]] && compgen -G "$AOB_ANDROID_SDK_ROOT/ndk/*" >/dev/null; then
    pass "Android NDK installation detected"
  else
    fail "No Android NDK installation detected"
  fi
else
  fail "Android SDK directory is missing: $AOB_ANDROID_SDK_ROOT"
fi

printf '\nGitHub access\n'
if aob_command_exists gh; then
  if gh auth status -h github.com >/dev/null 2>&1; then pass "GitHub CLI authentication"; else warn "GitHub CLI is installed but not authenticated"; fi
fi
if aob_command_exists ssh; then
  if ssh -G git@github.com >/dev/null 2>&1; then pass "SSH configuration for github.com can be resolved"; else warn "SSH configuration for github.com cannot be resolved"; fi
else
  warn "OpenSSH client is not installed"
fi

printf '\nWritable paths\n'
for path in "$AOB_DATA_DIR" "$AOB_CACHE_DIR" "$AOB_CONFIG_DIR"; do
  parent="$path"
  while [[ ! -e "$parent" && "$parent" != '/' ]]; do
    parent="${parent%/*}"
    [[ -n "$parent" ]] || parent='/'
  done
  if [[ -w "$parent" ]]; then pass "$path"; else fail "$path is not writable (nearest existing parent: $parent)"; fi
done

printf '\nSummary: %d PASS, %d WARN, %d FAIL\n' "$passes" "$warnings" "$failures"

if ((failures > 0)); then
  exit "$AOB_EXIT_PREREQUISITE"
fi
if ((strict == 1 && warnings > 0)); then
  exit "$AOB_EXIT_PREREQUISITE"
fi
