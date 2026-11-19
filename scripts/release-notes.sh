#!/bin/sh
# Prints the release notes for a version: its CHANGELOG.md section, then the install note.
# Usage: scripts/release-notes.sh 0.1.1
set -eu
cd "$(dirname "$0")/.."

version=$1
awk -v heading="## [$version]" '
    index($0, heading) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found && /^\[/ { exit }
    found { print }
' CHANGELOG.md
cat .github/release-install-note.md
