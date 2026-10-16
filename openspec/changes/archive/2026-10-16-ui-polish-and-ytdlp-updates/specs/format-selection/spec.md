# Spec Delta

## MODIFIED Requirements

### Requirement: Flagging incompatible formats
With "Show all formats" on, the group of formats with the best compatibility with Mac (H.264 or HEVC video, AAC audio) SHALL come first, and its header MUST say "best compatibility with Mac". The header of every other group MUST carry a warning sign "⚠︎" and state what is needed to play the result: "needs a third-party player" when the result is saved as MKV, "needs a Mac with M3 or later" for AV1. Entries MUST NOT carry warning icons. In the main window, an orange warning icon MUST appear to the right of the menu whose choice lowers compatibility, with the requirement shown only as its tooltip, which MUST appear without the system's usual hover delay; a choice with the best compatibility MUST show no note.

#### Scenario: VP9 format
- **WHEN** "Show all formats" is on and the video has VP9 formats
- **THEN** they are listed under the header "VP9 · MKV — ⚠︎ needs a third-party player", and the entries themselves carry no warning icon

#### Scenario: Compatible choice
- **WHEN** H.264 video and AAC audio are selected
- **THEN** no compatibility icon or text is shown next to the menus

#### Scenario: Opus audio with H.264 video
- **WHEN** H.264 video and Opus audio are selected
- **THEN** a warning icon appears to the right of the Audio menu only, and hovering it shows "Needs a third-party player: QuickTime does not open MKV (Opus)"

#### Scenario: AV1 format
- **WHEN** an AV1 format is selected
- **THEN** a warning icon appears to the right of the Video menu, and hovering it shows "Needs a Mac with M3 or later: hardware AV1 decoding"

## ADDED Requirements

### Requirement: Formats grouped by format
With "Show all formats" on, the Video menu SHALL group entries by format (video codec and resulting container, e.g. "H.264 · MP4", "VP9 · MKV", "AV1 · MP4") with one entry per resolution, and the Audio menu by audio codec. Video entries MUST show a display icon and audio entries a speaker icon. When yt-dlp offers several streams for the same format and resolution (for example a direct and an HLS stream), only the preferred one MUST be listed.

#### Scenario: Big Buck Bunny
- **WHEN** the video has H.264, VP9 and AV1 streams, some of them both direct and HLS
- **THEN** the Video menu shows the groups "H.264 · MP4", "VP9 · MKV" and "AV1 · MP4" with one entry per resolution each

#### Scenario: Multi-language audio
- **WHEN** a video has AAC and Opus tracks in several languages
- **THEN** the Audio menu shows the groups "AAC · M4A" and "Opus", each entry naming the language and bitrate
