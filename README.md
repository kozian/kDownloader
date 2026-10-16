# kDownloader

A simple macOS app for downloading videos from sites supported by
[yt-dlp](https://github.com/yt-dlp/yt-dlp). Paste a link, pick a preset and a
folder, get a file that plays in QuickTime.

- macOS 14 or later, Apple Silicon only.
- yt-dlp, ffmpeg/ffprobe and Deno are bundled inside the app; nothing from
  Homebrew or `PATH` is used.

## Repository layout

| Path | Contents |
|---|---|
| `App/` | SwiftUI app target (synchronized folder in `kDownloader.xcodeproj`) |
| `Packages/KDownloaderCore/` | UI-independent logic and its tests |
| `tools/manifest.json` | Pinned versions, URLs and SHA-256 of the bundled tools |
| `scripts/` | Tool fetching, ffmpeg build, tool updates, release packaging |
| `openspec/` | Specifications and change proposals |

## Building

Requirements: Xcode 27 (command line tools included), `jq` (ships with macOS).

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
A checksum mismatch stops the build and names the tool.

### Checking the UI from the command line (Debug builds)

Debug builds listen for a few distributed notifications, so UI flows can be
checked without Screen Recording or Accessibility permissions:

```sh
swiftc -o .build/snapshot scripts/snapshot.swift
.build/snapshot --session "type:https://www.youtube.com/watch?v=jNQXAC9IVRw"
.build/snapshot --session analyze
.build/snapshot --menu "Log"
.build/snapshot /tmp/shots        # renders every window to /tmp/shots/<title>.png
```

See `App/Debug/` for the full list of commands. None of this is compiled into
Release builds.

## App icon

The icon is generated from `Design/AppleIcon.png` (a TV body with a dark rounded
frame on a plain background):

```sh
swift scripts/make-icon.swift            # options: --source <png> --threshold 0.68
```

The script cuts the body out along the traced edge of its frame, places it on
Apple's macOS icon grid (824 px body on a 1024 px canvas, soft shadow) and writes
all 10 sizes plus `Contents.json` to `App/Assets.xcassets/AppIcon.appiconset/`.
The output is deterministic and committed, so builds do not run the script. If a
rebuilt Debug app still shows the old icon, refresh the LaunchServices cache:

```sh
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

## Updating the bundled tools

```sh
scripts/update-tools.sh
```

The script updates `tools/manifest.json` to the latest stable yt-dlp, Deno and
ffmpeg, sets `tools/manifest-update-test.json` (Debug builds) to the yt-dlp
release before the latest, and prints which versions changed. yt-dlp and Deno are checked against
the checksums published with their releases. For ffmpeg, the `.asc` signature
is verified only when `gpg` is installed and the FFmpeg release key
(`FCF986EA15E6E293A5644F10B4322F04D67658D8`) is imported; otherwise the script
prints a warning. Commit the updated manifest and make a new release.

## Releasing

The version under development lives in `Config/Version.xcconfig`. Release it with:

```sh
scripts/release.sh                 # or: scripts/release.sh --next 0.2.1
```

The script refuses uncommitted changes, an existing tag `v<version>` and an
existing `dist/kDownloader-<version>.zip`. It builds the Release configuration
for arm64, checks that every bundled tool is arm64 and reports its version, signs
the app ad hoc and verifies the signature, commits "Release <version>" with the
build number (git commit count of that commit), tags it, writes
`dist/kDownloader-<version>.zip` with its `.sha256`, and then raises the version
to the next minor (or `--next`) in a "Start <next> development" commit.

For a verification build that changes nothing, use:

```sh
scripts/release.sh --dry-run       # writes dist/kDownloader-<version>-dryrun.zip
```

## Installing (friends and family)

The app is signed ad hoc, not notarized, so Gatekeeper blocks the first launch.

1. Unzip `kDownloader-<version>.zip` and move `kDownloader.app` to
   `/Applications`.
2. Remove the quarantine flag:

   ```sh
   xattr -dr com.apple.quarantine /Applications/kDownloader.app
   ```

   Alternatively, try to open the app once, then click **Open Anyway** in
   **System Settings → Privacy & Security**.

To use cookies from Safari (for age-restricted or sign-in-only videos), grant
the app **Full Disk Access** in **System Settings → Privacy & Security**.
