#!/usr/bin/env bash
# Builds SoundSwitch and wraps it in a menu-bar-only .app bundle (LSUIElement).
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/SoundSwitch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/SoundSwitch" "$APP/Contents/MacOS/SoundSwitch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP"
