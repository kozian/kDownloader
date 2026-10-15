# Proposal: kDownloader MVP

## Why

Downloading videos with yt-dlp from the terminal is inconvenient: users have to remember flags, understand format codes, and manually pick combinations that play in QuickTime. We want a simple native macOS app: paste a link, pick a clear preset and a folder, and get a file that opens on any Mac. The project is empty and this is the first version, so the scope is deliberately minimal.

## What Changes

- A new SwiftUI app, kDownloader, for macOS 14+ on Apple Silicon, not sandboxed.
- URL input through a text field only; pasting a valid link starts analysis immediately. All controls are visible from launch and disabled until analysis succeeds. Analysis shows a preview (thumbnail, title, author, duration) or a clear localized error from a fixed list of categories.
- Single videos only. A link to a video inside a playlist downloads only that video. Explicit playlist links, channel links and live streams are rejected with an error.
- Format selection:
  - two menus, Video and Audio; by default they list only QuickTime-compatible choices (H.264/HEVC + AAC in MP4), with "Best compatible" preselected;
  - "No video (audio only)" in the Video menu saves M4A/AAC;
  - audio tracks show their language, the original track is preselected;
  - "Show all formats" switches both menus to every format (including VP9/AV1/Opus), with incompatible formats flagged.
- Destination folder: defaults to Downloads, the last choice is remembered. Temporary and partial files stay in the destination folder, and the app does not clean them up.
- One download at a time: progress, speed, remaining time, cancel. On completion: a system notification and "Show in Finder".
- Browser cookies: an operation runs without cookies first. If it fails with an access-related error, it is retried once with cookies from the selected browser.
- Activity log: viewing in the app and export to a file.
- Localization: Russian and English.
- Bundled tools: yt-dlp, ffmpeg/ffprobe and Deno are packaged into the app. Their versions are pinned in a manifest, and build-time scripts update them and verify SHA-256 checksums.
- Release build: a zip with an ad-hoc signed `.app`, installed manually.

**Out of scope (backlog):** playlists (planned for a future version), channels, download queues and parallel downloads, history, resuming downloads as a feature, cleanup of temporary files, runtime dependency management, drag & drop and clipboard auto-fill, subtitles and metadata embedding, Sparkle, Developer ID and notarization, live streams.

## Capabilities

### New Capabilities
- `media-analysis`: URL input (including analysis on paste), main window layout, link analysis, video preview, link type rules (single video only; playlists, channels and live streams rejected), and error classification into clear categories.
- `format-selection`: Video and Audio menus with compatible and full lists, audio track languages, audio-only mode.
- `media-download`: destination folder, running a download, progress, cancel, file naming, notification and "Show in Finder".
- `browser-cookies`: retrying with browser cookies after an access error, browser selection, and handling denied cookie access.
- `diagnostic-logs`: writing the operation log, viewing and exporting it.
- `localization`: Russian and English UI based on the system language.
- `bundled-tools`: bundled external tools, startup checks, tool versions display.
- `release-packaging`: release build with pinned tool versions, checksum verification, ad-hoc signing, and a zip artifact.

### Modified Capabilities
- none (new project)

## Impact

- A new Xcode project (SwiftUI, Swift Concurrency, Observation), minimum macOS 14, arm64 architecture.
- External binary dependencies inside the bundle: yt-dlp (`yt-dlp_macos.zip`, onedir), ffmpeg and ffprobe (static arm64 builds), Deno (`deno-aarch64-apple-darwin`).
- Build scripts: tool download and verification, version manifest update, release packaging.
- System permissions: notifications; Full Disk Access when using Safari cookies; Keychain access prompts when using cookies from Chromium-based browsers.
