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
archs=${ARCHS:-$(uname -m)}

app=.build/AntiAITunes.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"

# One plain build per architecture, merged with lipo: the same build mode as `swift test`.
# Swift 6.4 builds every architecture into the same folder, so each binary is copied out before the next build.
thin=.build/bundle-thin
rm -rf "$thin"
mkdir -p "$thin"
set --
for arch in $archs; do
    swift build -c release --product AntiAITunes --arch "$arch" >&2
    cp "$(swift build -c release --product AntiAITunes --arch "$arch" --show-bin-path)/AntiAITunes" "$thin/$arch"
    set -- "$@" "$thin/$arch"
done
binary="$app/Contents/MacOS/AntiAITunes"
lipo -create "$@" -output "$binary"
for arch in $archs; do
    lipo -archs "$binary" | tr ' ' '\n' | grep -qx "$arch"
done

sed -e "s/__VERSION__/$version/" -e "s/__BUILD__/$build/" Support/Info.plist > "$app/Contents/Info.plist"

# Extended attributes break the code signature.
xattr -cr "$app"

set -- --force --options runtime --timestamp=none --entitlements Support/AntiAITunes.entitlements --sign "$identity"
if [ -n "${KEYCHAIN:-}" ]; then
    set -- "$@" --keychain "$KEYCHAIN"
fi
codesign "$@" "$app" >&2

echo "$app"
