# Security policy

## Supported versions

Only the latest release gets security fixes. The project is pre-alpha and has no releases yet.

## Report a vulnerability

Please do not open a public issue for a security problem.

Report it privately through GitHub instead:[^1]

1. Go to <https://github.com/joaocarmo/anti-ai-tunes/security/advisories/new>.
2. Fill in the form and click **Submit report**.

Only the maintainer sees the report. One person maintains this project, so responses are best effort. You get credit in the advisory unless you ask otherwise.

## Scope

These areas matter most:

- Parsing downloaded AI-artist lists.
- Transform commands: downloaded data must never become part of a shell command.
- Apple Events sent to the Music app.
- Release signing and the published downloads.

Problems with the content of an upstream AI-artist list are not security issues. Report them to the list's maintainers.

[^1]: GitHub Docs, "Privately reporting a security vulnerability". <https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability>
