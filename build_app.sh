#!/usr/bin/env bash
#
# Builds CPUTemp and packages it into a double-clickable CPUTemp.app bundle.
#
set -euo pipefail

APP_NAME="CPUTemp"
DISPLAY_NAME="CPU Temp"
BUNDLE_ID="com.example.cputemp"
VERSION="1.0.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

cd "$ROOT"

echo "==> Building (release)…"
swift build -c release

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>      <string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>       <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>       <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>          <string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <!-- Menu bar agent: no Dock icon, no main window. -->
    <key>LSUIElement</key>              <true/>
    <key>NSHumanReadableCopyright</key> <string>MIT License</string>
</dict>
</plist>
PLIST

# Ad-hoc code signature so Gatekeeper lets a locally-built app run.
echo "==> Ad-hoc signing…"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || \
    echo "   (codesign skipped — app still runs locally)"

echo "==> Done: $APP_DIR"
echo "   Launch with:  open \"$APP_DIR\""
