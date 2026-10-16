#!/usr/bin/env bash
# Builds the update test app: a Debug build that bundles an older yt-dlp
# (tools/manifest-update-test.json), so the in-app update can be tested against
# the real latest release. It has its own bundle identifier, so its settings,
# installed updates (~/Library/Application Support/kDownloader-updatetest) and
# logs (~/Library/Logs/kDownloader-updatetest) stay apart from the regular app.
#
#     scripts/build-update-test.sh        # prints the path of the app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
DERIVED="$ROOT/.build/update-test"

xcodebuild -project kDownloader.xcodeproj -scheme kDownloader -configuration Debug -derivedDataPath "$DERIVED" \
    PRODUCT_BUNDLE_IDENTIFIER=com.kozian.kDownloader.updatetest \
    INFOPLIST_KEY_CFBundleDisplayName="kDownloader Update Test" \
    KD_TOOLS_MANIFEST="$ROOT/tools/manifest-update-test.json" \
    KD_TOOLS_DIR="$ROOT/.build/tools-update-test" \
    build > "$ROOT/.build/update-test.log" 2>&1 \
    || { tail -n 40 "$ROOT/.build/update-test.log" >&2; exit 1; }

APP="$DERIVED/Build/Products/Debug/kDownloader.app"
echo "yt-dlp in the test app: $("$APP/Contents/Resources/yt-dlp/yt-dlp_macos" --version)"
echo "$APP"
