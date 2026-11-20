# Anti-AI Tunes

Anti-AI Tunes is a small menu-bar app for the Mac. It watches what plays in the Music app. If the artist is on a list of AI-generated artists, it skips the song. It also asks Apple Music to suggest less like it, where macOS allows this.

> **Status: early.** Version 0.2.0 skips songs by artists on the default AI list. Undo (**Not AI**) arrives in 0.3.0. Until then, use the Music app's back button. This README describes the planned app. [ROADMAP.md](ROADMAP.md) lists what is done and what comes next.

## Why

Apple Music has no way to block an artist. Apple labels AI music only when the label or distributor chooses to declare it.[^1] Community lists of AI artists exist, mostly for Spotify.[^2] This app uses those lists with the Music app on your Mac.

## Requirements

- A Mac with macOS 14 (Sonoma) or later.
- The Music app that comes with macOS.

## Install

1. Download `AntiAITunes-<version>.zip` from the [latest release](https://github.com/joaocarmo/anti-ai-tunes/releases/latest). You can check the download with `shasum -a 256 -c AntiAITunes-<version>.zip.sha256`.
2. Unzip it and move `AntiAITunes.app` to your Applications folder.
3. Open the app for the first time. Apple has not checked (notarised) the app, so macOS blocks it at first.
   - **macOS 15 and later:** open the app once and close the warning. Go to System Settings › Privacy & Security and click **Open Anyway**.[^3] Apple says the button is there for about an hour after you try to open the app.[^4] If you don't see it, try to open the app again.
   - **macOS 14:** Control-click the app and choose **Open**. macOS 15 removed this option.[^5]
   - **Any version:** in Terminal, run `xattr -dr com.apple.quarantine /Applications/AntiAITunes.app`.
4. Allow the app to control Music, and allow notifications.
5. Set the app's notification style to **Alerts**. The menu shows a warning if it is not.

To update, replace the app. Your permissions stay, because every release is signed with the same certificate.

## How it works

- The Music app announces every new song. Anti-AI Tunes reads the artist from that announcement.
- It checks the artist against the lists you subscribe to. Lists update once a day.
- On a match, it skips the song. It also tries to mark the song as "Suggest Less". You can change the action in Settings.
- A notification tells you what happened. Click **Not AI** to undo it and allow the artist from then on.

## Privacy

Everything stays on your Mac. The app goes online only to download the lists you add. It keeps a history of the songs it sees in a local database.

To read the last 20 songs:

```sh
sqlite3 ~/Library/Application\ Support/AntiAITunes/db.sqlite \
  'select started_at, artist, name, outcome from play order by id desc limit 20'
```

## Known limits

- The app matches artist names. A real artist with the same name as an AI artist gets skipped too. Click **Not AI** once to fix this.
- On macOS 27, the Music app ignores "Suggest Less" from other apps for songs outside your library.[^6] The app still skips these songs. Its history shows whether the mark stuck.
- Apple Music lets you mark songs and albums, not artists.[^7] The app marks one song at a time.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). To report a security problem, follow [SECURITY.md](SECURITY.md).

## Licence

MIT. See [LICENSE](LICENSE).

[^1]: MacRumors, "Apple Music Rolling Out Disclosure Tags for AI-Made Songs", 5 March 2026. <https://www.macrumors.com/2026/03/05/apple-music-ai-transparency-tags/>
[^2]: CennoxX, "spotify-ai-blocker" (community list of AI artists). <https://github.com/CennoxX/spotify-ai-blocker>
[^3]: Apple Support, "Safely open apps on your Mac". <https://support.apple.com/en-us/102445>
[^4]: Apple, Mac User Guide, "Open a Mac app from an unknown developer". <https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac>
[^5]: Apple Developer News, "Updates to runtime protection in macOS Sequoia", 6 August 2024. <https://developer.apple.com/news/?id=saqachfa>
[^6]: plmcgrn, "Setting favorite/suggest less keyboard shortcuts in Apple Music for Mac" (notes on macOS Tahoe). <https://gist.github.com/plmcgrn/5d908e576821b3e0a9e5d0c707316087> The project's own test on macOS 27.0.1 is in [ROADMAP.md](ROADMAP.md#spike-results-macos-2701).
[^7]: Apple, Music User Guide for Mac, "Rate and personalize music on Mac". <https://support.apple.com/guide/music/rate-and-personalize-music-musf7da17c25/mac>
