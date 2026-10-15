# Spec Delta

## Purpose

Gives the user a clear choice of quality and audio track for a video: by default only formats that are guaranteed to play with built-in macOS tools, and every format when asked.

## ADDED Requirements

### Requirement: Video and audio menus
Format selection SHALL consist of two menus, "Video" and "Audio". When the "Show all formats" setting is off, the menus MUST list only compatible choices; when it is on, they MUST list every format returned by yt-dlp. The last item of the Video menu MUST be "No video (audio only)".

#### Scenario: Default state
- **WHEN** analysis of a video finishes and "Show all formats" is off
- **THEN** the Video and Audio menus list only compatible choices

#### Scenario: All formats enabled
- **WHEN** "Show all formats" is on
- **THEN** both menus list every format returned by yt-dlp, including VP9, AV1 and Opus

### Requirement: "Show all formats" setting
"Show all formats" SHALL be an option in the Settings window, next to the browser cookies option, off by default. The choice MUST persist between launches, and changing it MUST update the menus of an analyzed video immediately.

#### Scenario: Turning it on with a video analyzed
- **WHEN** a video is analyzed and the user turns on "Show all formats" in Settings
- **THEN** the menus of the main window switch to every format, keeping the chosen video stream if possible

#### Scenario: Persistence
- **WHEN** the user turned on "Show all formats" and relaunches the app
- **THEN** the option is still on

### Requirement: Compatible video choices
With "Show all formats" cleared, the Video menu SHALL contain "Best compatible" followed by one entry per frame height that has an H.264 or HEVC stream which can be combined with AAC audio, highest first, then "No video (audio only)". The result is saved as MP4 and the video stream MUST NOT be re-encoded.

#### Scenario: YouTube video with VP9 4K and H.264 1080p
- **WHEN** the video is available as VP9 2160p, H.264 1080p, H.264 720p and AAC audio
- **THEN** the Video menu lists "Best compatible (1080p)", "1080p", "720p" and "No video (audio only)", but not "2160p"

#### Scenario: No compatible video
- **WHEN** the video has no H.264 or HEVC stream
- **THEN** the Video menu offers only "No video (audio only)" and the hint "No compatible formats — turn on “Show all formats” in Settings" is displayed

### Requirement: Default video choice
After each analysis, "Best compatible" SHALL be selected, corresponding to the highest compatible frame height. If there is no compatible video, "No video (audio only)" MUST be selected.

#### Scenario: Default selection
- **WHEN** analysis finishes and 1080p and 720p are compatible
- **THEN** "Best compatible (1080p)" is selected

### Requirement: Audio track languages
Every audio entry SHALL show the track language in the UI language when yt-dlp reports one. The original track MUST be labeled "Original (<language>)", or "Original" when no language is reported. A track is original when the site marks it so, or when the tracks report at most one language. With "Show all formats" off, the Audio menu MUST list one AAC track per language.

#### Scenario: Video with dubbed tracks
- **WHEN** a video has AAC tracks in English (original), Russian and German
- **THEN** the Audio menu lists "Original (English)", "Russian" and "German", one entry each

#### Scenario: Single language
- **WHEN** all audio tracks report the language `en` and none is marked original
- **THEN** the Audio menu shows "Original (English)"

#### Scenario: Tracks without a language
- **WHEN** no audio track reports a language
- **THEN** the Audio menu shows "Original"

### Requirement: Default audio track
After each analysis, the original track SHALL be selected. A track counts as original when yt-dlp marks it so (highest `language_preference` or "original" in the format note). If no track is marked, the first track MUST be selected.

#### Scenario: Original English track
- **WHEN** a video has 24 dubbed tracks and an English track marked original
- **THEN** the English track is selected by default

### Requirement: Audio only
Choosing "No video (audio only)" SHALL save the selected audio track as M4A with the AAC codec. If the selected track is not AAC, it MUST be re-encoded to AAC. With "Show all formats" off and no AAC track available, the Audio menu MUST list the best track per language, marked as converted to AAC.

#### Scenario: AAC track
- **WHEN** the user selects "No video (audio only)" and an AAC track
- **THEN** a `.m4a` file is saved without re-encoding

#### Scenario: Opus only
- **WHEN** the video only has Opus audio and the user selects "No video (audio only)"
- **THEN** a `.m4a` file is saved with the audio re-encoded to AAC

### Requirement: Video with or without audio in all formats mode
With "Show all formats" on, the Audio menu SHALL also offer "No audio". When the selected video format already contains audio, the Audio menu MUST be disabled and its own audio is used.

#### Scenario: Selecting VP9 and Opus
- **WHEN** the user selects VP9 2160p and an Opus track with "Show all formats" on
- **THEN** the download merges these streams into one file

#### Scenario: Video without audio
- **WHEN** the user selects a video-only format and "No audio"
- **THEN** a video-only file is saved

### Requirement: Flagging incompatible formats
Entries whose codecs do not play in QuickTime on Apple Silicon SHALL be flagged "May not open in QuickTime". AV1 entries MUST be flagged "Hardware decoding only on M3 and later" instead.

#### Scenario: VP9 format
- **WHEN** the Video menu contains a VP9 format
- **THEN** that entry is flagged and selecting it shows "May not open in QuickTime"

### Requirement: Output container
If all selected streams are MP4-compatible (H.264, HEVC, AV1, AAC), a video result SHALL be saved as MP4, otherwise as MKV. The resulting file extension and the estimated size MUST be shown before the download starts, next to the destination folder and the "Download" button.

#### Scenario: VP9 and Opus
- **WHEN** VP9 video and Opus audio are selected
- **THEN** the app shows, before the download, that the file will be saved as `.mkv`
