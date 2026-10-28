# Tasks

## 1. License of the app's code

- [x] 1.1 Add `LICENSE` at the repository root: MIT, "Copyright (c) 2026 kozian"; verify the text matches the SPDX MIT template
- [x] 1.2 Add a "Licenses" section to README: the code is MIT; the distributed app bundles yt-dlp (Unlicense, with its third-party components including mutagen GPL-2.0+), FFmpeg (LGPL-2.1+, source published with releases) and Deno (MIT; notices of V8 and Rust crates not aggregated upstream); where the licenses are in the app; verify the section renders and names every component
- [x] 1.3 Add a backlog task to replace the app icon, derived from an old YouTube iOS icon, with an original design; verify it appears in `BACKLOG.md` under Tasks

## 2. Pinned license files in the build

- [x] 2.1 Add `licenses` entries to `tools/manifest.json` and `tools/manifest-update-test.json` (yt-dlp: `LICENSE` url + `_internal/THIRD_PARTY_LICENSES.txt` fromArchive; Deno: `LICENSE.md` url; FFmpeg: `COPYING.LGPLv2.1` and `LICENSE.md` fromArchive), with SHA-256 of the files at the pinned tags; verify `jq -e` on both files
- [x] 2.2 Extend `scripts/fetch-tools.sh` to download, verify and cache url entries and to extract fromArchive entries into `.build/tools/licenses/<Component>/`, rebuilt on every run; verify a clean fetch produces every file, and that a wrong SHA-256 in a copy of the manifest stops it with a message naming the file
- [x] 2.3 Extend `scripts/embed-tools.sh` to copy the licenses to `Contents/Resources/Licenses/`, add the root `LICENSE` as `kDownloader/LICENSE`, `scripts/build-ffmpeg.sh` and a generated `FFmpeg/BUILD.txt` (version, source URL and SHA-256, `ffmpeg -buildconf`, note about the tarball next to releases); verify in a Debug build that the folder has all files and `codesign --verify --deep --strict` passes
- [x] 2.4 Extend `scripts/update-tools.sh` to repin the yt-dlp and Deno license URLs to the new tags with their SHA-256, and keep the Debug manifest's yt-dlp licenses on its older version; verify by running it against copies of the manifests set to older versions and checking both are repinned, and update the README "Updating the bundled tools" section

## 3. Release

- [x] 3.1 Add the license check to `scripts/release.sh` for releases and dry runs (every expected file present and non-empty); verify `--dry-run` passes, and fails naming the file when one license is removed from the built app
- [x] 3.2 Publish `dist/ffmpeg-<v>.tar.xz` and its `.sha256` on a real release from the verified cache, keeping an existing file of the same version and stopping on a checksum mismatch, never on a dry run; verify the dry run writes no tarball and verify the copy step with a scratch `DIST` directory
- [x] 3.3 Update README "Releasing" and "Installing (friends and family)" (hand out the FFmpeg tarball with the zip) and `.claude/skills/release-update/SKILL.md` (the tarball is a release output; check it in step 6); verify the documented commands match the script

## 4. About window

- [x] 4.1 Rework `App/AboutView.swift`: a "Bundled dependencies" heading over yt-dlp, FFmpeg and Deno with their versions (no row repeating the app version), and "Show Licenses in Finder"; keep the "updated" mark of yt-dlp; verify with a window snapshot in both languages
- [x] 4.2 Add the new strings to `Localizable.xcstrings` in ru and en; verify `python3 scripts/check-localization.py` reports no problems
- [x] 4.3 Update the `bundled-tools`-related unit or UI checks if any reference the About grid; verify all KDownloaderCore tests pass

## 5. Integration

- [x] 5.1 Run `scripts/release.sh --dry-run`, extract the zip, check the `Licenses` folder against the spec, open the About window; verify the dependency list and that the licenses folder is reachable from it
- [x] 5.2 Run `openspec validate license-compliance --strict`; verify it passes

## Workflow follow-up

- Release the next version with `release-update` to ship the first compliant app and its FFmpeg tarball.
- Archive the change with `/opsx:archive` after review.
