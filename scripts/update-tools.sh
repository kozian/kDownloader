#!/usr/bin/env bash
# Updates tools/manifest.json to the latest stable releases of the bundled
# tools and prints which versions changed.
#
# yt-dlp and Deno: checksums are taken from the files published with each
# GitHub release. ffmpeg: the newest release tarball from ffmpeg.org; its
# .asc signature is verified when gpg is installed, and its SHA-256 is pinned.
#
# The license files downloaded from the yt-dlp and Deno repositories are
# repinned to the new release tags; their SHA-256 is taken from the downloaded
# file, since the projects publish no checksums for them.
#
# Afterwards the Debug manifest (tools/manifest-update-test.json) is rewritten:
# the same tools, but yt-dlp one release behind, so Debug builds can test the
# in-app update against the real latest release.
#
# Usage: update-tools.sh [--manifest <path>] [--debug-manifest <path>]
# Set GITHUB_TOKEN to avoid GitHub API rate limits.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/tools/manifest.json"
DEBUG_MANIFEST="$ROOT/tools/manifest-update-test.json"
CACHE="$ROOT/.build/tools-cache"
FFMPEG_SIGNING_KEY="FCF986EA15E6E293A5644F10B4322F04D67658D8"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST="$2"; shift 2 ;;
        --debug-manifest) DEBUG_MANIFEST="$2"; shift 2 ;;
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

# Points the license entry <as> of tool <name> in <manifest> to <url> and pins
# the SHA-256 of the file found there.
pin_license() {
    local manifest="$1" name="$2" as="$3" url="$4" sha tmp
    sha="$(curl -fsSL "$url" | shasum -a 256 | awk '{print $1}')"
    if [[ ! "$sha" =~ ^[0-9a-f]{64}$ ]]; then
        echo "error: cannot download the $name license from $url" >&2
        exit 1
    fi
    tmp="$(mktemp)"
    jq --arg n "$name" --arg a "$as" --arg u "$url" --arg s "$sha" \
        '(.tools[] | select(.name == $n) | .licenses.files[] | select(.as == $a)) |= (.url = $u | .sha256 = $s)' \
        "$manifest" > "$tmp"
    mv "$tmp" "$manifest"
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
pin_license "$MANIFEST" yt-dlp LICENSE "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$tag/LICENSE"
report yt-dlp "$old" "$tag"

# Deno
old="$(current deno)"
tag="$(github_latest denoland/deno | jq -r '.tag_name')"
base="https://github.com/denoland/deno/releases/download/$tag"
sha="$(curl -fsSL "$base/deno-aarch64-apple-darwin.zip.sha256sum" | checksum_for deno-aarch64-apple-darwin.zip)"
set_tool deno "${tag#v}" "$base/deno-aarch64-apple-darwin.zip" "$sha"
pin_license "$MANIFEST" deno LICENSE.md "https://raw.githubusercontent.com/denoland/deno/$tag/LICENSE.md"
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

# Debug manifest: yt-dlp one release behind the release manifest.
current="$(current yt-dlp)"
auth=()
[[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
previous="$(curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/yt-dlp/yt-dlp/releases?per_page=30" \
    | jq -r --arg current "$current" '[.[] | select(.prerelease | not) | .tag_name] | map(select(. < $current)) | max // empty')"
[[ -n "$previous" ]] || { echo "error: no yt-dlp release older than $current" >&2; exit 1; }
base="https://github.com/yt-dlp/yt-dlp/releases/download/$previous"
sha="$(curl -fsSL "$base/SHA2-256SUMS" | checksum_for yt-dlp_macos.zip)"
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { echo "error: no checksum for yt-dlp $previous" >&2; exit 1; }
old_debug="$(jq -r '.tools[] | select(.name == "yt-dlp") | .version' "$DEBUG_MANIFEST" 2>/dev/null || echo none)"
jq --arg v "$previous" --arg u "$base/yt-dlp_macos.zip" --arg s "$sha" \
    '(.tools[] | select(.name == "yt-dlp")) |= (.version = $v | .url = $u | .sha256 = $s)' \
    "$MANIFEST" > "$DEBUG_MANIFEST.tmp"
mv "$DEBUG_MANIFEST.tmp" "$DEBUG_MANIFEST"
pin_license "$DEBUG_MANIFEST" yt-dlp LICENSE "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$previous/LICENSE"
report "yt-dlp (Debug builds)" "$old_debug" "$previous"

