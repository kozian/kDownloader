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

### Requirement: Consistent terminology
UI text in both languages SHALL use the terms of the project glossary (design.md of this change) and nothing else for the same concepts, for example "site" / «сайт» for the source of a video and "Download" / «Скачать» for the action.

#### Scenario: Unsupported site in Russian
- **WHEN** a user with the Russian UI analyzes a link to an unsupported site
- **THEN** the error says «Сайт не поддерживается», not «Площадка не поддерживается»

#### Scenario: Download button in Russian
- **WHEN** a video is analyzed in the Russian UI
- **THEN** the primary button says «Скачать»
