---
name: release-update
description: Update kDownloader's bundled tools (yt-dlp, Deno, ffmpeg) to their latest releases and/or release a new app version. Use when the user asks to update dependencies, refresh yt-dlp, or make a release of kDownloader.
---

# Update the bundled tools and release kDownloader

The user asking for this is the authorization to commit and release. Talk to the
user in Russian; commit messages stay in English.

## 1. Preconditions

- `git status --short`: commit unrelated pending work (e.g. `BACKLOG.md`) as its
  own commit first — `release.sh` refuses a dirty tree. Ask only if the pending
  changes are code that is not finished.
- `git log --oneline $(git describe --tags --abbrev=0)..HEAD`: what is unreleased.

## 2. Update the tools

```sh
scripts/update-tools.sh
```

It rewrites `tools/manifest.json` (latest stable yt-dlp, Deno, ffmpeg with
checksums, and the yt-dlp and Deno license files pinned to the new tags) and
`tools/manifest-update-test.json` (Debug: yt-dlp one release behind). The gpg
warning for ffmpeg is expected (gpg is not installed); mention it only if the
ffmpeg version changed. If nothing changed and there is nothing else unreleased,
stop and tell the user there is nothing to release.

A new ffmpeg version is compiled from source on the next build (~1 min).

## 3. Verify before releasing

1. `swift test --package-path Packages/KDownloaderCore` — all tests pass.
2. `scripts/release.sh --dry-run` — every tool reports the new version.
3. Live smoke test with the tools of the built app
   (`.build/release/Build/Products/Release/kDownloader.app`), in a fresh
   scratchpad folder: download a short video with separate video and audio
   streams so Deno (JS challenge) and ffmpeg (merge) are both exercised:

   ```sh
   "$APP/Contents/Resources/yt-dlp/yt-dlp_macos" --no-config --newline \
     --js-runtimes "deno:$APP/Contents/Helpers/deno" \
     --ffmpeg-location "$APP/Contents/Helpers" \
     -f 'bv[vcodec^=avc1][height<=240]+ba[ext=m4a]' --merge-output-format mp4 \
     -o '%(id)s.%(ext)s' 'https://www.youtube.com/watch?v=jNQXAC9IVRw'
   ```

   Expect `[jsc:deno] Solving JS challenges`, `[Merger]`, and `ffprobe` showing
   `h264` + `aac`. If it fails, stop and report — do not release.

## 4. Choose the version

`Config/Version.xcconfig` holds the version under development (X.Y.0). The
minor version is for new features; everything else is a patch.

- **No new features since the last tag** (tool updates, licenses, icon, docs,
  fixes) → patch release of the last released version: set `MARKETING_VERSION`
  to e.g. `0.2.2`, then `release.sh --next <the development version>` (e.g.
  `--next 0.3.0`), so development continues where it was. If unsure whether a
  change counts as a feature, ask.
- **New features** → release the development version as is:
  `release.sh` (next minor by default).

## 5. Release

```sh
git add tools Config/Version.xcconfig
git commit -m "Update bundled tools: yt-dlp <v>, Deno <v>[, ffmpeg <v>]"
scripts/release.sh [--next X.Y.Z]
```

Never pass `--force`-like workarounds: the script refuses an existing tag or zip
on purpose; if it refuses, report why.

## 6. Check the released archive

In a fresh scratchpad folder:

- `shasum -a 256 -c dist/kDownloader-<v>.zip.sha256`;
- `ditto -x -k` the zip, `codesign --verify --deep --strict` the app;
- `CFBundleShortVersionString` / `CFBundleVersion` from `Info.plist`;
- bundled `yt-dlp_macos --version` and `deno --version`;
- `open -n` the app, check the process stays up a few seconds, then quit it;
- `dist/ffmpeg-<ffmpeg version>.tar.xz` exists and
  `shasum -a 256 -c` of its `.sha256` passes; the app's
  `Contents/Resources/Licenses/` has the kDownloader, FFmpeg, Deno and yt-dlp
  folders (release.sh already refuses a build without them).

Delete stale `dist/*-dryrun*` archives so only releases remain.

## 7. Publish on GitHub

The repository is public at https://github.com/kozian/kDownloader (`origin`, SSH).
Only the new version gets a GitHub release.

```sh
git push origin main
git push origin v<v>
gh release create v<v> --verify-tag --latest --title "kDownloader <v>" --notes-file <notes> \
  dist/kDownloader-<v>.zip dist/kDownloader-<v>.zip.sha256 \
  dist/ffmpeg-<ffmpeg v>.tar.xz dist/ffmpeg-<ffmpeg v>.tar.xz.sha256
```

The FFmpeg tarball is attached to every release (LGPL), even when FFmpeg did not
change. Notes, in English: one-line description, "What's new", requirements
(macOS 14+, Apple Silicon), installing (unzip, move to /Applications,
`xattr -dr com.apple.quarantine`), a table of the files with their SHA-256, and
a line that the FFmpeg tarball is its unmodified LGPL source. Show the notes to
the user before publishing. Afterwards `gh release download v<v>` into a
scratchpad folder and `shasum -a 256 -c` the files.

## 8. Report

Tool versions before → after, the version and build number, the release URL, the
SHA-256 of the zip, the commits and tag created, and what was not verified (e.g.
the ffmpeg signature).
