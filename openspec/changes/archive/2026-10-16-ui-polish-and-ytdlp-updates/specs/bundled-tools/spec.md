# Spec Delta

## MODIFIED Requirements

### Requirement: Bundled tools only
The app SHALL use only the ffmpeg, ffprobe and Deno binaries from its own bundle, and either the bundled yt-dlp or a yt-dlp update installed and verified by the app itself (see `tool-updates`). User yt-dlp configuration files, Homebrew and `PATH` MUST NOT affect the app's behavior.

#### Scenario: User has their own yt-dlp and config
- **WHEN** yt-dlp is installed via Homebrew and `~/.config/yt-dlp/config` exists
- **THEN** the app uses its own yt-dlp (bundled or updated in the app) and ignores that config

### Requirement: Version display
The About window SHALL show the app version and the versions of all tools in use. For yt-dlp it MUST also show whether the bundled version or an update is active.

#### Scenario: About window
- **WHEN** the user opens the About window
- **THEN** the versions of the app, yt-dlp, ffmpeg and Deno are shown

#### Scenario: Updated yt-dlp
- **WHEN** an installed yt-dlp update is active
- **THEN** the About window shows its version marked "updated"
