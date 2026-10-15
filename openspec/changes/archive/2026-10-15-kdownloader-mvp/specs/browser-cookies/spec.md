# Spec Delta

## Purpose

Allows downloading media that requires sign-in (age restrictions, private access, "confirm you're not a bot" checks) by using the user's browser cookies only when they are actually needed.

## ADDED Requirements

### Requirement: No cookies first
Analysis and download SHALL always run without browser cookies first.

#### Scenario: Public video
- **WHEN** the user analyzes a public video
- **THEN** browser cookies are not read

### Requirement: Retry with cookies after an access error
If an analysis or download fails with "Sign-in required", "Private video", "Members only" or "Site is rate limiting requests", the app SHALL automatically retry once with cookies from the selected browser. If the retry fails, the retry's error MUST be shown.

#### Scenario: Age-restricted video
- **WHEN** analysis without cookies returns "Sign-in required" and a browser for cookies is selected
- **THEN** analysis is retried automatically with cookies and, on success, the preview is shown

#### Scenario: Retry did not help
- **WHEN** the retry with cookies fails with an access error again
- **THEN** the retry's error category is shown, and there is no third attempt

#### Scenario: Other errors
- **WHEN** analysis fails with "Site not supported"
- **THEN** no retry with cookies is made

### Requirement: Cookies carry over to the download
If the analysis succeeded only with cookies, the download of the same video SHALL use cookies from the start. A new analysis MUST start without cookies again.

#### Scenario: Download after analysis with cookies
- **WHEN** the analysis succeeded with cookies and the user starts the download
- **THEN** the download runs with cookies from the same browser from the start

### Requirement: Browser selection
The app SHALL let the user choose the browser for cookies in Settings from the installed supported browsers. If a retry is needed and no browser is selected, the app MUST ask the user to choose one, with a "Don't use" option. The choice MUST be remembered.

#### Scenario: No browser selected
- **WHEN** a retry with cookies is needed and no browser has been selected yet
- **THEN** the user is asked to choose a browser; after the choice the retry runs and the choice is saved in Settings

#### Scenario: User declines
- **WHEN** the user chooses "Don't use"
- **THEN** the original access error is shown without a retry

### Requirement: Cookie access denied
If the app cannot read the browser's cookies, a dedicated message SHALL explain why. For Safari, it MUST offer a button that opens the "Full Disk Access" system settings.

#### Scenario: Safari without Full Disk Access
- **WHEN** Safari is selected and the app does not have Full Disk Access
- **THEN** the message "Cannot access Safari cookies" is shown with an "Open Privacy Settings" button

### Requirement: Cookie privacy
The app SHALL NOT store, copy, or log cookie values. Cookies MUST be read only while an operation is running.

#### Scenario: Log after a retry with cookies
- **WHEN** an operation ran with cookies and the user exports the log
- **THEN** the log contains the browser name but no cookie values
