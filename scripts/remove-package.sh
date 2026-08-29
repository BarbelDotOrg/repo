#!/usr/bin/env bash
# scripts/remove-package.sh
#
# Remove a pinned package submodule from packages/<type>/<name>.
#
# Usage:
#   ./scripts/remove-package.sh <package-name> --type aur|own

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

usage() {
  echo "Usage: $0 <package-name> --type aur|own" >&2
  exit 1
}

[ $# -lt 1 ] && usage

PKG_NAME="$1"
shift
PKG_TYPE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --type)
      PKG_TYPE="${2:-}"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

case "$PKG_TYPE" in
  aur|own) ;;
  *) echo "Error: --type must be 'aur' or 'own'" >&2; exit 1 ;;
esac

TARGET_PATH="packages/$PKG_TYPE/$PKG_NAME"

if ! grep -q "submodule \"$TARGET_PATH\"" .gitmodules 2>/dev/null; then
  echo "Error: '$TARGET_PATH' is not a registered submodule" >&2
  exit 1
fi

echo "Removing $PKG_TYPE package '$PKG_NAME'..."

git submodule deinit -f "$TARGET_PATH"
git rm -f "$TARGET_PATH"
rm -rf ".git/modules/$TARGET_PATH"

git commit -m "$PKG_TYPE: remove $PKG_NAME"

echo "Removed '$PKG_NAME'."
echo ""
echo "When ready:"
echo "  git push"