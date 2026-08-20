#!/usr/bin/env bash
# scripts/add-update-aur-pkg.sh
#
# Add or update a pinned AUR package's PKGBUILD in packages/aur/<name>
# as a git submodule tracking the AUR package's own git repo.
#
# Usage:
#   ./scripts/add-update-aur-pkg.sh <package-name>
#   ./scripts/add-update-aur-pkg.sh <package-name> --pin <commit-or-tag>

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
AUR_BASE="https://aur.archlinux.org"
PKG_DIR="packages/aur"

usage() {
  echo "Usage: $0 <package-name> [--pin <ref>]" >&2
  echo "  <package-name>   Name of the AUR package (as it appears on aur.archlinux.org)" >&2
  echo "  --pin <ref>      Optional commit hash or tag to pin to (default: latest on AUR)" >&2
  exit 1
}

[ $# -lt 1 ] && usage

PKG_NAME="$1"
shift
PIN_REF=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pin)
      PIN_REF="${2:-}"
      [ -z "$PIN_REF" ] && { echo "Error: --pin requires a value" >&2; exit 1; }
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

cd "$REPO_ROOT"

TARGET_PATH="$PKG_DIR/$PKG_NAME"
AUR_URL="$AUR_BASE/$PKG_NAME.git"

# Verify the package actually exists on the AUR before doing anything
echo "Checking AUR for '$PKG_NAME'..."
if ! curl -sf "$AUR_BASE/rpc/v5/info/$PKG_NAME" | grep -q '"resultcount":1'; then
  echo "Error: '$PKG_NAME' not found on AUR" >&2
  exit 1
fi

mkdir -p "$PKG_DIR"

if [ -d "$TARGET_PATH" ]; then
  echo "Package '$PKG_NAME' already present at $TARGET_PATH — updating..."

  git submodule update --init "$TARGET_PATH"

  (
    cd "$TARGET_PATH"
    git fetch origin

    if [ -n "$PIN_REF" ]; then
      git checkout "$PIN_REF"
    else
      git checkout "origin/HEAD"
    fi
  )

  NEW_SHA="$(git -C "$TARGET_PATH" rev-parse --short HEAD)"
  git add "$TARGET_PATH"

  if git diff --cached --quiet -- "$TARGET_PATH"; then
    echo "No changes — '$PKG_NAME' is already at the requested revision."
    exit 0
  fi

  git commit -m "aur: update $PKG_NAME to $NEW_SHA"
  echo "Updated '$PKG_NAME' to $NEW_SHA"

else
  echo "Adding new AUR package '$PKG_NAME'..."

  git submodule add "$AUR_URL" "$TARGET_PATH"

  if [ -n "$PIN_REF" ]; then
    (
      cd "$TARGET_PATH"
      git checkout "$PIN_REF"
    )
    git add "$TARGET_PATH"
  fi

  PINNED_SHA="$(git -C "$TARGET_PATH" rev-parse --short HEAD)"
  git commit -m "aur: add $PKG_NAME (pinned at $PINNED_SHA)"
  echo "Added '$PKG_NAME' pinned at $PINNED_SHA"
fi

echo ""
echo "Review the PKGBUILD before pushing:"
echo "  cat $TARGET_PATH/PKGBUILD"
echo ""
echo "When ready:"
echo "  git push --recurse-submodules=on-demand"
