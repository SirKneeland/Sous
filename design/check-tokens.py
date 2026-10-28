#!/usr/bin/env python3
"""Verify SousTheme.swift still matches design/tokens.json.

Sous keeps its palette in two places by necessity: tokens.json (the source of
truth, and what Figma imports) and SousTheme.swift (what the app compiles).
This script proves they agree. Run it after any palette change.

    python3 design/check-tokens.py

Exits 0 when they match, 1 when they have drifted, and prints every mismatch.
"""

import json
import subprocess
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "tokens.json"
THEME = ROOT / "ios" / "SousApp" / "SousApp" / "Views" / "SousTheme.swift"
PLUGIN = ROOT / "figma" / "code.js"

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

# Any haptic built by hand rather than played from the SousHaptic scale.
RAW_HAPTIC = re.compile(r"UI(?:Impact|Notification|Selection)FeedbackGenerator")

# static let control: CGFloat = 52
SIZE_DECL = re.compile(r"static let (?P<symbol>\w+):\s*CGFloat\s*=\s*(?P<value>\d+)")

# static let panelArrive = Spring(response: 0.42, dampingFraction: 0.86)
SPRING_DECL = re.compile(
    r"static let (?P<symbol>\w+)\s*=\s*Spring\("
    r"response:\s*(?P<response>[0-9.]+),\s*"
    r"dampingFraction:\s*(?P<damping>[0-9.]+)\)"
)



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
    # Haptics are chosen from the SousHaptic scale, not by picking an intensity at
    # the call site. SousHaptics.swift is where a role becomes a generator.
    haptic_exempt = {"SousHaptics.swift"}
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
            if RAW_HAPTIC.search(line) and swift.name not in haptic_exempt:
                problems.append(
                    f"{rel}:{lineno}: feedback generator built outside "
                    f"SousHaptics.swift — play a SousHaptic role instead"
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

    # Every size token that claims a Swift home must match it. Tokens without a
    # `$swift` key are documentation only and are skipped, so adding one is how a
    # dimension graduates from written-down to enforced.
    size_decls = {m.group("symbol"): int(m.group("value")) for m in SIZE_DECL.finditer(theme_src_all)}
    for name, entry in doc["semantic"]["size"].items():
        if not isinstance(entry, dict) or "$swift" not in entry:
            continue
        symbol = entry["$swift"]
        checked += 1
        if symbol not in size_decls:
            problems.append(
                f"size.{name}: tokens.json expects SousTheme.swift to define "
                f"'SousSize.{symbol}', but it does not exist"
            )
        elif size_decls[symbol] != entry["$value"]:
            problems.append(
                f"size.{name} (SousSize.{symbol}) has drifted:\n"
                f"    tokens.json:      {entry['$value']}\n"
                f"    SousTheme.swift:  {size_decls[symbol]}"
            )

    # Springs are the first motion tokens. Same opt-in contract as size: a token
    # carrying a `$swift` key must match its SousMotion constant.
    spring_decls = {
        m.group("symbol"): (float(m.group("response")), float(m.group("damping")))
        for m in SPRING_DECL.finditer(theme_src_all)
    }
    for name, entry in doc["semantic"].get("motion", {}).items():
        if not isinstance(entry, dict) or "$swift" not in entry:
            continue
        symbol = entry["$swift"]
        checked += 1
        want = (float(entry["$value"]["response"]), float(entry["$value"]["dampingFraction"]))
        if symbol not in spring_decls:
            problems.append(
                f"motion.{name}: tokens.json expects SousTheme.swift to define "
                f"'SousMotion.{symbol}', but it does not exist"
            )
        elif spring_decls[symbol] != want:
            problems.append(
                f"motion.{name} (SousMotion.{symbol}) has drifted:\n"
                f"    tokens.json:      response {want[0]}  damping {want[1]}\n"
                f"    SousTheme.swift:  response {spring_decls[symbol][0]}  "
                f"damping {spring_decls[symbol][1]}"
            )

    for name in doc["semantic"]["typography"]:
        if name.startswith("$"):
            continue
        if f"static let {name}:" not in theme_src_all:
            problems.append(
                f"typography.{name}: declared in tokens.json but not defined in "
                f"SousTheme.swift"
            )
        checked += 1

    # The generated Figma plugin must match what its sources would produce today
    # (tokens.json, the plugin template and the component builders).
    if PLUGIN.exists():
        stale = subprocess.run(
            [sys.executable, str(ROOT / "design" / "build-figma-plugin.py"), "--check"],
            capture_output=True, text=True,
        )
        if stale.returncode != 0:
            problems.append(
                "figma/code.js is out of date with its sources — "
                "run: python3 design/build-figma-plugin.py"
            )

    if problems:
        print(f"DRIFT DETECTED — {len(problems)} problem(s)\n")
        for p in problems:
            print(f"  - {p}")
        print("\ntokens.json and SousTheme.swift must agree. Fix one or the other.")
        return 1

    print(f"OK — {checked} tokens match SousTheme.swift.")
    print(f"     Icon scale: {sorted(theme_icon_sizes)}pt. "
          f"No hardcoded colors, inline font sizes or hand-built haptics in views.")
    if PLUGIN.exists():
        print("     Figma plugin is in sync with tokens.json.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
