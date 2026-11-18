#!/bin/sh
# Builds AntiAITunes.app from the SwiftPM executable, signs it and prints its path.
#
# Usage: scripts/bundle.sh [version] [build-number]
# Environment:
#   SIGN_IDENTITY  certificate name; "-" (the default) signs ad hoc
#   KEYCHAIN       keychain that holds the certificate (optional)
#   ARCHS          space-separated architectures, e.g. "arm64 x86_64" (default: this Mac's)
set -eu
cd "$(dirname "$0")/.."

version=${1:-0.0.0}
build=${2:-1}
identity=${SIGN_IDENTITY:--}

arch_flags=""
for arch in ${ARCHS:-}; do
    arch_flags="$arch_flags --arch $arch"
done

swift build -c release --product AntiAITunes $arch_flags >&2
bin_dir=$(swift build -c release --product AntiAITunes $arch_flags --show-bin-path)

app=.build/AntiAITunes.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/AntiAITunes" "$app/Contents/MacOS/AntiAITunes"
sed -e "s/__VERSION__/$version/" -e "s/__BUILD__/$build/" Support/Info.plist > "$app/Contents/Info.plist"

set -- --force --options runtime --timestamp=none --entitlements Support/AntiAITunes.entitlements --sign "$identity"
if [ -n "${KEYCHAIN:-}" ]; then
    set -- "$@" --keychain "$KEYCHAIN"
fi
codesign "$@" "$app" >&2

echo "$app"
