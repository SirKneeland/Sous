#!/usr/bin/env python3
"""Generate the Sous Figma plugin from design/tokens.json.

The plugin is a single self-contained file with the token data inlined, so it
needs no bundler, no network access and no Figma plan features beyond variables.

    python3 design/build-figma-plugin.py

Writes figma/code.js. Re-run it after any change to tokens.json, then re-run the
plugin inside Figma. design/check-tokens.py fails if the two fall out of sync.
"""

import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "tokens.json"
OUT = ROOT / "figma" / "code.js"


def hex_to_rgba(value):
    """'#F2EFE9' or '#FFFFFF33' -> {r,g,b,a} in 0..1, rounded for stable output."""
    h = value.lstrip("#")
    if len(h) not in (6, 8):
        raise ValueError(f"bad hex: {value}")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
    return {k: round(v, 6) for k, v in (("r", r), ("g", g), ("b", b), ("a", a))}


def flatten_primitives(doc):
    out = {}
    for hue, entries in doc["primitive"]["color"].items():
        if "$value" in entries:
            out[hue] = {"value": entries["$value"], "description": entries.get("$description", "")}
            continue
        for step, entry in entries.items():
            out[f"{hue}/{step}"] = {"value": entry["$value"],
                                    "description": entry.get("$description", "")}
    return out


def resolve(ref, primitives):
    """'{primitive.color.cream.100}' -> the primitive key 'cream/100'."""
    if not (ref.startswith("{") and ref.endswith("}")):
        return None
    key = ref[1:-1].removeprefix("primitive.color.")
    parts = key.split(".")
    for candidate in ("/".join(parts), parts[0]):
        if candidate in primitives:
            return candidate
    raise ValueError(f"unresolvable reference: {ref}")


# Scopes keep a variable out of pickers where it makes no sense.
SCOPES = {
    "background": ["FRAME_FILL", "SHAPE_FILL"],
    "text":       ["TEXT_FILL"],
    "accent":     ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"],
    "border":     ["STROKE_COLOR"],
    "status":     ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL"],
    "voice":      ["FRAME_FILL", "SHAPE_FILL", "TEXT_FILL", "STROKE_COLOR"],
}

# Token name -> the name a designer sees on the Figma text style.
STYLE_NAMES = {
    "sousTitle": "Title", "sousLogotype": "Logotype",
    "sousSectionHeader": "Section Header", "sousBody": "Body",
    "sousCaption": "Caption", "sousButton": "Button",
    "sousButtonQuiet": "Button Quiet", "sousHeading1": "Heading 1",
    "sousHeading2": "Heading 2", "sousHeading3": "Heading 3",
    "sousReadoutLarge": "Readout Large", "sousReadout": "Readout",
    "sousPickerValue": "Picker Value", "sousPickerLabel": "Picker Label",
    "sousTimerBanner": "Timer Banner", "sousVoiceLabel": "Voice Label",
    "sousVoiceButton": "Voice Button",
}


def build():
    raw = TOKENS.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()[:16]
    doc = json.loads(raw)

    primitives = flatten_primitives(doc)
    data = {
        "primitives": {k: {"rgba": hex_to_rgba(v["value"]),
                           "hex": v["value"],
                           "description": v["description"]}
                       for k, v in primitives.items()},
        "semantic": [],
        "type": [],
        "icon": [],
        "spacing": [],
        "border": [],
    }

    for group, entries in doc["semantic"]["color"].items():
        if not isinstance(entries, dict):
            continue
        for name, entry in entries.items():
            if not isinstance(entry, dict) or "light" not in entry:
                continue
            light, dark = entry["light"], entry["dark"]
            swift = (f"Color.{entry['$swift']}" if "$swift" in entry
                     else entry.get("$ios"))
            data["semantic"].append({
                "name": f"{group}/{name}",
                "swift": swift,
                "light": {"alias": resolve(light, primitives)} if light.startswith("{")
                         else {"rgba": hex_to_rgba(light)},
                "dark": {"alias": resolve(dark, primitives)} if dark.startswith("{")
                        else {"rgba": hex_to_rgba(dark)},
                "description": entry.get("$description", ""),
                "scopes": SCOPES.get(group, []),
            })

    for name, role in doc["semantic"]["typography"].items():
        if name.startswith("$"):
            continue
        data["type"].append({
            "token": name,
            "styleName": STYLE_NAMES.get(name, name),
            "family": role["family"],
            "size": role["size"],
            "weight": role["weight"],
            "case": role["case"],
            "tracking": role["tracking"],
            "description": role.get("$description", ""),
        })

    for name, entry in doc["semantic"]["iconSize"].items():
        if name.startswith("$"):
            continue
        data["icon"].append({"name": name, "value": entry["$value"],
                             "description": entry.get("$description", ""),
                             "scopes": ["FONT_SIZE", "WIDTH_HEIGHT"],
                             "swift": f"SousIconSize.{name}"})

    for name, entry in doc["semantic"]["spacing"].items():
        if name.startswith("$"):
            continue
        data["spacing"].append({"name": name, "value": entry["$value"],
                                "description": entry.get("$description", ""),
                                "scopes": ["GAP"], "swift": None})

    border = doc["semantic"]["border"]
    data["border"].append({"name": "border/hairline",
                           "value": border["width"]["hairline"]["$value"],
                           "description": border["width"]["hairline"]["$description"],
                           "scopes": ["STROKE_FLOAT"], "swift": None})
    for name, entry in border["radius"].items():
        data["border"].append({"name": f"radius/{name}", "value": entry["$value"],
                               "description": entry.get("$description", ""),
                               "scopes": ["CORNER_RADIUS"], "swift": None})

    payload = json.dumps(data, indent=2, ensure_ascii=False)
    components = (ROOT / "design" / "figma-components.js").read_text()
    symbols = json.loads((ROOT / "design" / "sf-symbols.json").read_text())["symbols"]
    components = components.replace("__SF_SYMBOLS__", json.dumps(symbols, indent=2))
    js = (PLUGIN_TEMPLATE()
          .replace("// __COMPONENTS__", components)
          .replace("__TOKENS__", payload)
          .replace("__DIGEST__", digest))
    OUT.parent.mkdir(exist_ok=True)

    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text() != js:
            print("figma/code.js is stale — run: python3 design/build-figma-plugin.py")
            return 1
        print("OK — figma/code.js matches tokens.json")
        return 0

    OUT.write_text(js)
    print(f"figma/code.js written  ({len(data['primitives'])} primitives, "
          f"{len(data['semantic'])} semantic colors, {len(data['type'])} text styles, "
          f"{len(data['icon'])} icon sizes, {len(data['spacing'])} spacing, "
          f"{len(data['border'])} border)")
    return 0


TEMPLATE = ROOT / "design" / "figma-plugin-template.js"


def PLUGIN_TEMPLATE():
    return TEMPLATE.read_text()


if __name__ == "__main__":
    sys.exit(build())
