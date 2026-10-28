# licensing Specification

## Purpose
States the license of kDownloader's own code and makes sure every distributed
app carries the license notices of the bundled third-party components and
offers the source the LGPL requires.

## Requirements

### Requirement: License of the app's code
The repository SHALL contain a `LICENSE` file with the MIT license for kDownloader's own code, naming kozian as the copyright holder. The same text MUST ship inside the app.

#### Scenario: Repository
- **WHEN** someone opens the repository root
- **THEN** `LICENSE` contains the MIT license with the copyright line for kozian

#### Scenario: Distributed app
- **WHEN** the release zip is extracted
- **THEN** the app contains the same MIT license text in its licenses folder

### Requirement: Third-party license notices in the app
The app bundle SHALL contain a licenses folder with one subfolder per bundled component: kDownloader, FFmpeg, Deno and yt-dlp. Each subfolder MUST hold the license text that applies to the version that is bundled.

#### Scenario: FFmpeg
- **WHEN** the licenses folder of a built app is inspected
- **THEN** the FFmpeg folder holds the LGPL-2.1 text and FFmpeg's `LICENSE.md` from the bundled version's source tarball

#### Scenario: Deno
- **WHEN** the licenses folder of a built app is inspected
- **THEN** the Deno folder holds Deno's MIT `LICENSE.md` from the release tag of the bundled version

#### Scenario: yt-dlp
- **WHEN** the licenses folder of a built app is inspected
- **THEN** the yt-dlp folder holds yt-dlp's `LICENSE` (the Unlicense) and the `THIRD_PARTY_LICENSES.txt` shipped with the bundled yt-dlp build, which covers its embedded components including mutagen (GPL-2.0+) and the maintainers' offer of their source

### Requirement: FFmpeg build information
The FFmpeg folder in the app SHALL also state the bundled FFmpeg version, the configure options it was built with, the URL and SHA-256 of its source tarball, and that the tarball is published with each release. It MUST include the build script used.

#### Scenario: Rebuilding FFmpeg from the notice
- **WHEN** a user reads the FFmpeg folder of the app
- **THEN** it names the exact source tarball and configure options, and contains the build script that produced the bundled ffmpeg and ffprobe

### Requirement: Pinned license files
The license files of the tools SHALL be pinned in the tool version manifest with their URL and SHA-256, or taken from the already verified tool archive. The build MUST verify them like the tools and fail on a mismatch.

#### Scenario: Tampered license file
- **WHEN** a downloaded license file does not match the SHA-256 in the manifest
- **THEN** the build stops with a message naming the file

### Requirement: License files follow tool updates
The tool update command SHALL pin the license files of the new tool versions together with the versions. The licenses in the app MUST always belong to the bundled versions.

#### Scenario: New Deno release
- **WHEN** the update command moves Deno to a new release
- **THEN** the manifest points to the `LICENSE.md` of that release tag with its SHA-256

### Requirement: Dependencies and licenses in the About window
Under the app version, the About window SHALL list the bundled dependencies (yt-dlp, FFmpeg, Deno) with their versions under the heading "Bundled dependencies". It MUST offer one action that shows the app's licenses folder in Finder.

#### Scenario: About window
- **WHEN** the user opens the About window
- **THEN** it shows the app version and, under "Bundled dependencies", yt-dlp, FFmpeg and Deno with their versions

#### Scenario: All licenses
- **WHEN** the user chooses to show all licenses
- **THEN** Finder shows the licenses folder of the app

### Requirement: License check of the release build
The release command SHALL verify, in releases and dry runs, that the built app contains every expected license file with non-empty content. It MUST fail when one is missing.

#### Scenario: Missing license
- **WHEN** the Deno license file is missing from the built app
- **THEN** the release command stops with an error naming it

### Requirement: FFmpeg source with every release
A release SHALL publish the FFmpeg source tarball of the bundled version and its SHA-256 file next to the release zip, with the checksum from the manifest. An existing tarball of the same version MUST be kept, not overwritten. A dry run MUST NOT publish it.

#### Scenario: Releasing 0.2.2
- **WHEN** the developer releases a version that bundles FFmpeg 9.0.2
- **THEN** `dist/` contains `ffmpeg-9.0.2.tar.xz` and its `.sha256` next to the release zip

#### Scenario: Dry run
- **WHEN** the developer runs a dry run
- **THEN** no FFmpeg tarball is written to `dist/`
