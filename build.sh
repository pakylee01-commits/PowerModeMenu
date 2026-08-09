#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
APP_DIR="$PROJECT_DIR/build/PowerModeMenu.app"
CONTENTS_DIR="$APP_DIR/Contents"

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS"

xcrun clang \
    -fobjc-arc \
    -O2 \
    -mmacosx-version-min=13.0 \
    -framework Cocoa \
    "$PROJECT_DIR/Source/PowerModeMenu.m" \
    -o "$CONTENTS_DIR/MacOS/PowerModeMenu"

cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
