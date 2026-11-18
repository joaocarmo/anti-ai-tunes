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
| 3 | v0.1.0 | Walking skeleton: menu-bar app that shows the current artist and title. CI with the coverage gate. Signed releases. | Next |
| 4 | v0.2.0 | Skip AI artists from the default list. "Skipped X (AI)" notification. | Planned |
| 5 | v0.3.0 | **Not AI** button: allow the artist and go back to the skipped song. | Planned |
| 6 | v0.4.0 | History of played songs. Best-effort dislike, with the result recorded. "Couldn't detect the artist" notification. Daily notification cap. | Planned |
| 7 | v0.5.0 | Settings: action on match, delay, pause, launch at login, notification-style warning. | Planned |
| 8 | v0.6.0 | Subscribed lists: add and edit lists, `lines` format, transform command. | Planned |
| 9 | v0.7.0 | Manual control: mark as AI, report upstream, list of decisions. | Planned |
| 10 | v0.8.0 | History archive. | Planned |
| 11 | v1.0.0 | Stable release, after v0.8.0 runs for a while with no open bugs. | Planned |
| 12 | later | Experimental: "Suggest Less" through UI scripting, if macOS offers a reliable control. | Idea |

Increment 3 needs the signing certificate and 2 repository secrets first. See "One-time signing setup" in CONTRIBUTING.md.

## Product decisions

| Topic | Decision |
|---|---|
| Platform | Swift menu-bar app, unsandboxed, macOS 14 or later. No paid services, accounts or APIs. |
| Track detection | The `com.apple.Music.playerInfo` distributed notification. No polling and no Apple Events for reading. |
| Track key | Normalised `Name + Artist + Album`. A notification without `Name` only updates the player state. Repeated notifications for the same key count once. |
| Matching | Case-fold, strip diacritics, keep dots, trim and collapse spaces. Split the artist on `, `, ` & `, ` x `, ` feat. ` and ` ft. `. Also read `(feat. X)` from the title. Match the whole string or any part. |
| Verdict | An `allow` decision excludes that part. A `skip` decision or a listed name triggers the action. |
| Action on match | `skip` (default), `pause` or `nothing`, after a delay of 0 to 60 seconds (default 0). A track change or **Not AI** cancels a pending action. The app acts only while the track key still matches. |
| Dislike | Best-effort, before every skip. The app sets `disliked`, reads it back and records the result. It never claims a dislike that did not stick. All of it sits behind `MusicControlling.dislikeCurrentTrack()`, so a better method later changes only the adapter. |
| Undo (**Not AI**) | Store `allow` for each matched part. Go back with `previous track`. Wait up to 1 second for the skipped song. If it is not playing, send `previous track` once more. Stop after 2 calls. Clear the dislike only if it stuck. |
| No artist | A song with a name but no artist gets 1 notification: "Couldn't detect the artist for <name>". |
| Notification cap | After N notifications (default 3) for the same key on one day, the app acts silently. 0 means no cap. Counts reset at local midnight and when a decision changes. |
| Lists | Subscriptions with a URL and a format (`csv` with a column, or `lines`). An optional local transform command reads the download on stdin. Refresh at launch, every 24 hours and on demand, with ETag. Default list: CennoxX `SpotifyAiArtists.csv`. |
| History | 1 row per song played. The newest 1,000 rows stay in `db.sqlite`. Older rows move to `history-archive.sqlite` in the same folder. |
| Storage | SQLite through GRDB, in `~/Library/Application Support/AntiAITunes/`. Settings in `UserDefaults`. |
| Library songs | Treated like any other song. |
| Releases | Signed with one self-signed certificate. Not notarised. |

## Spike results (macOS 27.0.1)

The spike ran on 18 November 2026 with streamed songs only.

- **Track data.** `playerInfo` has `Name`, `Artist`, `Album`, `Genre`, `Composer`, `Total Time` and `Player State`. It has no persistent ID and no store URL. `Total Time` can change for the same song.
- **Skip and back.** `next track` works. `previous track` first restarts the song if it has played for a few seconds. A second call then goes back.
- **Dislike.** `set disliked of current track to true` gives no error. Reading it back returns `false`, and the song's menu still offers "Suggest Less". Music ignores it.
- **Suggest Less.** It is not in the menu bar. It is only in the Now Playing bar and on each song row. The accessibility tree shows the row buttons only while the row is on screen. A full-screen Music window is not visible to the accessibility API.
