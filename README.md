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

## Updating the bundled tools

```sh
scripts/update-tools.sh
```

The script updates `tools/manifest.json` to the latest stable yt-dlp, Deno and
ffmpeg and prints which versions changed. yt-dlp and Deno are checked against
the checksums published with their releases. For ffmpeg, the `.asc` signature
is verified only when `gpg` is installed and the FFmpeg release key
(`FCF986EA15E6E293A5644F10B4322F04D67658D8`) is imported; otherwise the script
prints a warning. Commit the updated manifest and make a new release.

## Releasing

Bump `MARKETING_VERSION` in the project, then:

```sh
scripts/release.sh
```

It builds the Release configuration for arm64, checks that every bundled tool
is arm64 and reports its version, signs the app ad hoc, verifies the signature
and writes `dist/kDownloader-<version>.zip`.

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
