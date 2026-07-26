#!/usr/bin/env bash
set -Eeuo pipefail

AOB_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/common.sh
source "$AOB_ROOT/lib/common.sh"
# shellcheck source=lib/config.sh
source "$AOB_ROOT/lib/config.sh"
aob_load_config
# shellcheck source=config/android.conf
source "$AOB_ROOT/config/android.conf"

accept_licenses=false
force=false

usage() {
  cat <<'EOF'
Usage: ./aob install [--accept-licenses] [--force]

Installs a project-managed Android SDK under AOB_ANDROID_SDK_ROOT.
The Android SDK license must be accepted explicitly.
EOF
}

while (($#)); do
  case "$1" in
    --accept-licenses) accept_licenses=true ;;
    --force) force=true ;;
    -h|--help) usage; exit 0 ;;
    *) aob_die "$AOB_EXIT_USAGE" "Unknown install option: $1" ;;
  esac
  shift
done

[[ "$(uname -s)" == Linux ]] || aob_die "$AOB_EXIT_PREREQ" 'The installer currently supports Linux only.'
[[ "$(uname -m)" == x86_64 ]] || aob_die "$AOB_EXIT_PREREQ" 'The installer currently supports x86_64 only.'
command -v java >/dev/null || aob_die "$AOB_EXIT_PREREQ" 'Java 17 is required.'
command -v curl >/dev/null || aob_die "$AOB_EXIT_PREREQ" 'curl is required.'
command -v unzip >/dev/null || aob_die "$AOB_EXIT_PREREQ" 'unzip is required.'
command -v sha256sum >/dev/null || aob_die "$AOB_EXIT_PREREQ" 'sha256sum is required.'

if [[ "$accept_licenses" != true ]]; then
  cat >&2 <<'EOF'
Android SDK licenses have not been accepted.
Review Google's Android SDK license, then rerun:

  ./aob install --accept-licenses
EOF
  exit "$AOB_EXIT_USAGE"
fi

aob_ensure_runtime_dirs
sdk_root="$AOB_ANDROID_SDK_ROOT"
archive="$AOB_DOWNLOAD_DIR/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip"
url="https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip"
staging="$AOB_WORK_DIR/android-command-line-tools"

printf 'Android SDK root: %s\n' "$sdk_root"
printf 'Command-line tools: %s\n' "$ANDROID_CMDLINE_TOOLS_VERSION"
printf 'Platform: %s\n' "$ANDROID_PLATFORM"
printf 'Build Tools: %s\n' "$ANDROID_BUILD_TOOLS"
printf 'NDK: %s\n' "$ANDROID_NDK_VERSION"

mkdir -p "$AOB_DOWNLOAD_DIR" "$sdk_root/cmdline-tools"

if [[ ! -f "$archive" ]] || [[ "$force" == true ]]; then
  printf 'Downloading Android command-line tools...\n'
  printf 'URL: %s\n' "$url"
  tmp="${archive}.part"
  rm -f "$tmp"
  curl --ipv4 --fail --location --retry 3 --output "$tmp" "$url"
  mv "$tmp" "$archive"
fi

printf '%s  %s\n' "$ANDROID_CMDLINE_TOOLS_SHA256" "$archive" | sha256sum --check --status \
  || aob_die "$AOB_EXIT_NETWORK" 'Command-line tools checksum verification failed.'
printf 'Checksum verified.\n'

rm -rf "$staging"
mkdir -p "$staging"
unzip -q "$archive" -d "$staging"

if [[ "$force" == true ]]; then
  rm -rf "$sdk_root/cmdline-tools/latest"
fi

if [[ ! -x "$sdk_root/cmdline-tools/latest/bin/sdkmanager" ]]; then
  rm -rf "$sdk_root/cmdline-tools/latest"
  mkdir -p "$sdk_root/cmdline-tools/latest"
  cp -a "$staging/cmdline-tools/." "$sdk_root/cmdline-tools/latest/"
fi
rm -rf "$staging"

sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"
[[ -x "$sdkmanager" ]] || aob_die "$AOB_EXIT_OPERATIONAL" 'sdkmanager was not installed correctly.'

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"

printf 'Accepting Android SDK package licenses...\n'
yes | "$sdkmanager" --sdk_root="$sdk_root" --licenses >/dev/null || true

printf 'Installing Android SDK packages...\n'
"$sdkmanager" --sdk_root="$sdk_root" --channel=0 \
  'platform-tools' \
  "platforms;${ANDROID_PLATFORM}" \
  "build-tools;${ANDROID_BUILD_TOOLS}" \
  "ndk;${ANDROID_NDK_VERSION}" \
  "cmake;${ANDROID_CMAKE_VERSION}"

cat > "$sdk_root/aob-toolchain.env" <<EOF
export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"
export ANDROID_NDK_HOME="$sdk_root/ndk/$ANDROID_NDK_VERSION"
export PATH="$sdk_root/cmdline-tools/latest/bin:$sdk_root/platform-tools:\$PATH"
EOF

printf '\nAndroid toolchain installation completed.\n'
printf 'Environment file: %s\n' "$sdk_root/aob-toolchain.env"
printf 'Run: ./aob doctor\n'
