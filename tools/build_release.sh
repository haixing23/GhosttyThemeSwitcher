#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Ghostty Theme Switcher"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ARCH="arm64"
DEFAULT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/tools/Info.plist")"
RAW_VERSION="${RELEASE_VERSION:-v${DEFAULT_VERSION}}"
VERSION="${RAW_VERSION//\//-}"
ARTIFACT_BASE="GhosttyThemeSwitcher-${VERSION}-macos-${ARCH}"
ZIP_PATH="$DIST_DIR/${ARTIFACT_BASE}.zip"
DMG_PATH="$DIST_DIR/${ARTIFACT_BASE}.dmg"
DMG_STAGE_DIR="$DIST_DIR/.dmg-staging"
DMG_VOLUME_NAME="Ghostty Theme Switcher ${VERSION}"

function fail() {
    echo "Error: $1" >&2
    exit 1
}

function cleanup() {
    rm -rf "$DMG_STAGE_DIR"
}

trap cleanup EXIT

cd "$ROOT_DIR"
env CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache" SWIFTPM_ENABLE_CLI_CACHE=0 swift test
zsh "$ROOT_DIR/tools/build_app.sh"

rm -f "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$DMG_STAGE_DIR"

cp -R "$APP_DIR" "$DMG_STAGE_DIR/"
ln -s /Applications "$DMG_STAGE_DIR/Applications"

if [ ! -d "$DMG_STAGE_DIR/$APP_NAME.app" ]; then
    fail "App bundle was not staged for packaging"
fi

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$DMG_STAGE_DIR" \
    -format UDZO \
    -fs HFS+ \
    -ov \
    "$DMG_PATH"

if [ ! -f "$ZIP_PATH" ]; then
    fail "ZIP artifact was not created"
fi

if [ ! -f "$DMG_PATH" ]; then
    fail "DMG artifact was not created"
fi

echo "Built release artifacts:"
echo "$ZIP_PATH"
echo "$DMG_PATH"
