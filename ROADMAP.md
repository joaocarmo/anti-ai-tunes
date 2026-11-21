# Roadmap

This file lists what comes next and in which order. It also records the product decisions that each increment builds on.

- What is done for users: [CHANGELOG.md](CHANGELOG.md).
- All finished work, internal included: the closed issues.
- What is being built now: the one open issue with the `increment` label.

[CONTRIBUTING.md](CONTRIBUTING.md) explains how increments work.

## Increments

| # | Version | Goal | Status |
|---|---|---|---|
| 0 | n/a | Repository bootstrap: docs and community files | Done |
| 1 | n/a | Spike on macOS 27.0.1 (see "Spike results") | Done |
| 2 | n/a | Working model docs, this roadmap, the increment issue form | Done |
| 3 | v0.1.0 | Walking skeleton: menu-bar app that shows the current artist and title. CI with the coverage gate. Signed releases. | Done |
| 4 | v0.2.0 | Skip AI artists from the default list. "Skipped X (AI)" notification. | Done |
| 5 | v0.3.0 | **Not AI** button: allow the artist and go back to the skipped song. | Done |
| 6 | v0.4.0 | History of played songs. Best-effort dislike, with the result recorded. "Couldn't detect the artist" notification. Daily notification cap. | Next |
| 7 | v0.5.0 | Settings: action on match, delay, pause, launch at login, notification-style warning. The new views are checked with VoiceOver. | Planned |
| 8 | v0.6.0 | Subscribed lists: add and edit lists, `lines` format, transform command. | Planned |
| 9 | v0.7.0 | Manual control: mark as AI, report upstream, list of decisions. | Planned |
| 10 | v0.8.0 | History archive. | Planned |
| 11 | v0.9.0 | Polish: app icon, menu-bar icon, About panel with the version. Check for a newer release, with an off switch (no auto-update). Check whether a download made by the app skips the Gatekeeper prompt on each update. Localisation in British English (`en-GB`) and European Portuguese (`pt-PT`). | Planned |
| 12 | v1.0.0 | Stable release, after v0.9.0 runs for a while with no open bugs. | Planned |
| 13 | later | Experimental: "Suggest Less" through UI scripting, if macOS offers a reliable control. | Idea |

Increment 3 shipped as v0.1.1. The v0.1.0 release has no build attached (see CHANGELOG.md).

## Product decisions

| Topic | Decision |
|---|---|
| Platform | Swift menu-bar app, unsandboxed, macOS 14 or later. No paid services, accounts or APIs. |
| Track detection | The `com.apple.Music.playerInfo` distributed notification. No polling. One best-effort Apple Events read of the current song at launch, because Music announces only changes. |
| Track key | Normalised `Name + Artist + Album`. A notification without `Name` only updates the player state. Repeated notifications for the same key count once. |
| Matching | Case-fold, strip diacritics, keep dots, trim and collapse spaces. Split the artist on `, `, ` & `, ` x `, ` feat. ` and ` ft. `. Also read `(feat. X)` from the title. Match the whole string or any part. |
| Verdict | An `allow` decision excludes that part. A `skip` decision or a listed name triggers the action. |
| Action on match | `skip` (default), `pause` or `nothing`, after a delay of 0 to 60 seconds (default 0). A track change or **Not AI** cancels a pending action. The app acts only while the track key still matches. |
| Dislike | Best-effort, before every skip. The app sets `disliked`, reads it back and records the result. It never claims a dislike that did not stick. All of it sits behind `MusicControlling.dislikeCurrentTrack()`, so a better method later changes only the adapter. |
| Undo (**Not AI**) | Store `allow` for each matched part. Go back with `previous track`. Wait up to 1 second for the skipped song. If it is not playing, send `previous track` once more. Stop after 2 calls. The app waits a fixed 1 second. It goes back only for the most recent skip, while the song after it plays. An older skip is only allowed. **Not AI** is in the notification and the menu, because banners disappear on a timer. Clear the dislike only if it stuck. |
| No artist | A song with a name but no artist gets 1 notification: "Couldn't detect the artist for <name>". |
| Notification cap | After N notifications (default 3) for the same key on one day, the app acts silently. 0 means no cap. Counts reset at local midnight and when a decision changes. |
| Lists | Subscriptions with a URL and a format (`csv` with a column, or `lines`). An optional local transform command reads the download on stdin. Refresh at launch, every 24 hours and on demand, with ETag. Default list: CennoxX `SpotifyAiArtists.csv`. |
| History | 1 row per song played. The newest 1,000 rows stay in `db.sqlite`. Older rows move to `history-archive.sqlite` in the same folder. |
| Storage | SQLite through GRDB, in `~/Library/Application Support/AntiAITunes/`. Settings in `UserDefaults`. |
| Library songs | Treated like any other song. |
| Manual decisions | **Not AI** stores `allow` for each matched part, so "A & B" with A listed allows A. **Mark as AI** stores `skip` for the whole artist string, so marking "A & B" does not cover A alone. |
| Report upstream | Opens `https://github.com/CennoxX/spotify-ai-blocker/issues/new?template=ai-artist.yml&artist_name=<name>`. That form also requires Spotify artist and track URLs, which the user adds by hand. |
| Notification settings | At launch and when the app becomes active, it reads `UNNotificationSettings`. If notifications are off or `alertStyle` is not `.alert`, the menu shows a warning with a button to `x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=<bundle id>` (fallback: `com.apple.preference.notifications?id=<bundle id>`). |
| Transform command | Local settings only, never from a list. Runs `/bin/zsh -c <command>` with the download on stdin and expects 1 name per line. 30-second timeout and an output cap. On failure the previous rows stay. |
| Launch at login | `SMAppService.mainApp`, on by default, with a Settings toggle. |
| Default list storage | v0.2.x used a JSON cache file (`default-list.json`). From v0.3.0 the list lives in `db.sqlite`, and the old file is deleted. |
| Releases | Signed with one self-signed certificate. Not notarised. |
| Localisation (v0.9.0) | `en-GB` (the development region) and `pt-PT`. The core keeps its strings in `.lproj` folders and reads them with `NSLocalizedString(_:bundle: .module, comment:)`, because `String(localized:)` is missing on Linux. The app bundle also gets `en-GB.lproj` and `pt-PT.lproj` folders with an `InfoPlist.strings` that translates `NSAppleEventsUsageDescription`. Those folders also tell macOS which languages the app supports. Without them, macOS shows the core's strings in English only. A probe on the CI runner showed: other English variants get `en-GB`, `pt-BR` and `pt` get `pt-PT`, and other languages get `en-GB`. |

## Spike results (macOS 27.0.1)

The spike ran on 18 November 2026 with streamed songs only.

- **Track data.** `playerInfo` has `Name`, `Artist`, `Album`, `Genre`, `Composer`, `Total Time` and `Player State`. It has no persistent ID and no store URL. `Total Time` can change for the same song.
- **Skip and back.** `next track` works. `previous track` first restarts the song if it has played for a few seconds. A second call then goes back.
- **Dislike.** `set disliked of current track to true` gives no error. Reading it back returns `false`, and the song's menu still offers "Suggest Less". Music ignores it.
- **Suggest Less.** It is not in the menu bar. It is only in the Now Playing bar and on each song row. The accessibility tree shows the row buttons ("More") only while the row is on screen. It shows no Now Playing button, and the Mini Player exposes none. A full-screen Music window is not visible to the accessibility API.
- **Accessibility permission.** On macOS 27 it is under Privacy & Security › Device Control and Data Access.
- **Launch read.** `get {name, artist, album} of current track` returned the streamed song. Reports say this failed on macOS 26.0, so the read stays best-effort.

## Decisions and alternatives

| Topic | Chosen | Rejected | Why |
|---|---|---|---|
| Packaging | SwiftPM executable and shell scripts | Xcode project, XcodeGen, swift-bundler | Plain-text build files that agents in a Linux sandbox can read and check. XcodeGen adds a tool everywhere. swift-bundler's last release is from 2022. |
| Universal build | One `swift build` per architecture, merged with `lipo` | One build with 2 `--arch` flags | Same build mode as `swift test`. Swift 6.4 builds every architecture into the same folder, so each thin binary is copied out first. |
| Signing | One self-signed certificate | Developer ID and notarisation, ad hoc | No paid membership. Ad hoc signatures change with every build, so macOS asks for permissions again. |
| Releases | Tag push creates a draft with assets, then publish | Upload after publishing | The repo uses immutable releases, which lock assets on publish. |
| CI steps | Shell steps for the keychain and `gh` for releases | Apple-Actions/import-codesign-certs, softprops/action-gh-release | GitHub's own signing guide uses the same commands. Fewer third-party actions handle secrets or a write token. |
| Action pinning | `actions.lock` from `gh actions-lock` | SHA pins in workflow files | GitHub's recommendation. It also covers transitive actions. |
| CI image | `xcode-27` runner with Xcode 27.2 | `macos-26` with Xcode 26.6 | Newest toolchain, same Swift (6.4.2) as the sandbox, so `swift format` agrees. The image is in preview; `macos-26` is the fallback. |
| Coverage gate | `scripts/coverage.sh` inside the required `test` check | GitHub Code Quality's coverage rule | Code Quality is paid per committer and needs a Cobertura report. |
| Dislike | AppleScript attempt with read-back | Apple Music API ratings, UI-scripted "Suggest Less" | The API needs a paid membership. The UI control is not reliably reachable (see the spike). |
| Test doubles | Hand-written fakes with one shared event log | Mockable and other macro libraries | Tests can check call order, with no dependency. Revisit above about 6 ports. |
| Persistence in v0.2.0 | JSON cache file | GRDB now | GRDB arrives with decisions in v0.3.0. GRDB on Linux is unofficial. |

## Beyond the roadmap

- A History window: one row per song with the action taken, and buttons for **Not AI**, **Mark as AI** and **Report upstream**. It reads the main database and, on demand, the archive.
- A REST API on top of the core package. The package has no UI imports so that a server can use it.
