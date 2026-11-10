#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 'Developer ID Application: Name (TEAMID)'" >&2
    exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGNING_IDENTITY="$1"
"$ROOT_DIR/script/build_and_run.sh" --build-universal

APP_BUNDLE="$ROOT_DIR/work/distribution/Flip H.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
BUNDLE_ID="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$INFO_PLIST")"
DMG="$ROOT_DIR/outputs/Flip-H-$VERSION.dmg"

WORK_DIR="$(mktemp -d "$ROOT_DIR/work/dmg.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
STAGED_APP="$WORK_DIR/Flip H.app"
STAGED_DMG="$WORK_DIR/Flip-H-$VERSION.dmg"
/usr/bin/ditto "$APP_BUNDLE" "$STAGED_APP"

ARCHITECTURES="$(/usr/bin/xcrun lipo -archs "$STAGED_APP/Contents/MacOS/FlipH")"
case "$ARCHITECTURES" in
    'arm64 x86_64'|'x86_64 arm64') ;;
    *) echo "Expected arm64 and x86_64. Found: $ARCHITECTURES" >&2; exit 1 ;;
esac
/usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$STAGED_APP"
/usr/bin/codesign --verify --deep --strict "$STAGED_APP"

BACKGROUND="$ROOT_DIR/Assets/InstallerBackground.svg"
magick -density 96 "$BACKGROUND" -units PixelsPerInch -density 72 -depth 8 -compress LZW "$WORK_DIR/background.tiff"
magick -density 192 "$BACKGROUND" -units PixelsPerInch -density 144 -depth 8 -compress LZW "$WORK_DIR/background@2x.tiff"
/usr/bin/tiffutil -cathidpicheck "$WORK_DIR/background.tiff" "$WORK_DIR/background@2x.tiff" -out "$WORK_DIR/InstallerBackground.tiff"

# dmgbuild asks for a per-filesystem sync. macOS sync flushes all mounted disks.
# Flush Finder's metadata here, then let dmgbuild detach and flush the volume.
mkdir "$WORK_DIR/bin"
cat > "$WORK_DIR/bin/sync" <<'PYTHON'
#!/usr/bin/python3
import os
from pathlib import Path
import sys

if len(sys.argv) != 3 or sys.argv[1] != "--file-system":
    sys.exit("Expected sync --file-system <installer volume>")

volume = Path(sys.argv[2])
for name in (".DS_Store", ".background.tiff"):
    with (volume / name).open("r+b") as file:
        os.fsync(file.fileno())
PYTHON
chmod +x "$WORK_DIR/bin/sync"
PATH="$WORK_DIR/bin:$PATH" UV_CACHE_DIR="$ROOT_DIR/work/uv-cache" uvx --from 'dmgbuild==1.6.7' dmgbuild \
    -s "$ROOT_DIR/script/dmg_layout.py" -D "app=$STAGED_APP" -D "background=$WORK_DIR/InstallerBackground.tiff" \
    "Flip H $VERSION" "$STAGED_DMG"
/usr/bin/codesign --timestamp --identifier "$BUNDLE_ID.dmg" --sign "$SIGNING_IDENTITY" "$STAGED_DMG"
/usr/bin/codesign --verify --strict "$STAGED_DMG"
# Export only the Developer ID-signed app alongside the signed disk image.
/usr/bin/ditto "$STAGED_APP" "$ROOT_DIR/outputs/Flip H.app"
mv "$STAGED_DMG" "$DMG"
printf '%s\n' "$DMG"
