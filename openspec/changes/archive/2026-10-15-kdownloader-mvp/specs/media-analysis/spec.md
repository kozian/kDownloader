# Spec Delta

## Purpose

Lets the user enter a link to a video on a site supported by yt-dlp and get information about it, or a clear explanation of why the link cannot be processed.

## ADDED Requirements

### Requirement: URL input through a text field
The app SHALL accept a link only through the text field of the main window and start analysis when the user clicks "Analyze" or presses Return. Leading and trailing whitespace MUST be trimmed. An empty field or a string that is not an http(s) URL MUST NOT start analysis.

#### Scenario: Analyzing a valid link
- **WHEN** the user enters `https://www.youtube.com/watch?v=abc` and presses Return
- **THEN** the app starts analysis and shows a progress indicator

#### Scenario: Invalid string
- **WHEN** the user enters `hello world` and clicks "Analyze"
- **THEN** analysis does not start and an "Invalid link" message is shown below the field

#### Scenario: Empty field
- **WHEN** the URL field is empty
- **THEN** the "Analyze" button is disabled

### Requirement: Analysis starts on paste
When the user pastes text into the URL field and the resulting field content is a valid http(s) link, analysis SHALL start immediately without pressing "Analyze". Typing character by character MUST NOT start analysis.

#### Scenario: Pasting a link
- **WHEN** the URL field is empty and the user pastes `https://www.youtube.com/watch?v=abc`
- **THEN** analysis starts immediately

#### Scenario: Pasting text that is not a link
- **WHEN** the user pastes `hello world`
- **THEN** analysis does not start and no error is shown until the user presses "Analyze"

#### Scenario: Typing a link
- **WHEN** the user types a link character by character
- **THEN** analysis starts only after pressing Return or "Analyze"

### Requirement: All controls visible from launch
The main window SHALL show all controls from launch: the URL field, the preview area, the Video and Audio menus, the destination folder with the resulting file type and size, and the "Download" button. Until an analysis succeeds, the preview MUST show a placeholder and the format controls and "Download" MUST be disabled. The destination folder MUST be changeable at any time except during a download.

#### Scenario: First launch
- **WHEN** the app starts
- **THEN** every control is visible, the preview shows a placeholder, and the format menus and "Download" are disabled

#### Scenario: Analysis fails
- **WHEN** an analysis fails
- **THEN** the error is shown and the format controls and "Download" stay disabled

### Requirement: Link type rules
The app SHALL process only links to single videos. A link that points to both a video and a playlist MUST be treated as a single video. Explicit playlist links and links to channels or user pages MUST be rejected with the "Playlists and channels are not supported" category, and live or upcoming streams MUST be rejected with "Live streams are not supported".

#### Scenario: Video inside a playlist
- **WHEN** the user analyzes `https://www.youtube.com/watch?v=abc&list=PL123`
- **THEN** only video `abc` is analyzed, as a single video

#### Scenario: Explicit playlist link
- **WHEN** the user analyzes `https://www.youtube.com/playlist?list=PL123`
- **THEN** the error "Playlists and channels are not supported" is shown

#### Scenario: Channel link
- **WHEN** the user analyzes `https://www.youtube.com/@somechannel`
- **THEN** the error "Playlists and channels are not supported" is shown

#### Scenario: Live stream
- **WHEN** the link points to a stream that is live or has not started yet
- **THEN** the error "Live streams are not supported" is shown

### Requirement: Video preview
After a video is analyzed successfully, the app SHALL show its thumbnail, title, author (channel) and duration, followed by format selection. Fields the site does not provide MUST be hidden without an error.

#### Scenario: Successful analysis
- **WHEN** analysis of a link to an available video succeeds
- **THEN** the thumbnail, title, author, duration and the format selection block are displayed

#### Scenario: Video without a thumbnail
- **WHEN** the site does not return a thumbnail
- **THEN** a neutral placeholder is shown instead, and the remaining data is displayed

### Requirement: Error classification
Any failure of analysis or download SHALL be presented as exactly one localized category from a fixed list, with a short explanation and a suggested action. The original yt-dlp text MUST be available in an expandable details section.

#### Scenario: List of categories
- **WHEN** the app classifies an error
- **THEN** the result is exactly one of: "Invalid link", "Site not supported", "Playlists and channels are not supported", "Live streams are not supported", "Video unavailable or removed", "Private video", "Sign-in required", "Members only", "Not available in your region", "Site is rate limiting requests", "No network connection", "Not enough disk space", "Cannot write to the destination folder", "Video processing failed", "Unknown error"

#### Scenario: Private video
- **WHEN** yt-dlp reports that the video is private, and the retry with cookies also fails
- **THEN** the "Private video" category is shown, with the original yt-dlp message available under details

#### Scenario: Unrecognized error
- **WHEN** the yt-dlp message does not match any known category
- **THEN** "Unknown error" is shown with the original message and an "Open Log" link

#### Scenario: No network
- **WHEN** analysis fails with a connection error
- **THEN** "No network connection" is shown with a "Retry" button

### Requirement: Cancelling and replacing analysis
The user SHALL be able to cancel an analysis in progress. Editing the URL after analysis MUST clear the preview and format selection.

#### Scenario: Cancelling analysis
- **WHEN** analysis is in progress and the user clicks "Cancel"
- **THEN** analysis stops and the app returns to URL input without an error message

#### Scenario: Editing the link after analysis
- **WHEN** a preview is displayed and the user edits the text in the URL field
- **THEN** the preview and format selection are hidden until a new analysis
