# Spec Delta

## Purpose

Provides a reproducible release build with verified external tool versions and an easy way to update those versions when releasing a new app version.

## ADDED Requirements

### Requirement: Tool version manifest
The versions, download URLs and SHA-256 checksums of all bundled tools SHALL be kept in a single manifest in the repository. The build MUST use only the versions from the manifest.

#### Scenario: Reproducibility
- **WHEN** two developers build the app from the same commit
- **THEN** both bundles contain byte-identical tools

### Requirement: Checksum verification
The build SHALL verify the SHA-256 of every downloaded tool against the manifest and MUST fail on a mismatch.

#### Scenario: Tampered file
- **WHEN** the checksum of a downloaded archive does not match the manifest
- **THEN** the build stops with a message naming the tool that failed verification

### Requirement: Updating tool versions
The repository SHALL contain an update command that finds the latest stable releases of the tools, verifies them against the checksums or signatures published by their sources, and updates the manifest. If a signature cannot be verified on the developer machine, the command MUST print a warning. The command MUST print the list of changed versions.

#### Scenario: New yt-dlp release
- **WHEN** the developer runs the update command after a new yt-dlp version is released
- **THEN** the manifest contains the new version and its SHA-256, and the output reports the yt-dlp version change

### Requirement: Built bundle verification
The release build SHALL verify that every bundled tool is an arm64 executable and reports its version successfully when run from the bundle.

#### Scenario: Wrong architecture
- **WHEN** an x86_64-only binary ends up in the bundle
- **THEN** the release build fails

### Requirement: Release artifact
The release command SHALL produce a zip archive containing the `.app`, ad-hoc signed (including all bundled binaries), for macOS 14+ and arm64. The archive name MUST contain the app version.

#### Scenario: Building a release
- **WHEN** the developer runs the release command for version 0.1.0
- **THEN** `kDownloader-0.1.0.zip` is created, and `codesign --verify --deep --strict` passes for the `.app` inside it
