#!/usr/bin/env bash
set -euo pipefail

# Config
REPO_NAME="barbel"
REPO_DIR="repo/os/x86_64"
DB_FILE="${REPO_DIR}/${REPO_NAME}.db.tar.gz"

# Optional: set SIGN=1 and GPG_KEY=<keyid> to sign the db and packages
SIGN="${SIGN:-0}"
GPG_KEY="${GPG_KEY:-}"

cd "$(dirname "$0")"

if [ ! -d "$REPO_DIR" ]; then
  echo "Error: $REPO_DIR does not exist" >&2
  exit 1
fi

shopt -s nullglob
pkgs=("$REPO_DIR"/*.pkg.tar.zst)
shopt -u nullglob

# if [ ${#pkgs[@]} -eq 0 ]; then
#   echo "No packages found in $REPO_DIR" >&2
#   exit 1
# fi

echo "Found ${#pkgs[@]} package(s). Rebuilding database..."

REPO_ADD_ARGS=()
if [ "$SIGN" = "1" ]; then
  if [ -z "$GPG_KEY" ]; then
    echo "Error: SIGN=1 requires GPG_KEY to be set" >&2
    exit 1
  fi
  REPO_ADD_ARGS+=(-s -k "$GPG_KEY")
  # sign each package if not already signed
  for pkg in "${pkgs[@]}"; do
    if [ ! -f "${pkg}.sig" ]; then
      echo "Signing $(basename "$pkg")..."
      gpg --detach-sign --default-key "$GPG_KEY" "$pkg"
    fi
  done
fi

repo-add "${REPO_ADD_ARGS[@]}" "$DB_FILE" "${pkgs[@]}"

echo "Done. Database updated at $DB_FILE"
