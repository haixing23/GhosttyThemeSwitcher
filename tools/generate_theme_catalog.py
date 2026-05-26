#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Sources" / "GhosttyThemeSwitcher" / "Resources"
OUTPUT_JSON = RESOURCES / "bundled-themes.json"
LEGACY_JSON = RESOURCES / "themes.json"
OUTPUT_THEMES = RESOURCES / "BundledThemes"
DEFAULT_CACHE = ROOT / ".build" / "theme-source" / "iTerm2-Color-Schemes"
SOURCE_REPO = "https://github.com/mbadolato/iTerm2-Color-Schemes.git"


def source_dir() -> Path:
    override = os.environ.get("GHOSTTY_THEMES_SOURCE")
    if override:
        candidate = Path(override).expanduser().resolve()
        if (candidate / "ghostty").is_dir():
            return candidate / "ghostty"
        if candidate.is_dir():
            return candidate

    if not (DEFAULT_CACHE / "ghostty").is_dir():
        DEFAULT_CACHE.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "git",
                "clone",
                "--depth",
                "1",
                "--filter=blob:none",
                "--sparse",
                SOURCE_REPO,
                str(DEFAULT_CACHE),
            ],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(DEFAULT_CACHE), "sparse-checkout", "set", "ghostty"],
            check=True,
        )

    return DEFAULT_CACHE / "ghostty"


def normalized_hex(value: str) -> str:
    value = value.strip()
    return value.upper() if value.startswith("#") else value


def luminance(hex_value: str) -> float:
    clean = hex_value.strip().lstrip("#")
    red = int(clean[0:2], 16) / 255
    green = int(clean[2:4], 16) / 255
    blue = int(clean[4:6], 16) / 255
    return 0.299 * red + 0.587 * green + 0.114 * blue


def slug(value: str) -> str:
    result = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-").lower()
    return result or "theme"


def parse_theme(path: Path, theme_id: str) -> dict[str, object]:
    values: dict[str, str] = {}
    palette: dict[int, str] = {}

    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = [part.strip() for part in line.split("=", 1)]
        if key == "palette":
            index_text, color = [part.strip() for part in value.split("=", 1)]
            palette[int(index_text)] = normalized_hex(color)
        else:
            values[key] = normalized_hex(value)

    background = values["background"]
    foreground = values["foreground"]
    palette_hex = [palette.get(index, foreground) for index in range(16)]
    surface = values.get("selection-background") or palette.get(0) or background
    overlay = palette.get(8) or values.get("selection-background") or surface
    subtext = palette.get(7) or foreground
    accent = palette.get(12) or palette.get(4) or foreground

    return {
        "id": theme_id,
        "title": path.name,
        "ghosttyThemeName": path.name,
        "source": "bundled",
        "appearance": "light" if luminance(background) >= 0.5 else "dark",
        "bundledFileName": path.name,
        "background": background,
        "surface": surface,
        "overlay": overlay,
        "text": foreground,
        "subtext": subtext,
        "accent": accent,
        "palette": palette_hex,
    }


def main() -> None:
    src = source_dir()
    if OUTPUT_THEMES.exists():
        shutil.rmtree(OUTPUT_THEMES)
    OUTPUT_THEMES.mkdir(parents=True, exist_ok=True)

    used_ids: dict[str, int] = {}
    themes: list[dict[str, object]] = []

    for path in sorted(p for p in src.iterdir() if p.is_file()):
        base_id = slug(path.name)
        count = used_ids.get(base_id, 0)
        used_ids[base_id] = count + 1
        theme_id = base_id if count == 0 else f"{base_id}-{count + 1}"
        themes.append(parse_theme(path, theme_id))
        shutil.copy2(path, OUTPUT_THEMES / path.name)

    RESOURCES.mkdir(parents=True, exist_ok=True)
    rendered = json.dumps(themes, indent=2, ensure_ascii=False) + "\n"
    OUTPUT_JSON.write_text(rendered, encoding="utf-8")
    LEGACY_JSON.write_text(rendered, encoding="utf-8")
    print(f"Wrote {len(themes)} bundled themes to {OUTPUT_JSON}")


if __name__ == "__main__":
    main()
