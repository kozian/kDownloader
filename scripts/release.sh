#!/usr/bin/env bash
# Builds a release: an ad-hoc signed arm64 kDownloader.app packed into
# dist/kDownloader-<version>.zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/.build/release"
DIST="$ROOT/dist"
APP="$DERIVED/Build/Products/Release/kDownloader.app"

cd "$ROOT"

VERSION="$(xcodebuild -project kDownloader.xcodeproj -target kDownloader -configuration Release \
    -showBuildSettings 2> /dev/null | awk -F' = ' '/ MARKETING_VERSION = / {print $2; exit}')"
if [[ -z "$VERSION" ]]; then
    echo "error: cannot read MARKETING_VERSION" >&2
    exit 1
fi

echo "==> Building kDownloader $VERSION (Release, arm64)"
rm -rf "$DERIVED"
xcodebuild -project kDownloader.xcodeproj -scheme kDownloader -configuration Release \
    -derivedDataPath "$DERIVED" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build > "$ROOT/.build/release.log" 2>&1 \
    || { tail -n 40 "$ROOT/.build/release.log" >&2; exit 1; }

echo "==> Checking bundled tools"
MANIFEST="$APP/Contents/Resources/tools-manifest.json"
check_tool() {
    local path="$1"; shift
    if [[ ! -x "$path" ]]; then
        echo "error: $path is missing or not executable" >&2
        exit 1
    fi
    if ! lipo -archs "$path" | tr ' ' '\n' | grep -qx arm64; then
        echo "error: $path has no arm64 slice ($(lipo -archs "$path"))" >&2
        exit 1
    fi
    local output
    if ! output="$("$path" "$@" 2>&1 | head -n 1)"; then
        echo "error: $path failed to report its version" >&2
        exit 1
    fi
    echo "    $(basename "$path"): $output"
}
check_tool "$APP/Contents/Resources/yt-dlp/yt-dlp_macos" --version
check_tool "$APP/Contents/Helpers/ffmpeg" -version
check_tool "$APP/Contents/Helpers/ffprobe" -version
check_tool "$APP/Contents/Helpers/deno" --version
jq -e . "$MANIFEST" > /dev/null

echo "==> Signing (ad hoc, inside-out)"
while IFS= read -r file; do
    codesign -v "$file" 2> /dev/null || codesign --force --sign - --timestamp=none "$file"
done < <(find "$APP/Contents/Helpers" "$APP/Contents/Resources/yt-dlp" -type f -perm -u+x \
    -exec sh -c 'file -b "$1" | grep -q Mach-O && echo "$1"' _ {} \;)
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=1 "$APP"

echo "==> Packing"
mkdir -p "$DIST"
ZIP="$DIST/kDownloader-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"
