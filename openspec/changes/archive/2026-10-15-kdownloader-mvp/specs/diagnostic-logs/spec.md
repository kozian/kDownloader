# Spec Delta

## Purpose

Keeps a detailed log of the app and its external tools so errors can be investigated, especially when a site changes its behavior.

## ADDED Requirements

### Requirement: Writing the log
The app SHALL log its launch with tool versions, every tool invocation (arguments, time, exit code), and the tool's output and errors. Every entry MUST have a timestamp.

#### Scenario: Failed analysis
- **WHEN** analysis fails
- **THEN** the log contains the invocation command, the full yt-dlp error output and the exit code

### Requirement: Storage and rotation
Logs SHALL be stored in `~/Library/Logs/kDownloader/`, one file per app launch. At most the 10 most recent files are kept, and older ones MUST be deleted at launch.

#### Scenario: Eleventh launch
- **WHEN** the log folder already contains 10 files and the app launches
- **THEN** the oldest file is deleted and a new one is created

### Requirement: Viewing the log
The app SHALL provide a log window (menu "Window → Log") showing the current log, updated in real time, with a "Show in Finder" button. The error screen MUST contain an "Open Log" link.

#### Scenario: Opening the log from an error
- **WHEN** the user clicks "Open Log" on the error screen
- **THEN** the log window opens with the latest entries

### Requirement: Exporting the log
The user SHALL be able to save the current log to a text file through the system save dialog.

#### Scenario: Export
- **WHEN** the user clicks "Export…" and chooses a location
- **THEN** a `.txt` file with the log contents is created there
