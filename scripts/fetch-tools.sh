#!/usr/bin/env bash
# Downloads the tools listed in the manifest, verifies their SHA-256 and
# prepares them in the output directory. Valid results are cached.
#
# The license files of each tool (manifest "licenses") are written to
# <out>/licenses/<folder>/ on every run, so they always match the manifest:
# "url" entries are downloaded and verified like the tools, "fromArchive"
# entries are extracted from the verified tool archive ("{version}" in the
# path is replaced with the tool version).
#
# Usage: fetch-tools.sh [--manifest <path>] [--out <dir>]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/tools/manifest.json"
OUT="$ROOT/.build/tools"
CACHE="$ROOT/.build/tools-cache"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

# Xcode build phases run with a minimal PATH.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

mkdir -p "$OUT/.stamps" "$CACHE"

sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# Downloads <url> into the cache unless a file with the expected hash is there.
# The cache file is named after the URL unless a fourth argument names it.
fetch() {
    local name="$1" url="$2" sha="$3"
    local file="$CACHE/${4:-$(basename "$url")}"
    if [[ -f "$file" && "$(sha256_of "$file")" == "$sha" ]]; then
        echo "$file"
        return
    fi
    echo "==> Downloading $name from $url" >&2
    curl -fsSL --retry 3 -o "$file.tmp" "$url" >&2
    local actual
    actual="$(sha256_of "$file.tmp")"
    if [[ "$actual" != "$sha" ]]; then
        rm -f "$file.tmp"
        echo "error: checksum mismatch for $name" >&2
        echo "  expected: $sha" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
    mv "$file.tmp" "$file"
    echo "$file"
}

# Zip archives do not keep symlinks, so frameworks inside them arrive with
# their symlinks flattened into copies and a broken bundle signature.
# Restores the standard framework layout and re-signs it ad hoc.
repair_frameworks() {
    local fw name versions version sibling
    while IFS= read -r fw; do
        name="$(basename "$fw" .framework)"
        versions="$fw/Versions"
        [[ -d "$versions/Current" && ! -L "$versions/Current" ]] || continue
        version="$(ls "$versions" | grep -vx Current)"
        if [[ "$(wc -l <<<"$version")" -ne 1 ]]; then
            echo "error: cannot repair $fw: expected exactly one version" >&2
            exit 1
        fi
        rm -rf "$versions/Current"
        ln -s "$version" "$versions/Current"
        for entry in "$name" Resources; do
            if [[ -e "$fw/$entry" && ! -L "$fw/$entry" ]]; then
                rm -rf "${fw:?}/$entry"
                ln -s "Versions/Current/$entry" "$fw/$entry"
            fi
        done
        # A copy of the framework binary next to the framework was a symlink too.
        sibling="$(dirname "$fw")/$name"
        if [[ -f "$sibling" && ! -L "$sibling" ]] && cmp -s "$sibling" "$versions/$version/$name"; then
            rm "$sibling"
            ln -s "$name.framework/Versions/Current/$name" "$sibling"
        fi
        codesign --force --sign - --timestamp=none "$versions/$version" 2> /dev/null
    done < <(find "$1" -name "*.framework" -type d -prune)
}

count="$(jq '.tools | length' "$MANIFEST")"
for ((i = 0; i < count; i++)); do
    tool="$(jq -c ".tools[$i]" "$MANIFEST")"
    name="$(jq -r '.name' <<<"$tool")"
    version="$(jq -r '.version' <<<"$tool")"
    url="$(jq -r '.url' <<<"$tool")"
    sha="$(jq -r '.sha256' <<<"$tool")"
    kind="$(jq -r '.kind' <<<"$tool")"
    executable="$(jq -r '.executable' <<<"$tool")"
    stamp="$OUT/.stamps/$name"

    if [[ -f "$stamp" && "$(cat "$stamp")" == "$sha" && -x "$OUT/$executable" ]]; then
        echo "==> $name $version is up to date"
        continue
    fi

    archive="$(fetch "$name" "$url" "$sha")"
    rm -f "$stamp"

    case "$kind" in
        zip-directory)
            destination="$(jq -r '.destination' <<<"$tool")"
            rm -rf "${OUT:?}/$destination"
            mkdir -p "$OUT/$destination"
            ditto -x -k "$archive" "$OUT/$destination"
            repair_frameworks "$OUT/$destination"
            ;;
        zip-file)
            destination="$(jq -r '.destination' <<<"$tool")"
            archive_path="$(jq -r '.archivePath' <<<"$tool")"
            tmp="$(mktemp -d)"
            ditto -x -k "$archive" "$tmp"
            install -m 0755 "$tmp/$archive_path" "$OUT/$destination"
            rm -rf "$tmp"
            ;;
        ffmpeg-source)
            "$ROOT/scripts/build-ffmpeg.sh" "$archive" "$version" "$OUT"
            ;;
        *)
            echo "error: unknown kind '$kind' for $name" >&2
            exit 1
            ;;
    esac

    echo "$sha" > "$stamp"
    echo "==> $name $version ready"
done

# License files.
rm -rf "$OUT/licenses"
for ((i = 0; i < count; i++)); do
    tool="$(jq -c ".tools[$i]" "$MANIFEST")"
    jq -e '.licenses' <<<"$tool" > /dev/null || continue
    name="$(jq -r '.name' <<<"$tool")"
    version="$(jq -r '.version' <<<"$tool")"
    folder="$OUT/licenses/$(jq -r '.licenses.folder' <<<"$tool")"
    mkdir -p "$folder"
    archive=""
    while IFS= read -r entry; do
        as="$(jq -r '.as' <<<"$entry")"
        if jq -e '.url' <<<"$entry" > /dev/null; then
            file="$(fetch "$name license $as" "$(jq -r '.url' <<<"$entry")" "$(jq -r '.sha256' <<<"$entry")" \
                "license-$name-$version-$as")"
            cp "$file" "$folder/$as"
        else
            [[ -n "$archive" ]] || archive="$(fetch "$name" "$(jq -r '.url' <<<"$tool")" "$(jq -r '.sha256' <<<"$tool")")"
            path="$(jq -r '.fromArchive' <<<"$entry")"
            path="${path//\{version\}/$version}"
            case "$archive" in
                *.zip) unzip -p "$archive" "$path" > "$folder/$as" 2> /dev/null || true ;;
                *.tar.*) tar -xOf "$archive" "$path" > "$folder/$as" 2> /dev/null || true ;;
            esac
            if [[ ! -s "$folder/$as" ]]; then
                echo "error: $path not found in the $name $version archive" >&2
                exit 1
            fi
        fi
    done < <(jq -c '.licenses.files[]' <<<"$tool")
done
echo "==> Licenses ready in $OUT/licenses"
