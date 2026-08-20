#!/usr/bin/env bash
# Reads packages/own-repos.txt (format: "<pkgdir> <owner/repo>" per line),
# bumps any package whose upstream has a newer GitHub release, and prints
# a JSON array of changed package dirs for use as a GH Actions matrix.

set -euo pipefail

MAPPING_FILE="packages/own-repos.txt"
[ -f "$MAPPING_FILE" ] || { echo "Error: $MAPPING_FILE not found" >&2; exit 1; }

changed=()

while read -r pkgdir ghrepo; do
    [ -z "$pkgdir" ] && continue
    [[ "$pkgdir" =~ ^# ]] && continue

    before="$(git rev-parse HEAD)"
    ./scripts/bump-release.sh "packages/own/$pkgdir" "$ghrepo" || {
        echo "::warning::bump failed for $pkgdir ($ghrepo), skipping" >&2
        continue
    }
    after="$(git rev-parse HEAD)"

    if [ "$before" != "$after" ]; then
        changed+=("$pkgdir")
    fi
done < "$MAPPING_FILE"

# Emit JSON array, e.g. ["charist","otherpkg"]
printf '%s\n' "$(printf '"%s",' "${changed[@]}" | sed 's/,$//' | sed 's/^/[/;s/$/]/')"
