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
