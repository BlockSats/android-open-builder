#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
metadata="$("$ROOT/aob" info retroarch)"
help_text="$("$ROOT/aob" build retroarch --help)"

[[ "$metadata" == *'status=smoke-build'* ]]
[[ "$metadata" == *'default_cores=fceumm'* ]]
[[ "$metadata" == *'core_bundled_in_apk=no'* ]]
[[ "$help_text" == *'--cores fceumm'* ]]
[[ "$help_text" == *'not yet bundled inside the APK'* ]]

printf 'test_retroarch_builder: PASS\n'
