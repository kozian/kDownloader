# Backlog

Two parts:

- **Tasks** — understood well enough to do. Each becomes (part of) an OpenSpec
  change: take it into a proposal, then remove it here.
- **Ideas** — need thinking first. Each lists what we know and the questions to
  answer; once answered, an idea becomes a task.

## Tasks

### T1. All settings in the main window

Drop the Settings window and keep everything in the main window, with a switch
between simple and advanced settings.

- [ ] A visible switch "Simple / Advanced" in the main window; the choice is
      remembered between launches.
- [ ] Simple mode: link, preview, Video and Audio menus with compatible choices
      only, destination folder, Download. Nothing else.
- [ ] Advanced mode adds: every format in the menus (replaces the "Show all
      formats" setting), the browser for cookies, and the yt-dlp section
      (version and source, Check for Updates, Install with progress, Use Bundled
      Version).
- [ ] The update icon next to the link field switches to advanced mode and
      reveals the yt-dlp section instead of opening Settings.
- [ ] The Settings window and its menu item (⌘,) are removed.
- [ ] The window keeps fitting its content in both modes; snapshots in both
      languages and both modes.
- [ ] Specs to update: `format-selection` ("Show all formats" setting),
      `browser-cookies` (browser selection), `tool-updates` (update indicator,
      manual check, return to the bundled version).

### T2. Manual checks carried over

Implemented, but verifiable only by the user (permission prompts, clicks,
hovering). Listed in `openspec/changes/archive/2026-10-16-ui-polish-and-ytdlp-updates/tasks.md`.

- [ ] Notifications: allow them, download a video, click the banner — Finder
      shows the file.
- [ ] Safari cookies with Full Disk Access: grant FDA, sign in to YouTube in
      Safari, analyze an age-restricted video — the preview appears.
- [ ] The exported log after an operation with cookies contains `safari` and no
      cookie values.
- [ ] "Open Log" on an error screen opens the log window; "Export…" writes a
      `.txt`.
- [ ] The compatibility tooltip appears almost at once when hovering the
      warning icon.
- [ ] Release walkthrough from the zip: 1080p, audio only, VP9 → MKV, playlist
      link error, cookies, cancel, yt-dlp update (`--dry-run --old-ytdlp`
      archive); record the result in README ("Verified").

### T3. Spec and quality chores

- [ ] Split the requirement "Flagging incompatible formats" in
      `openspec/specs/format-selection/spec.md` into two (menu headers; icon
      next to the menus): it is over 500 characters, a warning of
      `openspec validate --strict`.
- [ ] Check dark mode on every screen; fix colors that do not adapt.
- [ ] Check VoiceOver labels on every control (icons without text included).

### T4. UI polish

- [ ] Merge the Download button, the Cancel button and the download progress bar
      into one control: "Download" turns into a progress bar with Cancel while a
      download runs, and back when it finishes or is cancelled.
- [ ] Show the download stage clearly. Today the progress bar fills up from 0
      to 100% at least three times (video stream, audio stream, processing),
      which misleads about the overall progress. Show one overall progress (for
      example weighted by stream sizes) with the current stage as a label, or
      steps "1 of 3: video · 2 of 3: audio · 3 of 3: processing".
- [ ] Rework the buttons shown after a download finishes. "New Download"
      («Другое видео») is misleading and must be replaced. How the finished
      state should look is still open (see I5).

### T5. Small conveniences

- [ ] Download progress on the Dock icon.
- [ ] Prevent system sleep while a download runs (`IOPMAssertion`).

### T6. An original app icon

`Design/AppIcon.png` is a recolored version of an old YouTube iOS icon: the
design belongs to others (and YouTube's look is a trademark), so recoloring
does not make it ours.

- [ ] Draw a new icon from scratch. The idea of a retro TV may stay, but the
      shape, proportions, screen and details must be our own, with no red
      "play" screen or anything else that recalls YouTube.
- [ ] Replace `Design/AppIcon.png`, regenerate with `scripts/make-icon.swift`,
      check Finder, the Dock and the About window.

## Ideas to think about

### I1. Playlists

Today explicit playlist links are rejected; a link to a video inside a playlist
downloads only that video.

Worked out once, then dropped as too complex for 0.1.0:
- the whole playlist with one preset, no per-item selection;
- presets as yt-dlp format selectors, since formats are not analyzed per item
  (`--flat-playlist` keeps analysis fast): "Best compatible", "1080p max",
  "720p max", "480p max", "Audio only (M4A)";
- a subfolder named after the playlist, unique with ` (N)`; files
  `<NNN> - <title>.<ext>`;
- progress "Video N of M"; a failed item does not stop the rest; a summary of
  downloaded and failed items; cancel keeps finished items.

Questions:
- How to keep it controllable: confirm large playlists? Item list with
  checkboxes after all?
- Items without a compatible format: skip and report, or fall back?
- Cookies: retry failed items one by one, or the whole playlist?
- Resume an interrupted playlist (`--download-archive`)?
- Channels: still out, or "latest N videos"?

### I2. Extended management of dependency versions

Today yt-dlp updates in the app (latest stable, checksum from the release, two
versions kept, "Use Bundled Version"); ffmpeg, ffprobe and Deno change only with
app releases.

Possible directions:
- choose a specific yt-dlp version; roll back to the previous installed one;
- the yt-dlp nightly channel for days when stable is broken by a site change;
- install yt-dlp updates automatically instead of by button;
- update Deno in the app (GitHub releases with `.sha256sum`, same flow as yt-dlp);
- update ffmpeg in the app — needs a trusted source of prebuilt arm64 builds
  (ffmpeg.martin-riedl.de was ~1 KB/s from here; we build from source now);
- verify signatures, not only checksums (`SHA2-256SUMS.sig`, ffmpeg `.asc`);
- a "Components" list with every tool, its version and source.

Questions:
- Does a user ever need more than "latest that works"? Which of these pays for
  its complexity?
- How to report a broken update without technical noise?

### I3. Automatic updates of the app itself

Today: an ad-hoc signed zip, installed by hand.

Options:
- Sparkle with an appcast (where to host?) and EdDSA-signed updates. With ad-hoc
  signing macOS treats every new build as a new app, so permissions (Full Disk
  Access, notifications) are asked again after each update.
- Developer ID (paid Apple Developer Program) plus notarization: no manual
  install step, permissions survive updates; Sparkle becomes straightforward.
- Minimal: check releases and show "Version X is available" with a link, like
  the yt-dlp update icon.

Questions:
- Friends and family only, or wider distribution?
- Where are releases published (GitHub Releases, own server)?
- Is the Developer ID cost justified?

### I4. Other ideas

- Codec in the closed Video menu ("2160p60 · VP9 · 1,36 GB")? Today VP9 and AV1
  at the same resolution look alike once the menu is closed. Clearer, but
  repetitive inside the open menu.
- Download queue and parallel downloads; download history.
- Resume as a feature; cleanup of leftover `.part` files (today they stay in the
  destination folder by decision).
- Links by drag and drop, from the clipboard on activation, a Share extension,
  a `kdownloader://` URL scheme.
- Subtitles (languages, auto-generated, embedded or separate); embedded
  thumbnail, chapters, metadata.
- Time range download (`--download-sections`); SponsorBlock.
- Filename template; speed limit; proxy.
- Live streams: record from now, or after the stream ends.
- Menu bar mode.

### I5. The finished state of a download

Today a success card shows "Download complete", the file name, "Show in Finder"
and "New Download" («Другое видео»). "New Download" only clears the link field,
which the label does not convey.

Questions:
- Which actions does a user want after a download: open the file, show it in
  Finder, download the same video in another format, paste the next link?
- Is a "clear" action needed at all, given that pasting a new link already
  replaces the old one and starts the analysis?
- Should the finished state merge with the single Download/progress control
  from T4 (the control turns into "Open" / "Show in Finder")?
