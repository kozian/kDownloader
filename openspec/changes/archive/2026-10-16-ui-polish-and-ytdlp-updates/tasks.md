# Tasks

## 1. yt-dlp updates: core

- [x] 1.1 Add yt-dlp version parsing and comparison (`YYYY.MM.DD[.N]`); verify with unit tests including `.N` suffixes and equal versions
- [x] 1.2 Add the `HTTPClient` protocol with a `URLSession` implementation and a test fake; implement the release lookup (latest tag, asset URLs, checksum for `yt-dlp_macos.zip`); verify with tests on recorded GitHub API and `SHA2-256SUMS` fixtures
- [x] 1.3 Implement the installer per D2 (download, SHA-256, `ditto`, framework repair and ad-hoc re-sign, `--version` smoke test, atomic rename, keep two versions); verify with tests on a fake archive: success, checksum mismatch, wrong version output, cleanup of old versions, incoming folder removed on failure
- [x] 1.4 Implement the active-version choice per D3 (installed updates newer than bundled, newest first, fallback to bundled) and the revert; verify with tests on temporary install folders with a broken and a working update
- [x] 1.5 Implement the update state per D4 (last check, latest known, dismissed) and the "once a day" rule; verify with tests on `UserDefaults(suiteName:)` and an injected clock

## 2. yt-dlp updates: app

- [x] 2.1 Use the chosen yt-dlp in `ToolLocator`/`ToolChecker`/`AppModel`, rebuild `YtDlpClient` after install or revert, show the source in About; verify manually with an installed update, a deliberately broken update and the bundled version (log and About)
- [x] 2.2 Run the daily check after launch and show the update notice in the main window with "Install" and "Not Now", disabled during analysis and download; verify by snapshots with a stubbed newer version
- [x] 2.3 Add the "yt-dlp" section to Settings (version and source, Check for Updates, Install with progress, Use Bundled Version, errors); verify by snapshots and a real install of the current release over an older bundled manifest in a Debug build

## 3. Compatibility display

- [x] 3.1 Add format groups (codec + container, one entry per resolution, duplicates resolved by preference, best-compatible group first, requirement per group) and `compatibility(video:audio:)` to `FormatCatalog` per D5; verify with tests on the Big Buck Bunny, multi-language and combined-format fixtures
- [x] 3.2 Show the grouped menus with section headers (warning icon and requirement only in headers), display icons on video entries and speaker icons on audio entries, and the compatibility line, replacing "⚠︎" suffixes and badges; verify by snapshots with H.264+AAC, VP9+Opus and AV1 selections and by checking that macOS 27 renders the symbols in the menu (fallback per D5)

## 4. Main window and Settings polish

- [x] 4.1 Rebuild the main window per D6 (shared label column, `StatusCard`, prominent Download, new placeholder); verify by snapshots of launch, analyzing, ready, error, downloading and finished states in both languages
- [x] 4.2 Rebuild Settings per D7; verify by snapshots in both languages at 500 pt width

## 5. Wording

- [x] 5.1 Rewrite English and Russian strings per the D8 glossary and extend the catalog generator with the "Not used" check; verify the generator reports no violations and review snapshots of every screen in both languages

## 6. App icon

- [x] 6.1 Write `scripts/make-icon.swift` per D9 (outline tracing cut-out of `Design/AppleIcon.png`) and generate `App/Assets.xcassets/AppIcon.appiconset`; verify the 10 PNG sizes and `Contents.json`, a clean edge on light and dark backgrounds, and that the built app shows the icon in Finder, the Dock and About
- [x] 6.2 Document the icon workflow in README; verify the documented command regenerates identical files

## 8. Revisions after the second review

- [x] 8.1 Move the version to `Config/Version.xcconfig` (0.2.0 now) and rework `scripts/release.sh` per D10 (refusals, dry run, build number, release commit and tag, zip + sha256, next version commit); verify with a dry run, with the refusals on a dirty tree and an existing archive, and with a real release in a throwaway clone
- [x] 8.2 Make the warning in menu section headers red per D5; verify on an open menu in a Debug build which candidate renders in color
- [x] 8.3 Replace the compatibility line with a warning icon and tooltip next to the menu that lowers compatibility, and show nothing for the best compatibility; verify with tests of `compatibilityIssues` and snapshots of H.264+AAC, H.264+Opus, VP9+Opus and AV1
- [x] 8.4 Add the update test build per D11; verify the test app reports yt-dlp 2026.07.04, shows the update notice for the latest release, installs it into its own folder, uses it after a relaunch, and returns to the bundled version, without touching the regular app's settings or folder

## 9. Revisions after the third review

- [x] 9.1 Return the "⚠︎" sign to menu section headers and make the icon next to the menus orange; verify on an open menu and by snapshots
- [x] 9.2 Make Debug builds bundle the previous yt-dlp release and let `update-tools.sh` keep the Debug manifest one release behind, per D11; verify a Debug build reports 2026.07.04 and offers 2026.08.19, a dry-run release bundles 2026.08.19, and `update-tools.sh` on an outdated copy of the manifests rewrites both

## 10. Revisions after the fourth review

- [x] 10.1 Replace "needs IINA or VLC" with "needs a third-party player" in headers, tooltips, catalog and glossary; verify on an open menu and with `scripts/check-localization.py`
- [x] 10.2 Register `NSInitialToolTipDelay` = 100 ms at launch; verify the setting is in effect in the running app (the user confirms the hover timing)
- [x] 10.3 Add `--old-ytdlp` to `release.sh --dry-run` per D11; verify the archive's app bundles 2026.07.04 and shows the update notice for 2026.08.19, and that `--old-ytdlp` without `--dry-run` is refused

## 11. Revisions after the fifth review

- [x] 11.1 Replace the update card in the main window with an update icon between the URL field and "Analyze" (tooltip, click opens Settings), keeping all update actions, progress and errors in Settings; verify by snapshots with an available update, during an install and when up to date, and by clicking the icon (Settings opens)

## 7. Manual checks carried over from kdownloader-mvp

- 7.1 — moved to the next change (manual check pending): see "Moved manual checks" below.
- 7.2 — moved to the next change (manual check pending): see "Moved manual checks" below.
- 7.3 — moved to the next change (manual check pending): see "Moved manual checks" below.
- 7.4 — moved to the next change (manual check pending): see "Moved manual checks" below.
- 7.5 — moved to the next change (manual check pending): see "Moved manual checks" below.

## Moved manual checks

These checks need the user (system permission prompts, clicks, hovering, a release walkthrough) and continue in the next change:

- 7.1 Notifications: allow notifications for kDownloader, download a video, click the banner; Finder shows the file
- 7.2 Safari cookies with Full Disk Access: grant FDA, sign in to YouTube in Safari, analyze `https://www.youtube.com/watch?v=Tq92D6wQ1mg`; the preview appears
- 7.3 Log after cookies: after 7.2 export the log; it contains `safari` and no cookie values
- 7.4 Log window: "Open Log" on an error screen opens the log window; "Export…" writes a `.txt`
- 7.5 Release walkthrough: extract the release zip, remove quarantine, walk through 1080p, audio only, VP9 → MKV, playlist error, cookies, cancel, and a yt-dlp update; record the result in README ("Verified")
- Hover timing of the compatibility tooltip (10.2): the tooltip appears almost at once.

## Workflow follow-up

- Archive the change after implementation and the manual checks.
- Release 0.2.0.
