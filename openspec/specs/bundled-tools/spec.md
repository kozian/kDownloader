# bundled-tools Specification

## Purpose
Ensures the app works only with bundled external tools verified at build time and does not depend on the user's environment.

## Requirements

### Requirement: Bundled tools only
The app SHALL use only the yt-dlp, ffmpeg, ffprobe and Deno binaries from its own bundle. User yt-dlp configuration files, Homebrew and `PATH` MUST NOT affect the app's behavior.

#### Scenario: User has their own yt-dlp and config
- **WHEN** yt-dlp is installed via Homebrew and `~/.config/yt-dlp/config` exists
- **THEN** the app uses the bundled yt-dlp and ignores that config

### Requirement: Tool check at launch
At launch the app SHALL verify that every bundled tool is present and runs. If the check fails, the app MUST show a "The app is damaged — please reinstall it" screen naming the failing tool, and analysis MUST be unavailable.

#### Scenario: ffmpeg removed
- **WHEN** ffmpeg is missing from the bundle
- **THEN** the damaged-app screen names ffmpeg at launch and the URL field is disabled

### Requirement: Version display
The About window SHALL show the app version and the versions of all bundled tools.

#### Scenario: About window
- **WHEN** the user opens the About window
- **THEN** the versions of the app, yt-dlp, ffmpeg and Deno are shown
