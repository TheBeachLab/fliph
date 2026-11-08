#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
APP_BUNDLE="$ROOT_DIR/outputs/Flip H.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/FlipH"
if pgrep -x FlipH >/dev/null; then pkill -TERM -x FlipH; fi
mkdir -p "$ROOT_DIR/work/cache" "$APP_BUNDLE/Contents/MacOS"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/work/cache"
swift build --disable-sandbox --configuration release --product FlipH
cp "$ROOT_DIR/.build/release/FlipH" "$APP_BINARY"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FlipH</string>
<key>CFBundleIdentifier</key><string>local.fran.fliph</string>
<key>CFBundleName</key><string>Flip H</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Flip H utiliza la imagen del monitor elegido para mostrarla invertida horizontalmente.</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.fran.fliph "$APP_BUNDLE"
case "$MODE" in
    --build) ;;
    run) open -n "$APP_BUNDLE" ;;
    --verify) open -n "$APP_BUNDLE"; sleep 2; pgrep -x FlipH ;;
    --debug) lldb -- "$APP_BINARY" ;;
    --logs) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "FlipH"' ;;
    --telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.fran.fliph"' ;;
    *) echo "Uso: $0 [run|--build|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
