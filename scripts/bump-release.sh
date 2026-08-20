#!/usr/bin/env bash
# scripts/bump-release.sh
#
# Bumps a PKGBUILD's pkgver to match the latest GitHub release of its
# upstream repo, resets pkgrel to 1, regenerates checksums, and commits.
#
# Usage: ./scripts/bump-release.sh <package-dir> <github-owner/repo> [version]

set -euo pipefail

PKG_DIR="$1"
GH_REPO="$2"
FORCE_VERSION="${3:-}"

[ -d "$PKG_DIR" ] || { echo "Error: $PKG_DIR not found" >&2; exit 1; }

PKGBUILD="$PKG_DIR/PKGBUILD"

if [ -n "$FORCE_VERSION" ]; then
    LATEST="$FORCE_VERSION"
else
    LATEST=$(curl -sf "https://api.github.com/repos/$GH_REPO/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
fi

[ -z "$LATEST" ] || [ "$LATEST" = "null" ] && { echo "Error: could not resolve latest release for $GH_REPO" >&2; exit 1; }

CURRENT=$(grep '^pkgver=' "$PKGBUILD" | cut -d= -f2)

if [ "$CURRENT" = "$LATEST" ]; then
    echo "Already at $LATEST — nothing to do."
    exit 0
fi

echo "Bumping $(basename "$PKG_DIR"): $CURRENT -> $LATEST"

sed -i "s/^pkgver=.*/pkgver=$LATEST/" "$PKGBUILD"
sed -i "s/^pkgrel=.*/pkgrel=1/" "$PKGBUILD"

# Regenerate the checksum against the real release tarball
( cd "$PKG_DIR" && updpkgsums )

git add "$PKGBUILD"
git commit -m "$(basename "$PKG_DIR"): bump to $LATEST"

echo "Bumped and committed. Build will pick this up next."
