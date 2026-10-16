# Design: UI polish and yt-dlp updates

## Context

See `proposal.md` for motivation. Current state (v0.1.0):

- yt-dlp is bundled as a PyInstaller onedir build in `Contents/Resources/yt-dlp/`; `ToolLocator(appBundle:)` points there, `ToolChecker` checks every tool at launch, `YtDlpClient` is created once in `AppModel`.
- `scripts/fetch-tools.sh` already knows how to verify `yt-dlp_macos.zip` against `SHA2-256SUMS` and how to repair the `Python.framework` inside it (zip flattens its symlinks, so the bundle signature is invalid until symlinks are restored and the framework is re-signed ad hoc).
- The app is not sandboxed and signed ad hoc; files downloaded by the app itself through `URLSession` get no quarantine attribute, so they run without Gatekeeper prompts.
- Settings is a two-row `Form` (`LabeledContent` rows); the main window is one fixed layout (`ContentView.swift`); incompatible formats get a "⚠︎" suffix and an orange note.
- The project has no asset catalog yet; `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` is already set.

## Goals / Non-Goals

**Goals:**
- Keep update logic in `KDownloaderCore`, testable with a fake HTTP layer and a fake yt-dlp archive.
- Never leave the app without a working yt-dlp: every failure path ends with the previous or the bundled version.
- One source of truth for wording (the glossary below) and for the icon (one source image).

**Non-Goals:**
- Updating ffmpeg, ffprobe or Deno at runtime, the nightly channel, delta updates.
- Background updates while the app is not running.

## Decisions

### D1. Release lookup and verification
- `GET https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest` → `tag_name` and the asset URLs of `yt-dlp_macos.zip` and `SHA2-256SUMS`.
- The archive is verified with SHA-256 (CryptoKit) against the line for `yt-dlp_macos.zip` in `SHA2-256SUMS` of the same release. Trust is the same as at build time: HTTPS to GitHub and the checksum file of the release. (GPG verification of `SHA2-256SUMS.sig` stays out of scope: no gpg on users' Macs.)
- Versions are yt-dlp tags `YYYY.MM.DD[.N]`, compared component by component as integers.
- Network access goes through a small `HTTPClient` protocol (data request, file download with progress); the app uses `URLSession`, tests use a fake that serves fixture files.

### D2. Installing
1. Download to `~/Library/Application Support/kDownloader/yt-dlp/.incoming-<uuid>/yt-dlp_macos.zip`.
2. Verify the checksum; on mismatch delete the folder and fail with "The download is damaged".
3. Extract with `/usr/bin/ditto -x -k`.
4. Repair frameworks (same algorithm as `fetch-tools.sh`, ported to Swift: restore `Versions/Current`, top-level symlinks and the sibling symlink of the framework binary) and re-sign each repaired framework with `/usr/bin/codesign --force --sign -`.
5. Run `yt-dlp_macos --version` with a timeout; the output must equal the tag.
6. Atomically rename the folder to `yt-dlp/<version>/`, then delete installed versions other than the new and the previous one.

Any failure deletes the incoming folder and keeps the active version. Installation is refused while an analysis or download is running (the button is disabled; the core also checks a flag passed by the app).

### D3. Choosing the active yt-dlp at launch
- Candidates: installed versions newer than the bundled one, newest first, then the bundled one.
- `ToolChecker` checks yt-dlp candidates in that order and takes the first that answers `--version`; a broken update is logged and skipped. Only a broken bundled yt-dlp leads to the damaged-app screen, as before.
- `ToolLocator` gets the chosen yt-dlp path; `AppModel` keeps `activeYtDlp: (version, source: .bundled | .updated)` and rebuilds `YtDlpClient` after an install or a revert. `SessionModel` reads `app.ytDlp` at the start of each operation, so a running operation is never switched mid-way.

### D4. Check scheduling and state
- `UserDefaults`: `ytDlpLastCheck` (date), `ytDlpLatestVersion` (string), `ytDlpDismissedVersion` (string).
- The daily check runs after the launch tool check, in a background task; it only updates the stored state. No timers: the app is usually short-lived, and a check at launch is enough.
- The main window only shows an update icon (`arrow.down.circle.fill`, accent color) between the URL field and "Analyze" when `latest > active` or an install is running; its `.help` names the version, and a click calls `openSettings()` (macOS 14). Cards, progress and errors of updates live only in Settings. The "dismissed" state from the first version of this design is no longer used by the UI.

### D5. Compatibility display and grouping
- `FormatCatalog` gets format groups for the full lists: video groups keyed by codec family (H.264, HEVC, VP9, AV1, other) plus the container the result would get (`fitsMP4` rule), audio groups keyed by codec family (AAC, Opus, other). Within a group one entry per resolution (height and fps) or, for audio, per language and bitrate; duplicates resolve with the existing preference (direct before HLS, higher bitrate, regular before DRC).
- Group order: the best-compatible group (H.264/HEVC, AAC) first, then the others by best resolution.
- `FormatGroup.requirement`: `nil` for the best-compatible group, `.thirdPartyPlayer` when the result is MKV (VP9, Opus, unknown codecs), `.m3OrLater` for AV1 in MP4. Facts behind them: QuickTime does not open MKV in any macOS version; AV1 is decoded only by the hardware decoder of M3 and later Apple chips (macOS 14+).
- Menus: SwiftUI `Section` per group with a text header ("H.264 · MP4 — best compatibility with Mac", "VP9 · MKV — ⚠︎ needs a third-party player"); the warning appears only in headers, never on entries, to keep the menu light. Entries are `Label`s with the `display` symbol (video) or `speaker.wave.2` (audio). Whether macOS 27 renders symbols in the menu is checked on the first build; if it does not, entries stay plain text.
- The warning in section headers is the text sign "⚠︎" (SwiftUI menu section headers render text only). A red "❗️" was tried and rejected by the user: the orange icon next to the menu already draws attention.
- The main window shows no note for the best compatibility. A function `compatibilityIssues(video:audio:)` tells which menu lowers compatibility (video: VP9/unknown codec → MKV, AV1 → M3; audio: Opus/unknown → MKV); that menu gets an orange `exclamationmark.triangle.fill` to its right (orange, not red: red reads as an error) with the requirement as `.help` tooltip. The app registers `NSInitialToolTipDelay` = 100 ms so tooltips appear almost at once instead of after the system delay.

### D6. Main window layout
- One `Grid` with a trailing-aligned label column for "Video", "Audio" and "Save to", so the controls start at the same x.
- `StatusCard(kind: .info | .success | .warning, …)` replaces the three hand-made backgrounds (error, progress, completion) and is reused by the update notice.
- "Download" uses `.borderedProminent` and `.controlSize(.large)`; the file type and size line stays to its left.
- Preview placeholder: rounded rectangle with the `play.rectangle` symbol and the hint text in the title area.

### D7. Settings
Three `LabeledContent` rows separated by spacing: "Formats" (toggle + note), "Browser cookies" (picker + note), "yt-dlp" (version and source, status line, "Check for Updates", "Install" when available, "Use Bundled Version" when an update is active, install progress). Width stays 500 pt; snapshots in both languages.

### D8. Glossary

| Concept | English | Russian | Not used |
|---|---|---|---|
| where videos come from | site | сайт | площадка |
| main action | Download | Скачать | Загрузить |
| running process | Downloading | Скачивание | Загрузка |
| result | Download complete | Видео скачано | Загрузка завершена |
| folder in Finder | Downloads (system name) | Загрузки (system name) | — |
| inspecting a link | Analyze | Анализировать | — |
| audio stream | audio track | аудиодорожка | дорожка звука |
| first audio of a video | Original | Оригинал | — |
| the in-app log | Log | Журнал | Лог |
| yt-dlp shipped with the app | bundled version | встроенная версия | — |
| H.264/HEVC + AAC result | best compatibility with Mac | лучшая совместимость с Mac | открывается в QuickTime, совместимое |
| MKV result | needs a third-party player | нужен сторонний плеер | — |
| AV1 result | needs a Mac with M3 or later | нужен Mac с M3 или новее | — |

The catalog is rewritten against this table; the generator script reports any Russian value that contains a "Not used" word.

### D9. App icon
- Source: `Design/AppleIcon.png` (1024×1024, a TV body with a dark rounded frame on a beige background with its own drop shadow). `Design/AppleIcon.jpeg` is the same picture and is not used.
- Vision's subject mask (`VNGenerateForegroundInstanceMaskRequest`) was tried and rejected: it leaves a wavy edge and a light fringe of background and shadow.
- `scripts/make-icon.swift` (AppKit/Core Graphics, run with `swift`) instead traces the outer edge of the frame: rays from the center of the dark-pixel bounds, walking inward until luminance crosses the threshold between background and frame, with sub-pixel interpolation; the radius profile is averaged over the four mirror symmetries, lightly smoothed and moved 1 px inward. The body is clipped with that outline, scaled into an 824 px square centered on a 1024 px transparent canvas, and gets a soft shadow (offset −10, blur 22, 32% black). The threshold is a parameter of the script.
- The script writes the 10 PNGs (16–512 pt at 1× and 2×) and `Contents.json` into `App/Assets.xcassets/AppIcon.appiconset/`; the generated files are committed, so builds do not depend on the script. A prototype of this approach produced a clean edge on light and dark backgrounds.

### D10. Versions and releases
- `Config/Version.xcconfig` holds `MARKETING_VERSION` (the version under development) and `CURRENT_PROJECT_VERSION` (build number = git commit count of the release commit); it is the base configuration of every build configuration, and the keys are removed from `project.pbxproj`. After v0.1.0 the version under development is 0.2.0.
- `scripts/release.sh [--dry-run] [--next X.Y.Z]` releases the version in the xcconfig: refuses a dirty tree, an existing tag `v<version>` or an existing `dist/kDownloader-<version>.zip`; builds and verifies; sets the build number, commits "Release <version>", tags; writes the zip and its `.sha256`; then sets the next version (next minor by default) and commits "Start <next> development". `--dry-run` writes `dist/kDownloader-<version>-dryrun.zip` and leaves git untouched; verification builds use only this mode.

### D11. Update test build
- `tools/manifest-update-test.json` is the release manifest with the previous yt-dlp release (now 2026.07.04, one before the bundled 2026.08.19).
- The Debug configuration sets the build settings `KD_TOOLS_MANIFEST = $(SRCROOT)/tools/manifest-update-test.json` and `KD_TOOLS_DIR = $(SRCROOT)/.build/tools-update-test`; the embed phase and `fetch-tools.sh` honor them, so every Debug build offers the real latest release as an update. Release builds (and `release.sh`, also with `--dry-run`) use the release manifest.
- `scripts/update-tools.sh` rewrites the Debug manifest after the release manifest: same tools, yt-dlp set to the newest non-prerelease release older than the one in the release manifest, checksum from that release's `SHA2-256SUMS`.
- `scripts/release.sh --dry-run --old-ytdlp` builds the Release configuration with the Debug manifest's tools and writes `dist/kDownloader-<version>-dryrun-old-ytdlp.zip` (refused without `--dry-run`), so the update can be tested from a packaged app.
- `scripts/build-update-test.sh` builds a separate app with bundle identifier `com.kozian.kDownloader.updatetest`, `.build/update-test`; the app derives its Application Support and log folders from the bundle identifier (`kDownloader-updatetest`), so tests there never touch the regular app.

## Risks / Trade-offs

- [GitHub API rate limit (60 requests/hour without a token)] → one request a day per user; a 403 is treated as a failed check and logged.
- [yt-dlp changes the onedir layout] → the smoke test refuses the update; the bundled or previous version stays active.
- [An updated yt-dlp works with `--version` but fails on real sites] → "Use Bundled Version" reverts; the previous installed version is kept as well.
- [About 80 MB per installed version] → at most two versions are kept.
- [`codesign` or `ditto` missing] → both are part of macOS; a failure is reported as "The update could not be installed" with details in the log.
- [Russian wording changes may lengthen labels] → snapshots of every screen in both languages before finishing.

## Open Questions

- None.
