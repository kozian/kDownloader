# Developing kDownloader

How to build, test and release the app. For what the app does and how to use it,
see [README.md](README.md).

## Repository layout

| Path | Contents |
|---|---|
| `App/` | SwiftUI app target (synchronized folder in `kDownloader.xcodeproj`) |
| `Packages/KDownloaderCore/` | UI-independent logic and its tests |
| `tools/manifest.json` | Pinned versions, URLs and SHA-256 of the bundled tools and their license files |
| `scripts/` | Tool fetching, ffmpeg build, tool updates, release packaging |
| `Config/Version.xcconfig` | The version under development |
| `Design/AppIcon.png` | Source picture of the app icon |
| `docs/` | Pictures for the README |
| `openspec/` | Specifications (`specs/`) and change proposals (`changes/`) |
| `.claude/skills/` | Workflows for Claude Code: OpenSpec and `release-update` |
| `BACKLOG.md` | Tasks and ideas not yet taken into a change |

Behavior is specified first: a change is proposed in `openspec/changes/`
(proposal, spec deltas, design, tasks), implemented, then archived, which merges
its deltas into `openspec/specs/`.

## Building

Requirements: macOS 14+ on Apple Silicon, Xcode 27 (command line tools
included), `jq` (ships with macOS).

```sh
# Run the core tests
swift test --package-path Packages/KDownloaderCore

# Also install the real latest yt-dlp release into a temporary folder
KD_NETWORK_TESTS=1 swift test --package-path Packages/KDownloaderCore --filter LiveUpdateTests

# Build the app; the "Embed Tools" build phase downloads, verifies and
# prepares the tools on first build (ffmpeg is compiled from source, ~1 min)
xcodebuild -project kDownloader.xcodeproj -scheme kDownloader build
```

The tools can also be prepared without Xcode:

```sh
scripts/fetch-tools.sh
```

Downloads are cached in `.build/tools-cache`, prepared tools in `.build/tools`.
A checksum mismatch stops the build and names the tool or license file.

### Checking the UI from the command line (Debug builds)

Debug builds listen for a few distributed notifications, so UI flows can be
checked without Screen Recording or Accessibility permissions:

```sh
swiftc -o .build/snapshot scripts/snapshot.swift
.build/snapshot --session "type:https://www.youtube.com/watch?v=jNQXAC9IVRw"
.build/snapshot --session analyze
.build/snapshot --menu "Log"
.build/snapshot --click "About kDownloader@120,40"   # click in a window by title
.build/snapshot /tmp/shots        # renders every window to /tmp/shots/<title>.png
```

See `App/Debug/` for the full list of commands. None of this is compiled into
Release builds.

## App icon

The icon is generated from `Design/AppIcon.png` (a TV body with a dark rounded
frame on a plain background):

```sh
swift scripts/make-icon.swift            # options: --source <png> --threshold 0.68
```

The script cuts the body out along the traced edge of its frame, places it on
Apple's macOS icon grid (824 px body on a 1024 px canvas, soft shadow) and writes
all 10 sizes plus `Contents.json` to `App/Assets.xcassets/AppIcon.appiconset/`.
The output is deterministic and committed, so builds do not run the script. If a
rebuilt app that was launched before from the same path still shows the old
icon, refresh the LaunchServices cache (`touch` is needed):

```sh
touch <path to kDownloader.app>
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f <path to kDownloader.app>
```

## Localization

Command-line builds do not add new keys to `App/Localizable.xcstrings`. After a
build, check the catalog against the strings the compiler extracted:

```sh
python3 scripts/check-localization.py
```

It lists missing keys, missing Russian translations, unused entries and Russian
wording the glossary rules out ("площадка", "Загрузить", …).

## Testing yt-dlp updates

Debug builds bundle the yt-dlp release before the one in `tools/manifest.json`
(`tools/manifest-update-test.json`, kept one release behind by
`scripts/update-tools.sh`), so every Debug build offers the real latest release
as an update. Release builds and `release.sh --dry-run` bundle the latest one.

To test without touching the regular app's settings and installed updates, build
the separate update test app:

```sh
scripts/build-update-test.sh     # prints the path of the test app
```

The test app has its own bundle identifier (`com.kozian.kDownloader.updatetest`),
settings, installed updates (`~/Library/Application Support/kDownloader-updatetest`)
and logs (`~/Library/Logs/kDownloader-updatetest`), so it never touches the
regular app. Open it, install the offered update, relaunch to see it used, and
press "Use Bundled Version" in Settings to go back.

`scripts/release.sh --dry-run --old-ytdlp` writes
`dist/kDownloader-<version>-dryrun-old-ytdlp.zip`: the regular app with the
previous yt-dlp, for testing the update from a packaged app.

## Updating the bundled tools

```sh
scripts/update-tools.sh
```

The script updates `tools/manifest.json` to the latest stable yt-dlp, Deno and
ffmpeg, sets `tools/manifest-update-test.json` (Debug builds) to the yt-dlp
release before the latest, and prints which versions changed. yt-dlp and Deno
are checked against the checksums published with their releases. For ffmpeg, the
`.asc` signature is verified only when `gpg` is installed and the FFmpeg release
key (`FCF986EA15E6E293A5644F10B4322F04D67658D8`) is imported; otherwise the
script prints a warning. The license files of yt-dlp and Deno are repinned to
the new release tags (see [License notices](#license-notices)). Commit the
updated manifests and make a new release.

## Releasing

The version under development lives in `Config/Version.xcconfig`. A new feature
is released as the next minor version (`0.3.0`); everything else (tool updates,
licenses, icon, fixes) as a patch of the last release (`0.2.3`): set
`MARKETING_VERSION` to the patch version first and pass the development version
as `--next`.

```sh
scripts/release.sh                 # or: scripts/release.sh --next 0.3.0
```

The script refuses uncommitted changes, an existing tag `v<version>` and an
existing `dist/kDownloader-<version>.zip`. It builds the Release configuration
for arm64, checks that every bundled tool is arm64 and reports its version,
checks that every license file is in the app, signs the app ad hoc and verifies
the signature. Then it commits "Release <version>" with the build number (git
commit count of that commit), tags it, writes the source of the bundled FFmpeg
(`dist/ffmpeg-<ffmpeg version>.tar.xz` with its `.sha256`, kept if already
there) and `dist/kDownloader-<version>.zip` with its `.sha256`, and raises the
version to the next minor (or `--next`) in a "Start <next> development" commit.

For a verification build that changes nothing, use:

```sh
scripts/release.sh --dry-run       # writes dist/kDownloader-<version>-dryrun.zip
```

### Publishing

The repository is [kozian/kDownloader](https://github.com/kozian/kDownloader).
Only the new version gets a GitHub release, with the zip, the FFmpeg source
(required by the LGPL, attached every time) and their checksums:

```sh
git push origin main
git push origin v<version>
gh release create v<version> --verify-tag --latest --title "kDownloader <version>" \
  --notes-file <notes.md> \
  dist/kDownloader-<version>.zip dist/kDownloader-<version>.zip.sha256 \
  dist/ffmpeg-<ffmpeg version>.tar.xz dist/ffmpeg-<ffmpeg version>.tar.xz.sha256
```

The `release-update` skill in `.claude/skills/` describes the whole flow, from
updating the tools to checking the published files.

## License notices

The license texts of the bundled tools are not kept in this repository. Each
tool in `tools/manifest.json` lists its license files: downloaded from the
upstream repository at the release tag (pinned with SHA-256), or taken from the
verified tool archive. `scripts/fetch-tools.sh` prepares them in
`.build/tools/licenses/`, and the "Embed Tools" build phase copies them into
`Contents/Resources/Licenses/` together with kDownloader's `LICENSE`, the ffmpeg
build script and a generated `FFmpeg/BUILD.txt` (version, source URL and
checksum, configure options of the built binary). `release.sh` refuses a build
without them.
