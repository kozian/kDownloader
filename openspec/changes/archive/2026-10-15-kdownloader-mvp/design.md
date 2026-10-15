# Design: kDownloader MVP

## Context

The repository is empty apart from git and OpenSpec. See `proposal.md` for motivation and scope, and `specs/` for requirements. The development environment is Xcode 27 on Apple Silicon. `jq` and `python3` are available on the system; XcodeGen and Tuist are not installed. The app is not sandboxed and runs the bundled tools as child processes.

Current source artifacts at planning time:
- yt-dlp 2026.08.19: `yt-dlp_macos.zip` (onedir), `SHA2-256SUMS` (+ `.sig`);
- Deno 2.9.7: `deno-aarch64-apple-darwin.zip` + `.sha256sum`;
- ffmpeg/ffprobe 9.0.2: built from the official source tarball `ffmpeg-9.0.2.tar.xz` (ffmpeg.org publishes only `.asc` signatures, no checksum files). Prebuilt arm64 binaries from ffmpeg.martin-riedl.de were rejected: the host delivered ~1 KB/s from the development network.

## Goals / Non-Goals

**Goals:**
- Keep all UI-independent logic (JSON parsing, presets, error classification, naming, progress parsing, cookie retry policy) in a separate module that is tested with `swift test` without launching the app.
- Make yt-dlp invocations fully deterministic: fixed flags, foreign configs ignored, separate cache.
- Produce a release with a single command.

**Non-Goals:**
- An abstraction for backends other than yt-dlp.
- An architecture for queues or parallel downloads. We neither build for it nor block it: a download is encapsulated in its own task object.
- CI. All build scripts run locally.

## Decisions

### D1. Project layout: Xcode project + local Swift package
- `kDownloader.xcodeproj` uses Xcode file-system synchronized folders, so new files are picked up without editing `project.pbxproj`.
- `Packages/KDownloaderCore` is a SwiftPM package with models and pure logic, tested with Swift Testing and fixtures.
- The app target (`App/`) contains SwiftUI views, the `@Observable` state model, and adapters to the system: Process, NSWorkspace, notifications.
- *Alternatives:* XcodeGen or Tuist give a text-based project but add an environment dependency; a single monolithic target forces tests through `xcodebuild`, which is slower and harder to iterate on.

### D2. Screen state as an explicit state machine
One window; the state is an `enum`: `idle → analyzing → ready(VideoInfo) → downloading(Progress) → finished(URL) | failed(AppError)`, plus `toolsBroken` at launch. The app model is `@Observable`, and all transitions live in one place. This automatically enforces "one operation at a time", disabling the URL field during a download, and clearing the preview when the URL changes.

### D3. Running tools: `Process` + `AsyncStream`
- A single `ToolRunner` launches a binary and streams stdout/stderr line by line through `AsyncThrowingStream`, mirroring the output to the log. `YtDlpClient` is built on top of it.
- **Common flags for every invocation:** `--ignore-config`, `--no-playlist`, `--ffmpeg-location <Helpers>/ffmpeg`, `--js-runtimes deno:<Helpers>/deno`, `--cache-dir ~/Library/Caches/kDownloader/yt-dlp`, `-v` (for the log).
- **Process environment** is set explicitly: minimal `PATH`, `LANG=en_US.UTF-8`. The user environment is not inherited, which satisfies `bundled-tools`.
- **Cancel:** SIGINT, then SIGTERM after 5 seconds. No file cleanup (D4).
- **`--print` implies simulation in yt-dlp**, so every download that uses `--print` also passes `--no-simulate`.
- *Alternative:* embedding Python and yt-dlp as a library via PythonKit. It is harder to package and gives less isolation.

### D4. Temporary files stay in the destination folder
No separate temporary directory: yt-dlp writes `.part` files and intermediate streams (`*.fNNN.*`) next to the final file, its default behavior. After cancellation or failure the app does not delete anything; leftover files are the user's to manage manually. A side effect: a repeated download with the same output name lets yt-dlp continue an existing `.part` file. This is acceptable, but it is not presented as a resume feature.

### D5. Analysis and link type detection
- A single invocation: `-J --flat-playlist <url>`. Because `--no-playlist` is always set, a video-in-playlist URL resolves to the video; `--flat-playlist` keeps the rejection of playlist and channel links fast (entries are not extracted).
- **Playlists and channels:** if the result has `_type == playlist` (explicit playlist, channel, or channel tab), the app shows "Playlists and channels are not supported". No URL pattern heuristics are needed.
- **Live streams:** `live_status` in `is_live` or `is_upcoming` → "Live streams are not supported".

### D6. Choices computed from the analysis JSON (`FormatCatalog`)
- **Compatible video codecs:** `avc1*`, `hvc1*`, `hev1*`. Compatible audio: `mp4a*`.
- For each height, the best compatible video stream is picked: direct `https` downloads are preferred over HLS (`m3u8*`, slower fragmented downloads), then higher `tbr`, preferring H.264 on ties. It is paired with the best AAC stream, preferring regular streams over `-drc` (dynamic range compressed) variants.
- Formats that already carry both video and audio (`acodec != none`) with compatible codecs are candidates too. This matters for sites without separate DASH streams.
- **Container:** MP4 if all codecs are in `{avc1, hvc1, hev1, av01, mp4a}`, otherwise MKV.
- The "May not open in QuickTime" flag goes on everything outside that set; AV1 gets an extra flag.
- **The download uses concrete format IDs** (`-f 137+140`), so the download matches exactly what the user saw. Other flags: `--merge-output-format mp4|mkv`, `-o <absolute path>` (with `%` escaped), `--newline`, `--progress-template "download:KDPROGRESS %(progress)j"`, `--print after_move:filepath`, `--no-simulate`.
- **Audio only:** the selected AAC track ID, or a non-AAC track + `-x --audio-format m4a`.
- **Audio tracks by language:** `MediaFormat` carries `language` and `language_preference` from yt-dlp. Tracks are grouped by language; per language the best track is picked with the audio preference above. A track is original when its `language_preference` is the highest among tracks and positive, or its format note contains "original", or the tracks report at most one language (YouTube marks "original" only when dubs exist). The original track is selected by default, otherwise the first group, and is labeled "Original (<language>)" or "Original". Languages are shown with `Locale.current.localizedString(forIdentifier:)`. Video presets pair with the selected track, so the language choice applies to both video and audio-only downloads.
- **Menus:** both modes use the same two menus; the catalog provides the compatible lists (presets, one AAC track per language) and the full lists (every video format, every audio-only format). "No video (audio only)" is a separate menu value, not a format.
- **"Show all formats"** is a persisted setting (`UserDefaults`, shown in Settings), observed by the app model; the main window applies a change to the current choices immediately.

### D6a. Main window layout and paste detection
- The main window has one fixed layout: URL row, preview (placeholder until analysis), format block (Video and Audio menus), and a bottom block with the destination folder, the resulting file type and size, and the Download button. State changes enable and disable controls instead of swapping views; errors and progress appear in a status area between the preview and the format block.
- Paste detection: SwiftUI's `TextField` has no paste callback, so a change of `urlText` counts as a paste when more than one character was inserted at once and the new value is a valid link. Typing changes the text one character at a time and never triggers it.

### D7. Error classification by ordered rules on `ERROR:` text
`ErrorClassifier` is a pure function that takes stderr and the exit code and returns a category. The rules are an ordered list of regexes over known yt-dlp messages: `Unsupported URL`, `Private video`, `Sign in to confirm your age`, `Sign in to confirm you’re not a bot`, `members-only`, `not available in your country`, `HTTP Error 429`, `Unable to download webpage: … nodename nor servname`, `No space left on device`, `Permission denied`, `Postprocessing:` / `ffmpeg`, and so on. If no rule matches → "Unknown error". Cookie read failures (`could not find … cookies database`, `Operation not permitted` on `Cookies.binarycookies`) map to an internal `cookiesUnavailable` category. Every rule is covered by a fixture with real error text.

### D8. Cookie policy as a separate pure type
`CookieRetryPolicy` takes the error category and the current context (`cookiesUsed`, `browserChosen`) and decides whether to retry, ask for a browser, or show the final error. At most one retry per operation. The "analysis succeeded with cookies" flag is kept in the `ready` state and passed to the download.
- **Browsers:** Safari, Chrome, Firefox, Brave, Edge, Chromium, Opera, Vivaldi. Only installed ones are shown (detected by bundle ID via `NSWorkspace`).
- **The Safari button** opens `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`.

### D9. File naming
`OutputNamer` replaces `/`, `:` and control characters in the title with `-`, trims whitespace, limits the length to 200 UTF-8 bytes, and picks a free name with a ` (N)` suffix before yt-dlp starts. An empty title falls back to the video ID.

### D10. Settings and log
- **Settings:** `UserDefaults` stores the destination folder path and the cookie browser. Security-scoped bookmarks are not needed without a sandbox.
- **Log:** the `LogStore` actor writes a text file `~/Library/Logs/kDownloader/kDownloader-<timestamp>.log`, rotates to 10 files at launch, and publishes new lines for the log window. Cookies are never passed as arguments (only the browser name), so their values never reach the log.

### D11. Localization
String Catalog (`Localizable.xcstrings`): English as the development language, plus Russian. Error categories are localizable keys; original yt-dlp text is not localized.

### D12. Bundling tools and building
- `tools/manifest.json`: for each tool — `version`, `url`, `sha256`, archive type, and the binary path inside the archive. ffmpeg is listed as a source tarball with its pinned SHA-256.
- `scripts/fetch-tools.sh`: downloads to `.build/tools-cache/` (ignored by git), verifies with `shasum -a 256`, extracts to `.build/tools/`. A valid cache is not downloaded or rebuilt again. Zip archives do not keep symlinks, so the `Python.framework` inside the yt-dlp onedir arrives flattened (duplicate copies, broken bundle signature); `fetch-tools.sh` restores the standard framework symlinks and re-signs the framework ad hoc.
- `scripts/build-ffmpeg.sh` (called by `fetch-tools.sh`): builds static arm64 `ffmpeg` and `ffprobe` with `clang` for macOS 14, `--disable-autodetect` plus explicitly enabled system-only components (zlib, bzlib, iconv, AudioToolbox, VideoToolbox, Secure Transport for TLS), no `ffplay`, no docs. The result links only system libraries (checked with `otool -L`), so the build does not depend on Homebrew or anything else on the developer machine. The first build takes a few minutes and is then cached.
- **Xcode build phase "Embed Tools"** runs `fetch-tools.sh` and copies `ffmpeg`, `ffprobe` and `deno` into `Contents/Helpers/`, and the yt-dlp onedir into `Contents/Resources/yt-dlp/`. The onedir mixes Mach-O files with data files (`cacert.pem`, Python modules), and `codesign` rejects non-code files in `Helpers`, so it lives in `Resources`. The manifest is copied to `Contents/Resources/tools-manifest.json` for the About window.
- `scripts/update-tools.sh`: fetches the latest releases of yt-dlp and Deno via the GitHub API and verifies them against their published checksums. For ffmpeg, it takes the newest `ffmpeg-X.Y.Z.tar.xz` from `https://ffmpeg.org/releases/`, verifies the `.asc` signature when `gpg` is installed (otherwise prints a warning), and records the tarball's SHA-256. It then rewrites the manifest with `jq` and prints a version diff.
- `scripts/release.sh`: `xcodebuild` Release for arm64 → `lipo -archs`/`file` and `--version` check for every tool → ad-hoc signing inside-out (every Mach-O in `Helpers` and `Resources/yt-dlp`, then the `.app`, `codesign -s -`) → `codesign --verify --deep --strict` → `ditto -c -k --keepParent` into `dist/kDownloader-<version>.zip`.
- **Launch-time check:** the app verifies each tool exists and is executable, and runs `--version` in parallel with a 10-second timeout per tool. The results feed the About window and the log.
- *Alternative:* the onefile `yt-dlp_macos`. Each run unpacks it into a temp folder (+1–3 s), and nested signing of a PyInstaller onefile is unreliable.

## Risks / Trade-offs

- [YouTube changes behavior and the bundled yt-dlp goes stale] → `update-tools.sh` + `release.sh` let us ship a new build in minutes; "Unknown error" points the user to the log.
- [Gatekeeper blocks the ad-hoc signed app for recipients] → the README describes manual installation ("Open Anyway" or `xattr -dr com.apple.quarantine`), as in previous projects.
- [yt-dlp error texts change between versions] → the classifier is fixture-based; run the tests and check key scenarios manually after each yt-dlp update. Unknown errors are not lost and are shown with the original text.
- [The structure of the yt-dlp onedir archive may change] → the binary path inside the archive is set in the manifest; `release.sh` checks `--version` from the bundle.
- [ffmpeg is built locally, which adds build time and a configure step that may break on new ffmpeg or Xcode versions] → the build is cached, the configuration is minimal with no third-party libraries, and `release.sh` checks the result runs.
- [Without `gpg`, an ffmpeg update cannot verify the release signature] → the tarball is fetched over HTTPS from ffmpeg.org, the script warns loudly, and the SHA-256 is pinned for every later build.
- [No compatible formats above 1080p on YouTube] → a deliberate trade-off for compatibility; higher resolutions are available with "Show all formats".
- [Leftover `.part` and intermediate files in the destination folder] → accepted for the MVP by decision; cleanup is in the backlog.

## Migration Plan

Not applicable: first version. Rollback means using the previous zip release.
