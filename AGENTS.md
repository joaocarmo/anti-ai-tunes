# AGENTS.md

Anti-AI Tunes is a macOS menu-bar app. It skips AI-generated artists in the Music app (Apple Music). Stack: Swift, SwiftUI, SQLite through GRDB.

Status: v0.1.0 in progress. The core package and a menu-bar app that shows the current song exist. ARCHITECTURE.md marks planned types.

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
- `scripts/`: `coverage.sh` (coverage gate), `bundle.sh` (build and sign the `.app`), `run.sh` (bundle and open locally).
- `.github/`: CI, release workflow, issue and PR templates.

## Commands

```sh
swift format lint --strict -r Sources Tests App Package.swift   # format check
swift test --enable-code-coverage                               # tests
scripts/coverage.sh                                             # 100% line coverage gate
scripts/bundle.sh                                               # build and sign the app (macOS only)
```

The first 3 run on macOS and on Linux, where `Package.swift` leaves out the app target. In a Linux sandbox, check whether `swift` is on `PATH` and set `SWIFT_BACKTRACE=enable=no`. The app itself builds only on macOS, so CI (`.github/workflows/ci.yml`) is the final check. CI pins the newest toolchain: the `xcode-27` runner with Xcode 27.2. Change both workflows together. Run the same steps before you finish.

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
- [ ] All time goes through `Clock`. Tests never sleep.
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
