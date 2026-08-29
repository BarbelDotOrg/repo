#!/usr/bin/env bash
# scripts/update-all-packages.sh
#
# Update every pinned package submodule (aur and/or own) to the latest
# commit on its default branch, committing each package individually
# so the history stays reviewable/revertable per-package.
#
# Usage:
#   ./scripts/update-all-packages.sh                # update everything
#   ./scripts/update-all-packages.sh --type aur      # only packages/aur/*
#   ./scripts/update-all-packages.sh --type own      # only packages/own/*
#   ./scripts/update-all-packages.sh --dry-run       # show what would change, commit nothing

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

usage() {
  echo "Usage: $0 [--type aur|own|all] [--dry-run]" >&2
  exit 1
}

FILTER_TYPE="all"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --type)
      FILTER_TYPE="${2:-}"
      [ -z "$FILTER_TYPE" ] && { echo "Error: --type requires a value" >&2; exit 1; }
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      usage
      ;;
  esac
done

case "$FILTER_TYPE" in
  aur|own|all) ;;
  *) echo "Error: --type must be 'aur', 'own', or 'all'" >&2; exit 1 ;;
esac

if [ ! -f .gitmodules ]; then
  echo "No .gitmodules found — nothing to update."
  exit 0
fi

# Collect submodule paths, filtered by type if requested
mapfile -t SUBMODULE_PATHS < <(
  git config -f .gitmodules --get-regexp '\.path$' |
  awk '{print $2}' |
  { if [ "$FILTER_TYPE" = "all" ]; then cat; else grep "^packages/$FILTER_TYPE/"; fi; }
)

if [ ${#SUBMODULE_PATHS[@]} -eq 0 ]; then
  echo "No submodules found for type '$FILTER_TYPE'."
  exit 0
fi

echo "Initializing submodules..."
git submodule update --init "${SUBMODULE_PATHS[@]}"

UPDATED=()
UNCHANGED=()
FAILED=()

for path in "${SUBMODULE_PATHS[@]}"; do
  name="$(basename "$path")"
  pkg_type="$(basename "$(dirname "$path")")"

  echo ""
  echo "== $pkg_type/$name =="

  OLD_SHA="$(git -C "$path" rev-parse --short HEAD)"

  if ! (
    cd "$path"
    git fetch origin --quiet
    git checkout --quiet origin/HEAD
  ); then
    echo "  failed to fetch/checkout"
    FAILED+=("$pkg_type/$name")
    continue
  fi

  NEW_SHA="$(git -C "$path" rev-parse --short HEAD)"

  if [ "$OLD_SHA" = "$NEW_SHA" ]; then
    echo "  up to date ($OLD_SHA)"
    UNCHANGED+=("$pkg_type/$name")
    continue
  fi

  echo "  $OLD_SHA -> $NEW_SHA"

  if [ "$DRY_RUN" -eq 1 ]; then
    UPDATED+=("$pkg_type/$name ($OLD_SHA -> $NEW_SHA)")
    # revert the checkout so a dry run doesn't leave the tree dirty
    git -C "$path" checkout --quiet "$OLD_SHA"
    continue
  fi

  git add "$path"
  git commit --quiet -m "$pkg_type: update $name to $NEW_SHA"
  UPDATED+=("$pkg_type/$name ($OLD_SHA -> $NEW_SHA)")
done

echo ""
echo "==================== Summary ===================="
echo "Updated (${#UPDATED[@]}):"
printf '  %s\n' "${UPDATED[@]}"
echo "Unchanged (${#UNCHANGED[@]}):"
printf '  %s\n' "${UNCHANGED[@]}"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "Failed (${#FAILED[@]}):"
  printf '  %s\n' "${FAILED[@]}"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  echo "Dry run — no commits made."
elif [ ${#UPDATED[@]} -gt 0 ]; then
  echo ""
  echo "When ready:"
  echo "  git push --recurse-submodules=on-demand"
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  exit 1
fi