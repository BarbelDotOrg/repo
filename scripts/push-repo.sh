#!/usr/bin/env bash
set -euo pipefail

# Config
LOCAL_REPO="repo"
REMOTE="r2:public/barbel"   # <-- set your rclone remote:bucket/path

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -d "$LOCAL_REPO" ]; then
  echo "Error: $LOCAL_REPO does not exist" >&2
  exit 1
fi

echo "Syncing db/files metadata (no-cache)..."
rclone sync "$LOCAL_REPO" "$REMOTE" \
  --header-upload "Cache-Control: no-cache" \
  --copy-links \
  --include "*.db.tar.gz" \
  --include "*.files.tar.gz" \
  --include "*.db" \
  --include "*.files" \
  --progress

echo "Syncing packages (immutable, long cache)..."
rclone sync "$LOCAL_REPO" "$REMOTE" \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --include "*.pkg.tar.zst" \
  --include "*.pkg.tar.zst.sig" \
  --progress

echo "Sync complete."
