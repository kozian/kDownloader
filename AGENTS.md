# Agent instructions

kDownloader is a SwiftUI macOS app around yt-dlp. [README.md](README.md) is the
user guide, [DEVELOPMENT.md](DEVELOPMENT.md) covers building, testing and
releasing, [BACKLOG.md](BACKLOG.md) lists tasks and ideas.

## Workflow

- Behavior changes go through OpenSpec: propose a change in `openspec/changes/`,
  implement it, archive it. `openspec/specs/` is the source of truth for how the
  app behaves; check it before changing behavior.
- Code, comments, commit messages, specs, README and BACKLOG are in English. The
  UI is in English and Russian (`App/Localizable.xcstrings`).

## Git and GitHub

- Commit only when asked.
- The repository is public: never push, push tags, create GitHub releases or
  force-push without an explicit request.
- No `Co-Authored-By` or other attribution lines in commits.

## Releases

- Run `scripts/release.sh` without `--dry-run` only when a release is asked for,
  following the `release-update` skill (`.claude/skills/release-update/`).
- After changes the maintainer will try, rebuild the test archive with
  `scripts/release.sh --dry-run` and name the file
  (`dist/kDownloader-<version>-dryrun.zip`) and its build time. The maintainer
  tests from `dist/`, not from the Xcode build.

## Checks after code changes

- `swift test --package-path Packages/KDownloaderCore`.
- After a build, `python3 scripts/check-localization.py`: new keys, Russian
  translations and wording the glossary rules out.
- Check the UI with the Debug snapshot hooks (`scripts/snapshot.swift`, see
  DEVELOPMENT.md): agents have no Screen Recording or Accessibility permission,
  so window snapshots are the way to see the UI.

## Pitfalls

- Never commit tool binaries or third-party license texts: both are downloaded
  and verified by the build from `tools/manifest.json`.
- A new bundled tool needs a `licenses` entry in the manifests (see
  DEVELOPMENT.md "License notices"); `release.sh` refuses a build without them.
- Do not edit `App/Assets.xcassets/AppIcon.appiconset/` by hand: regenerate it
  from `Design/AppIcon.png` with `scripts/make-icon.swift`.
