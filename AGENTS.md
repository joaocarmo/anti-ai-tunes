# AGENTS.md

Anti-AI Tunes is a macOS menu-bar app. It skips AI-generated artists in the Music app (Apple Music). Stack: Swift, SwiftUI, SQLite through GRDB.

Status: v0.4.0 in progress. The menu-bar app shows the current song, skips songs by artists on the default AI list, and undoes a skip with **Not AI**. It records each song in a history. ARCHITECTURE.md marks planned types.

This file follows the AGENTS.md convention.[^1] Claude Code reads it directly, so the repo has no `CLAUDE.md`.[^2]

## Start here

Work happens in small increments: 1 issue, 1 PR and 1 release each. Before you change anything:

1. Read [CHANGELOG.md](CHANGELOG.md): what is already done.
2. Read [ROADMAP.md](ROADMAP.md): what comes next, and the product decisions.
3. Run `gh issue list --label increment --state open` and read that issue. Build only what it describes.

When the increment closes, plan the next one and open its issue. [CONTRIBUTING.md](CONTRIBUTING.md) › Workflow has the full rules.

## Read first

1. [ARCHITECTURE.md](ARCHITECTURE.md): design, invariants and boundaries. Its MUST rules are binding.
2. [CONTRIBUTING.md](CONTRIBUTING.md): workflow and definition of done.

[README.md](README.md) is for end users.

## Layout

- `Package.swift`, `Sources/AntiAITunesCore/`: all logic. A local Swift package.
- `Tests/AntiAITunesCoreTests/`: unit tests and hand-written fakes.
- `App/`: the app's SwiftPM executable target. Thin adapters and SwiftUI views only. No Xcode project.
- `Support/`: `Info.plist` and entitlements for the app bundle.
- `scripts/`: `coverage.sh` (coverage gate), `bundle.sh` (build and sign the `.app`), `run.sh` (bundle and open locally), `release-notes.sh` (CHANGELOG section for a release).
- `.github/`: CI, release workflow, issue and PR templates.

## Commands

```sh
swift format lint --strict -r Sources Tests App Package.swift   # format check
swift test --enable-code-coverage -Xswiftc -warnings-as-errors  # tests, warnings fail the build
scripts/coverage.sh                                             # 100% line coverage gate
swift test --sanitize=thread                                    # data races
swift test --sanitize=address                                   # memory errors
scripts/bundle.sh                                               # build and sign the app (macOS only)
```

All but `bundle.sh` run on macOS and on Linux, where `Package.swift` leaves out the app target. The app itself builds only on macOS, so CI (`.github/workflows/ci.yml`) is the final check. CI pins the newest toolchain: the `xcode-27` runner with Xcode 27.2. Change both workflows together. Run the same steps before you finish.

## Linux sandbox

Agents often run in a Linux container without Xcode.

- Install a Swift 6.4 toolchain for Linux from swift.org and verify its signature. If it fails with `libncurses.so.6` missing, extract the `libncurses6` package's libraries next to the toolchain (`usr/lib/swift/linux`). Set `SWIFT_BACKTRACE=enable=no`.
- GRDB needs the SQLite headers, and the container may have only `libsqlite3.so.0`. Without root, run `apt-get download libsqlite3-dev` and extract it with `dpkg -x`. Copy `sqlite3.h` and `sqlite3ext.h` into the toolchain's `usr/lib/clang/<version>/include`, and link `libsqlite3.so` to the system `libsqlite3.so.0` in `usr/lib/swift/linux`. The toolchain searches both folders by default, so no build flags are needed.
- Put the toolchain on `PATH` by symlinking `swift`, `swift-format` and `sourcekit-lsp` into a directory already on it, such as `~/.local/bin`.
- For code intelligence in Claude Code, install the `swift-lsp` plugin from `claude-plugins-official`. It needs `sourcekit-lsp` on `PATH`. Files in `App/` are not indexed on Linux.
- On Linux, the address sanitizer also checks for leaks and reports some in the XCTest runner at exit. Run it with `ASAN_OPTIONS=detect_leaks=0`. macOS does not run this leak check.
- The core package builds and tests there. The app target, `scripts/bundle.sh` and anything that talks to Music need macOS, so CI is the check for them.
- The clone's `origin` may point to a local mirror. Push to a remote that points to GitHub.
- `gh actions-lock` needs `gh extension install github/gh-actions-lock --pin v0.4.1`.

## Hard rules

- [ ] Package line coverage stays at 100%. The package has no coverage exclusions.
- [ ] `App/` has no logic. Move any real `if`, `guard`, `switch` or `??` into the package, with a test.
- [ ] The package never imports AppKit, SwiftUI or UserNotifications.
- [ ] Never launch Music.app. Check that it is running before any Apple Event.
- [ ] Detect song changes only from the `com.apple.Music.playerInfo` notification. Never poll Music. One read of the current song at launch is allowed.
- [ ] Act on a track only while its key matches the latest `playerInfo`.
- [ ] Attempt the dislike before `next track`. Never claim a dislike unless the read-back says `true`.
- [ ] Downloaded list data reaches a transform command only on stdin. It never becomes part of a shell command.
- [ ] All database access goes through `Store`.
- [ ] All time goes through `TimeSource`. Tests never sleep.
- [ ] No paid services, accounts or APIs.
- [ ] No new dependency without a reason in the PR description.

## Writing

- Prose (docs, PR descriptions, issues): British English. Short sentences, one idea each. No em dashes.
- Code (identifiers, code comments, commit messages): American English.
- Docs cite sources as GitHub footnotes. Definitions go at the bottom of the file.

## Commits and pull requests

- Use Conventional Commits, for example `feat(matching): split artists on "feat."`.
- Keep one logical change per PR, and fill in the PR template.
- Add an `Unreleased` entry to `CHANGELOG.md` for user-visible changes.
- Say in the PR that an AI agent helped, and which one.

## Do not

- Edit `.github/workflows/actions.lock` by hand. Run `gh actions-lock`.
- Commit `.p12` files, certificates or secrets.
- Add a `CLAUDE.md` or `CLAUDE.local.md`. Either one stops Claude Code from reading this file.[^2]

[^1]: AGENTS.md, the open format for guiding coding agents. <https://agents.md/>
[^2]: Claude Code docs, "How Claude remembers your project", section "AGENTS.md". <https://code.claude.com/docs/en/memory>
