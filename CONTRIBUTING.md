# Contributing

Thank you for helping. This guide is for people and for AI coding agents. Agents should read [AGENTS.md](AGENTS.md) first.

Status: pre-alpha. Some steps below describe tooling that does not exist yet.

## Before you start

- Read [ARCHITECTURE.md](ARCHITECTURE.md). Its invariants are binding.
- For a bug or a feature, open an issue first, using one of the forms.
- A wrongly flagged or missing artist usually belongs in the upstream list, not here. The "Wrong match" form explains where to go.
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Set up

You need a Mac with macOS 14 or later and Xcode 16 or later. Xcode 16 includes `swift format`, so you need no extra tools.[^1]

```sh
git clone https://github.com/joaocarmo/anti-ai-tunes.git
cd anti-ai-tunes
swift test
```

Local builds signed with your own team look like a different app to macOS. Each one asks for permissions again. That is expected.

## Workflow

1. Create a branch from `main`.
2. Make one logical change.
3. Run the checks in "Definition of done".
4. Open a pull request and fill in the template.

### Commit messages

Use Conventional Commits 1.0.0.[^2] Write the message in American English.

```text
feat(matching): split artists on "feat."
fix(store): keep old rows when a refresh fails
docs: explain the archive setting
```

Common types are `feat`, `fix`, `docs`, `test`, `refactor`, `ci` and `chore`. Mark breaking changes with `!` or a `BREAKING CHANGE:` footer.

## Definition of done

A change is done when all of these pass:

- [ ] `swift format lint --strict -r Sources Tests App`
- [ ] `swift test --enable-code-coverage`, with package line coverage at 100%
- [ ] The app target builds with `xcodebuild`
- [ ] Every new branch of logic has a test
- [ ] `CHANGELOG.md` has an `Unreleased` entry for user-visible changes[^3]
- [ ] `ARCHITECTURE.md` is updated if an invariant or a boundary changed
- [ ] The README is updated if users see a change

CI runs the same checks on every pull request.

## Code style

- Follow the Swift API Design Guidelines. Their first rule is clarity at the point of use.[^4]
- `swift format` decides layout. Its settings are in `.swift-format`.[^1]
- A comment explains why, never what. Leave ticket numbers and dates out of code.
- Code, identifiers and code comments use American English.

## Writing style

These rules apply to docs, PR descriptions and issues.

- Use British English.
- Write one idea per sentence.[^5] Aim for 15 to 20 words at most.[^6]
- Prefer common words. Use a technical term when it is the precise one.
- Do not use em dashes.
- Cite sources as GitHub footnotes, defined at the bottom of the file.[^7]

## For AI coding agents

- Read [AGENTS.md](AGENTS.md) before you change anything.
- Run every check in "Definition of done". Report what you ran and the result.
- Say in the PR that an agent helped, and which one.
- Claude Code reads `AGENTS.md` when the repo has no `CLAUDE.md`.[^8] A personal `CLAUDE.local.md` turns that off. If you need one, set **Project instructions** to `claude-md-and-agents-md` in `/config`.

## Releases (maintainers)

The project uses Semantic Versioning 2.0.0.[^9]

1. Move the `Unreleased` entries in `CHANGELOG.md` under a new version heading with today's date (`YYYY-MM-DD`).
2. Tag the commit `vX.Y.Z` and publish a GitHub release for it.
3. The release workflow tests, signs, zips and uploads the app.

### One-time signing setup

Releases are signed with one self-signed certificate, so macOS keeps user permissions across updates.

1. On a Mac, open Keychain Access › Certificate Assistant › Create a Certificate.
2. Set the type to **Code Signing** and the validity to 10 years.
3. Export the certificate and its key as a `.p12` file with a password.
4. Add 2 repository secrets: `SIGNING_CERT_P12_BASE64` (the output of `base64 -i cert.p12`) and `SIGNING_CERT_PASSWORD`.
5. Delete the exported `.p12` file. Never commit it.

[^1]: swiftlang, "swift-format", section "Included in the Swift Toolchain". <https://github.com/swiftlang/swift-format>
[^2]: Conventional Commits 1.0.0. <https://www.conventionalcommits.org/en/v1.0.0/>
[^3]: Keep a Changelog 1.1.0. <https://keepachangelog.com/en/1.1.0/>
[^4]: Swift.org, "API Design Guidelines". <https://www.swift.org/documentation/api-design-guidelines/>
[^5]: Digital.gov, "Clear and short". <https://digital.gov/guides/plain-language/writing/clear-short>
[^6]: Publications Office of the European Union, "Plain language guidelines". <https://op.europa.eu/documents/d/accessibility/accessible-publishing-plain-language-guidelines>
[^7]: GitHub Docs, "Basic writing and formatting syntax", section "Footnotes". <https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax>
[^8]: Claude Code docs, "How Claude remembers your project", section "AGENTS.md". <https://code.claude.com/docs/en/memory>
[^9]: Semantic Versioning 2.0.0. <https://semver.org/spec/v2.0.0.html>
