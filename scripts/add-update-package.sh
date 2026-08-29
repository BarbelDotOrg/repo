#!/usr/bin/env bash
# scripts/add-update-pkg.sh
#
# Add or update a pinned package's PKGBUILD as a git submodule.
#
# For AUR packages, tracks the package's AUR git repo (looked up automatically).
# For own packages, tracks whatever git URL you supply.
#
# Usage:
#   ./scripts/add-update-pkg.sh <package-name> [--pin <ref>]
#   ./scripts/add-update-pkg.sh <package-name> --type own --url <git-url> [--pin <ref>]

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
AUR_BASE="https://aur.archlinux.org"

usage() {
  echo "Usage: $0 <package-name> [--type aur|own] [--url <git-url>] [--pin <ref>]" >&2
  echo "  <package-name>   Name of the package / target dir under packages/<type>/" >&2
  echo "  --type <type>    'aur' (default) or 'own'" >&2
  echo "  --url <git-url>  Required for --type own; the package repo's git URL" >&2
  echo "  --pin <ref>      Optional commit hash or tag to pin to (default: latest)" >&2
  exit 1
}

[ $# -lt 1 ] && usage

PKG_NAME="$1"
shift
PIN_REF=""
PKG_TYPE="aur"
PKG_URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pin)
      PIN_REF="${2:-}"
      [ -z "$PIN_REF" ] && { echo "Error: --pin requires a value" >&2; exit 1; }
      shift 2
      ;;
    --type)
      PKG_TYPE="${2:-}"
      [ -z "$PKG_TYPE" ] && { echo "Error: --type requires a value" >&2; exit 1; }
      shift 2
      ;;
    --url)
      PKG_URL="${2:-}"
      [ -z "$PKG_URL" ] && { echo "Error: --url requires a value" >&2; exit 1; }
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

if [ "$PKG_TYPE" = "own" ] && [ -z "$PKG_URL" ]; then
  echo "Error: --type own requires --url <git-url>" >&2
  exit 1
fi

cd "$REPO_ROOT"

PKG_DIR="packages/$PKG_TYPE"
TARGET_PATH="$PKG_DIR/$PKG_NAME"

if [ "$PKG_TYPE" = "aur" ]; then
  SRC_URL="$AUR_BASE/$PKG_NAME.git"

  # Verify the package actually exists on the AUR before doing anything
  echo "Checking AUR for '$PKG_NAME'..."
  if ! curl -sf "$AUR_BASE/rpc/v5/info/$PKG_NAME" | grep -q '"resultcount":1'; then
    echo "Error: '$PKG_NAME' not found on AUR" >&2
    exit 1
  fi
else
  SRC_URL="$PKG_URL"
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

  git commit -m "$PKG_TYPE: update $PKG_NAME to $NEW_SHA"
  echo "Updated '$PKG_NAME' to $NEW_SHA"

else
  echo "Adding new $PKG_TYPE package '$PKG_NAME'..."

  git submodule add "$SRC_URL" "$TARGET_PATH"

  if [ -n "$PIN_REF" ]; then
    (
      cd "$TARGET_PATH"
      git checkout "$PIN_REF"
    )
    git add "$TARGET_PATH"
  fi

  PINNED_SHA="$(git -C "$TARGET_PATH" rev-parse --short HEAD)"
  git commit -m "$PKG_TYPE: add $PKG_NAME (pinned at $PINNED_SHA)"
  echo "Added '$PKG_NAME' pinned at $PINNED_SHA"
fi

echo ""
echo "Review the PKGBUILD before pushing:"
echo "  cat $TARGET_PATH/PKGBUILD"
echo ""
echo "When ready:"
echo "  git push --recurse-submodules=on-demand"