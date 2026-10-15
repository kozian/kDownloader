#!/usr/bin/env bash
# Updates tools/manifest.json to the latest stable releases of the bundled
# tools and prints which versions changed.
#
# yt-dlp and Deno: checksums are taken from the files published with each
# GitHub release. ffmpeg: the newest release tarball from ffmpeg.org; its
# .asc signature is verified when gpg is installed, and its SHA-256 is pinned.
#
# Usage: update-tools.sh [--manifest <path>]
# Set GITHUB_TOKEN to avoid GitHub API rate limits.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/tools/manifest.json"
CACHE="$ROOT/.build/tools-cache"
FFMPEG_SIGNING_KEY="FCF986EA15E6E293A5644F10B4322F04D67658D8"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

mkdir -p "$CACHE"

github_latest() {
    local auth=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$1/releases/latest"
}

# Prints the hash for <file> from a "hash  file" checksum list on stdin.
checksum_for() {
    awk -v f="$1" '$2 == f || $2 == "*"f {print $1}'
}

current() { jq -r --arg n "$1" '.tools[] | select(.name == $n) | .version' "$MANIFEST"; }

set_tool() {
    local name="$1" version="$2" url="$3" sha="$4" tmp
    if [[ ! "$sha" =~ ^[0-9a-f]{64}$ ]]; then
        echo "error: no valid checksum found for $name $version" >&2
        exit 1
    fi
    tmp="$(mktemp)"
    jq --arg n "$name" --arg v "$version" --arg u "$url" --arg s "$sha" \
        '(.tools[] | select(.name == $n)) |= (.version = $v | .url = $u | .sha256 = $s)' \
        "$MANIFEST" > "$tmp"
    mv "$tmp" "$MANIFEST"
}

report() {
    if [[ "$2" == "$3" ]]; then
        echo "$1: $2 (unchanged)"
    else
        echo "$1: $2 -> $3"
    fi
}

# yt-dlp
old="$(current yt-dlp)"
tag="$(github_latest yt-dlp/yt-dlp | jq -r '.tag_name')"
base="https://github.com/yt-dlp/yt-dlp/releases/download/$tag"
sha="$(curl -fsSL "$base/SHA2-256SUMS" | checksum_for yt-dlp_macos.zip)"
set_tool yt-dlp "$tag" "$base/yt-dlp_macos.zip" "$sha"
report yt-dlp "$old" "$tag"

# Deno
old="$(current deno)"
tag="$(github_latest denoland/deno | jq -r '.tag_name')"
base="https://github.com/denoland/deno/releases/download/$tag"
sha="$(curl -fsSL "$base/deno-aarch64-apple-darwin.zip.sha256sum" | checksum_for deno-aarch64-apple-darwin.zip)"
set_tool deno "${tag#v}" "$base/deno-aarch64-apple-darwin.zip" "$sha"
report deno "$old" "${tag#v}"

# ffmpeg
old="$(current ffmpeg)"
version="$(curl -fsSL https://ffmpeg.org/releases/ \
    | grep -oE 'ffmpeg-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz"' \
    | sed -E 's/^ffmpeg-(.*)\.tar\.xz"$/\1/' | sort -uV | tail -n 1)"
url="https://ffmpeg.org/releases/ffmpeg-$version.tar.xz"
tarball="$CACHE/ffmpeg-$version.tar.xz"
if [[ ! -f "$tarball" ]]; then
    curl -fsSL --retry 3 -o "$tarball.tmp" "$url"
    mv "$tarball.tmp" "$tarball"
fi
if command -v gpg > /dev/null; then
    curl -fsSL -o "$tarball.asc" "$url.asc"
    if ! gpg --verify "$tarball.asc" "$tarball" 2> /dev/null; then
        rm -f "$tarball" "$tarball.asc"
        echo "error: ffmpeg $version signature verification failed." >&2
        echo "  Import the FFmpeg release key first: gpg --recv-keys $FFMPEG_SIGNING_KEY" >&2
        exit 1
    fi
    echo "ffmpeg: signature verified"
else
    echo "WARNING: gpg is not installed, the ffmpeg $version signature was NOT verified." >&2
    echo "         Install gnupg and import key $FFMPEG_SIGNING_KEY to verify it." >&2
fi
set_tool ffmpeg "$version" "$url" "$(shasum -a 256 "$tarball" | awk '{print $1}')"
report ffmpeg "$old" "$version"
