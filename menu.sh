#!/usr/bin/env bash
set -Eeuo pipefail

AOB_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

while true; do
  cat <<'EOF_MENU'

Android Open Builder

1. Diagnostic
2. List builders
3. Show paths
4. RetroArch builder information
0. Quit
EOF_MENU
  printf '\nChoice: '
  IFS= read -r choice
  case "$choice" in
    1) "$AOB_ROOT/aob" doctor || true ;;
    2) "$AOB_ROOT/aob" list ;;
    3) "$AOB_ROOT/aob" paths ;;
    4) "$AOB_ROOT/aob" info retroarch ;;
    0) exit 0 ;;
    *) printf 'Invalid choice.\n' >&2 ;;
  esac
done
