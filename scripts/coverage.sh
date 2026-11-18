#!/bin/sh
# Fails unless every line in Sources/AntiAITunesCore is covered.
# Run `swift test --enable-code-coverage` first.
set -eu
cd "$(dirname "$0")/.."

json=$(swift test --show-codecov-path)
python3 -I - "$json" <<'EOF'
import json
import sys

files = [
    f for f in json.load(open(sys.argv[1]))["data"][0]["files"]
    if "/Sources/AntiAITunesCore/" in f["filename"]
]
covered = sum(f["summary"]["lines"]["covered"] for f in files)
total = sum(f["summary"]["lines"]["count"] for f in files)
for f in files:
    lines = f["summary"]["lines"]
    if lines["covered"] < lines["count"]:
        print(f"{f['filename']}: {lines['covered']}/{lines['count']} lines covered")
print(f"AntiAITunesCore line coverage: {covered}/{total}")
if not files or covered < total:
    sys.exit(1)
EOF
