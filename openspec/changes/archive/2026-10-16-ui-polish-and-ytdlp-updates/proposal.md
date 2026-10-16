# Proposal: UI polish and yt-dlp updates

## Why

Version 0.1.0 works, but it has no icon, the main window and Settings look unfinished, incompatible formats are marked with a bare "⚠︎", and the Russian wording mixes terms ("площадка", "загрузка"). The bigger risk is YouTube: it breaks yt-dlp every few weeks, and today the only fix is a new app release. Users should be able to update yt-dlp from inside the app.

## What Changes

- **App icon** from the image provided by the user (`Design/AppleIcon.png`, a TV on a beige background): a script cuts the body out along its detected outline and produces the whole `AppIcon.appiconset` on Apple's macOS grid (824 px body on a 1024 px canvas, soft shadow).
- **Main window polish:**
  - labels of the Video and Audio menus and "Save to" share one aligned label column;
  - errors, progress and completion use one card style;
  - "Download" is the prominent primary button;
  - a cleaner preview placeholder.
- **Clearer compatibility display:** with "Show all formats" on, the menus are grouped by format (e.g. "H.264 · MP4", "VP9 · MKV", "AV1 · MP4") with one entry per resolution. The best-compatible group comes first and is labeled "best compatibility with Mac"; the headers of other groups carry a warning icon and say what is needed ("needs a third-party player", "needs a Mac with M3 or later"). Entries show a display icon (video) or a speaker icon (audio). A line under the menus repeats this for the current choice.
- **Settings:** sections "Formats", "Browser cookies" and a new "yt-dlp" section with the current version, its source (bundled or updated), "Check for Updates", "Install" and "Use Bundled Version".
- **Consistent wording** in English and Russian, following one glossary (see design.md), for example "сайт" instead of "площадка" and "Скачать" for the action.
- **In-app yt-dlp updates:**
  - at launch, at most once a day, the app checks the latest yt-dlp release; when a newer version exists, an update icon appears between the link field and "Analyze" (tooltip, click opens Settings), and Settings show it as available;
  - the update is installed only when the user presses "Install";
  - the download is verified against the checksums published with the release and smoke-tested before use;
  - the app uses the newest valid installed version and falls back to the bundled one; "Use Bundled Version" returns to it;
  - ffmpeg, ffprobe and Deno are still updated only with app releases.
- **Manual checks carried over** from `kdownloader-mvp`: notifications, Safari cookies with Full Disk Access, log after an operation with cookies, "Open Log" and export, release walkthrough.

**Out of scope:** updating ffmpeg or Deno in the app, the yt-dlp nightly channel, updating the app itself (Sparkle), Developer ID and notarization.

## Capabilities

### New Capabilities
- `tool-updates`: checking for, installing, verifying and reverting yt-dlp updates from inside the app, and the update notice.

### Modified Capabilities
- `bundled-tools`: yt-dlp may come from a verified in-app update instead of the bundle; the About window shows which yt-dlp is used.
- `format-selection`: in the full list, formats are grouped by format with one entry per resolution; compatibility is shown by group headers (with a warning icon and the requirement for other groups) and a line under the menus; entries carry display or speaker icons.
- `localization`: UI wording follows a fixed glossary in both languages.
- `release-packaging`: the release includes an app icon generated from the source image.

## Impact

- New code in `KDownloaderCore`: release lookup, download, checksum verification, install directory management, version selection.
- The app: Settings window rework, update icon, main window layout, compatibility display, icon asset catalog.
- New script `scripts/make-icon.swift` and the source image `Design/AppleIcon.png`.
- Network: one request to the GitHub API at most once a day, plus the download when the user installs an update.
- Disk: updated yt-dlp versions in `~/Library/Application Support/kDownloader/yt-dlp/` (about 80 MB each; only the active and the previous version are kept).
