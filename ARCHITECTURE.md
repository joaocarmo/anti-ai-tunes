# Architecture

This file describes how Anti-AI Tunes is built and the rules the code must follow. It follows the ARCHITECTURE.md format: a short map of the code plus the rules that rarely change.[^1] Find code with symbol search. This file names types but does not link to them, because links go stale.

Status: pre-alpha. This is the planned design. Update this file when an invariant or a boundary changes.

## Bird's-eye view

The Music app posts a distributed notification, `com.apple.Music.playerInfo`, whenever the track changes. The app turns it into a `TrackInfo`. It normalises the artist and splits collaborations into parts. Then it checks each part against the subscribed AI-artist lists and the user's own decisions.

On a match, the app runs the configured action through Apple Events. The default action is to dislike the track, then skip it. The app records a row in its history and posts a notification with a **Not AI** button. That button undoes the action and allows the artist from then on.

```text
Music.app --playerInfo--> MusicObserverAdapter --TrackInfo--> MatchCoordinator
                                                                |-- Verdict (ArtistNormalizer, listed artists, decisions)
                                                                |-- MusicControlling --Apple Events--> Music.app
                                                                |-- Notifying --> notification with "Not AI"
                                                                '-- Store --> SQLite (history, decisions)

SourceRefresher --HTTP + ETag--> [TransformRunner] --> SourceParser --> Store (listed artists)
```

## Codemap

### `AntiAITunesCore` (Swift package)

All logic lives here. It has no UI code.

- `ArtistNormalizer`: case-folds, strips diacritics and collapses whitespace. Splits an artist string on `&`, `,`, `x`, `feat.` and `ft.`, and reads `(feat. X)` from the title.
- `Verdict`: a pure function. It takes the artist parts, the listed names and the decisions, and returns match or ignore.
- `TrackInfo`: parses the `playerInfo` dictionary and builds the track key. The key is the persistent ID, or `Name + Artist + Album` when that ID is missing.
- `MatchCoordinator`: the core flow. It handles the delay before acting, the track-key check, history rows, the daily notification cap, and the **Not AI** undo.
- `SourceParser`: turns a `csv` (with a named column) or `lines` body into names.
- `TransformRunner`: runs an optional local command. The downloaded body goes in on stdin, and names come out on stdout.
- `SourceRefresher`: downloads each subscribed list with `If-None-Match`. It replaces that list's rows in one transaction.
- `Store`: the GRDB database, its migrations and all queries.
- `Archiver`: moves history rows beyond the newest N into the archive database.
- `MenuState`: the view model. Views only render it.
- Ports: `MusicControlling`, `Notifying` and `Clock`. These protocols are the only way the package reaches the system.

### `App/` (Xcode project)

Thin adapters and views. The folder is excluded from coverage as a whole.

- `AntiAITunesApp`: the `MenuBarExtra` and the Settings scene. Wires the adapters into the package.
- `MusicObserverAdapter`: subscribes to `com.apple.Music.playerInfo` through `DistributedNotificationCenter`.
- `MusicControllerAdapter`: implements `MusicControlling` with pre-compiled `NSAppleScript`.
- `NotifierAdapter`: implements `Notifying` with `UNUserNotificationCenter`.
- Views: menu, settings, sources and decisions. The launch-at-login toggle binds `SMAppService.mainApp` directly.[^2]

### Data

- `db.sqlite`: lists (`source`, `listed_artist`), decisions (`decision`), history (`play`) and daily notification counts (`notification_count`).
- `history-archive.sqlite`: older `play` rows, same schema.

Both files live in `~/Library/Application Support/AntiAITunes/`.

## Invariants

MUST and MUST NOT have the meaning given in BCP 14 (RFC 2119 and RFC 8174).[^3][^4] They have this meaning only in capitals.

1. `AntiAITunesCore` MUST NOT import AppKit, SwiftUI or UserNotifications.
2. Code in `App/` MUST NOT contain logic. A branch that does more than forward a nil belongs in the package, with a test.
3. Package line coverage MUST be 100%, with no exclusions inside the package.
4. The app MUST NOT launch Music.app. Every Apple Event is sent only while Music.app is running.
5. Track data MUST come from the `playerInfo` notification. The app MUST NOT read the current track with Apple Events. On some macOS versions, that fails for tracks outside the library.[^5]
6. An action MUST run only if the matched track key equals the key of the latest `playerInfo`. This check MUST NOT use Apple Events.
7. A dislike MUST run before `next track`. Otherwise it lands on the wrong track.
8. Downloaded list data MUST reach a transform command only on stdin. It MUST NOT become part of a command string or argument.
9. A failed refresh, transform or archive MUST NOT delete existing data.
10. Code outside `Store` MUST NOT touch the database. Code outside `SourceRefresher` MUST NOT touch the network. Code outside `TransformRunner` MUST NOT start processes.
11. Time MUST come from `Clock`. Tests MUST NOT sleep.
12. A shipped migration MUST NOT change. Schema changes add a new migration.
13. The app MUST NOT use paid services, accounts or APIs.

## Boundaries

- **Package and system.** The package reaches the system only through `MusicControlling`, `Notifying` and `Clock`. Tests use hand-written fakes that log every call to one shared event log, so a test can check call order.
- **Package and database.** `Store` owns the schema and every query. Other types get plain values.
- **Package and network.** `SourceRefresher` is the only network client. It sends `If-None-Match` and treats `304` as "no change".
- **Package and shell.** `TransformRunner` runs `/bin/zsh -c <command>` with a 30-second timeout and an output cap. The command comes from local settings only, never from a list.
- **App and package.** Adapters translate system types into package types and back. Views read `MenuState` and call package methods.

## Cross-cutting concerns

### Errors

Apple Event failures are best-effort. They are logged in the `play` row's `error` column, and the flow continues. For example, a failed dislike still skips. Refresh failures keep the previous rows and show the error on the source. Archive failures roll back and show the error in Settings.

### Time

All timers, delays and dates come from `Clock`. The notification cap counts per local calendar day.

### Persistence

GRDB handles the database and migrations. Lists and decisions are cached in memory, as a `Set` and a `Dictionary`, and reloaded after every write. History keeps the newest N rows (1,000 by default). Older rows move to the archive in one transaction.

### Testing

Every feature in the package ships with unit tests. CI fails below 100% line coverage. Faults such as a read-only directory, a non-zero exit or a timeout are injected, never waited for.

### Security

The app is unsandboxed, because it sends Apple Events to Music.app. It declares `NSAppleEventsUsageDescription`[^6] and, with the hardened runtime, the `com.apple.security.automation.apple-events` entitlement.[^7] The transform command is the main risk, and invariant 8 covers it.

### Signing and releases

Releases are signed with one self-signed certificate. A stable signature lets macOS keep permissions across updates.[^8] The app is not notarised, so first launch needs **Open Anyway**. See the README.

### Platform risk

The `playerInfo` keys are undocumented. `TrackInfo` is the only place that reads them. Dislike through AppleScript may fail for tracks outside the library on some macOS versions.[^5] The fallback is still open: UI scripting "Suggest Less", or skip only.

[^1]: Aleksey Kladov, "ARCHITECTURE.md", 6 February 2021. <https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html>
[^2]: Apple Developer Documentation, `SMAppService.mainApp` (macOS 13.0+). <https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp>
[^3]: RFC 2119, "Key words for use in RFCs to Indicate Requirement Levels". <https://www.rfc-editor.org/rfc/rfc2119>
[^4]: RFC 8174, "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words". <https://www.rfc-editor.org/rfc/rfc8174>
[^5]: plmcgrn, "Setting favorite/suggest less keyboard shortcuts in Apple Music for Mac" (notes on macOS Tahoe). <https://gist.github.com/plmcgrn/5d908e576821b3e0a9e5d0c707316087>
[^6]: Apple Developer Documentation, `NSAppleEventsUsageDescription`. <https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription>
[^7]: Apple Developer Documentation, `com.apple.security.automation.apple-events`. <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events>
[^8]: Barkeep, "Why macOS permissions vanish every time you rebuild your app". <https://barkeepmac.com/macos-permissions-lost-after-rebuild.html>
