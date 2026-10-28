#!/usr/bin/env bash
# Publishes the FFmpeg source tarball of the bundled version next to the release
# archives, as the LGPL requires for the distributed ffmpeg and ffprobe.
# Called by release.sh for a release (not a dry run).
#
#     scripts/publish-ffmpeg-source.sh <dist-dir> [<manifest>]
#
# Writes <dist-dir>/ffmpeg-<version>.tar.xz and its .sha256 from the verified
# build cache (downloading and verifying it if the cache is empty). An existing
# tarball of that version is kept when its checksum matches the manifest; a
# mismatch is an error, never an overwrite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${1:?usage: publish-ffmpeg-source.sh <dist-dir> [<manifest>]}"
MANIFEST="${2:-$ROOT/tools/manifest.json}"
CACHE="$ROOT/.build/tools-cache"

fail() { echo "publish-ffmpeg-source: $*" >&2; exit 1; }

version="$(jq -r '.tools[] | select(.name == "ffmpeg") | .version' "$MANIFEST")"
url="$(jq -r '.tools[] | select(.name == "ffmpeg") | .url' "$MANIFEST")"
sha="$(jq -r '.tools[] | select(.name == "ffmpeg") | .sha256' "$MANIFEST")"
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || fail "no ffmpeg checksum in $MANIFEST"

name="ffmpeg-$version.tar.xz"
target="$DIST/$name"
mkdir -p "$DIST"

if [[ -e "$target" ]]; then
    [[ "$(shasum -a 256 "$target" | awk '{print $1}')" == "$sha" ]] \
        || fail "$target exists with a checksum that does not match the manifest; not overwriting it"
    echo "==> FFmpeg source: $target already published"
else
    cached="$CACHE/$(basename "$url")"
    if [[ ! -f "$cached" || "$(shasum -a 256 "$cached" | awk '{print $1}')" != "$sha" ]]; then
        mkdir -p "$CACHE"
        curl -fsSL --retry 3 -o "$cached.tmp" "$url"
        mv "$cached.tmp" "$cached"
    fi
    [[ "$(shasum -a 256 "$cached" | awk '{print $1}')" == "$sha" ]] || fail "checksum mismatch for $url"
    cp "$cached" "$target.tmp"
    mv "$target.tmp" "$target"
    echo "==> FFmpeg source: $target"
fi
(cd "$DIST" && echo "$sha  $name" > "$name.sha256")
