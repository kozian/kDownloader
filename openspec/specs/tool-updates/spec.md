# tool-updates Specification

## Purpose
Lets the user update yt-dlp from inside the app when a site breaks the bundled version, safely and reversibly, without waiting for a new app release.

## Requirements

### Requirement: Daily update check
At launch the app SHALL check for the latest stable yt-dlp release at most once every 24 hours. The check MUST NOT download or install anything, MUST NOT delay other work, and a failed check MUST be logged without bothering the user.

#### Scenario: First launch of the day
- **WHEN** the app starts and the last check was more than 24 hours ago
- **THEN** it asks for the latest yt-dlp release in the background and records the time of the check

#### Scenario: Recent check
- **WHEN** the app starts 3 hours after the last check
- **THEN** no request is made

#### Scenario: No network
- **WHEN** the check fails because there is no connection
- **THEN** the failure is written to the log and nothing is shown to the user

### Requirement: Manual update check
Settings SHALL offer "Check for Updates", which checks immediately regardless of the last check and shows the result: "Up to date", "Version X is available" or the reason the check failed.

#### Scenario: Already up to date
- **WHEN** the user presses "Check for Updates" and the active yt-dlp is the latest release
- **THEN** Settings show "yt-dlp is up to date"

### Requirement: Update indicator
When a newer yt-dlp release than the active one is known, or an update is being installed, the main window SHALL show an update icon between the URL field and the "Analyze" button. Its tooltip MUST name the available version, and clicking it MUST open Settings. The main window MUST NOT show update cards, buttons, progress or errors; all update actions and their state are shown only in Settings.

#### Scenario: Newer version found
- **WHEN** the check finds yt-dlp 2026.10.01 and 2026.08.19 is active
- **THEN** the main window shows the update icon with the tooltip "yt-dlp 2026.10.01 is available — open Settings to install"

#### Scenario: Opening Settings
- **WHEN** the user clicks the update icon
- **THEN** the Settings window opens with the yt-dlp section, which offers "Install"

#### Scenario: Up to date
- **WHEN** the active yt-dlp is the latest known release
- **THEN** the main window shows no update icon

### Requirement: Installing an update
"Install" SHALL download the release, verify it against the SHA-256 checksums published with that release, prepare it and run it with `--version`. Only an update that passes every step MUST become active. Installation MUST NOT be possible while a download is running, and progress and failures MUST be shown in Settings.

#### Scenario: Successful update
- **WHEN** the user presses "Install" for 2026.10.01
- **THEN** the app downloads, verifies and tests it, makes it active, and Settings show "yt-dlp 2026.10.01 (updated)"

#### Scenario: Checksum mismatch
- **WHEN** the downloaded archive does not match the published checksum
- **THEN** the update is discarded, the previous yt-dlp stays active, and the error "The download is damaged" is shown

#### Scenario: During a download
- **WHEN** a video download is running
- **THEN** "Install" is disabled with the hint "Available after the current download"

### Requirement: Choosing the active version
The app SHALL use the newest installed update that passes the launch check, otherwise the bundled yt-dlp. At most the active and the previous installed update MUST be kept on disk.

#### Scenario: Broken installed update
- **WHEN** the installed update fails to run at launch
- **THEN** the app uses the bundled yt-dlp, logs the reason and does not show the damaged-app screen

#### Scenario: Bundled version is newer
- **WHEN** a new app release bundles a yt-dlp newer than the installed update
- **THEN** the bundled yt-dlp is used

### Requirement: Return to the bundled version
Settings SHALL offer "Use Bundled Version" while an update is active. It MUST remove the installed updates and switch to the bundled yt-dlp.

#### Scenario: Reverting
- **WHEN** an updated yt-dlp misbehaves and the user presses "Use Bundled Version"
- **THEN** the installed updates are removed and the bundled yt-dlp version is shown as active
