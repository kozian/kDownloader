# localization Specification

## Purpose
Provides the app's user interface in Russian and English according to the system language settings.

## Requirements

### Requirement: Supported languages
All UI text, including error messages, notifications and menus, SHALL be available in Russian and English. The language MUST follow the system settings (including the per-app language in System Settings). English MUST be used for all other languages.

#### Scenario: Russian system
- **WHEN** the primary system language is Russian
- **THEN** the UI is shown in Russian

#### Scenario: German system
- **WHEN** the primary system language is German
- **THEN** the UI is shown in English

### Requirement: Original tool messages
Original messages from yt-dlp and other tools in error details and in the log SHALL be shown untranslated.

#### Scenario: Error details
- **WHEN** a user with the Russian UI expands error details
- **THEN** the error category is in Russian and the original yt-dlp message is shown as is
