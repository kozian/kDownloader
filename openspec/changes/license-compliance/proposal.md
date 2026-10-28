# Proposal

## Why

The released app bundles FFmpeg (LGPL-2.1+), Deno (MIT) and yt-dlp, whose
PyInstaller build contains components under various licenses, mutagen
(GPL-2.0+) among them. Today the app does not ship the FFmpeg and Deno license
texts. It also does not make the FFmpeg source available or mention the
components anywhere, and kDownloader's own code has no license. The project
should meet these obligations before the app is passed around any further.

## What Changes

- kDownloader's own source is released under the MIT license: a `LICENSE` file at
  the repository root (copyright kozian), also shipped inside the app.
- The app bundle gets `Contents/Resources/Licenses/` with one folder per
  component:
  - `kDownloader/`: the MIT license;
  - `FFmpeg/`: the LGPL-2.1 text and `LICENSE.md` from the source tarball, the
    configure options and build script used, and where to get the exact source;
  - `Deno/`: Deno's `LICENSE.md` (MIT);
  - `yt-dlp/`: the Unlicense and yt-dlp's own `THIRD_PARTY_LICENSES.txt`, which
    lists Python, OpenSSL, mutagen (GPL-2.0+) and the rest, with the
    maintainers' offer of their source.
- License texts are pinned in the tool manifest (URL and SHA-256) and fetched and
  verified by the build like the tools. The tool update command updates them
  together with the tool versions.
- The About window lists the bundled dependencies with their versions under a
  "Bundled dependencies" heading, and shows the licenses folder in Finder.
- The release command checks that every license file is in the built app. For a
  release (not a dry run) it also puts the matching FFmpeg source tarball and its
  checksum next to the release zip in `dist/`.
- README gets a "Licenses" section: the MIT license of the code, the components
  of the distributed app and their licenses, and where the FFmpeg source is.

Out of scope: the app icon is derived from an old YouTube iOS icon (another
party's design and trademark). Replacing it with an original icon becomes a
backlog task. Rights to downloaded content are the user's responsibility and
not part of this change.

## Capabilities

### New Capabilities
- `licensing`: the license of kDownloader's code and the third-party license
  notices shipped with the app. Covers how the notices are pinned and updated,
  how they are reached from the About window, and the availability of the FFmpeg source
  for every release.

### Modified Capabilities
<!-- None. The existing bundled-tools and release-packaging requirements stay as
     they are. The new license checks and release outputs are specified in
     `licensing`. -->

## Impact

- New: `LICENSE`, `Contents/Resources/Licenses/…` in the bundle.
- `tools/manifest.json`, `tools/manifest-update-test.json`: license entries per
  tool.
- `scripts/fetch-tools.sh`, `scripts/embed-tools.sh`: fetch, verify and embed the
  license files.
- `scripts/update-tools.sh`: pin the license files of new versions.
- `scripts/release.sh`: verify the licenses in the bundle and publish the FFmpeg
  source with a release.
- `App/AboutView.swift`, `Localizable.xcstrings` (ru/en): dependency list and
  the licenses folder.
- `README.md`, `BACKLOG.md` (icon task), `.claude/skills/release-update` (the
  FFmpeg source is now a release output).
- No new runtime dependencies. Bundle size grows by about 0.3 MB of text.
