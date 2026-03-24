#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_PRODUCT="MinistryScheduler"
APP_NAME="media-scheduler-mac"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

if [[ ! -f "$ROOT_DIR/packaging/AppIcon.icns" ]]; then
    "$ROOT_DIR/packaging/generate_icns.sh"
fi

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/$BUILD_PRODUCT" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/packaging/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/$APP_NAME"

echo "Created app bundle at: $APP_DIR"
