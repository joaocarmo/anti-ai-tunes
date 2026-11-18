#!/bin/sh
# Builds, bundles and opens the app for local testing.
# Signs with the "Anti-AI Tunes" certificate when the keychain has it, so macOS keeps permissions across rebuilds.
set -eu
cd "$(dirname "$0")/.."

if security find-certificate -c "Anti-AI Tunes" >/dev/null 2>&1; then
    export SIGN_IDENTITY="Anti-AI Tunes"
fi

pkill -x AntiAITunes || true
open "$(scripts/bundle.sh)"
