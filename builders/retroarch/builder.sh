#!/usr/bin/env bash
# shellcheck disable=SC2154

builder_metadata() {
  cat <<'EOF_METADATA'
name=retroarch
display_name=RetroArch
status=scaffold
target=Android ARM64
EOF_METADATA
}

builder_doctor() {
  return 0
}

builder_main() {
  aob_die "$AOB_EXIT_PREREQUISITE" \
    "The RetroArch builder is scaffolded but compilation will be implemented in Phase 3."
}
