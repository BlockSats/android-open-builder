#!/usr/bin/env bash
# shellcheck disable=SC2154

_retroarch_builder_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=builders/retroarch/config.conf
source "$_retroarch_builder_dir/config.conf"
# shellcheck source=config/android.conf
source "$AOB_ROOT/config/android.conf"

builder_metadata() {
  cat <<EOF_METADATA
name=retroarch
display_name=RetroArch AOB
status=smoke-build
target=Android ARM64
frontend_revision=$RETROARCH_REVISION
default_cores=$RETROARCH_DEFAULT_CORES
core_bundled_in_apk=no
EOF_METADATA
}

builder_doctor() {
  local ndk_build="$AOB_ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION/ndk-build"
  [[ -x "$ndk_build" ]] && aob_command_exists javac
}

_retroarch_usage() {
  cat <<'EOF_USAGE'
Usage: ./aob build retroarch [options]

Builds an ARM64 RetroArch debug APK and an FCEUmm core artifact.
The core is produced separately and is not yet bundled inside the APK.

Options:
  --cores fceumm      Core selection; only fceumm is supported in this smoke build
  --jobs N            Parallel build jobs; defaults to AOB_BUILD_JOBS or host CPU count
  --no-clean          Skip Gradle clean before assembling the APK
  -h, --help          Show this help
EOF_USAGE
}

_retroarch_resolve_jobs() {
  local requested="$1"
  if [[ "$requested" == "auto" ]]; then
    getconf _NPROCESSORS_ONLN 2>/dev/null || nproc
    return
  fi
  [[ "$requested" =~ ^[1-9][0-9]*$ ]] || aob_die "$AOB_EXIT_USAGE" "Invalid job count: $requested"
  printf '%s\n' "$requested"
}

_retroarch_preflight() {
  local ndk_dir="$AOB_ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"
  local ndk_build="$ndk_dir/ndk-build"
  local command_name

  for command_name in git python3 jq sha256sum stat tee awk find readlink; do
    aob_command_exists "$command_name" || aob_die "$AOB_EXIT_PREREQUISITE" "Required command is missing: $command_name"
  done

  aob_command_exists javac || aob_die "$AOB_EXIT_PREREQUISITE" \
    'Java 17 JDK is required, but javac is missing. Install openjdk-17-jdk-headless.'

  [[ -d "$AOB_ANDROID_SDK_ROOT/platforms/$ANDROID_PLATFORM" ]] || \
    aob_die "$AOB_EXIT_PREREQUISITE" "Android platform is missing: $ANDROID_PLATFORM"
  [[ -d "$AOB_ANDROID_SDK_ROOT/build-tools/$ANDROID_BUILD_TOOLS" ]] || \
    aob_die "$AOB_EXIT_PREREQUISITE" "Android Build Tools are missing: $ANDROID_BUILD_TOOLS"
  [[ -x "$ndk_build" ]] || \
    aob_die "$AOB_EXIT_PREREQUISITE" "Android ndk-build is missing: $ndk_build"
}

_retroarch_checkout() {
  local label="$1" url="$2" revision="$3" destination="$4"

  aob_info "Fetching $label at $revision"
  if [[ ! -d "$destination/.git" ]]; then
    rm -rf -- "$destination"
    mkdir -p -- "$destination"
    git -C "$destination" init
    git -C "$destination" remote add origin "$url"
  fi

  git -C "$destination" remote set-url origin "$url"
  git -C "$destination" fetch --force --depth 1 origin "$revision"
  git -C "$destination" checkout --detach FETCH_HEAD
  git -C "$destination" reset --hard FETCH_HEAD
  git -C "$destination" clean -ffd
}

_retroarch_prepare_frontend() {
  local source_dir="$1" jobs="$2"
  local gradle_file="$source_dir/pkg/android/phoenix/build.gradle"
  local local_properties="$source_dir/pkg/android/phoenix/local.properties"

  aob_info "Fetching RetroArch submodules"
  git -C "$source_dir" submodule sync --recursive
  git -C "$source_dir" -c protocol.version=2 submodule update \
    --init --recursive --depth 1 --jobs "$jobs"

  python3 - "$gradle_file" "$RETROARCH_APPLICATION_ID_SUFFIX" "$RETROARCH_APP_NAME" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
suffix = sys.argv[2]
app_name = sys.argv[3]
text = path.read_text()
old = """    aarch64 {
      applicationIdSuffix '.aarch64'
      resValue \"string\", \"app_name\", \"RetroArch (AArch64)\"
      buildConfigField \"boolean\", \"PLAY_STORE_BUILD\", \"false\"

      dimension \"variant\"
      ndk {
        abiFilters 'arm64-v8a', 'x86_64'
      }
    }"""
new = f"""    aarch64 {{
      applicationIdSuffix '{suffix}'
      resValue \"string\", \"app_name\", \"{app_name}\"
      buildConfigField \"boolean\", \"PLAY_STORE_BUILD\", \"false\"

      dimension \"variant\"
      ndk {{
        abiFilters 'arm64-v8a'
      }}
    }}"""
if text.count(old) != 1:
    raise SystemExit("Pinned RetroArch aarch64 Gradle block was not found exactly once")
path.write_text(text.replace(old, new))
PY

  cat > "$local_properties" <<EOF_PROPERTIES
sdk.dir=$AOB_ANDROID_SDK_ROOT
EOF_PROPERTIES
}

_retroarch_build_core() {
  local core_dir="$1" jobs="$2"
  local ndk_build="$AOB_ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION/ndk-build"
  local core_output="$core_dir/libs/$RETROARCH_TARGET_ABI/libretro.so"

  aob_info "Building FCEUmm for $RETROARCH_TARGET_ABI"
  rm -rf -- "$core_dir/libs" "$core_dir/obj"
  "$ndk_build" -C "$core_dir" \
    NDK_PROJECT_PATH="$core_dir" \
    APP_BUILD_SCRIPT="$core_dir/jni/Android.mk" \
    NDK_APPLICATION_MK="$core_dir/jni/Application.mk" \
    APP_ABI="$RETROARCH_TARGET_ABI" \
    APP_PLATFORM="$RETROARCH_MIN_API" \
    -j"$jobs"

  [[ -f "$core_output" ]] || {
    aob_error "FCEUmm output was not found: $core_output"
    return 1
  }
  RETROARCH_CORE_OUTPUT="$core_output"
}

_retroarch_build_frontend() {
  local source_dir="$1" jobs="$2" clean="$3"
  local gradle_dir="$source_dir/pkg/android/phoenix"
  local java_home
  local -a gradle_tasks=()
  local -a apks=()

  java_home="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"

  if [[ "$clean" == true ]]; then
    gradle_tasks+=(clean)
  fi
  gradle_tasks+=("$RETROARCH_GRADLE_TASK")

  aob_info "Building RetroArch frontend with Gradle task $RETROARCH_GRADLE_TASK"
  aob_info "Using Java home: $java_home"
  if ! (
    cd "$gradle_dir"
    JAVA_HOME="$java_home" \
    ANDROID_HOME="$AOB_ANDROID_SDK_ROOT" \
    ANDROID_SDK_ROOT="$AOB_ANDROID_SDK_ROOT" \
    GRADLE_USER_HOME="$AOB_CACHE_DIR/gradle" \
      ./gradlew --no-daemon --stacktrace --max-workers="$jobs" "${gradle_tasks[@]}"
  ); then
    aob_error "Gradle task failed: $RETROARCH_GRADLE_TASK"
    return 1
  fi

  if [[ ! -d "$gradle_dir/build/outputs/apk" ]]; then
    aob_error "Gradle APK output directory was not created: $gradle_dir/build/outputs/apk"
    return 1
  fi

  mapfile -t apks < <(find "$gradle_dir/build/outputs/apk" -type f \
    -name '*aarch64*debug*.apk' -print | sort)
  if ((${#apks[@]} != 1)); then
    aob_error "Expected exactly one AArch64 debug APK, found ${#apks[@]}"
    printf '%s\n' "${apks[@]}" >&2
    return 1
  fi
  RETROARCH_APK_OUTPUT="${apks[0]}"
}

_retroarch_write_manifest() {
  local artifact_dir="$1" build_id="$2" apk_name="$3" core_name="$4"
  local frontend_dir="$5" core_dir="$6"
  local apk_sha core_sha builder_revision frontend_revision core_revision
  local apk_size core_size

  apk_sha="$(sha256sum "$artifact_dir/$apk_name" | awk '{print $1}')"
  core_sha="$(sha256sum "$artifact_dir/$core_name" | awk '{print $1}')"
  apk_size="$(stat -c '%s' "$artifact_dir/$apk_name")"
  core_size="$(stat -c '%s' "$artifact_dir/$core_name")"
  builder_revision="$(git -C "$AOB_ROOT" rev-parse HEAD)"
  frontend_revision="$(git -C "$frontend_dir" rev-parse HEAD)"
  core_revision="$(git -C "$core_dir" rev-parse HEAD)"

  jq -n \
    --arg build_id "$build_id" \
    --arg builder_revision "$builder_revision" \
    --arg frontend_revision "$frontend_revision" \
    --arg core_revision "$core_revision" \
    --arg abi "$RETROARCH_TARGET_ABI" \
    --arg application_id "com.retroarch${RETROARCH_APPLICATION_ID_SUFFIX}" \
    --arg app_name "$RETROARCH_APP_NAME" \
    --arg android_platform "$ANDROID_PLATFORM" \
    --arg build_tools "$ANDROID_BUILD_TOOLS" \
    --arg ndk "$ANDROID_NDK_VERSION" \
    --arg apk "$apk_name" \
    --arg apk_sha256 "$apk_sha" \
    --argjson apk_size "$apk_size" \
    --arg core "$core_name" \
    --arg core_sha256 "$core_sha" \
    --argjson core_size "$core_size" \
    '{
      schema_version: 1,
      build_id: $build_id,
      project: "retroarch",
      builder_revision: $builder_revision,
      frontend_revision: $frontend_revision,
      core_revisions: {fceumm: $core_revision},
      target_abi: $abi,
      application_id: $application_id,
      application_name: $app_name,
      core_bundled_in_apk: false,
      toolchain: {
        android_platform: $android_platform,
        build_tools: $build_tools,
        ndk: $ndk
      },
      artifacts: [
        {type: "apk", name: $apk, size: $apk_size, sha256: $apk_sha256},
        {type: "libretro-core", name: $core, size: $core_size, sha256: $core_sha256}
      ]
    }' > "$artifact_dir/manifest.json"
}

_retroarch_execute() {
  local build_id="$1" jobs="$2" clean="$3"
  local work_root="$AOB_WORK_DIR/retroarch"
  local frontend_dir="$work_root/retroarch-src"
  local core_dir="$work_root/fceumm-src"
  local artifact_dir="$AOB_OUTPUT_DIR/retroarch/$build_id"
  local apk_name="RetroArch-AOB-$RETROARCH_TARGET_ABI-debug.apk"
  local core_name="fceumm_libretro_android.so"

  unset RETROARCH_APK_OUTPUT RETROARCH_CORE_OUTPUT || true

  mkdir -p -- "$work_root"
  _retroarch_checkout "RetroArch" "$RETROARCH_REPOSITORY" "$RETROARCH_REVISION" "$frontend_dir" || return $?
  _retroarch_checkout "FCEUmm" "$FCEUMM_REPOSITORY" "$FCEUMM_REVISION" "$core_dir" || return $?
  _retroarch_prepare_frontend "$frontend_dir" "$jobs" || return $?
  _retroarch_build_core "$core_dir" "$jobs" || return $?
  _retroarch_build_frontend "$frontend_dir" "$jobs" "$clean" || return $?

  mkdir -p -- "$artifact_dir"
  cp -- "$RETROARCH_APK_OUTPUT" "$artifact_dir/$apk_name"
  cp -- "$RETROARCH_CORE_OUTPUT" "$artifact_dir/$core_name"
  (
    cd "$artifact_dir"
    sha256sum "$apk_name" "$core_name" > SHA256SUMS
  )
  _retroarch_write_manifest "$artifact_dir" "$build_id" "$apk_name" "$core_name" \
    "$frontend_dir" "$core_dir"

  aob_ok "RetroArch smoke build completed"
  printf 'Artifacts: %s\n' "$artifact_dir"
}

builder_main() {
  local cores="$RETROARCH_DEFAULT_CORES"
  local requested_jobs="$AOB_BUILD_JOBS"
  local clean=true
  local jobs build_id log_dir log_file artifact_dir status

  while (($#)); do
    case "$1" in
      --cores)
        (($# >= 2)) || aob_die "$AOB_EXIT_USAGE" '--cores requires a value'
        cores="$2"
        shift
        ;;
      --jobs)
        (($# >= 2)) || aob_die "$AOB_EXIT_USAGE" '--jobs requires a value'
        requested_jobs="$2"
        shift
        ;;
      --no-clean) clean=false ;;
      -h|--help) _retroarch_usage; return 0 ;;
      *) aob_die "$AOB_EXIT_USAGE" "Unknown RetroArch option: $1" ;;
    esac
    shift
  done

  [[ "$cores" == "fceumm" ]] || \
    aob_die "$AOB_EXIT_USAGE" "This smoke builder currently supports only: --cores fceumm"

  _retroarch_preflight
  jobs="$(_retroarch_resolve_jobs "$requested_jobs")"
  build_id="$(date -u +'%Y%m%dT%H%M%SZ')-retroarch-${RETROARCH_REVISION:0:7}"
  log_dir="$AOB_LOG_DIR/retroarch/$build_id"
  log_file="$log_dir/build.log"
  artifact_dir="$AOB_OUTPUT_DIR/retroarch/$build_id"
  mkdir -p -- "$log_dir"

  printf 'Build ID: %s\n' "$build_id"
  printf 'Parallel jobs: %s\n' "$jobs"
  printf 'Build log: %s\n' "$log_file"

  set +e
  _retroarch_execute "$build_id" "$jobs" "$clean" 2>&1 | tee "$log_file"
  status=${PIPESTATUS[0]}
  set -e

  if ((status != 0)); then
    aob_error "RetroArch build failed with status $status"
    printf 'Log retained at: %s\n' "$log_file" >&2
    exit "$status"
  fi

  cp -- "$log_file" "$artifact_dir/build.log"
  printf 'Build log copied to: %s\n' "$artifact_dir/build.log"
}
