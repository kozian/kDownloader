# Spec Delta

## ADDED Requirements

### Requirement: App icon from a source image
The repository SHALL keep one square source image of the app icon, and a script MUST generate every size of the macOS app icon from it following Apple's grid (an 824×824 body on a 1024×1024 transparent canvas with a soft shadow). The release app MUST show this icon in Finder, the Dock and the About window.

#### Scenario: Regenerating the icon
- **WHEN** the developer replaces the source image and runs the icon script
- **THEN** all icon sizes in the asset catalog are regenerated and the next build shows the new icon

#### Scenario: Release app
- **WHEN** the release zip is extracted
- **THEN** Finder shows the kDownloader icon instead of the generic app icon

### Requirement: Version of the work in progress
The app version SHALL be kept in one place in the repository. Right after a release is committed and tagged, the release command MUST raise the version to the next one (the next minor version unless another is given) and commit that, so every later build carries the version under development and never the number of a released version.

#### Scenario: After releasing 0.2.0
- **WHEN** the developer releases 0.2.0
- **THEN** the repository has the commit "Release 0.2.0" tagged `v0.2.0`, followed by a commit that sets the version to 0.3.0

#### Scenario: Development build
- **WHEN** the developer builds the app between releases 0.2.0 and 0.3.0
- **THEN** the app reports version 0.3.0

### Requirement: Releases never overwrite each other
The release command SHALL refuse to run when the working tree has uncommitted changes, when the tag of the version exists, or when the release archive of that version already exists. A dry-run mode MUST build and verify everything, write an archive marked as a dry run, and change nothing in git.

#### Scenario: Version already released
- **WHEN** `dist/kDownloader-0.2.0.zip` or the tag `v0.2.0` exists and the developer runs the release command for 0.2.0
- **THEN** it stops with an error and the existing archive is untouched

#### Scenario: Dry run
- **WHEN** the developer runs the release command with `--dry-run`
- **THEN** `dist/kDownloader-<version>-dryrun.zip` is written, and no commit, tag or version change is made

### Requirement: Update test build
Debug builds SHALL bundle the yt-dlp release that precedes the one in the release manifest, so the in-app update can be tested against the real latest release at any time; release builds MUST bundle the latest one. The tool update command MUST keep the Debug manifest one release behind. A separate update test app with its own bundle identifier, settings and update folder MUST be available for testing without touching the regular app.

#### Scenario: Debug build
- **WHEN** the developer builds the Debug configuration while the release manifest has yt-dlp 2026.08.19
- **THEN** the app bundles yt-dlp 2026.07.04 and offers 2026.08.19 as an update

#### Scenario: Release build
- **WHEN** the developer builds a release or a dry run
- **THEN** the app bundles yt-dlp 2026.08.19

#### Scenario: Updating the tools
- **WHEN** `update-tools.sh` moves the release manifest to a new yt-dlp release
- **THEN** the Debug manifest moves to the release before it

### Requirement: Release archive with the previous yt-dlp
A dry run SHALL be able to produce, next to the regular archive, an archive of the regular app bundling the previous yt-dlp release, so the update can be tested from a packaged app. Producing it outside a dry run MUST be refused.

#### Scenario: Release archive with the previous yt-dlp
- **WHEN** the developer runs the release command with `--dry-run --old-ytdlp`
- **THEN** `dist/kDownloader-<version>-dryrun-old-ytdlp.zip` contains the regular app with the previous yt-dlp release, which offers the latest one as an update

#### Scenario: Not a dry run
- **WHEN** the developer runs the release command with `--old-ytdlp` but without `--dry-run`
- **THEN** it stops with an error

