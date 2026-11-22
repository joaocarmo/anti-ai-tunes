# Architecture

This file describes how Anti-AI Tunes is built and the rules the code must follow. It follows the ARCHITECTURE.md format: a short map of the code plus the rules that rarely change.[^1] Find code with symbol search. This file names types but does not link to them, because links go stale.

Status: v0.4.0 in progress. Types marked *(planned)* do not exist yet. The rest is in the code. Update this file when an invariant or a boundary changes.

## Bird's-eye view

The Music app posts a distributed notification, `com.apple.Music.playerInfo`, whenever the track changes. The app turns it into a `PlayerEvent`. It normalises the artist and splits collaborations into parts. Then it checks each part against the subscribed AI-artist lists and the user's own decisions.

On a match, the app runs the configured action through Apple Events. The default action is to skip the track. Before the skip, the app tries to dislike the track and reads the result back. On macOS 27, Music ignores this for streamed songs, so the history records whether it stuck. The app records a row in its history and posts a notification with a **Not AI** button. That button undoes the action and allows the artist from then on.

```text
Music.app --playerInfo--> MusicObserverAdapter --PlayerEvent--> MatchCoordinator
                                                                   |-- Verdict (Track.artistParts(), listed artists, decisions)
                                                                   |-- MusicControlling --Apple Events--> Music.app
                                                                   |-- Notifying --> notification with "Not AI"
                                                                   '-- Store --> SQLite (history, decisions)

SourceRefresher --HTTP + ETag--> [TransformRunner] --> SourceParser --> Store (listed artists)
```

## Codemap

### `AntiAITunesCore` (Swift package)

All logic lives here. It has no UI code.

- `Normalizer`: case-folds, strips diacritics, trims and collapses whitespace. Keeps dots.
- `Track.artistParts()`: normalises the artist and splits it on `, `, ` & `, ` x `, ` feat. `, ` ft. ` and ` featuring `. Also reads featured names from the title, after `feat.`, `ft.` or `featuring`: inside `()`, `[]` or `{}` up to the matching bracket, or without a bracket up to the end. Brackets inside a name stay in it.
- `Verdict`: the parts that are on the list and not allowed by a decision.
- `PlayerEvent` and `Track`: parse the `playerInfo` dictionary and the launch read. A message without `Name` is a state-only event. `Track.key` joins the normalised `Name`, `Artist` and `Album`, because streamed songs carry no persistent ID.
- `NowPlaying`: applies events to the current state and reports when a different song starts, so repeats count once.
- `MatchCoordinator`: the core flow. It owns `NowPlaying` and checks each song once, the first time it plays. It records 1 `play` row per song. On a match, it tries the dislike, skips and notifies. A song without an artist and without a match gets a notification that says so. A play gets at most 1 notification, and a song at most 3 on one local day, counted from its `play` rows. The calendar for the local day is passed in. It acts in the same main-actor turn as the matching `playerInfo`, so the key is still the latest (invariant 6). A delay before acting must compare the key again. It sends Apple Events only while `MusicControlling.isRunning` is true. **Not AI** allows every matched part. For the most recent skip, and only while the song after it plays, it also sends `previous track`, waits 1 second, and sends it once more if the skipped song is not back. The first call may only restart the current song. If the dislike stuck, it clears it the next time the skipped song plays while the app runs, for any skip, because the call acts on the current song. Later it also handles the delay before acting and its track-key check.
- `Skip`: the track key, matched parts and display names of a skip, and the notification payload that brings them back to **Not AI**, even after a relaunch.
- `CSVNames`: parses a `csv` body (RFC 4180) and returns the normalised names in a named column. Drops blank names. The `lines` format comes with subscribed lists.
- `TransformRunner` *(planned)*: runs an optional local command. The downloaded body goes in on stdin, and names come out on stdout.
- `SourceRefresher` *(planned)*: downloads each subscribed list with `If-None-Match`. It replaces that list's rows in one transaction.
- `ListRefresher` and `ListCache`: download the default list with `If-None-Match` at launch and every 24 hours, with a 10 MB cap. They keep it in `Store`, with the time the names last changed and the time the host last answered. Any failure keeps the stored list. `SourceRefresher` replaces `ListRefresher`.
- `Store`: the GRDB database (`db.sqlite`), its migrations and all queries. If the file cannot open, it saves nothing, and the menu says that changes are not saved.
- `Archiver` *(planned)*: moves history rows beyond the newest N into the archive database.
- `MenuState`: the view model. Views only render it.
- Ports: `MusicControlling`, `Notifying`, `TimeSource` and `HTTPClient`. These protocols are the only way the package reaches the system. `HTTPBody.collect` enforces the response size cap for the `HTTPClient` adapter. `MusicControlling.dislikeCurrentTrack(name:artist:album:)` dislikes the current song only if it is still the matched one, and returns the read-back as text, or nil on failure, and `Dislike` maps it to `.accepted`, `.ignored` or `.failed`. A better dislike method later changes only the adapter.

### `App/` (SwiftPM executable target `AntiAITunes`)

Thin adapters and views. The folder is excluded from coverage as a whole. `Package.swift` adds this target only on macOS, so the core package also builds and tests on Linux. There is no Xcode project: `scripts/bundle.sh` assembles and signs `AntiAITunes.app` from the binary, `Support/Info.plist` and `Support/AntiAITunes.entitlements`.

- `AntiAITunesApp`: the `MenuBarExtra` and, later, the Settings scene. `AppModel` wires the adapters into the package. The menu also offers **Not AI** for the last skip, because notification banners disappear on a timer.[^10]
- `MusicObserverAdapter`: subscribes to `com.apple.Music.playerInfo` through `DistributedNotificationCenter`.
- `MusicControllerAdapter`: implements `MusicControlling` with pre-compiled `NSAppleScript`. It also reads the current song at launch.
- `NotifierAdapter`: implements `Notifying` with `UNUserNotificationCenter`. It asks for permission at launch. As the notification delegate, it registers the **Not AI** action, shows notifications while the app is in front, and forwards the action. `AppModel` creates it in `App.init`, because Apple requires the delegate before the app finishes launching.[^9]
- `URLSessionHTTPClient` and `SystemClock`: implement `HTTPClient` and `TimeSource`.
- Views: menu, settings, sources and decisions. The launch-at-login toggle binds `SMAppService.mainApp` directly.[^2]

### Data

- `db.sqlite`: lists (`source`, `listedArtist`) and decisions (`decision`) and history (`play`). The daily notification cap counts `play` rows, so it has no table of its own.
- `history-archive.sqlite` *(planned)*: older `play` rows, same schema.

All files live in `~/Library/Application Support/AntiAITunes/`. Versions before 0.3.0 kept the default list in `default-list.json`. `Store` deletes that file.

Schema conventions:

1. Table and column names are English, singular and camelCase. Every table has an explicit primary key. A single-column key is an `INTEGER PRIMARY KEY` named `id`.[^11]
2. Unique values have a unique index. Relations use foreign keys, and child keys are indexed.[^11][^12]
3. Every table is `STRICT`.[^13] Closed value sets use `CHECK (x IN (…))`, listing only values the roadmap names.
4. Dates are UTC `TEXT` in GRDB's format, `YYYY-MM-DD HH:MM:SS.SSS`. Names are stored normalised, so comparisons are binary. History rows also keep the song's name, artist and album as Music shows them.
5. `WITHOUT ROWID` only for composite keys with small rows.[^14]
6. Migrations are SQL strings that never use app types. A shipped migration never changes. Later needs add tables, columns or indexes.[^15]

## Invariants

MUST and MUST NOT have the meaning given in BCP 14 (RFC 2119 and RFC 8174).[^3][^4] They have this meaning only in capitals.

1. `AntiAITunesCore` MUST NOT import AppKit, SwiftUI or UserNotifications.
2. Code in `App/` MUST NOT contain logic. A branch that does more than forward a nil belongs in the package, with a test.
3. Package line coverage MUST be 100%, with no exclusions inside the package.
4. The app MUST NOT launch Music.app. Every Apple Event is sent only while Music.app is running.
5. Song changes MUST come from the `playerInfo` notification. The app MUST NOT poll Music with Apple Events. One best-effort read of the current song at launch is allowed, because Music announces only changes. That read can fail for songs outside the library on some macOS versions.[^5]
6. An action MUST run only if the matched track key equals the key of the latest `playerInfo`. This check MUST NOT use Apple Events.
7. A dislike attempt MUST run before `next track`. Otherwise it lands on the wrong track. The app MUST NOT report a dislike unless the read-back returns `true`.
8. Downloaded list data MUST reach a transform command only on stdin. It MUST NOT become part of a command string or argument.
9. A failed refresh, transform or archive MUST NOT delete existing data.
10. Code outside `Store` MUST NOT touch the database. Code outside `SourceRefresher` (today `ListRefresher`) MUST NOT touch the network. Code outside `TransformRunner` MUST NOT start processes.
11. Time MUST come from `TimeSource`. Tests MUST NOT sleep.
12. A shipped migration MUST NOT change. Schema changes add a new migration.
13. The app MUST NOT use paid services, accounts or APIs.

## Boundaries

- **Package and system.** The package reaches the system only through `MusicControlling`, `Notifying`, `TimeSource` and `HTTPClient`. Tests use hand-written fakes that log every call to one shared event log, so a test can check call order.
- **Package and database.** `Store` owns the schema and every query. Other types get plain values.
- **Package and network.** `SourceRefresher` (today `ListRefresher`) is the only network client. It sends `If-None-Match` and treats `304` as "no change".
- **Package and shell.** `TransformRunner` runs `/bin/zsh -c <command>` with a 30-second timeout and an output cap. The command comes from local settings only, never from a list.
- **App and package.** Adapters translate system types into package types and back. Views read `MenuState` and call package methods.

## Cross-cutting concerns

### Errors

Apple Event failures are best-effort, and the flow continues. A failed dislike is recorded as `failed` in its `play` row and still skips. The other Apple Events report no error. Refresh failures keep the previous rows and show the error on the source. Archive failures roll back and show the error in Settings.

### Time

All timers, delays and dates come from `TimeSource`. The notification cap counts per local calendar day.

### Persistence

GRDB handles the database and migrations. Lists and decisions are cached in memory as sets, and updated with every write. History keeps the newest N rows (1,000 by default). Older rows move to the archive in one transaction.

### Testing

Every feature in the package ships with unit tests. CI fails below 100% line coverage. Faults such as a read-only directory, a non-zero exit or a timeout are injected, never waited for.

Fixtures use real songs, with the artist, title and album as Apple Music shows them. The Velvet Sundown, "Dust on the Wind" (*Floating on Echoes*), is on the default list and plays the AI artist. System Of A Down, "Chop Suey!" (*Toxicity*), plays the human artist. A test never lists a real human artist as AI. When no real data fits, it uses a clearly fictional name.

### Security

The app is unsandboxed, because it sends Apple Events to Music.app. It declares `NSAppleEventsUsageDescription`[^6] and, with the hardened runtime, the `com.apple.security.automation.apple-events` entitlement.[^7] The transform command is the main risk, and invariant 8 covers it.

### Signing and releases

Releases are signed with one self-signed certificate. A stable signature lets macOS keep permissions across updates.[^8] The app is not notarised, so first launch needs **Open Anyway**. See the README.

### Platform risk

The `playerInfo` keys are undocumented. `PlayerEvent` is the only place that reads them. On macOS 27.0.1, Music ignores AppleScript dislikes for streamed songs.[^5] "Suggest Less" exists only in window controls that the accessibility API cannot reach reliably. ROADMAP.md has the spike details. The app therefore skips without relying on the dislike.

[^1]: Aleksey Kladov, "ARCHITECTURE.md", 6 February 2021. <https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html>
[^2]: Apple Developer Documentation, `SMAppService.mainApp` (macOS 13.0+). <https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp>
[^3]: RFC 2119, "Key words for use in RFCs to Indicate Requirement Levels". <https://www.rfc-editor.org/rfc/rfc2119>
[^4]: RFC 8174, "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words". <https://www.rfc-editor.org/rfc/rfc8174>
[^5]: plmcgrn, "Setting favorite/suggest less keyboard shortcuts in Apple Music for Mac" (notes on macOS Tahoe). <https://gist.github.com/plmcgrn/5d908e576821b3e0a9e5d0c707316087> The project's own test on macOS 27.0.1 is in [ROADMAP.md](ROADMAP.md#spike-results-macos-2701).
[^6]: Apple Developer Documentation, `NSAppleEventsUsageDescription`. <https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription>
[^7]: Apple Developer Documentation, `com.apple.security.automation.apple-events`. <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events>
[^8]: Barkeep, "Why macOS permissions vanish every time you rebuild your app". <https://barkeepmac.com/macos-permissions-lost-after-rebuild.html>
[^9]: Apple Developer Documentation, `UNUserNotificationCenterDelegate`. <https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate>
[^10]: Apple Human Interface Guidelines, "Accessibility", section "Cognitive": "Minimize use of time-boxed interface elements." <https://developer.apple.com/design/human-interface-guidelines/accessibility>
[^11]: GRDB, "Database Schema Recommendations". <https://github.com/groue/GRDB.swift/blob/master/GRDB/Documentation.docc/DatabaseSchemaRecommendations.md>
[^12]: SQLite, "SQLite Foreign Key Support", section "Required and Suggested Database Indexes". <https://www.sqlite.org/foreignkeys.html>
[^13]: SQLite, "STRICT Tables". <https://www.sqlite.org/stricttables.html>
[^14]: SQLite, "The WITHOUT ROWID Optimization", section "When To Use WITHOUT ROWID". <https://www.sqlite.org/withoutrowid.html>
[^15]: GRDB, "Migrations", section "Good Practices for Defining Migrations". <https://github.com/groue/GRDB.swift/blob/master/GRDB/Documentation.docc/Migrations.md>
