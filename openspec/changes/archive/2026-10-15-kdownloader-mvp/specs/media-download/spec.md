# Spec Delta

## Purpose

Downloads the selected format into the chosen folder, shows download progress, and gives quick access to the finished file.

## ADDED Requirements

### Requirement: Destination folder
The app SHALL show the current destination folder and let the user choose another one through the system dialog. The user's Downloads folder MUST be the default. The chosen folder MUST persist between launches.

#### Scenario: First launch
- **WHEN** the user launches the app for the first time
- **THEN** the destination folder is `~/Downloads`

#### Scenario: Remembering the choice
- **WHEN** the user has chosen `~/Movies` and relaunches the app
- **THEN** the destination folder is `~/Movies`

#### Scenario: Folder no longer exists
- **WHEN** the saved folder no longer exists
- **THEN** `~/Downloads` is used and the user sees a notice about it in the window

### Requirement: One download at a time
At most one download SHALL run at any time. While a download is running, the URL field, analysis and format selection MUST be disabled.

#### Scenario: Trying to edit the link during a download
- **WHEN** a download is running
- **THEN** the URL field and the "Analyze" button are disabled

### Requirement: Progress display
During a download the app SHALL show the current stage ("Downloading video", "Downloading audio", "Processing"), percentage, speed, remaining time and downloaded size. During "Processing" an indeterminate indicator MUST be shown.

#### Scenario: Downloading video
- **WHEN** yt-dlp is downloading the video stream
- **THEN** the "Downloading video" stage, percentage, speed and remaining time are shown, updated at least once per second

#### Scenario: Merging streams
- **WHEN** the streams have been downloaded and are being merged
- **THEN** the "Processing" stage is shown with an indeterminate indicator

### Requirement: Temporary files stay in the destination folder
Temporary and partial files (for example `.part` files and separate streams before merging) SHALL be written to the destination folder. The app MUST NOT delete them after cancellation or failure.

#### Scenario: Partial file after a failure
- **WHEN** a download fails halfway
- **THEN** the partial files remain in the destination folder untouched

### Requirement: Cancelling a download
The user SHALL be able to cancel a download. After cancellation the app MUST return to format selection for the same video.

#### Scenario: Cancel
- **WHEN** the user clicks "Cancel" during a download
- **THEN** the process stops and format selection is shown again; partial files remain in the destination folder

### Requirement: File name without overwriting
The file SHALL be named after the video title with the container extension, without characters that are invalid in macOS file names. Existing files MUST NOT be overwritten: on a conflict a ` (2)`, ` (3)`, etc. suffix is appended to the name.

#### Scenario: File already exists
- **WHEN** the folder already contains `Video.mp4` and the user downloads a video with the same title as MP4
- **THEN** the new file is saved as `Video (2).mp4`

#### Scenario: Invalid characters
- **WHEN** the video title is `A/B: test`
- **THEN** the file name contains neither `/` nor `:`

### Requirement: Download completion
After a successful download the app SHALL show a success message in the window with "Show in Finder" and "New Download" buttons, and post a system notification. Clicking the notification MUST reveal the result in Finder.

#### Scenario: Successful download
- **WHEN** downloading and processing are finished
- **THEN** a system notification is posted, and the window shows "Show in Finder" and "New Download"

#### Scenario: Show in Finder
- **WHEN** the user clicks "Show in Finder"
- **THEN** Finder opens with the downloaded file selected

#### Scenario: Notifications denied
- **WHEN** the user has denied notifications for the app
- **THEN** the download completes the same way, without a system notification

### Requirement: Download failure
When a download fails, the app SHALL show the error category (see `media-analysis`) and offer "Retry".

#### Scenario: Out of space
- **WHEN** the disk runs out of space during a download
- **THEN** "Not enough disk space" is shown and a "Retry" button is available
