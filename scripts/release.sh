#!/usr/bin/env bash
# Releases the version under development (Config/Version.xcconfig).
#
#     scripts/release.sh [--dry-run [--old-ytdlp]] [--next X.Y.Z]
#
# 1. Refuses a dirty working tree, an existing tag v<version> or an existing
#    dist/kDownloader-<version>.zip, so a release never overwrites another one.
# 2. Builds Release for arm64, checks the bundled tools, signs ad hoc, verifies.
# 3. Sets the build number (git commit count of the release commit), commits
#    "Release <version>", tags v<version>, writes the zip and its .sha256.
# 4. Raises the version to --next (default: next minor) and commits
#    "Start <next> development", so later builds never carry a released number.
#
# --dry-run builds and verifies, writes dist/kDownloader-<version>-dryrun.zip and
# leaves git and the version untouched. Use it for every verification build.
# --dry-run --old-ytdlp bundles the previous yt-dlp release (the Debug manifest,
# tools/manifest-update-test.json) and writes …-dryrun-old-ytdlp.zip, so the
# in-app update can be tested from a packaged app.
# RELEASE_COMMIT_TRAILER, when set, is appended to both commit messages.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

XCCONFIG="Config/Version.xcconfig"
DERIVED="$ROOT/.build/release"
DIST="$ROOT/dist"
APP="$DERIVED/Build/Products/Release/kDownloader.app"

fail() { echo "release: $*" >&2; exit 1; }

DRY_RUN=0
OLD_YTDLP=0
NEXT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --old-ytdlp) OLD_YTDLP=1; shift ;;
        --next) NEXT="${2:-}"; shift 2 ;;
        *) fail "usage: scripts/release.sh [--dry-run [--old-ytdlp]] [--next X.Y.Z]" ;;
    esac
done
[[ "$OLD_YTDLP" == 1 && "$DRY_RUN" == 0 ]] && fail "--old-ytdlp is only for test archives; use it with --dry-run"
TOOLS_SETTINGS=()
if [[ "$OLD_YTDLP" == 1 ]]; then
    DERIVED="$ROOT/.build/release-old-ytdlp"
    APP="$DERIVED/Build/Products/Release/kDownloader.app"
    TOOLS_SETTINGS=(KD_TOOLS_MANIFEST="$ROOT/tools/manifest-update-test.json" KD_TOOLS_DIR="$ROOT/.build/tools-update-test")
fi

read_setting() { awk -F' = ' -v key="$1" '$1 == key {print $2}' "$XCCONFIG"; }
VERSION="$(read_setting MARKETING_VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "MARKETING_VERSION in $XCCONFIG is not X.Y.Z: '$VERSION'"
if [[ -z "$NEXT" ]]; then
    IFS=. read -r MAJOR MINOR _ <<<"$VERSION"
    NEXT="$MAJOR.$((MINOR + 1)).0"
fi
[[ "$NEXT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "--next must be X.Y.Z, got '$NEXT'"
[[ "$(printf '%s\n%s\n' "$VERSION" "$NEXT" | sort -V | tail -n 1)" == "$NEXT" && "$NEXT" != "$VERSION" ]] \
    || fail "next version $NEXT must be higher than $VERSION"

TAG="v$VERSION"
ZIP="$DIST/kDownloader-$VERSION.zip"
[[ "$DRY_RUN" == 1 ]] && ZIP="$DIST/kDownloader-$VERSION-dryrun.zip"
[[ "$OLD_YTDLP" == 1 ]] && ZIP="$DIST/kDownloader-$VERSION-dryrun-old-ytdlp.zip"

# 1. Preconditions.
if [[ "$DRY_RUN" == 0 ]]; then
    [[ -z "$(git status --porcelain)" ]] || fail "the working tree has uncommitted changes; commit or stash them first"
    git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && fail "tag $TAG already exists"
    [[ -e "$ZIP" ]] && fail "$ZIP already exists; a release never overwrites another one"
fi
echo "==> Releasing kDownloader $VERSION$([[ "$DRY_RUN" == 1 ]] && echo " (dry run)"), next version $NEXT"

# 2. Build and verify.
rm -rf "$DERIVED"
xcodebuild -project kDownloader.xcodeproj -scheme kDownloader -configuration Release \
    -derivedDataPath "$DERIVED" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO ${TOOLS_SETTINGS[@]+"${TOOLS_SETTINGS[@]}"} build > "$ROOT/.build/release.log" 2>&1 \
    || { tail -n 40 "$ROOT/.build/release.log" >&2; fail "Release build failed; see .build/release.log"; }

echo "==> Checking bundled tools"
check_tool() {
    local path="$1"; shift
    [[ -x "$path" ]] || fail "$path is missing or not executable"
    lipo -archs "$path" | tr ' ' '\n' | grep -qx arm64 || fail "$path has no arm64 slice ($(lipo -archs "$path"))"
    local output
    output="$("$path" "$@" 2>&1 | head -n 1)" || fail "$path failed to report its version"
    echo "    $(basename "$path"): $output"
}
check_tool "$APP/Contents/Resources/yt-dlp/yt-dlp_macos" --version
check_tool "$APP/Contents/Helpers/ffmpeg" -version
check_tool "$APP/Contents/Helpers/ffprobe" -version
check_tool "$APP/Contents/Helpers/deno" --version
jq -e . "$APP/Contents/Resources/tools-manifest.json" > /dev/null

BUILT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ "$BUILT" == "$VERSION" ]] || fail "built app reports $BUILT, expected $VERSION"

sign_and_pack() {
    echo "==> Signing (ad hoc, inside-out)"
    while IFS= read -r file; do
        codesign -v "$file" 2> /dev/null || codesign --force --sign - --timestamp=none "$file"
    done < <(find "$APP/Contents/Helpers" "$APP/Contents/Resources/yt-dlp" -type f -perm -u+x \
        -exec sh -c 'file -b "$1" | grep -q Mach-O && echo "$1"' _ {} \;)
    codesign --force --sign - --timestamp=none "$APP"
    codesign --verify --deep --strict "$APP" || fail "code signature of $APP is not valid"
    mkdir -p "$DIST"
    rm -f "$ZIP" "$ZIP.sha256"
    ditto -c -k --keepParent "$APP" "$ZIP"
    (cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
}

commit() {
    local message="$1"
    [[ -n "${RELEASE_COMMIT_TRAILER:-}" ]] && message="$message"$'\n\n'"$RELEASE_COMMIT_TRAILER"
    git add "$XCCONFIG"
    git commit -q -m "$message"
}

if [[ "$DRY_RUN" == 1 ]]; then
    sign_and_pack
    echo "==> Dry run: $ZIP ($(du -h "$ZIP" | awk '{print $1}')); git and the version are unchanged"
    exit 0
fi

# 3. Release commit and tag. The build number is the count of the release commit.
BUILD_NUMBER=$(( $(git rev-list --count HEAD) + 1 ))
sed -i '' -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$XCCONFIG"
# Rebuild so the app carries the build number.
xcodebuild -project kDownloader.xcodeproj -scheme kDownloader -configuration Release \
    -derivedDataPath "$DERIVED" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build > "$ROOT/.build/release.log" 2>&1 \
    || { git checkout -- "$XCCONFIG"; fail "Release build failed; see .build/release.log"; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")" == "$BUILD_NUMBER" ]] \
    || { git checkout -- "$XCCONFIG"; fail "built app does not carry build number $BUILD_NUMBER"; }
sign_and_pack
commit "Release $VERSION"
[[ "$(git rev-list --count HEAD)" == "$BUILD_NUMBER" ]] || fail "release commit is #$(git rev-list --count HEAD), expected #$BUILD_NUMBER"
git tag -a "$TAG" -m "kDownloader $VERSION ($BUILD_NUMBER)"

# 4. Start the next version right away.
sed -i '' -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $NEXT/" "$XCCONFIG"
commit "Start $NEXT development"

echo "==> Released kDownloader $VERSION ($BUILD_NUMBER): tag $TAG, $ZIP"
cat "$ZIP.sha256"
echo "==> Version under development is now $NEXT"
