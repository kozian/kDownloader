#!/usr/bin/env bash
# Xcode build phase: prepares the tools and copies them into the app bundle.
# Single-file binaries go to Contents/Helpers. The yt-dlp onedir build mixes
# code with data files, which codesign rejects in Helpers, so it goes to
# Contents/Resources/yt-dlp.
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# The update test build (scripts/build-update-test.sh) passes another manifest
# and tools folder as build settings.
MANIFEST="${KD_TOOLS_MANIFEST:-$ROOT/tools/manifest.json}"
TOOLS="${KD_TOOLS_DIR:-$ROOT/.build/tools}"
CONTENTS="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"

"$ROOT/scripts/fetch-tools.sh" --manifest "$MANIFEST" --out "$TOOLS"

mkdir -p "$CONTENTS/Helpers" "$CONTENTS/Resources"
rsync -a --delete "$TOOLS/yt-dlp/" "$CONTENTS/Resources/yt-dlp/"
for binary in ffmpeg ffprobe deno; do
    install -m 0755 "$TOOLS/$binary" "$CONTENTS/Helpers/$binary"
done
cp "$MANIFEST" "$CONTENTS/Resources/tools-manifest.json"

# License notices (see DEVELOPMENT.md "License notices"): the tools' files prepared by
# fetch-tools.sh, kDownloader's own license, and how the bundled FFmpeg was built.
LICENSES="$CONTENTS/Resources/Licenses"
rm -rf "$LICENSES"
mkdir -p "$LICENSES/kDownloader"
cp -R "$TOOLS/licenses/" "$LICENSES/"
cp "$ROOT/LICENSE" "$LICENSES/kDownloader/LICENSE"
cp "$ROOT/scripts/build-ffmpeg.sh" "$LICENSES/FFmpeg/build-ffmpeg.sh"
ffmpeg_version="$(jq -r '.tools[] | select(.name == "ffmpeg") | .version' "$MANIFEST")"
{
    echo "FFmpeg $ffmpeg_version (ffmpeg and ffprobe in this app)"
    echo
    echo "License: GNU Lesser General Public License 2.1 or later (COPYING.LGPLv2.1)."
    echo "Built without GPL and non-free components."
    echo
    echo "Source: $(jq -r '.tools[] | select(.name == "ffmpeg") | .url' "$MANIFEST")"
    echo "SHA-256: $(jq -r '.tools[] | select(.name == "ffmpeg") | .sha256' "$MANIFEST")"
    echo "The same tarball is published next to each kDownloader release as"
    echo "ffmpeg-$ffmpeg_version.tar.xz. build-ffmpeg.sh is the script that built it."
    echo
    "$TOOLS/ffmpeg" -hide_banner -buildconf
} > "$LICENSES/FFmpeg/BUILD.txt"
