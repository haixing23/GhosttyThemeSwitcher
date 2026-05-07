#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Ghostty Theme Switcher"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ICON_FILE="$ROOT_DIR/tools/AppIcon.icns"

cd "$ROOT_DIR"
swift build -c release
zsh "$ROOT_DIR/tools/build_icon.sh"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/GhosttyThemeSwitcher" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/tools/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Copy the SPM-generated resource bundle (contains themes.json and any other
# bundled resources) into the .app so Bundle.module can find it at runtime.
RESOURCE_BUNDLE_NAME="GhosttyThemeSwitcher_GhosttyThemeSwitcher.bundle"
RESOURCE_BUNDLE_SRC="$BUILD_DIR/$RESOURCE_BUNDLE_NAME"
if [ -d "$RESOURCE_BUNDLE_SRC" ]; then
    cp -R "$RESOURCE_BUNDLE_SRC" "$APP_DIR/Contents/Resources/$RESOURCE_BUNDLE_NAME"
fi

# Ad-hoc sign the bundle so it has a stable identity. This does NOT remove
# Gatekeeper warnings on other Macs, but it prevents spurious "is damaged"
# errors after the bundle is reassembled.
codesign --force --deep --sign - "$APP_DIR"

echo "Built app bundle at:"
echo "$APP_DIR"
