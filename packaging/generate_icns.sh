#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

swift "$ROOT_DIR/scripts/generate_app_icon.swift"
iconutil -c icns "$ROOT_DIR/packaging/AppIcon.iconset" -o "$ROOT_DIR/packaging/AppIcon.icns"

echo "Generated icns at: $ROOT_DIR/packaging/AppIcon.icns"
