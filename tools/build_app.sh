#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Ghostty Theme Switcher"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ICON_FILE="$ROOT_DIR/tools/AppIcon.icns"
EXECUTABLE_NAME="GhosttyThemeSwitcher"

function fail() {
    echo "Error: $1" >&2
    exit 1
}

cd "$ROOT_DIR"
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
zsh "$ROOT_DIR/tools/build_icon.sh"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/tools/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [ ! -f "$APP_DIR/Contents/MacOS/$APP_NAME" ]; then
    fail "Expected app executable at $APP_DIR/Contents/MacOS/$APP_NAME"
fi

bundle_paths=("$BUILD_DIR"/*.bundle(N))
resource_bundle_found=0
for bundle_path in "${bundle_paths[@]}"; do
    cp -R "$bundle_path" "$APP_DIR/Contents/Resources/"
    resource_bundle_found=1
done

if [ "$resource_bundle_found" -eq 0 ]; then
    fail "No SwiftPM resource bundle was found in $BUILD_DIR"
fi

THEMES_BUNDLE_PATH="$(find "$APP_DIR/Contents/Resources" -maxdepth 2 -path '*.bundle/themes.json' -print -quit)"
if [ -z "$THEMES_BUNDLE_PATH" ]; then
    fail "themes.json was not copied into the app bundle"
fi

archs="$(lipo -archs "$APP_DIR/Contents/MacOS/$APP_NAME")"
if [ "$archs" != "arm64" ]; then
    fail "Expected an Apple Silicon build, got architecture(s): $archs"
fi

# Ad-hoc sign the bundle so it has a stable identity. This does NOT remove
# Gatekeeper warnings on other Macs, but it prevents spurious "is damaged"
# errors after the bundle is reassembled.
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Built app bundle at:"
echo "$APP_DIR"
