#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_ICON="$ROOT_DIR/tools/AppIcon.png"
ICONSET_DIR="$ROOT_DIR/tools/AppIcon.iconset"
OUTPUT_ICON="$ROOT_DIR/tools/AppIcon.icns"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

python3 - <<'PY'
from pathlib import Path
import sys

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow is required to rebuild AppIcon.icns.", file=sys.stderr)
    sys.exit(1)

root = Path.cwd()
source_icon = root / "tools" / "AppIcon.png"
iconset_dir = root / "tools" / "AppIcon.iconset"
output_icon = root / "tools" / "AppIcon.icns"

sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

source = Image.open(source_icon).convert("RGBA")
for filename, size in sizes.items():
    resized = source.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(iconset_dir / filename)

source.save(output_icon, format="ICNS")
PY

echo "Built icon at:"
echo "$OUTPUT_ICON"
