#!/bin/sh
set -euo pipefail
# Xcode Cloud may invoke the script next to the .xcodeproj; delegate to repo-root script.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
ROOT_SCRIPT="$SCRIPT_DIR/../../../ci_scripts/ci_post_clone.sh"
if [ ! -f "$ROOT_SCRIPT" ]; then
  # Fallback: compute from CI_PRIMARY_REPOSITORY_PATH
  ROOT_SCRIPT="${CI_PRIMARY_REPOSITORY_PATH:-}/ci_scripts/ci_post_clone.sh"
fi
exec /bin/sh "$ROOT_SCRIPT"
