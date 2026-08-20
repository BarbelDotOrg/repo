#!/usr/bin/env bash
# scripts/bump-all.sh
#
# Bumps every package under packages/own/ to the latest GitHub release of
# its upstream repo, inferred from the PKGBUILD's url= (falling back to
# source=) line.
#
# Usage: ./scripts/bump-all.sh [packages-own-dir]
#   packages-own-dir defaults to packages/own

set -euo pipefail

OWN_DIR="${1:-packages/own}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -d "$OWN_DIR" ] || { echo "Error: $OWN_DIR not found" >&2; exit 1; }

bumped=()
skipped=()
failed=()

for pkg_dir in "$OWN_DIR"/*/; do
  pkg_dir="${pkg_dir%/}"
  pkg="$(basename "$pkg_dir")"
  pkgbuild="$pkg_dir/PKGBUILD"

  [ -f "$pkgbuild" ] || { skipped+=("$pkg (no PKGBUILD)"); continue; }

  repo=$(grep -ohE 'github\.com/[^/[:space:]"'"'"']+/[^/[:space:]"'"'"']+' "$pkgbuild" \
    | head -n1 \
    | sed -E 's#github\.com/##; s#\.git$##; s#/$##')

  if [ -z "$repo" ]; then
    echo "Warning: could not find a github.com URL in $pkgbuild, skipping $pkg" >&2
    skipped+=("$pkg (no github url)")
    continue
  fi

  echo "=== $pkg ($repo) ==="
  if "$SCRIPT_DIR/bump-release.sh" "$pkg_dir" "$repo"; then
    bumped+=("$pkg")
  else
    echo "Warning: failed to bump $pkg" >&2
    failed+=("$pkg")
  fi
  echo
done

echo "----------------------------------------"
echo "Bumped: ${#bumped[@]}"
for p in "${bumped[@]:-}"; do [ -n "$p" ] && echo "  - $p"; done
echo "Skipped: ${#skipped[@]}"
for p in "${skipped[@]:-}"; do [ -n "$p" ] && echo "  - $p"; done
echo "Failed: ${#failed[@]}"
for p in "${failed[@]:-}"; do [ -n "$p" ] && echo "  - $p"; done

[ "${#failed[@]}" -eq 0 ]
