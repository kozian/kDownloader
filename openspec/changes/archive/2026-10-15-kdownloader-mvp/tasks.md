# Tasks

## 1. Project skeleton

- [x] 1.1 Create `.gitignore` (`.build/`, `dist/`, `DerivedData`, `xcuserdata`) and verify that `git status` shows no build artifacts
- [x] 1.2 Create the Swift package `Packages/KDownloaderCore` (macOS 14, Swift Testing) with an empty module and a placeholder test; verify `swift test --package-path Packages/KDownloaderCore` passes
- [x] 1.3 Create the Xcode project `kDownloader` (SwiftUI App, macOS 14, arm64 only, no App Sandbox, synchronized `App/` folder) and link the local package; verify `xcodebuild -scheme kDownloader build` succeeds and the app opens an empty window
- [x] 1.4 Add `Localizable.xcstrings` with en (development) and ru; verify a test string is shown in Russian when launched with `-AppleLanguages (ru)`

## 2. Bundled tools and build

- [x] 2.1 Create `tools/manifest.json` with yt-dlp 2026.08.19 (`yt-dlp_macos.zip`), Deno 2.9.7 (`deno-aarch64-apple-darwin.zip`), ffmpeg 9.0.2 source tarball from ffmpeg.org: versions, URLs, SHA-256 (published checksums for yt-dlp and Deno, the tarball's own hash for ffmpeg), binary paths in archives; verify `jq . tools/manifest.json` succeeds
- [x] 2.2 Write `scripts/fetch-tools.sh` (download to `.build/tools-cache`, SHA-256 check, extract to `.build/tools`, caching); verify a successful run and a failure naming the tool when the `sha256` is altered in a copy of the manifest
- [x] 2.3 Write `scripts/build-ffmpeg.sh` (static arm64 build of ffmpeg and ffprobe per D12, cached) and call it from `fetch-tools.sh`; verify `otool -L` lists only system libraries, `lipo -archs` prints `arm64`, and the ffmpeg encoders list includes `aac`
- [x] 2.4 Add the "Embed Tools" build phase that copies the tools into the bundle per D12 (`Contents/Helpers/` and `Contents/Resources/yt-dlp/`); verify `Contents/Resources/yt-dlp/yt-dlp_macos --version`, `Contents/Helpers/ffmpeg -version` and `Contents/Helpers/deno --version` work from the built `.app` and `codesign --verify --deep --strict` passes
- [x] 2.5 Write `scripts/update-tools.sh` (latest yt-dlp/Deno via the GitHub API with published checksum verification, latest ffmpeg tarball from ffmpeg.org with `.asc` verification when `gpg` is available, manifest update via `jq`, printing changed versions); verify the run and that the updated manifest works with `fetch-tools.sh`
- [x] 2.6 Write `scripts/release.sh` (Release build for arm64, tool architecture and `--version` checks, inside-out ad-hoc signing, `codesign --verify --deep --strict`, `dist/kDownloader-<version>.zip`); verify the app from the extracted zip launches
- [x] 2.7 Document the fetch/update/release commands and manual installation (quarantine removal) in `README.md`; verify the commands run as written

## 3. Core: running tools and the log

- [x] 3.1 Implement `LogStore` (one file per launch in `~/Library/Logs/kDownloader/`, rotation to 10 files, stream of new lines); verify rotation and timestamped line format with unit tests
- [x] 3.2 Implement `ToolRunner` (Process, explicit environment, line-by-line stdout/stderr via `AsyncThrowingStream`, mirroring to the log, SIGINT→SIGTERM cancel); verify line output, exit code and cancellation with tests on `/bin/sh` scripts
- [x] 3.3 Implement `ToolLocator` and the launch-time tool check (existence, executability, `--version` with timeout); verify with a test on a temporary directory with a missing binary
- [x] 3.4 Wire the "The app is damaged" screen and tool versions in the About window into the app; verify manually by removing `ffmpeg` from the built bundle

## 4. Link analysis and error classification

- [x] 4.1 Implement the `VideoInfo`/`MediaFormat` models and decoding of `yt-dlp -J` JSON; add fixtures (YouTube video, video with combined formats, playlist, channel, live stream) and verify decoding with tests
- [x] 4.2 Implement URL validation (trim, http/https only); verify with tests on valid, empty and invalid strings
- [x] 4.3 Implement link type rules per D5 (reject `_type == playlist` and live/upcoming streams); verify with tests on the playlist, channel and live fixtures
- [x] 4.4 Implement `ErrorClassifier` with every category from the `media-analysis` spec plus the internal `cookiesUnavailable`; verify with a real-error-text fixture per category and the "Unknown error" fallback
- [x] 4.5 Implement `YtDlpClient.analyze` (common flags from D3, `-J`, rejecting playlists, channels and live streams); verify with a test using a fake executable script that returns fixtures
- [x] 4.6 Implement the UI: URL field, "Analyze"/"Cancel" buttons, indicator, single-video preview (thumbnail with placeholder, title, author, duration), error screen with details, "Retry" and "Open Log"; clear the preview when the URL changes; verify manually with a public YouTube video, a video-in-playlist link (only the video is analyzed), `https://example.com` and a playlist link

## 5. Format selection

- [x] 5.1 Implement `FormatCatalog`: compatible presets by height, "Best compatible", "Audio only (M4A)" with a re-encode flag, container selection, incompatibility and AV1 flags; verify with tests on fixtures (VP9 4K + H.264 1080p, VP9 only, Opus only, combined formats)
- [x] 5.2 Implement the UI for basic presets (default selection and the no-compatible-formats hint) and the advanced list (video + optional audio, flags, resulting container shown); verify manually on a YouTube video

## 6. Download

- [x] 6.1 Implement `OutputNamer` (name sanitization, length limit, ` (N)` suffixes, ID fallback); verify with tests
- [x] 6.2 Implement parsing of `KDPROGRESS` lines into stage, percentage, speed, ETA and size; verify with tests on recorded yt-dlp progress lines
- [x] 6.3 Implement `YtDlpClient.download` (flags from D6, `--print after_move:filepath --no-simulate`, cancel without cleanup); verify with a fake-script test for success, failure and cancel, checking that partial files are left untouched
- [x] 6.4 Implement destination folder settings (default `~/Downloads`, persistence, fallback with a notice when the folder is missing); verify with a test on `UserDefaults(suiteName:)`
- [x] 6.5 Implement the download UI: folder selection, input lock, stages and progress, "Cancel", success screen with "Show in Finder" and "New Download", error screen with "Retry"; verify manually a 1080p MP4 download, "Audio only", and cancelling halfway
- 6.6 — moved to the next change (manual check pending): see "Moved manual checks" below.

## 7. Browser cookies

- [x] 7.1 Implement `CookieRetryPolicy` (retry only for access categories, at most once, ask for a browser, decline); verify every branch from the `browser-cookies` spec with tests
- [x] 7.2 Implement detection of installed supported browsers and the browser setting; verify with a test using a list of bundle IDs and a stubbed detector
- [x] 7.3 Integrate the `--cookies-from-browser` retry into analysis and download, and pass the "with cookies" flag from analysis to the download; verify with a fake-script test that fails without the cookies flag and passes with it
- 7.4 — moved to the next change (manual check pending): see "Moved manual checks" below.
- 7.5 — moved to the next change (manual check pending): see "Moved manual checks" below.

## 8. Log UI

- 8.1 — moved to the next change (manual check pending): see "Moved manual checks" below.

## 9. Localization and final verification

- [x] 9.1 Translate all UI strings, errors and notifications into Russian; verify the String Catalog has no untranslated keys and visually check the UI with `-AppleLanguages (ru)`, `(en)` and `(de)`
- 9.2 — moved to the next change (manual check pending): see "Moved manual checks" below.

## 10. Revisions after the first review

- [x] 10.1 Decode `language` and `language_preference` into `MediaFormat`; add a multi-language fixture (YouTube video with dubbed tracks) and verify decoding with tests
- [x] 10.2 Extend `FormatCatalog` with audio tracks per language, the original-track default, compatible and full menu lists, and plans for "video + track" and "No video (audio only)"; verify with tests on the multi-language, Big Buck Bunny, Opus-only and combined-format fixtures
- [x] 10.3 Replace the radio presets with Video and Audio menus driven by "Show all formats" per the `format-selection` spec, showing languages and the original marker; verify manually on the multi-language video and Big Buck Bunny (both modes, audio only, VP9 → MKV)
- [x] 10.4 Rebuild the main window as one fixed layout with every control visible from launch and disabled until analysis succeeds; verify manually by snapshots of the launch, analyzing, ready, failed, downloading and finished states
- [x] 10.5 Start analysis when a valid link is pasted (multi-character insertion), not when typing; verify with a unit test of the paste detector and manually by pasting a link
- [x] 10.6 Label tracks as "Original · <format>" when no track reports a language, keeping language names otherwise; verify with catalog tests on the Me at the zoo fixture and a single-language (`en`) case, and manually on both kinds of video
- [x] 10.7 Treat the track as original when the tracks report at most one language and label original tracks "Original (<language>)" or "Original"; verify with catalog tests (single language, no language, dubbed) and manually on a video of each kind
- [x] 10.8 Move "Show all formats" into the Settings window as a persisted setting applied to the current menus immediately, and move the file type and size line next to the destination and Download; verify with a settings persistence test and snapshots of the main window and Settings

## Moved manual checks

Implemented, but the manual verification needs the user (system permission prompts, clicks, a release walkthrough). These checks continue in the next change:

- 6.6 Implement the completion system notification that reveals the result in Finder when clicked; verify manually with notifications allowed and denied
- 7.4 Implement the UI: browser choice dialog with "Don't use", and the "Cannot access Safari cookies" message with a button opening the "Full Disk Access" settings; verify manually on an age-restricted video with Safari, with and without FDA
- 7.5 Verify that the log after an operation with cookies contains the browser name and no cookie values (inspect an exported log)
- 8.1 Implement the log window ("Window → Log") with real-time updates, "Show in Finder" and "Export…" to `.txt`; verify manually opening it from an error screen and exporting
- 9.2 End-to-end check of the release build: run `scripts/release.sh`, extract the zip to another folder, and walk through "public video 1080p", "audio only", "advanced VP9 → MKV", "error: playlist link", "age restriction with cookies", "cancel"; record the results in the README ("Verified" section)

## Workflow follow-up

- Archive the change (`/opsx:archive`) after implementation and verification.
