# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog 1.1.0.[^1] This project follows Semantic Versioning 2.0.0.[^2]

## [Unreleased]

## [0.3.1] - 2026-11-22

### Fixed

- Skips featured AI artists in more credit styles, such as `[feat. X]` and `featuring X`, and AI artists with 1-character names.

## [0.3.0] - 2026-11-22

### Added

- **Not AI** in the skip notification and in the menu: allows the artist and goes back to the skipped song.

### Changed

- The AI list is stored in a database. The app downloads it again once after the update.

## [0.2.1] - 2026-11-21

### Changed

- The menu shows the AI list in an **AI list** submenu: the number of artists, when the list last changed and when the app last checked it.

### Fixed

- The list date showed the last check, labelled "updated", even when the list had not changed.

## [0.2.0] - 2026-11-21

### Added

- Skips songs by artists on the default AI-artist list, with a notification. There is no undo yet. To hear a song skipped by mistake, quit the app from its menu. **Not AI** arrives in 0.3.0.

## [0.1.1] - 2026-11-19

### Fixed

- Releases now include the signed app. The 0.1.0 release was published without it.

## [0.1.0] - 2026-11-19

### Added

- A menu-bar app that shows the artist and title playing in the Music app.
- Project documentation, community files and issue and pull request templates.
- A roadmap and an increment-based workflow for contributors.

[unreleased]: https://github.com/joaocarmo/anti-ai-tunes/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/joaocarmo/anti-ai-tunes/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/joaocarmo/anti-ai-tunes/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/joaocarmo/anti-ai-tunes/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/joaocarmo/anti-ai-tunes/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/joaocarmo/anti-ai-tunes/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/joaocarmo/anti-ai-tunes/releases/tag/v0.1.0

[^1]: Keep a Changelog 1.1.0. <https://keepachangelog.com/en/1.1.0/>
[^2]: Semantic Versioning 2.0.0. <https://semver.org/spec/v2.0.0.html>
