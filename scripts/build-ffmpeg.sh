#!/usr/bin/env bash
# Builds static arm64 ffmpeg and ffprobe from an official source tarball.
# The result links only macOS system libraries and frameworks.
#
# Usage: build-ffmpeg.sh <source-tarball> <version> <output-dir>
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 <source-tarball> <version> <output-dir>" >&2
    exit 2
fi

TARBALL="$1"
VERSION="$2"
OUT="$3"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.build/ffmpeg-build/$VERSION"
SRC="$WORK/ffmpeg-$VERSION"
MIN_MACOS="14.0"

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"
tar -xJf "$TARBALL" -C "$WORK"

echo "==> Configuring ffmpeg $VERSION"
(
    cd "$SRC"
    ./configure \
        --cc=clang \
        --arch=arm64 \
        --target-os=darwin \
        --pkg-config=false \
        --enable-static \
        --disable-shared \
        --disable-doc \
        --disable-ffplay \
        --disable-debug \
        --disable-autodetect \
        --enable-zlib \
        --enable-bzlib \
        --enable-iconv \
        --enable-audiotoolbox \
        --enable-videotoolbox \
        --enable-securetransport \
        --extra-cflags="-arch arm64 -mmacosx-version-min=$MIN_MACOS" \
        --extra-ldflags="-arch arm64 -mmacosx-version-min=$MIN_MACOS" \
        --extra-libs="-liconv" \
        > "$WORK/configure.log" 2>&1 || { tail -n 40 "$WORK/configure.log" >&2; exit 1; }
)

echo "==> Building ffmpeg $VERSION (this takes a few minutes)"
make -C "$SRC" -j"$(sysctl -n hw.ncpu)" ffmpeg ffprobe > "$WORK/build.log" 2>&1 \
    || { tail -n 40 "$WORK/build.log" >&2; exit 1; }

for product in ffmpeg ffprobe; do
    install -m 0755 "$SRC/$product" "$OUT/$product"
    strip -x "$OUT/$product"
done

# The binaries must not depend on anything outside the system.
for product in ffmpeg ffprobe; do
    if otool -L "$OUT/$product" | tail -n +2 | awk '{print $1}' \
        | grep -vE '^(/usr/lib/|/System/Library/)' | grep -q .; then
        echo "error: $product links non-system libraries:" >&2
        otool -L "$OUT/$product" >&2
        exit 1
    fi
done

rm -rf "$WORK"
echo "==> ffmpeg $VERSION built into $OUT"
