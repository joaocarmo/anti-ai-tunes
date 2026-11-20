# Contributing

Thank you for helping. This guide is for people and for AI coding agents. Agents should read [AGENTS.md](AGENTS.md) first.

Status: v0.1.0 in progress.

## Before you start

- Read [ARCHITECTURE.md](ARCHITECTURE.md). Its invariants are binding.
- For a bug or a feature, open an issue first, using one of the forms.
- A wrongly flagged or missing artist usually belongs in the upstream list, not here. The "Wrong match" form explains where to go.
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Set up

You need a Mac with macOS 14 or later and Xcode 16 or later. Xcode 16 includes `swift format`, so you need no extra tools.[^1] CI uses Xcode 27.2. Use the same version, because `swift format` rules can differ between versions. There is no Xcode project. Open `Package.swift` in Xcode to edit and debug.

```sh
git clone https://github.com/joaocarmo/anti-ai-tunes.git
cd anti-ai-tunes
swift test
scripts/run.sh    # build, sign and open the app
```

`scripts/run.sh` signs with the "Anti-AI Tunes" certificate when your keychain has it (see "One-time signing setup"). Then macOS keeps the app's permissions across rebuilds. Without it, the script signs ad hoc, and macOS asks again after each rebuild.

The core package also builds and tests on Linux. The app needs macOS.

## Workflow

The app grows in small increments. [ROADMAP.md](ROADMAP.md) lists them in order.

- Each increment is 1 issue with the `increment` label, 1 pull request and 1 release.
- Each increment keeps `main` green. It compiles, keeps package line coverage at 100% and produces a signed build that installs and runs. The build does what the CHANGELOG says, even if that is little.
- Increments that change only docs ship no build.
- Exactly 1 increment issue is open at a time.

### Start here

Read these 3 things before you change anything:

1. [CHANGELOG.md](CHANGELOG.md): what users already have.
2. [ROADMAP.md](ROADMAP.md): what comes next, and the product decisions.
3. The open increment issue: `gh issue list --label increment --state open`, or the Issues tab filtered by `increment`. Build what it describes.

### Work on an increment

1. Create a branch from `main`, for example `inc/v0.2.0-skip`.
2. Make the changes the issue describes, and nothing more.
3. Run the checks in "Definition of done".
4. Open a pull request, fill in the template and add `Closes #<issue number>`.

### Close an increment

1. Merge the pull request.
2. The maintainer publishes the release (see "Releases").
3. Mark the row as Done in ROADMAP.md.
4. Plan the next increment and open its issue with the **Increment** form. Plan it now, with the newest code in hand. This keeps 1 open increment issue.

Bugs and feature requests from the other forms go into ROADMAP.md when they are accepted. A bug that blocks users can become the next increment.

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

- [ ] `swift format lint --strict -r Sources Tests App Package.swift`
- [ ] `swift test --enable-code-coverage -Xswiftc -warnings-as-errors`, with package line coverage at 100%
- [ ] `scripts/coverage.sh` passes
- [ ] `swift test --sanitize=thread` and `swift test --sanitize=address` pass
- [ ] The app builds with `scripts/bundle.sh`
- [ ] `gh actions-lock --no-fix` passes, if a workflow changed
- [ ] Every new branch of logic has a test
- [ ] `CHANGELOG.md` has an `Unreleased` entry for user-visible changes[^3]
- [ ] `ARCHITECTURE.md` is updated if an invariant or a boundary changed
- [ ] The README is updated if users see a change

CI runs the same checks on every pull request. The `main` ruleset requires its 2 jobs, `test` and `lockfile`, to pass. `.github/CODEOWNERS` names the maintainer as owner of every file.

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

## Repository settings (maintainers)

These settings live on GitHub, not in the code. Update this list when one changes.

- **`main` ruleset:** no deletion and no force push. Commits must be signed. Pull requests need 1 approval from a code owner and the checks `test` and `lockfile`. Repository admins may bypass it for pull requests only.
- **Why the bypass:** agents open pull requests under the maintainer's account. GitHub does not let authors approve their own pull requests, so the maintainer merges with the bypass.
- **Releases:** immutable. See "Releases" below.
- **Actions:** the Require lockfile policy is on. Workflows run only with `actions.lock` entries.
- **Security:** private vulnerability reporting is on. `SECURITY.md` and the Code of Conduct depend on it.
- **Moderation:** reported content should be accepted from contributors (Settings › Moderation options).
- **Labels:** `increment`, `wrong-match`, plus GitHub's defaults.
- **Secrets:** `SIGNING_CERT_P12_BASE64` and `SIGNING_CERT_PASSWORD` (see "One-time signing setup").

## Releases (maintainers)

The project uses Semantic Versioning 2.0.0.[^9]

1. Move the `Unreleased` entries in `CHANGELOG.md` under a new version heading with today's date (`YYYY-MM-DD`), and merge that change.
2. Tag the merge commit on `main` and push the tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. The release workflow tests, signs and zips the app. It creates a **draft** release with the zip, its SHA-256 and notes from the CHANGELOG section.
4. Review the draft and publish it.

Releases are immutable once published.[^10] Their assets and tag can never change, and a tag name can never be reused. Only publish a draft that has its assets. A broken release needs a new patch version.

### One-time signing setup

Releases are signed with one self-signed certificate, so macOS keeps user permissions across updates.

1. On a Mac, open Keychain Access › Certificate Assistant › Create a Certificate.
2. Name it exactly **Anti-AI Tunes**. The release workflow and `scripts/run.sh` look for this name.
3. Set the type to **Code Signing**. Tick **Let me override defaults** and set the validity to 3650 days (10 years).
4. Export the certificate and its key as a `.p12` file with a password.
5. Add 2 repository secrets: `SIGNING_CERT_P12_BASE64` (the output of `base64 -i cert.p12`) and `SIGNING_CERT_PASSWORD`.
6. Delete the exported `.p12` file. Never commit it. The certificate stays in your keychain for local builds.

[^1]: swiftlang, "swift-format", section "Included in the Swift Toolchain". <https://github.com/swiftlang/swift-format>
[^2]: Conventional Commits 1.0.0. <https://www.conventionalcommits.org/en/v1.0.0/>
[^3]: Keep a Changelog 1.1.0. <https://keepachangelog.com/en/1.1.0/>
[^4]: Swift.org, "API Design Guidelines". <https://www.swift.org/documentation/api-design-guidelines/>
[^5]: Digital.gov, "Clear and short". <https://digital.gov/guides/plain-language/writing/clear-short>
[^6]: Publications Office of the European Union, "Plain language guidelines". <https://op.europa.eu/documents/d/accessibility/accessible-publishing-plain-language-guidelines>
[^7]: GitHub Docs, "Basic writing and formatting syntax", section "Footnotes". <https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax>
[^8]: Claude Code docs, "How Claude remembers your project", section "AGENTS.md". <https://code.claude.com/docs/en/memory>
[^9]: Semantic Versioning 2.0.0. <https://semver.org/spec/v2.0.0.html>
[^10]: GitHub Docs, "Immutable releases". <https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases>
