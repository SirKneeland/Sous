#!/usr/bin/env python3
"""Verify SousTheme.swift still matches design/tokens.json.

Sous keeps its palette in two places by necessity: tokens.json (the source of
truth, and what Figma imports) and SousTheme.swift (what the app compiles).
This script proves they agree. Run it after any palette change.

    python3 design/check-tokens.py

Exits 0 when they match, 1 when they have drifted, and prints every mismatch.
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "tokens.json"
THEME = ROOT / "ios" / "SousApp" / "SousApp" / "Views" / "SousTheme.swift"

# static let sousBackgroundUI = sousDynamic(light: 0xF2EFE9, dark: 0x1A1A1A)
DECL = re.compile(
    r"static let (?P<symbol>\w+)UI\s*=\s*sousDynamic\("
    r"light:\s*0x(?P<light>[0-9A-Fa-f]{6}),\s*"
    r"dark:\s*0x(?P<dark>[0-9A-Fa-f]{6})\)"
)

# Any color literal built by hand rather than from a token.
RAW_COLOR = re.compile(r"(?:Color|UIColor)\(red:")

# Any font size written inline rather than taken from a token.
RAW_FONT = re.compile(r"\.system\(size:")

# The five permitted SF Symbol sizes, as declared by SousIconSize.
ICON_CASE = re.compile(r"case \w+ = (\d+)")


def load_primitives(doc):
    flat = {}
    for hue, entries in doc["primitive"]["color"].items():
        if "$value" in entries:
            flat[f"primitive.color.{hue}"] = entries["$value"]
            continue
        for step, entry in entries.items():
            flat[f"primitive.color.{hue}.{step}"] = entry["$value"]
    return flat


def resolve(value, primitives, trail):
    """Turn '{primitive.color.cream.100}' into '#F2EFE9'."""
    if not (value.startswith("{") and value.endswith("}")):
        return value.upper()
    key = value[1:-1]
    if key not in primitives:
        trail.append(f"unknown primitive reference: {value}")
        return None
    return primitives[key].upper()


def main():
    doc = json.loads(TOKENS.read_text())
    primitives = load_primitives(doc)
    theme_src = THEME.read_text()

    declared = {
        m.group("symbol"): ("#" + m.group("light").upper(), "#" + m.group("dark").upper())
        for m in DECL.finditer(theme_src)
    }

    problems = []
    checked = 0

    for group, entries in doc["semantic"]["color"].items():
        if not isinstance(entries, dict):
            continue
        for name, entry in entries.items():
            if not isinstance(entry, dict) or "$swift" not in entry:
                continue
            symbol = entry["$swift"]
            checked += 1

            if symbol not in declared:
                problems.append(
                    f"{group}.{name}: tokens.json expects SousTheme.swift to define "
                    f"'{symbol}UI', but it does not exist"
                )
                continue

            want = (
                resolve(entry["light"], primitives, problems),
                resolve(entry["dark"], primitives, problems),
            )
            got = declared[symbol]
            if None in want:
                continue
            if want != got:
                problems.append(
                    f"{group}.{name} ({symbol}UI) has drifted:\n"
                    f"    tokens.json:      light {want[0]}  dark {want[1]}\n"
                    f"    SousTheme.swift:  light {got[0]}  dark {got[1]}"
                )

    # Every palette and type value must live in the theme. TexturePreviewView
    # builds colors from live slider values for texture tuning and is exempt.
    color_exempt = {"SousTheme.swift", "TexturePreviewView.swift"}
    app = ROOT / "ios" / "SousApp" / "SousApp"
    for swift in app.rglob("*.swift"):
        rel = swift.relative_to(ROOT)
        lines = swift.read_text().splitlines()
        for lineno, line in enumerate(lines, 1):
            if RAW_COLOR.search(line) and swift.name not in color_exempt:
                problems.append(
                    f"{rel}:{lineno}: hardcoded color outside SousTheme.swift — "
                    f"add a token instead"
                )
            if RAW_FONT.search(line) and swift.name != "SousTheme.swift":
                problems.append(
                    f"{rel}:{lineno}: inline font size outside SousTheme.swift — "
                    f"use a type token, or Font.sousIcon(_:) for an SF Symbol"
                )

    # The icon scale in the theme must match the scale in tokens.json.
    theme_icon_sizes = []
    in_enum = False
    for line in (app / "Views" / "SousTheme.swift").read_text().splitlines():
        if line.startswith("enum SousIconSize"):
            in_enum = True
            continue
        if in_enum:
            if line.startswith("}"):
                break
            m = ICON_CASE.search(line)
            if m:
                theme_icon_sizes.append(int(m.group(1)))

    want_icon = [
        int(v["$value"]) for v in doc["semantic"]["iconSize"].values()
        if isinstance(v, dict) and "$value" in v
    ]
    if sorted(theme_icon_sizes) != sorted(want_icon):
        problems.append(
            f"icon scale has drifted:\n"
            f"    tokens.json:      {sorted(want_icon)}\n"
            f"    SousIconSize:     {sorted(theme_icon_sizes)}"
        )

    # Every type token in tokens.json must exist in the theme.
    theme_src_all = (app / "Views" / "SousTheme.swift").read_text()
    for name in doc["semantic"]["typography"]:
        if name.startswith("$"):
            continue
        if f"static let {name}:" not in theme_src_all:
            problems.append(
                f"typography.{name}: declared in tokens.json but not defined in "
                f"SousTheme.swift"
            )
        checked += 1

    if problems:
        print(f"DRIFT DETECTED — {len(problems)} problem(s)\n")
        for p in problems:
            print(f"  - {p}")
        print("\ntokens.json and SousTheme.swift must agree. Fix one or the other.")
        return 1

    print(f"OK — {checked} tokens match SousTheme.swift.")
    print(f"     Icon scale: {sorted(theme_icon_sizes)}pt. "
          f"No hardcoded colors or inline font sizes in views.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
