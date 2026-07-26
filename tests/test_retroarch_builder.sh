#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
metadata="$("$ROOT/aob" info retroarch)"
help_text="$("$ROOT/aob" build retroarch --help)"
builder="$ROOT/builders/retroarch/builder.sh"
installer="$ROOT/builders/retroarch/BundledCoreInstaller.java"

[[ "$metadata" == *'status=bundled-core-build'* ]]
[[ "$metadata" == *'default_cores=fceumm'* ]]
[[ "$metadata" == *'core_bundled_in_apk=yes'* ]]
[[ "$help_text" == *'--cores fceumm'* ]]
[[ "$help_text" == *'FCEUmm bundled inside it'* ]]
[[ -f "$installer" ]]
grep -F 'libfceumm_libretro_android.so' "$builder" >/dev/null
grep -F 'BundledCoreInstaller.install(this);' "$builder" >/dev/null
grep -F 'BUNDLED_FCEUMM_REVISION' "$installer" >/dev/null

printf 'test_retroarch_builder: PASS\n'
