# Spec Delta

## ADDED Requirements

### Requirement: Consistent terminology
UI text in both languages SHALL use the terms of the project glossary (design.md of this change) and nothing else for the same concepts, for example "site" / «сайт» for the source of a video and "Download" / «Скачать» for the action.

#### Scenario: Unsupported site in Russian
- **WHEN** a user with the Russian UI analyzes a link to an unsupported site
- **THEN** the error says «Сайт не поддерживается», not «Площадка не поддерживается»

#### Scenario: Download button in Russian
- **WHEN** a video is analyzed in the Russian UI
- **THEN** the primary button says «Скачать»
