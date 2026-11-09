#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
APP_BUNDLE="$ROOT_DIR/outputs/Flip H.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/FlipH"
if [[ "$MODE" != --build && "$MODE" != --build-universal ]]; then
    if pgrep -x FlipH >/dev/null; then pkill -TERM -x FlipH; fi
fi
ICON_INFO="$ROOT_DIR/work/FlipHIconInfo.plist"
mkdir -p "$ROOT_DIR/work/cache" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/work/cache"
BUILD_ARGS=(--disable-sandbox --configuration release --product FlipH)
if [[ "$MODE" == --build-universal ]]; then
    BUILD_ARGS+=(--scratch-path "$ROOT_DIR/work/universal" --arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}"
cp "$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/FlipH" "$APP_BINARY"
/usr/bin/xcrun actool Assets/FlipH.icon --compile "$APP_BUNDLE/Contents/Resources" \
    --platform macosx --minimum-deployment-target 14.0 --target-device mac --app-icon FlipH \
    --output-partial-info-plist "$ICON_INFO" --output-format human-readable-text
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>FlipH</string>
<key>CFBundleIdentifier</key><string>local.fran.fliph</string>
<key>CFBundleName</key><string>Flip H</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Flip H uses the selected display’s image to mirror it horizontally.</string>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Merge \"$ICON_INFO\"" "$APP_BUNDLE/Contents/Info.plist"
/usr/bin/ditto "$ROOT_DIR/Resources" "$APP_BUNDLE/Contents/Resources"
codesign --force --sign - --identifier local.fran.fliph "$APP_BUNDLE"
case "$MODE" in
    --build|--build-universal) ;;
    run) open -n "$APP_BUNDLE" ;;
    --verify) open -n "$APP_BUNDLE"; sleep 2; pgrep -x FlipH ;;
    --debug) lldb -- "$APP_BINARY" ;;
    --logs) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "FlipH"' ;;
    --telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.fran.fliph"' ;;
    *) echo "Usage: $0 [run|--build|--build-universal|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
