// Sous Design Tokens — Figma plugin
//
// GENERATED FILE. Do not edit by hand.
// Regenerate with:  python3 design/build-figma-plugin.py
// tokens.json digest: a88550595f36b16f
//
// Running this creates (or updates) the Sous variable collections and text
// styles in the current Figma file. It is safe to run repeatedly — variables are
// matched by name and updated in place, never duplicated.

const TOKENS = {
  "primitives": {
    "cream/100": {
      "rgba": {
        "r": 0.94902,
        "g": 0.937255,
        "b": 0.913725,
        "a": 1.0
      },
      "hex": "#F2EFE9",
      "description": "Warm off-white. Primary light background / dark-mode text."
    },
    "ink/800": {
      "rgba": {
        "r": 0.133333,
        "g": 0.133333,
        "b": 0.133333,
        "a": 1.0
      },
      "hex": "#222222",
      "description": "Dark-mode elevated surface (sheets, input fields)."
    },
    "ink/900": {
      "rgba": {
        "r": 0.101961,
        "g": 0.101961,
        "b": 0.101961,
        "a": 1.0
      },
      "hex": "#1A1A1A",
      "description": "Near-black. Primary light text and strong borders / dark background."
    },
    "warmGray/300": {
      "rgba": {
        "r": 0.815686,
        "g": 0.796078,
        "b": 0.764706,
        "a": 1.0
      },
      "hex": "#D0CBC3",
      "description": "Light-mode separator."
    },
    "warmGray/500": {
      "rgba": {
        "r": 0.603922,
        "g": 0.584314,
        "b": 0.564706,
        "a": 1.0
      },
      "hex": "#9A9590",
      "description": "Muted text: captions, timestamps, done steps, placeholders."
    },
    "warmGray/600": {
      "rgba": {
        "r": 0.458824,
        "g": 0.454902,
        "b": 0.443137,
        "a": 1.0
      },
      "hex": "#757471",
      "description": "Photo-sheet backdrop."
    },
    "warmGray/700": {
      "rgba": {
        "r": 0.227451,
        "g": 0.207843,
        "b": 0.188235,
        "a": 1.0
      },
      "hex": "#3A3530",
      "description": "Dark-mode separator."
    },
    "white": {
      "rgba": {
        "r": 1.0,
        "g": 1.0,
        "b": 1.0,
        "a": 1.0
      },
      "hex": "#FFFFFF",
      "description": "Light-mode sheet surface."
    },
    "burgundy/50": {
      "rgba": {
        "r": 0.968627,
        "g": 0.917647,
        "b": 0.92549,
        "a": 1.0
      },
      "hex": "#F7EAEC",
      "description": "Pale wash. Light-mode highlighted rows, user chat bubbles."
    },
    "burgundy/400": {
      "rgba": {
        "r": 0.768627,
        "g": 0.313725,
        "b": 0.407843,
        "a": 1.0
      },
      "hex": "#C45068",
      "description": "Lifted burgundy for legibility on dark surfaces."
    },
    "burgundy/700": {
      "rgba": {
        "r": 0.545098,
        "g": 0.180392,
        "b": 0.247059,
        "a": 1.0
      },
      "hex": "#8B2E3F",
      "description": "Brand burgundy. CTAs, accents, section headers, nav bar."
    },
    "burgundy/950": {
      "rgba": {
        "r": 0.172549,
        "g": 0.062745,
        "b": 0.094118,
        "a": 1.0
      },
      "hex": "#2C1018",
      "description": "Near-black with burgundy tint. Dark-mode highlighted rows."
    },
    "green/700": {
      "rgba": {
        "r": 0.176471,
        "g": 0.415686,
        "b": 0.309804,
        "a": 1.0
      },
      "hex": "#2D6A4F",
      "description": "Muted success green. Patch-diff additions only."
    },
    "blush/100": {
      "rgba": {
        "r": 0.980392,
        "g": 0.92549,
        "b": 0.905882,
        "a": 1.0
      },
      "hex": "#FAECE7",
      "description": "Voice mode: listening waveform, bright state label."
    },
    "blush/300": {
      "rgba": {
        "r": 0.960784,
        "g": 0.768627,
        "b": 0.701961,
        "a": 1.0
      },
      "hex": "#F5C4B3",
      "description": "Voice mode: speaking waveform, speaking label, exit icon."
    },
    "blush/500": {
      "rgba": {
        "r": 0.941176,
        "g": 0.6,
        "b": 0.482353,
        "a": 1.0
      },
      "hex": "#F0997B",
      "description": "Voice mode: ready/thinking labels, secondary voice text."
    }
  },
  "semantic": [
    {
      "name": "background/canvas",
      "swift": "Color.sousBackground",
      "light": {
        "alias": "cream/100"
      },
      "dark": {
        "alias": "ink/900"
      },
      "description": "Primary background on every screen.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL"
      ]
    },
    {
      "name": "background/surface",
      "swift": "Color.sousSurface",
      "light": {
        "alias": "white"
      },
      "dark": {
        "alias": "ink/800"
      },
      "description": "Chat sheet, history drawer, input fields.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL"
      ]
    },
    {
      "name": "background/surfaceInverse",
      "swift": "Color.sousSurfaceInverse",
      "light": {
        "alias": "ink/900"
      },
      "dark": {
        "alias": "ink/900"
      },
      "description": "Ink fill that stays dark in BOTH modes — the history drawer's settings button. Not for Inverse buttons: those flip with the mode; use background/inverse.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL"
      ]
    },
    {
      "name": "background/highlight",
      "swift": "Color.sousHighlightBackground",
      "light": {
        "alias": "burgundy/50"
      },
      "dark": {
        "alias": "burgundy/950"
      },
      "description": "Timer-highlight rows, user chat bubbles, tag backgrounds.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL"
      ]
    },
    {
      "name": "background/scrim",
      "swift": "Color.sousScrim",
      "light": {
        "alias": "warmGray/600"
      },
      "dark": {
        "alias": "warmGray/600"
      },
      "description": "Photo acquisition backdrop behind the chat sheet.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL"
      ]
    },
    {
      "name": "background/inverse",
      "swift": "Color.sousText",
      "light": {
        "alias": "ink/900"
      },
      "dark": {
        "alias": "cream/100"
      },
      "description": "Mode-flipping inverse fill — ink in light, cream in dark. Inverse buttons: ACCEPT, OK, TALK TO A RECIPE.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL"
      ]
    },
    {
      "name": "background/disabled",
      "swift": "Color.sousMuted",
      "light": {
        "alias": "warmGray/500"
      },
      "dark": {
        "alias": "warmGray/500"
      },
      "description": "Fill of a disabled filled button — ACCEPT with an invalid patch, Settings save with an empty key.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL"
      ]
    },
    {
      "name": "text/primary",
      "swift": "Color.sousText",
      "light": {
        "alias": "ink/900"
      },
      "dark": {
        "alias": "cream/100"
      },
      "description": "All primary text.",
      "scopes": [
        "TEXT_FILL"
      ]
    },
    {
      "name": "text/muted",
      "swift": "Color.sousMuted",
      "light": {
        "alias": "warmGray/500"
      },
      "dark": {
        "alias": "warmGray/500"
      },
      "description": "Captions, timestamps, struck-through done steps, placeholders.",
      "scopes": [
        "TEXT_FILL"
      ]
    },
    {
      "name": "text/accent",
      "swift": "Color.sousTerracotta",
      "light": {
        "alias": "burgundy/700"
      },
      "dark": {
        "alias": "burgundy/400"
      },
      "description": "Section headers, active states, REJECT label.",
      "scopes": [
        "TEXT_FILL"
      ]
    },
    {
      "name": "text/onAccent",
      "swift": null,
      "light": {
        "alias": "cream/100"
      },
      "dark": {
        "alias": "cream/100"
      },
      "description": "Text and icons sitting on a burgundy fill.",
      "scopes": [
        "TEXT_FILL"
      ]
    },
    {
      "name": "text/onInverse",
      "swift": "Color.white",
      "light": {
        "alias": "white"
      },
      "dark": {
        "alias": "white"
      },
      "description": "Text and icons sitting on an ink fill.",
      "scopes": [
        "TEXT_FILL"
      ]
    },
    {
      "name": "text/inverse",
      "swift": "Color.sousBackground",
      "light": {
        "alias": "cream/100"
      },
      "dark": {
        "alias": "ink/900"
      },
      "description": "Label on background/inverse or background/disabled — cream in light, ink in dark.",
      "scopes": [
        "TEXT_FILL"
      ]
    },
    {
      "name": "accent/primary",
      "swift": "Color.sousTerracotta",
      "light": {
        "alias": "burgundy/700"
      },
      "dark": {
        "alias": "burgundy/400"
      },
      "description": "CTA fill, nav bar, checked checkbox fill, voice bar background.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL",
        "TEXT_FILL",
        "STROKE_COLOR"
      ]
    },
    {
      "name": "border/strong",
      "swift": "Color.sousText",
      "light": {
        "alias": "ink/900"
      },
      "dark": {
        "alias": "cream/100"
      },
      "description": "Structural 1pt borders: buttons, checkboxes, cards.",
      "scopes": [
        "STROKE_COLOR"
      ]
    },
    {
      "name": "border/subtle",
      "swift": "Color.sousSeparator",
      "light": {
        "alias": "warmGray/300"
      },
      "dark": {
        "alias": "warmGray/700"
      },
      "description": "1pt dividers between rows and sections.",
      "scopes": [
        "STROKE_COLOR"
      ]
    },
    {
      "name": "status/added",
      "swift": "Color.sousGreen",
      "light": {
        "alias": "green/700"
      },
      "dark": {
        "alias": "green/700"
      },
      "description": "Patch-diff additions. The only non-burgundy accent in the app.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL",
        "TEXT_FILL"
      ]
    },
    {
      "name": "voice/labelBright",
      "swift": "Color.sousVoiceBright",
      "light": {
        "alias": "blush/100"
      },
      "dark": {
        "alias": "blush/100"
      },
      "description": "'listening' label and listening waveform.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL",
        "TEXT_FILL",
        "STROKE_COLOR"
      ]
    },
    {
      "name": "voice/labelSpeaking",
      "swift": "Color.sousVoiceSpeaking",
      "light": {
        "alias": "blush/300"
      },
      "dark": {
        "alias": "blush/300"
      },
      "description": "'speaking' label, speaking waveform, exit icon, patch-pending text.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL",
        "TEXT_FILL",
        "STROKE_COLOR"
      ]
    },
    {
      "name": "voice/labelWarm",
      "swift": "Color.sousVoiceWarm",
      "light": {
        "alias": "blush/500"
      },
      "dark": {
        "alias": "blush/500"
      },
      "description": "'ready' and 'thinking' labels, secondary voice copy.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL",
        "TEXT_FILL",
        "STROKE_COLOR"
      ]
    },
    {
      "name": "voice/exitBorder",
      "swift": "Color.white.opacity(0.2)",
      "light": {
        "rgba": {
          "r": 1.0,
          "g": 1.0,
          "b": 1.0,
          "a": 0.2
        }
      },
      "dark": {
        "rgba": {
          "r": 1.0,
          "g": 1.0,
          "b": 1.0,
          "a": 0.2
        }
      },
      "description": "Voice exit button border, white at 20%.",
      "scopes": [
        "FRAME_FILL",
        "SHAPE_FILL",
        "TEXT_FILL",
        "STROKE_COLOR"
      ]
    }
  ],
  "type": [
    {
      "token": "sousTitle",
      "styleName": "Title",
      "family": "serif",
      "size": 28,
      "weight": "bold",
      "case": "title",
      "tracking": 0,
      "description": "Recipe titles. The recipe canvas uppercases the title string itself, so the style is not forced to capitals — doc titles elsewhere keep their casing."
    },
    {
      "token": "sousLogotype",
      "styleName": "Logotype",
      "family": "serif",
      "size": 34,
      "weight": "bold",
      "case": "title",
      "tracking": 0,
      "description": "SOUS wordmark on the blank state."
    },
    {
      "token": "sousSectionHeader",
      "styleName": "Section Header",
      "family": "sans",
      "size": 11,
      "weight": "semibold",
      "case": "uppercase",
      "tracking": 1.2,
      "description": "INGREDIENTS, PROCEDURE, MISE EN PLACE."
    },
    {
      "token": "sousBody",
      "styleName": "Body",
      "family": "sans",
      "size": 16,
      "weight": "regular",
      "case": "sentence",
      "tracking": 0,
      "description": "Ingredient rows, step text, chat messages."
    },
    {
      "token": "sousCaption",
      "styleName": "Caption",
      "family": "sans",
      "size": 11,
      "weight": "regular",
      "case": "sentence",
      "tracking": 0,
      "description": "Captions, timestamps, revision numbers."
    },
    {
      "token": "sousButton",
      "styleName": "Button",
      "family": "sans",
      "size": 14,
      "weight": "semibold",
      "case": "uppercase",
      "tracking": 0,
      "description": "Button labels."
    },
    {
      "token": "sousButtonQuiet",
      "styleName": "Button Quiet",
      "family": "sans",
      "size": 13,
      "weight": "regular",
      "case": "sentence",
      "tracking": 0,
      "description": "De-emphasised button labels — destructive or secondary actions."
    },
    {
      "token": "sousHeading1",
      "styleName": "Heading 1",
      "family": "sans",
      "size": 17,
      "weight": "bold",
      "case": "sentence",
      "tracking": 0,
      "description": "Markdown H1 in assistant chat messages."
    },
    {
      "token": "sousHeading2",
      "styleName": "Heading 2",
      "family": "sans",
      "size": 15,
      "weight": "bold",
      "case": "sentence",
      "tracking": 0,
      "description": "Markdown H2 in assistant chat messages."
    },
    {
      "token": "sousHeading3",
      "styleName": "Heading 3",
      "family": "sans",
      "size": 14,
      "weight": "semibold",
      "case": "sentence",
      "tracking": 0,
      "description": "Markdown H3 and below in assistant chat messages."
    },
    {
      "token": "sousReadoutLarge",
      "styleName": "Readout Large",
      "family": "mono",
      "size": 32,
      "weight": "bold",
      "case": "uppercase",
      "tracking": 0,
      "description": "Timer-done banner — the largest readout in the app."
    },
    {
      "token": "sousReadout",
      "styleName": "Readout",
      "family": "mono",
      "size": 24,
      "weight": "bold",
      "case": "sentence",
      "tracking": 0,
      "description": "Active countdown in the adjust-timer sheet."
    },
    {
      "token": "sousPickerValue",
      "styleName": "Picker Value",
      "family": "mono",
      "size": 22,
      "weight": "regular",
      "case": "sentence",
      "tracking": 0,
      "description": "Digits in the duration and servings wheels."
    },
    {
      "token": "sousPickerLabel",
      "styleName": "Picker Label",
      "family": "mono",
      "size": 15,
      "weight": "semibold",
      "case": "uppercase",
      "tracking": 0,
      "description": "Wheel labels — HOURS, MINUTES, PEOPLE."
    },
    {
      "token": "sousTimerBanner",
      "styleName": "Timer Banner",
      "family": "mono",
      "size": 14,
      "weight": "semibold",
      "case": "sentence",
      "tracking": 0,
      "description": "Countdown inside a running-timer banner."
    },
    {
      "token": "sousVoiceLabel",
      "styleName": "Voice Label",
      "family": "mono",
      "size": 14,
      "weight": "regular",
      "case": "lowercase",
      "tracking": 0,
      "description": "Voice bar state labels — ready, listening, speaking, thinking."
    },
    {
      "token": "sousVoiceButton",
      "styleName": "Voice Button",
      "family": "mono",
      "size": 13,
      "weight": "semibold",
      "case": "uppercase",
      "tracking": 0,
      "description": "Voice bar ACCEPT / REJECT labels."
    }
  ],
  "icon": [
    {
      "name": "small",
      "value": 11,
      "description": "Chevrons, close buttons, inline row affordances. 17 sites.",
      "scopes": [
        "FONT_SIZE",
        "WIDTH_HEIGHT"
      ],
      "swift": "SousIconSize.small"
    },
    {
      "name": "medium",
      "value": 14,
      "description": "Standard bar and control icons — send, scan, pencil. 10 sites.",
      "scopes": [
        "FONT_SIZE",
        "WIDTH_HEIGHT"
      ],
      "swift": "SousIconSize.medium"
    },
    {
      "name": "large",
      "value": 16,
      "description": "Prominent controls — drawer buttons, mic, camera. 6 sites.",
      "scopes": [
        "FONT_SIZE",
        "WIDTH_HEIGHT"
      ],
      "swift": "SousIconSize.large"
    },
    {
      "name": "xLarge",
      "value": 22,
      "description": "Feature icons in sheets and pickers. 3 sites.",
      "scopes": [
        "FONT_SIZE",
        "WIDTH_HEIGHT"
      ],
      "swift": "SousIconSize.xLarge"
    },
    {
      "name": "huge",
      "value": 32,
      "description": "Empty-state illustration icons. 1 site.",
      "scopes": [
        "FONT_SIZE",
        "WIDTH_HEIGHT"
      ],
      "swift": "SousIconSize.huge"
    }
  ],
  "spacing": [
    {
      "name": "xs",
      "value": 4,
      "description": "",
      "scopes": [
        "GAP"
      ],
      "swift": null
    },
    {
      "name": "sm",
      "value": 8,
      "description": "",
      "scopes": [
        "GAP"
      ],
      "swift": null
    },
    {
      "name": "md",
      "value": 12,
      "description": "",
      "scopes": [
        "GAP"
      ],
      "swift": null
    },
    {
      "name": "lg",
      "value": 16,
      "description": "",
      "scopes": [
        "GAP"
      ],
      "swift": null
    },
    {
      "name": "gutter",
      "value": 20,
      "description": "Left/right content margin. The app's dominant rhythm — 52 uses.",
      "scopes": [
        "GAP"
      ],
      "swift": null
    },
    {
      "name": "xl",
      "value": 24,
      "description": "",
      "scopes": [
        "GAP"
      ],
      "swift": null
    },
    {
      "name": "2xl",
      "value": 32,
      "description": "",
      "scopes": [
        "GAP"
      ],
      "swift": null
    },
    {
      "name": "3xl",
      "value": 40,
      "description": "",
      "scopes": [
        "GAP"
      ],
      "swift": null
    }
  ],
  "border": [
    {
      "name": "border/hairline",
      "value": 1,
      "description": "The only border width in the app. 36 uses, zero exceptions.",
      "scopes": [
        "STROKE_FLOAT"
      ],
      "swift": null
    },
    {
      "name": "radius/square",
      "value": 0,
      "description": "Default. Buttons, checkboxes, cards, inputs.",
      "scopes": [
        "CORNER_RADIUS"
      ],
      "swift": null
    },
    {
      "name": "radius/soft",
      "value": 3,
      "description": "Rare. Maximum permitted radius.",
      "scopes": [
        "CORNER_RADIUS"
      ],
      "swift": null
    }
  ]
};

const log = [];
const warn = [];

// ---------------------------------------------------------------- collections

async function collectionNamed(name) {
  const all = await figma.variables.getLocalVariableCollectionsAsync();
  const found = all.find((c) => c.name === name);
  return found || figma.variables.createVariableCollection(name);
}

async function variableNamed(name, collection, type) {
  const all = await figma.variables.getLocalVariablesAsync();
  const found = all.find(
    (v) => v.name === name && v.variableCollectionId === collection.id
  );
  if (found && found.resolvedType === type) return found;
  return figma.variables.createVariable(name, collection, type);
}

// ------------------------------------------------------------------ primitives

async function buildPrimitives() {
  const collection = await collectionNamed("Sous Primitives");
  const mode = collection.modes[0].modeId;
  const made = {};
  for (const [name, spec] of Object.entries(TOKENS.primitives)) {
    const v = await variableNamed(name, collection, "COLOR");
    v.setValueForMode(mode, spec.rgba);
    v.description = spec.description + "  (" + spec.hex + ")";
    // Primitives are hidden from every picker: designs use semantic tokens only.
    v.scopes = [];
    made[name] = v;
  }
  log.push(Object.keys(made).length + " primitive colors");
  return made;
}

// -------------------------------------------------------------------- semantic

// Two modes in one collection is the right structure, but modes are a paid
// feature. Try it; if the plan refuses, fall back to one collection per theme.
// Upgrading the plan and re-running this plugin produces the merged structure.
async function buildSemantic(primitives) {
  const single = await collectionNamed("Sous Color");
  let lightMode = single.modes[0].modeId;
  let darkMode = null;

  const existingDark = single.modes.find((m) => m.name === "Dark");
  if (existingDark) {
    darkMode = existingDark.modeId;
  } else {
    try {
      darkMode = single.addMode("Dark");
    } catch (e) {
      darkMode = null;
    }
  }

  if (darkMode) {
    single.renameMode(lightMode, "Light");
    await writeSemantic(single, primitives, [
      ["light", lightMode],
      ["dark", darkMode],
    ]);
    log.push(TOKENS.semantic.length + " semantic colors in one collection, Light + Dark modes");
    return;
  }

  // Starter plan: no modes available.
  const light = single;
  light.renameMode(light.modes[0].modeId, "Light");
  const dark = await collectionNamed("Sous Color Dark");
  dark.renameMode(dark.modes[0].modeId, "Dark");

  await writeSemantic(light, primitives, [["light", light.modes[0].modeId]]);
  await writeSemantic(dark, primitives, [["dark", dark.modes[0].modeId]]);

  log.push(TOKENS.semantic.length + " semantic colors x2 (Sous Color + Sous Color Dark)");
  warn.push(
    "Your plan does not allow multiple variable modes, so light and dark live in " +
      "two collections. On a paid plan, re-run this plugin and it will merge them " +
      "into one collection with Light and Dark modes."
  );
}

async function writeSemantic(collection, primitives, pairs) {
  for (const token of TOKENS.semantic) {
    const v = await variableNamed(token.name, collection, "COLOR");
    for (const [theme, modeId] of pairs) {
      const spec = token[theme];
      if (spec.alias) {
        const target = primitives[spec.alias];
        v.setValueForMode(modeId, figma.variables.createVariableAlias(target));
      } else {
        v.setValueForMode(modeId, spec.rgba);
      }
    }
    v.description = token.description;
    if (token.scopes.length) v.scopes = token.scopes;
    if (token.swift) v.setVariableCodeSyntax("iOS", token.swift);
  }
}

// ----------------------------------------------------------------- number sets

async function buildNumbers(collectionName, items, prefix) {
  const collection = await collectionNamed(collectionName);
  const mode = collection.modes[0].modeId;
  for (const item of items) {
    const name = prefix ? prefix + "/" + item.name : item.name;
    const v = await variableNamed(name, collection, "FLOAT");
    v.setValueForMode(mode, item.value);
    v.description = item.description;
    v.scopes = item.scopes;
    if (item.swift) v.setVariableCodeSyntax("iOS", item.swift);
  }
  log.push(items.length + " values in " + collectionName);
}

// ---------------------------------------------------------------- text styles

// Sous uses Apple system faces. Figma can see them on the macOS desktop app; in
// a browser it cannot, so fall back to Inter and say which styles were affected.
const FAMILIES = {
  serif: ["New York", "Times New Roman", "Inter"],
  // "SF Pro" first: Figma hosts it, so it resolves on your Mac AND on Figma's
  // servers (where remote tools run). It also covers every optical size, unlike
  // the older "SF Pro Text" cut, which is tuned for small text only.
  sans: ["SF Pro", "SF Pro Text", "Inter"],
  mono: ["SF Mono", "Menlo", "Inter"],
};

const WEIGHTS = {
  regular: ["Regular"],
  medium: ["Medium", "Regular"],
  semibold: ["Semibold", "Semi Bold", "Bold"],
  bold: ["Bold"],
};

async function resolveFont(family, weight) {
  for (const candidate of FAMILIES[family]) {
    for (const style of WEIGHTS[weight]) {
      try {
        await figma.loadFontAsync({ family: candidate, style: style });
        return { family: candidate, style: style };
      } catch (e) {
        // try the next combination
      }
    }
  }
  await figma.loadFontAsync({ family: "Inter", style: "Regular" });
  return { family: "Inter", style: "Regular" };
}

const TEXT_CASE = { uppercase: "UPPER", lowercase: "LOWER" };

async function buildTextStyles() {
  const existing = await figma.getLocalTextStylesAsync();
  const substituted = [];

  for (const role of TOKENS.type) {
    const name = "Sous/" + role.styleName;
    let style = existing.find((s) => s.name === name);
    if (!style) {
      style = figma.createTextStyle();
      style.name = name;
    }

    const font = await resolveFont(role.family, role.weight);
    const wanted = FAMILIES[role.family][0];
    if (font.family !== wanted) substituted.push(role.styleName + " (" + wanted + ")");

    style.fontName = font;
    style.fontSize = role.size;
    style.textCase = TEXT_CASE[role.case] || "ORIGINAL";
    if (role.tracking) {
      style.letterSpacing = { value: role.tracking, unit: "PIXELS" };
    }
    style.description = role.description + "\n\nSwift token: Font." + role.token;
  }

  log.push(TOKENS.type.length + " text styles");
  if (substituted.length) {
    warn.push(
      "Figma could not find these Apple fonts and substituted: " +
        substituted.join(", ") +
        ". Run this from the Figma desktop app on a Mac to get the real faces."
    );
  }
}

// ---------------------------------------------------------------- verification

// Everything above writes. Everything below reads it back and checks it, so the
// plugin proves its own work instead of asking you to eyeball six panels.

const EPSILON = 0.001;
const checks = { passed: 0, failed: [] };

function check(label, condition, detail) {
  if (condition) {
    checks.passed++;
  } else {
    checks.failed.push(label + (detail ? " — " + detail : ""));
  }
}

function sameColor(a, b) {
  if (!a || !b) return false;
  return (
    Math.abs(a.r - b.r) < EPSILON &&
    Math.abs(a.g - b.g) < EPSILON &&
    Math.abs(a.b - b.b) < EPSILON &&
    Math.abs((a.a === undefined ? 1 : a.a) - (b.a === undefined ? 1 : b.a)) < EPSILON
  );
}

async function verify() {
  const collections = await figma.variables.getLocalVariableCollectionsAsync();
  const variables = await figma.variables.getLocalVariablesAsync();
  const styles = await figma.getLocalTextStylesAsync();

  const byCollection = {};
  for (const c of collections) byCollection[c.name] = c;

  const find = (collectionName, varName) => {
    const c = byCollection[collectionName];
    if (!c) return null;
    return variables.find(
      (v) => v.name === varName && v.variableCollectionId === c.id
    );
  };

  // --- primitives
  const primitiveIds = {};
  for (const [name, spec] of Object.entries(TOKENS.primitives)) {
    const v = find("Sous Primitives", name);
    if (!v) {
      check("primitive " + name, false, "missing");
      continue;
    }
    primitiveIds[name] = v.id;
    const value = v.valuesByMode[byCollection["Sous Primitives"].modes[0].modeId];
    check("primitive " + name, sameColor(value, spec.rgba), "wrong color");
    check("primitive " + name + " hidden", v.scopes.length === 0,
      "scopes " + v.scopes.join(","));
  }

  // --- semantic, in whichever shape the plan allowed
  const merged = byCollection["Sous Color"] &&
    byCollection["Sous Color"].modes.length > 1;

  const themes = merged
    ? [
        ["light", "Sous Color", modeIdNamed(byCollection["Sous Color"], "Light")],
        ["dark", "Sous Color", modeIdNamed(byCollection["Sous Color"], "Dark")],
      ]
    : [
        ["light", "Sous Color", byCollection["Sous Color"] &&
          byCollection["Sous Color"].modes[0].modeId],
        ["dark", "Sous Color Dark", byCollection["Sous Color Dark"] &&
          byCollection["Sous Color Dark"].modes[0].modeId],
      ];

  for (const token of TOKENS.semantic) {
    for (const [theme, collectionName, modeId] of themes) {
      const label = theme + " " + token.name;
      const v = find(collectionName, token.name);
      if (!v || !modeId) {
        check(label, false, "missing");
        continue;
      }
      if (theme === "light") {
        const got = (v.codeSyntax && v.codeSyntax.iOS) || null;
        check(label + " swift name", got === (token.swift || null),
          "expected " + token.swift + ", got " + got);
      }
      const value = v.valuesByMode[modeId];
      const spec = token[theme];
      if (spec.alias) {
        const ok = value && value.type === "VARIABLE_ALIAS" &&
          value.id === primitiveIds[spec.alias];
        check(label, ok, "should alias " + spec.alias);
      } else {
        check(label, sameColor(value, spec.rgba), "wrong color");
      }
    }
  }

  // --- number scales
  const numberSets = [
    ["Sous Icon Sizes", TOKENS.icon, "icon"],
    ["Sous Spacing", TOKENS.spacing, "space"],
    ["Sous Border", TOKENS.border, null],
  ];
  for (const [collectionName, items, prefix] of numberSets) {
    const c = byCollection[collectionName];
    for (const item of items) {
      const name = prefix ? prefix + "/" + item.name : item.name;
      const v = find(collectionName, name);
      if (!v || !c) {
        check(collectionName + " " + name, false, "missing");
        continue;
      }
      const value = v.valuesByMode[c.modes[0].modeId];
      check(collectionName + " " + name, value === item.value,
        "expected " + item.value + ", got " + value);
      // Figma returns scopes in its own order; compare contents, not order.
      check(collectionName + " " + name + " scopes",
        v.scopes.slice().sort().join(",") === item.scopes.slice().sort().join(","),
        "scopes " + v.scopes.join(","));
      const got = (v.codeSyntax && v.codeSyntax.iOS) || null;
      check(collectionName + " " + name + " swift name", got === (item.swift || null),
        "expected " + item.swift + ", got " + got);
    }
  }

  // --- text styles
  const fontsUsed = {};
  for (const role of TOKENS.type) {
    const name = "Sous/" + role.styleName;
    const style = styles.find((s) => s.name === name);
    if (!style) {
      check("style " + name, false, "missing");
      continue;
    }
    const wantCase = TEXT_CASE[role.case] || "ORIGINAL";
    const wantTracking = role.tracking || 0;
    const gotTracking = style.letterSpacing ? style.letterSpacing.value : 0;
    const ok =
      style.fontSize === role.size &&
      style.textCase === wantCase &&
      Math.abs(gotTracking - wantTracking) < EPSILON;
    check("style " + name, ok,
      "size " + style.fontSize + "/" + role.size +
      " case " + style.textCase + "/" + wantCase +
      " tracking " + gotTracking + "/" + wantTracking);
    fontsUsed[style.fontName.family] = (fontsUsed[style.fontName.family] || 0) + 1;
  }

  return { merged: merged, fonts: fontsUsed };
}

function modeIdNamed(collection, name) {
  const m = collection.modes.find((mode) => mode.name === name);
  return m ? m.modeId : null;
}

function buildReport(result) {
  const lines = [];
  lines.push("SOUS DESIGN TOKENS — import report");
  lines.push("tokens.json digest: a88550595f36b16f");
  lines.push("");
  lines.push("Created: " + log.join(", ") + ".");
  lines.push("Components: " + (COMPONENT_LOG.length ? COMPONENT_LOG.join(", ") : "none rebuilt") + ".");
  lines.push("");
  lines.push(
    "Colour structure: " +
      (result.merged
        ? "one collection, Light + Dark modes (paid plan)."
        : "two collections, Sous Color + Sous Color Dark (Starter plan, no modes).")
  );
  const fonts = Object.keys(result.fonts)
    .map((f) => f + " x" + result.fonts[f])
    .join(", ");
  lines.push("Fonts resolved: " + fonts + ".");
  lines.push("SF Symbols: " + sfSymbolReport() + ".");
  lines.push("");
  if (checks.failed.length === 0) {
    lines.push("VERIFIED — all " + checks.passed + " checks passed.");
  } else {
    lines.push(
      "FAILED — " + checks.failed.length + " of " +
        (checks.passed + checks.failed.length) + " checks did not pass:"
    );
    lines.push("");
    checks.failed.forEach((f) => lines.push("  - " + f));
  }
  if (warn.length) {
    lines.push("");
    lines.push("Notes:");
    warn.forEach((w) => lines.push("  - " + w));
  }
  return lines.join("\n");
}

// ----------------------------------------------------------------- components
//
// Component builders for the Sous Figma library. Spliced into figma/code.js by
// design/build-figma-plugin.py, after the token builders and before main.
//
// Rules every builder follows:
//   - Every fill, stroke, radius, gap and padding is bound to a Sous variable.
//     Nothing visual is hardcoded except intrinsic geometry (a checkbox is 20pt).
//   - Rebuilding is safe while a component has no instances: the old component
//     set and everything this plugin owns on its page (found by exact name) is
//     removed and rebuilt. Once instances exist, the builder skips and says so,
//     because deleting a used component would break every design that uses it.
//   - Only standard Plugin API calls. No helpers that exist only in remote tools.

const COMPONENT_LOG = [];

async function ensurePage(name) {
  let page = figma.root.children.find((p) => p.name === name);
  if (!page) {
    page = figma.createPage();
    page.name = name;
  }
  await figma.setCurrentPageAsync(page);
  return page;
}

async function colorVars() {
  const cols = await figma.variables.getLocalVariableCollectionsAsync();
  const vars = await figma.variables.getLocalVariablesAsync();
  const byName = {};
  for (const c of cols) byName[c.name] = c;
  return function (collection, name) {
    const c = byName[collection];
    const v = c && vars.find((x) => x.name === name && x.variableCollectionId === c.id);
    if (!v) throw new Error("Missing variable " + collection + " / " + name);
    return v;
  };
}

function boundPaint(variable, opacity) {
  const paint = figma.variables.setBoundVariableForPaint(
    { type: "SOLID", color: { r: 0, g: 0, b: 0 } }, "color", variable
  );
  // Mutating the returned paint does not stick — build a new object instead.
  return opacity === undefined ? paint : Object.assign({}, paint, { opacity: opacity });
}

// SF Symbols come from figma.util.getSfSymbolCharacter. Record exactly why a
// lookup failed (missing API vs rejected name) and warn once per symbol.
const SF_SYMBOL_STATUS = {};

// design/sf-symbols.json: every symbol the app uses, as an Apple PUA codepoint.
// The desktop plugin API has no symbol lookup, so the table is the primary source.
const SF_SYMBOL_TABLE = {
  "arrow.up": "100128",
  "arrowshape.turn.up.backward.2.fill": "100C23",
  "arrowshape.turn.up.backward.fill": "100C1B",
  "bubble.left": "10032A",
  "camera": "10031E",
  "carrot": "10158E",
  "checkmark": "100185",
  "checkmark.circle.fill": "100063",
  "chevron.down": "100188",
  "chevron.left": "100189",
  "chevron.right": "10018A",
  "clock": "10042B",
  "doc.on.clipboard": "100243",
  "doc.viewfinder": "1003BE",
  "exclamationmark.triangle": "1001FE",
  "gearshape": "1008CB",
  "gearshape.fill": "1008CC",
  "lightbulb.min": "101DD6",
  "line.3.horizontal": "100307",
  "message": "100324",
  "mic.fill": "1002B1",
  "paperplane.fill": "100220",
  "pencil": "10020A",
  "person.2": "10026B",
  "photo": "1003C5",
  "photo.on.rectangle": "1003EB",
  "plus": "10017C",
  "plus.square.fill": "1000DD",
  "square.and.arrow.up": "100202",
  "timer": "100431",
  "timer.circle.fill": "101646",
  "trash": "100211",
  "wand.and.stars": "10070D",
  "xmark": "100184"
};

function whiteAlpha(a) {
  return { type: "SOLID", color: { r: 1, g: 1, b: 1 }, opacity: a };
}

function sfSymbol(name) {
  if (name in SF_SYMBOL_STATUS) return SF_SYMBOL_STATUS[name].char;
  let char = "";
  let problem = null;
  const hex = SF_SYMBOL_TABLE[name];
  if (hex) {
    char = String.fromCodePoint(parseInt(hex, 16));
  } else if (figma.util && typeof figma.util.getSfSymbolCharacter === "function") {
    try {
      char = figma.util.getSfSymbolCharacter(name);
    } catch (e) {
      problem = "Figma rejected it: " + (e && e.message ? e.message : String(e));
    }
  } else {
    problem = 'not in design/sf-symbols.json — add it there (see that file\'s howToAdd)';
  }
  SF_SYMBOL_STATUS[name] = { char: char, problem: problem };
  if (problem) warn.push('SF Symbol "' + name + '" is blank — ' + problem + ".");
  return char;
}

function sfSymbolReport() {
  const used = Object.keys(SF_SYMBOL_STATUS);
  const bad = used.filter((k) => SF_SYMBOL_STATUS[k].problem);
  return used.length - bad.length + " of " + used.length + " drawn" +
    (bad.length ? " (blank: " + bad.join(", ") + ")" : "") +
    "; table has " + Object.keys(SF_SYMBOL_TABLE).length;
}

// SF Symbols render in SF Pro. When SF Pro is missing (Figma in a browser), fall
// back to Inter so the build still completes; the icon is blank either way.
async function loadIconFont() {
  const sf = { family: "SF Pro", style: "Semibold" };
  try {
    await figma.loadFontAsync(sf);
    return sf;
  } catch (e) {
    const inter = { family: "Inter", style: "Regular" };
    await figma.loadFontAsync(inter);
    return inter;
  }
}

// Returns true when it is safe to (re)build: nothing uses the old component.
async function clearOwned(page, setName, ownedNames, quiet) {
  const sets = page.children.filter(
    (n) => (n.type === "COMPONENT_SET" || n.type === "COMPONENT") && n.name === setName
  );
  for (const set of sets) {
    const variants = set.type === "COMPONENT_SET" ? set.children : [set];
    for (const variant of variants) {
      // Figma still lists instances deleted earlier in this same run; they have
      // no parent chain any more, which is why they reported "unknown page".
      const instances = (await variant.getInstancesAsync()).filter((i) => !i.removed);
      if (instances.length) {
        const where = {};
        for (const inst of instances) {
          let n = inst;
          while (n && n.type !== "PAGE") n = n.parent;
          const label = n ? n.name : "unknown page";
          where[label] = (where[label] || 0) + 1;
        }
        if (quiet) return false;
        warn.push(
          setName + " was not rebuilt: " + instances.length + " instance(s) still use it (" +
          Object.keys(where).map((k) => k + ": " + where[k]).join(", ") +
          "). Delete them if they are stray, then run again — or leave them and edit the " +
          "component in Figma."
        );
        return false;
      }
    }
  }
  for (const set of sets) set.remove();
  for (const n of page.children.filter((x) => ownedNames.includes(x.name))) n.remove();
  return true;
}

function autoLayout(direction) {
  const f = figma.createFrame();
  f.layoutMode = direction;
  f.primaryAxisSizingMode = "AUTO";
  f.counterAxisSizingMode = "AUTO";
  f.fills = [];
  return f;
}

async function textNode(styleName, characters, colorVar, name) {
  const styles = await figma.getLocalTextStylesAsync();
  const style = styles.find((s) => s.name === styleName);
  if (!style) throw new Error("Missing text style " + styleName);
  await figma.loadFontAsync(style.fontName);
  const t = figma.createText();
  t.name = name;
  await t.setTextStyleIdAsync(style.id);
  t.characters = characters;
  t.fills = [boundPaint(colorVar)];
  return t;
}

// Documentation panel shared by every component page.
async function docPanel(page, v, title, paragraphs) {
  const doc = autoLayout("VERTICAL");
  doc.name = title + " / Documentation";
  doc.itemSpacing = 12;
  doc.paddingTop = doc.paddingBottom = doc.paddingLeft = doc.paddingRight = 40;
  doc.fills = [boundPaint(v("Sous Color", "background/canvas"))];
  page.appendChild(doc);
  doc.x = 40;
  doc.y = 40;
  const lines = [
    ["Sous/Section Header", "COMPONENT", "text/accent", "eyebrow"],
    ["Sous/Title", title, "text/primary", "title"],
  ].concat(paragraphs);
  for (const [style, chars, color, name] of lines) {
    const t = await textNode(style, chars, v("Sous Color", color), name);
    doc.appendChild(t);
    t.textAutoResize = "HEIGHT";
    t.resize(520, t.height);
  }
  return doc;
}

// Axis labels beside a variant grid. Fixed-width boxes with alignment, so
// placement never depends on measuring text.
async function gridLabels(page, v, set, cols, rows, cell, pad, gap, prefix) {
  const LABEL_H = 16;
  const muted = v("Sous Color", "text/muted");
  const made = [];
  for (let i = 0; i < cols.length; i++) {
    const t = await textNode("Sous/Caption", cols[i], muted, prefix + "/col/" + cols[i]);
    page.appendChild(t);
    t.textAutoResize = "NONE";
    t.resize(cell.w, LABEL_H);
    t.textAlignHorizontal = "CENTER";
    t.x = set.x + pad + i * (cell.w + gap);
    t.y = set.y - LABEL_H - 8;
    made.push(t);
  }
  const ROW_W = 140;
  for (let i = 0; i < rows.length; i++) {
    const t = await textNode("Sous/Caption", rows[i], muted, prefix + "/row/" + rows[i]);
    page.appendChild(t);
    t.textAutoResize = "NONE";
    t.resize(ROW_W, LABEL_H);
    t.textAlignHorizontal = "RIGHT";
    t.textAlignVertical = "CENTER";
    t.x = set.x - ROW_W - 12;
    t.y = set.y + pad + i * (cell.h + gap) + cell.h / 2 - LABEL_H / 2;
    made.push(t);
  }
  return made;
}

function layoutGrid(set, colOf, rowOf, cell, pad, gap, nCols, nRows) {
  for (const c of set.children) {
    c.x = pad + colOf(c) * (cell.w + gap);
    c.y = pad + rowOf(c) * (cell.h + gap);
  }
  // Size the set to its real contents, so a variant taller than the nominal
  // cell (text is measured on the Mac) never spills outside the set's frame.
  let right = pad * 2 + nCols * cell.w + (nCols - 1) * gap;
  let bottom = pad * 2 + nRows * cell.h + (nRows - 1) * gap;
  for (const c of set.children) {
    right = Math.max(right, c.x + c.width + pad);
    bottom = Math.max(bottom, c.y + c.height + pad);
  }
  set.resizeWithoutConstraints(right, bottom);
}

function variantProps(node) {
  const out = {};
  for (const part of node.name.split(", ")) {
    const [k, val] = part.split("=");
    out[k] = val;
  }
  return out;
}

// ---------------------------------------------------------------------- Button
//
// Source: about 40 hand-built buttons across the SwiftUI views (there is no
// shared SwiftUI button yet). Five styles; Disabled exists only where the code
// draws one. Labels on burgundy are white in both modes (decided 2026-09-20).

const BUTTON_STYLES = [
  { style: "Primary", fill: "accent/primary", stroke: null, label: "text/onInverse" },
  { style: "Inverse", fill: "background/inverse", stroke: null, label: "text/inverse" },
  { style: "Secondary", fill: null, stroke: "border/strong", label: "text/primary" },
  { style: "Secondary Accent", fill: null, stroke: "accent/primary", label: "text/accent" },
  { style: "Text", fill: null, stroke: null, label: "text/accent" },
];
const BUTTON_DISABLED = {
  Inverse: { fill: "background/disabled", stroke: null, label: "text/inverse" },
  Secondary: { fill: null, stroke: "border/strong", label: "text/muted" },
};
const BUTTON_W = 353;   // 393 - 2x20pt gutter
const BUTTON_H = 52;

function buttonSpecs() {
  const specs = [];
  for (const s of BUTTON_STYLES) {
    specs.push(Object.assign({ state: "Default" }, s));
    if (BUTTON_DISABLED[s.style]) {
      specs.push(Object.assign({ state: "Disabled", style: s.style }, BUTTON_DISABLED[s.style]));
    }
  }
  return specs;
}

async function buildButton() {
  const page = await ensurePage("Button");
  const cols = ["Default", "Disabled"];
  const rows = BUTTON_STYLES.map((s) => s.style);
  const owned = ["Button / Documentation"]
    .concat(cols.map((c) => "button/col/" + c))
    .concat(rows.map((r) => "button/row/" + r));
  if (!(await clearOwned(page, "Button", owned))) return;

  const v = await colorVars();
  const n = (col, name) => v(col, name);
  const labelStyle = (await figma.getLocalTextStylesAsync()).find((s) => s.name === "Sous/Button");
  await figma.loadFontAsync(labelStyle.fontName);
  const iconFont = await loadIconFont();

  const comps = [];
  for (const spec of buttonSpecs()) {
    const c = figma.createComponent();
    c.name = "Style=" + spec.style + ", State=" + spec.state;
    c.layoutMode = "HORIZONTAL";
    c.primaryAxisAlignItems = "CENTER";
    c.counterAxisAlignItems = "CENTER";
    c.resize(BUTTON_W, BUTTON_H);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "FIXED";
    c.setBoundVariable("itemSpacing", n("Sous Spacing", "space/sm"));
    c.setBoundVariable("paddingLeft", n("Sous Spacing", "space/gutter"));
    c.setBoundVariable("paddingRight", n("Sous Spacing", "space/gutter"));
    for (const k of ["topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius"]) {
      c.setBoundVariable(k, n("Sous Border", "radius/square"));
    }
    c.fills = spec.fill ? [boundPaint(n("Sous Color", spec.fill))] : [];
    if (spec.stroke) {
      c.strokes = [boundPaint(n("Sous Color", spec.stroke))];
      c.strokeAlign = "INSIDE";
      c.setBoundVariable("strokeWeight", n("Sous Border", "border/hairline"));
    } else {
      c.strokes = [];
    }
    const labelColor = n("Sous Color", spec.label);

    const icon = figma.createText();
    icon.name = "icon";
    icon.fontName = iconFont;
    icon.characters = sfSymbol("message");
    icon.setBoundVariable("fontSize", n("Sous Icon Sizes", "icon/medium"));
    icon.fills = [boundPaint(labelColor)];
    c.appendChild(icon);
    icon.visible = false;

    const label = figma.createText();
    label.name = "label";
    await label.setTextStyleIdAsync(labelStyle.id);
    label.characters = "Button";
    label.fills = [boundPaint(labelColor)];
    c.appendChild(label);

    page.appendChild(c);
    comps.push(c);
  }

  const set = figma.combineAsVariants(comps, page);
  set.name = "Button";
  set.description =
    "Square, full width by default. Primary = burgundy fill (main action). Inverse = ink fill " +
    "that flips to cream in dark mode (ACCEPT, OK). Secondary = 1pt ink border. Secondary " +
    "Accent = 1pt burgundy border. Text = burgundy label only (Cancel, Reject). Labels always " +
    "ALL CAPS; labels on burgundy are white in both modes.\n\n" +
    "Swift: no shared button yet — each view draws its own with Font.sousButton.";

  const labelKey = set.addComponentProperty("Label", "TEXT", "Button");
  const iconKey = set.addComponentProperty("Icon", "BOOLEAN", false);
  for (const variant of set.children) {
    variant.findOne((x) => x.name === "label").componentPropertyReferences = { characters: labelKey };
    variant.findOne((x) => x.name === "icon").componentPropertyReferences = { visible: iconKey };
  }

  const PAD = 32, GAP = 24, cell = { w: BUTTON_W, h: BUTTON_H };
  layoutGrid(
    set,
    (c) => cols.indexOf(variantProps(c).State),
    (c) => rows.indexOf(variantProps(c).Style),
    cell, PAD, GAP, cols.length, rows.length
  );

  const doc = await docPanel(page, v, "Button", [
    ["Sous/Body",
      "Square corners, full width by default (353 × 52 on a 393pt iPhone). Five styles: Primary — burgundy fill, the main action. Inverse — ink fill that flips to cream in dark mode, for confirming (ACCEPT, OK). Secondary — 1pt ink border. Secondary Accent — 1pt burgundy border. Text — burgundy label only, for Cancel and Reject.",
      "text/primary", "description"],
    ["Sous/Body",
      "Labels are always ALL CAPS. Labels on burgundy are white in both modes. Only Inverse and Secondary have a disabled look in the app today; the others have none yet. Toggle Icon to show a leading SF Symbol, as TALK TO SOUS does.",
      "text/primary", "usage"],
    ["Sous/Body",
      'Not yet true in code: there is no shared SwiftUI button — each screen draws its own. "Make this recipe", "Reset Recipe" and "Restore Original Recipe" break the ALL CAPS rule. START, SET and "Make this recipe" still use a label that turns dark in dark mode instead of white.',
      "text/muted", "code-debt"],
  ]);
  set.x = doc.x + doc.width + 80 + 152;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, cols, rows, cell, PAD, GAP, "button");

  COMPONENT_LOG.push("Button (" + set.children.length + " variants)");
}

async function verifyButton() {
  const page = figma.root.children.find((p) => p.name === "Button");
  if (!page) {
    check("component Button", false, "page missing");
    return;
  }
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Button");
  if (!set) {
    check("component Button", false, "component set missing");
    return;
  }
  const specs = buttonSpecs();
  check("Button variant count", set.children.length === specs.length,
    set.children.length + " of " + specs.length);

  const varName = async (paint) => {
    const alias = paint && paint.boundVariables && paint.boundVariables.color;
    if (!alias) return null;
    const va = await figma.variables.getVariableByIdAsync(alias.id);
    return va ? va.name : null;
  };
  for (const spec of specs) {
    const name = "Style=" + spec.style + ", State=" + spec.state;
    const c = set.children.find((x) => x.name === name);
    if (!c) {
      check("Button " + name, false, "missing");
      continue;
    }
    const fill = c.fills.length ? await varName(c.fills[0]) : null;
    const stroke = c.strokes.length ? await varName(c.strokes[0]) : null;
    const label = c.findOne((x) => x.name === "label");
    const labelColor = label ? await varName(label.fills[0]) : null;
    check("Button " + name + " fill", fill === spec.fill, "got " + fill);
    check("Button " + name + " border", stroke === spec.stroke, "got " + stroke);
    check("Button " + name + " label color", labelColor === spec.label, "got " + labelColor);
    check("Button " + name + " size", c.width === BUTTON_W && c.height === BUTTON_H,
      c.width + "x" + c.height);
  }
  const props = Object.keys(set.componentPropertyDefinitions || {});
  check("Button has Label property", props.some((k) => k.indexOf("Label") === 0), props.join(","));
  check("Button has Icon property", props.some((k) => k.indexOf("Icon") === 0), props.join(","));
}

// ------------------------------------------------------------ shared helpers

async function getVariant2(pageName, componentName) {
  const page = figma.root.children.find((p) => p.name === pageName);
  if (!page) throw new Error("Missing page " + pageName);
  await figma.setCurrentPageAsync(page);
  const c = page.children.find((n) => n.type === "COMPONENT" && n.name === componentName);
  if (!c) throw new Error("Missing component " + componentName);
  return c;
}

async function getVariant(pageName, setName, variantName) {
  const page = figma.root.children.find((p) => p.name === pageName);
  if (!page) throw new Error("Missing page " + pageName + " (needed for " + setName + ")");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((n) => n.type === "COMPONENT_SET" && n.name === setName);
  if (!set) throw new Error("Missing component " + setName);
  const v = set.children.find((c) => c.name === variantName);
  if (!v) throw new Error("Missing variant " + setName + " / " + variantName);
  return v;
}

function hFrame(name) {
  const f = autoLayout("HORIZONTAL");
  f.name = name;
  return f;
}

function bindPadding(node, v, spec) {
  // spec: { top, bottom, left, right } — each a token name or a raw number.
  for (const side of ["top", "bottom", "left", "right"]) {
    const val = spec[side];
    if (val === undefined) continue;
    const field = "padding" + side[0].toUpperCase() + side.slice(1);
    if (typeof val === "number") node[field] = val;
    else node.setBoundVariable(field, v("Sous Spacing", val));
  }
}

async function varNameOf(paint) {
  const alias = paint && paint.boundVariables && paint.boundVariables.color;
  if (!alias) return null;
  const va = await figma.variables.getVariableByIdAsync(alias.id);
  return va ? va.name : null;
}

const ROW_W = 393; // iPhone 15/16 width; rows carry their own 20pt gutters

// ------------------------------------------------------------ Section Header
//
// Source: RecipeCanvasView (INGREDIENTS / MISE EN PLACE / PROCEDURE) — burgundy
// ALL CAPS label, 1.2 tracking, chevron.down that rotates -90° when collapsed;
// padding 20 sides, 20 top, 12 bottom. Static = SousSectionLabel (patch review,
// cap reached): same label, no chevron.

const SECTION_STATES = ["Expanded", "Collapsed", "Static"];

async function buildSectionHeader() {
  const page = await ensurePage("Section Header");
  const owned = ["Section Header / Documentation"].concat(SECTION_STATES.map((s) => "section/col/" + s));
  if (!(await clearOwned(page, "Section Header", owned))) return;
  const v = await colorVars();
  const accent = v("Sous Color", "text/accent");
  const iconFont = await loadIconFont();

  const comps = [];
  for (const state of SECTION_STATES) {
    const c = figma.createComponent();
    c.name = "State=" + state;
    c.layoutMode = "HORIZONTAL";
    c.counterAxisAlignItems = "CENTER";
    c.resize(ROW_W, 40);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "AUTO";
    c.fills = [];
    c.setBoundVariable("itemSpacing", v("Sous Spacing", "space/sm"));
    bindPadding(c, v, { top: "space/gutter", bottom: "space/md", left: "space/gutter", right: "space/gutter" });

    const title = await textNode("Sous/Section Header", "INGREDIENTS", accent, "title");
    c.appendChild(title);

    const chevron = figma.createText();
    chevron.name = "chevron";
    chevron.fontName = iconFont;
    chevron.characters = sfSymbol("chevron.down");
    chevron.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
    chevron.fills = [boundPaint(accent)];
    c.appendChild(chevron);
    chevron.rotation = state === "Collapsed" ? -90 : 0;
    chevron.visible = state !== "Static";

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Section Header";
  set.description =
    "Burgundy ALL CAPS section label. Expanded / Collapsed carry a chevron that turns -90° " +
    "when the section is collapsed (INGREDIENTS, MISE EN PLACE, PROCEDURE on the canvas). " +
    "Static has no chevron (patch review, cap reached).\n\n" +
    "Swift: RecipeCanvasView section buttons; SousSectionLabel(title:) for Static.";
  const titleKey = set.addComponentProperty("Title", "TEXT", "INGREDIENTS");
  for (const variant of set.children) {
    variant.findOne((x) => x.name === "title").componentPropertyReferences = { characters: titleKey };
  }

  const PAD = 32, GAP = 24, cell = { w: ROW_W, h: 43 };
  layoutGrid(set, (c) => SECTION_STATES.indexOf(variantProps(c).State), () => 0,
    cell, PAD, GAP, SECTION_STATES.length, 1);
  const doc = await docPanel(page, v, "Section Header", [
    ["Sous/Body",
      "Burgundy ALL CAPS label, letter-spaced. On the recipe canvas it heads INGREDIENTS, MISE EN PLACE and PROCEDURE, with a chevron that turns sideways when the section is collapsed. Static is the same label without a chevron, used on the patch review and monthly-limit screens.",
      "text/primary", "description"],
    ["Sous/Body",
      "The chevron is the SF Symbol chevron.down. It is blank until the SF Symbol table is added to the plugin; its rotation is already correct.",
      "text/muted", "code-debt"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, SECTION_STATES, [], cell, PAD, GAP, "section");
  COMPONENT_LOG.push("Section Header (" + set.children.length + " variants)");
}

async function verifySectionHeader() {
  const page = figma.root.children.find((p) => p.name === "Section Header");
  if (!page) return check("component Section Header", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Section Header");
  if (!set) return check("component Section Header", false, "component set missing");
  check("Section Header variant count", set.children.length === SECTION_STATES.length, String(set.children.length));
  for (const state of SECTION_STATES) {
    const c = set.children.find((x) => x.name === "State=" + state);
    if (!c) { check("Section Header " + state, false, "missing"); continue; }
    const title = c.findOne((x) => x.name === "title");
    const chevron = c.findOne((x) => x.name === "chevron");
    check("Section Header " + state + " title color", (await varNameOf(title.fills[0])) === "text/accent");
    check("Section Header " + state + " chevron", chevron.visible === (state !== "Static") &&
      chevron.rotation === (state === "Collapsed" ? -90 : 0),
      "visible " + chevron.visible + ", rotation " + chevron.rotation);
  }
}

// ---------------------------------------------------------------- Checkbox
//
// Source: SousTheme.SousCheckbox — square, 1pt border; checked fills burgundy
// with a white SF Symbol checkmark at half the box size. 20pt everywhere except
// the "don't show again" dialog, which uses 18pt.
//
// This one is BUILD-IF-MISSING. The Checkbox in SousWork was made before the
// plugin could build components and is already used by every row; rebuilding it
// would break them. The builder exists so the library can be recreated from an
// empty file.

const CHECKBOX_SIZES = { Default: 20, Small: 18 };

async function buildCheckbox() {
  const page = await ensurePage("Checkbox");
  const existing = page.children.find((n) => n.type === "COMPONENT_SET" && n.name === "Checkbox");
  if (existing) {
    // The original was built before the plugin managed components and is used by
    // every row, so it is never rebuilt — but fixes still have to reach it.
    // 2026-09-24: centred 1pt strokes straddle the edge and render unevenly.
    let squared = 0;
    for (const variant of existing.children) {
      if (variant.strokeAlign !== "INSIDE") { variant.strokeAlign = "INSIDE"; squared++; }
    }
    COMPONENT_LOG.push("Checkbox (kept" + (squared ? ", " + squared + " borders squared up" : "") + ")");
    return;
  }
  const v = await colorVars();
  const accent = v("Sous Color", "accent/primary");
  const ink = v("Sous Color", "border/strong");
  const onInverse = v("Sous Color", "text/onInverse");
  const iconFont = await loadIconFont();
  const mark = sfSymbol("checkmark");

  const comps = [];
  for (const sizeName of Object.keys(CHECKBOX_SIZES)) {
    const px = CHECKBOX_SIZES[sizeName];
    for (const state of ["Unchecked", "Checked"]) {
      const checked = state === "Checked";
      const c = figma.createComponent();
      c.name = "State=" + state + ", Size=" + sizeName;
      c.layoutMode = "HORIZONTAL";
      c.primaryAxisAlignItems = "CENTER";
      c.counterAxisAlignItems = "CENTER";
      c.resize(px, px);
      c.primaryAxisSizingMode = "FIXED";
      c.counterAxisSizingMode = "FIXED";
      c.clipsContent = false;
      c.fills = checked ? [boundPaint(accent)] : [];
      c.strokes = [boundPaint(checked ? accent : ink)];
      c.strokeAlign = "INSIDE";
      c.setBoundVariable("strokeWeight", v("Sous Border", "border/hairline"));
      for (const k of ["topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius"]) {
        c.setBoundVariable(k, v("Sous Border", "radius/square"));
      }
      const t = figma.createText();
      t.name = "checkmark";
      t.fontName = iconFont;
      t.characters = mark;
      t.fontSize = px * 0.5;  // SousCheckbox: .system(size: size * 0.5, weight: .bold)
      t.fills = [boundPaint(onInverse)];
      c.appendChild(t);
      t.textAutoResize = "NONE";
      t.layoutSizingHorizontal = "FIXED";
      t.layoutSizingVertical = "FIXED";
      t.resize(px, px);
      t.textAlignHorizontal = "CENTER";
      t.textAlignVertical = "CENTER";
      t.visible = checked;
      page.appendChild(c);
      comps.push(c);
    }
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Checkbox";
  set.description =
    "Square bordered checkbox. Unchecked: 1pt ink border. Checked: burgundy fill + white " +
    "checkmark at half the box size.\n\nSwift: SousCheckbox(isChecked:size:). Ingredients tick " +
    "without strikethrough; steps and mise en place strike through. Never fade a checked row.";
  const PAD = 32, GAP = 56, cell = { w: 20, h: 20 };
  const cols = ["Unchecked", "Checked"], rows = Object.keys(CHECKBOX_SIZES);
  layoutGrid(set,
    (c) => cols.indexOf(variantProps(c).State),
    (c) => rows.indexOf(variantProps(c).Size),
    cell, PAD, GAP, cols.length, rows.length);
  const doc = await docPanel(page, v, "Checkbox", [
    ["Sous/Body",
      "Square, bordered, never circular. Used on every ingredient, step and mise en place row. Default is 20pt; Small (18pt) appears only in the \"don't show again\" dialog.",
      "text/primary", "description"],
  ]);
  set.x = doc.x + doc.width + 80 + 152;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, cols, rows, cell, PAD, GAP, "checkbox");
  COMPONENT_LOG.push("Checkbox (" + set.children.length + " variants)");
}

async function verifyCheckbox() {
  const page = figma.root.children.find((p) => p.name === "Checkbox");
  if (!page) return check("component Checkbox", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Checkbox");
  if (!set) return check("component Checkbox", false, "component set missing");
  check("Checkbox variant count", set.children.length === 4, String(set.children.length));
  for (const sizeName of Object.keys(CHECKBOX_SIZES)) {
    for (const state of ["Unchecked", "Checked"]) {
      const name = "State=" + state + ", Size=" + sizeName;
      const c = set.children.find((x) => x.name === name);
      if (!c) { check("Checkbox " + name, false, "missing"); continue; }
      const checked = state === "Checked";
      const fill = c.fills.length ? await varNameOf(c.fills[0]) : null;
      check("Checkbox " + name + " fill", fill === (checked ? "accent/primary" : null), "got " + fill);
      check("Checkbox " + name + " border",
        (await varNameOf(c.strokes[0])) === (checked ? "accent/primary" : "border/strong"));
      check("Checkbox " + name + " border sits inside the square", c.strokeAlign === "INSIDE", c.strokeAlign);
      check("Checkbox " + name + " size",
        c.width === CHECKBOX_SIZES[sizeName] && c.height === CHECKBOX_SIZES[sizeName],
        c.width + "x" + c.height);
      const t = c.findOne((x) => x.name === "checkmark");
      check("Checkbox " + name + " checkmark shown only when checked", !!t && t.visible === checked);
    }
  }
}

// ------------------------------------------------------- checklist rows
//
// Steps, step groups and mise en place rows share one visual grammar with the
// ingredient row: optional checkbox (nudged down 2pt), sousBody text, 10pt
// vertical / 20pt side padding, and an iOS separator aligned to the text.
// What differs is state: Current is bold, Done is muted + struck through,
// Highlighted gets the pale burgundy row background.

const TIMER_SAMPLE = { prefix: "Simmer for ", time: "10 minutes", suffix: ", stirring occasionally." };

async function checklistRow(v, opts) {
  // opts: { name, state, checkbox, bold, done, highlighted, timer, text, checkboxVariants }
  const c = figma.createComponent();
  c.name = opts.name;
  c.layoutMode = "VERTICAL";
  c.resize(ROW_W, 44);
  c.primaryAxisSizingMode = "AUTO";
  c.counterAxisSizingMode = "FIXED";
  c.itemSpacing = 0;
  c.fills = opts.highlighted ? [boundPaint(v("Sous Color", "background/highlight"))] : [];

  const body = autoLayout("VERTICAL");
  body.name = "body";
  body.itemSpacing = 0;
  bindPadding(body, v, { top: 10, bottom: 10, left: "space/gutter", right: "space/gutter" });
  c.appendChild(body);
  body.layoutSizingHorizontal = "FILL";

  const line = hFrame("line");
  line.counterAxisAlignItems = "MIN";
  line.setBoundVariable("itemSpacing", v("Sous Spacing", "space/md"));
  body.appendChild(line);
  line.layoutSizingHorizontal = "FILL";

  // Indent and checkbox are switches, not variants. Auto-layout ignores hidden
  // children, so hiding either one closes the gap on its own.
  const indent = figma.createFrame();
  indent.name = "indent";
  indent.resize(20, 20);
  indent.fills = [];
  line.appendChild(indent);
  indent.visible = false;

  const slot = hFrame("checkbox-slot");
  slot.paddingTop = 2; // SousCheckbox .padding(.top, 2): aligns to the first text line
  line.appendChild(slot);
  const box = opts.checkboxVariants.createInstance();
  box.name = "checkbox";
  slot.appendChild(box);
  if (opts.checkbox === "Checked") box.setProperties({ State: "Checked" });

  const muted = v("Sous Color", "text/muted");
  const primary = v("Sous Color", "text/primary");
  let chars = opts.text;
  let span = null;
  if (opts.timer) {
    const icon = sfSymbol("timer");
    const start = TIMER_SAMPLE.prefix.length;
    chars = TIMER_SAMPLE.prefix + (icon ? icon + " " : "") + TIMER_SAMPLE.time + TIMER_SAMPLE.suffix;
    span = { start: start, end: start + (icon ? icon.length + 1 : 0) + TIMER_SAMPLE.time.length };
  }
  const text = await textNode("Sous/Body", chars, opts.done ? muted : primary, "text");
  line.appendChild(text);
  text.layoutSizingHorizontal = "FILL";
  text.textAutoResize = "HEIGHT";
  if (opts.bold) {
    const bold = { family: text.fontName.family, style: "Bold" };
    await figma.loadFontAsync(bold);
    text.fontName = bold;
  }
  // Per-range, not node-level: with a text style applied, assigning
  // text.textDecoration is silently ignored (found on device 2026-09-24).
  if (opts.done) text.setRangeTextDecoration(0, text.characters.length, "STRIKETHROUGH");
  if (span) text.setRangeFills(span.start, span.end, [boundPaint(v("Sous Color", "text/accent"))]);

  const notes = autoLayout("VERTICAL");
  notes.name = "notes";
  notes.paddingTop = 4;   // stepNotesView .padding(.top, 4)
  notes.itemSpacing = 2;  // VStack(spacing: 2)
  body.appendChild(notes);
  notes.layoutSizingHorizontal = "FILL";
  const note = await textNode("Sous/Body", "Don't let it boil — small bubbles at the edge only.", muted, "note");
  notes.appendChild(note);
  note.layoutSizingHorizontal = "FILL";
  note.textAutoResize = "HEIGHT";
  notes.visible = false;

  // The separator starts under the text, as iOS lists do. Its leading spacers
  // mirror the indent and checkbox switches, so it re-aligns automatically.
  const rule = hFrame("separator");
  rule.counterAxisAlignItems = "CENTER";
  rule.setBoundVariable("itemSpacing", v("Sous Spacing", "space/md"));
  bindPadding(rule, v, { left: "space/gutter", right: "space/gutter" });
  c.appendChild(rule);
  rule.layoutSizingHorizontal = "FILL";
  const sepIndent = figma.createFrame();
  sepIndent.name = "sep-indent";
  sepIndent.resize(20, 1);
  sepIndent.fills = [];
  rule.appendChild(sepIndent);
  sepIndent.visible = false;
  const sepBox = figma.createFrame();
  sepBox.name = "sep-checkbox";
  sepBox.resize(20, 1);
  sepBox.fills = [];
  rule.appendChild(sepBox);
  const hair = figma.createRectangle();
  hair.name = "hairline";
  hair.resize(ROW_W - 52, 1);
  hair.fills = [boundPaint(v("Sous Color", "border/subtle"))];
  rule.appendChild(hair);
  hair.layoutSizingHorizontal = "FILL";
  return c;
}

// ---------------------------------------------------------------- List Row
//
// One row, used for ingredients, procedure steps and mise en place. The app
// implements these as three separate SwiftUI views (IngredientRow,
// leafStepRowView, mepFlatRowView) but draws them identically; only the states
// differ, so the design system has one component with switches.
//
//   Ingredients  — State=Checked when ticked: never struck through, so the list
//                  stays readable while cooking.
//   Steps        — State=Done when finished (muted + struck), Timer variants,
//                  Highlighted after tapping a timer banner, Checkbox off for a
//                  parent step that only holds sub-steps.
//   Mise en place— State=Done when finished, Nested on for a task inside a vessel.

const LIST_ROW_SPECS = [
  { state: "To Do", timer: false },
  { state: "Checked", timer: false, checked: true },
  { state: "Current", timer: false, bold: true },
  { state: "Done", timer: false, done: true },
  { state: "To Do", timer: true },
  { state: "Current", timer: true, bold: true },
  { state: "Highlighted", timer: true, highlighted: true },
].map((s) => Object.assign(s, {
  name: "State=" + s.state + ", Timer=" + (s.timer ? "Yes" : "No"),
  checkbox: (s.done || s.checked) ? "Checked" : "Unchecked",
}));

async function buildListRow() {
  const boxVariant = await getVariant("Checkbox", "Checkbox", "State=Unchecked, Size=Default");
  // Retire the three separate row pages this component replaces.
  for (const old of ["Ingredient Row", "Step Row", "Mise en Place Row"]) {
    const page = figma.root.children.find((p) => p.name === old);
    if (!page) continue;
    // documentAccess: "dynamic-page" — a page that isn't the current one must be
    // loaded before its children can be read.
    await page.loadAsync();
    let safe = true;
    for (const n of page.children.filter((x) => x.type === "COMPONENT_SET" || x.type === "COMPONENT")) {
      const variants = n.type === "COMPONENT_SET" ? n.children : [n];
      for (const variant of variants) {
        if ((await variant.getInstancesAsync()).filter((i) => !i.removed).length) safe = false;
      }
    }
    if (!safe) {
      warn.push('Page "' + old + '" still has components in use, so it was left in place. ' +
        "Its rows now live in List Row.");
      continue;
    }
    page.remove();
    COMPONENT_LOG.push("retired page " + old);
  }

  const page = await ensurePage("List Row");
  const states = ["To Do", "Checked", "Current", "Done", "Highlighted"];
  const owned = ["List Row / Documentation"]
    .concat(["No timer", "Timer"].map((c) => "row/col/" + c))
    .concat(states.map((r) => "row/row/" + r));
  if (!(await clearOwned(page, "List Row", owned))) return;
  const v = await colorVars();

  const comps = [];
  for (const spec of LIST_ROW_SPECS) {
    const c = await checklistRow(v, Object.assign({}, spec, {
      text: "Pat the chicken dry and season it generously with salt.",
      checkboxVariants: boxVariant,
    }));
    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "List Row";
  set.description =
    "The row used for ingredients, steps and mise en place. Checked = ticked but NOT struck " +
    "through (ingredients). Done = muted and struck through (steps, prep). Current is bold. " +
    "Highlighted appears after tapping a timer banner. Switches: Checkbox off for a parent " +
    "step, Nested for a task inside a vessel, Timer for an inline duration, Notes for a " +
    "muted note beneath.\n\n" +
    "Swift: IngredientRow, leafStepRowView + TimerAffordanceText, mepFlatRowView — three " +
    "implementations of this one row.";

  // No TEXT property here, deliberately. Binding one across variants forces a
  // single styling on every bound layer: it wiped the Done row's strikethrough,
  // then leaked that strikethrough onto To Do / Checked and flattened Current's
  // bold (device reports, 2026-09-24). Row text is edited on the instance instead.
  const boxKey = set.addComponentProperty("Checkbox", "BOOLEAN", true);
  const nestedKey = set.addComponentProperty("Nested", "BOOLEAN", false);
  const notesKey = set.addComponentProperty("Notes", "BOOLEAN", false);
  for (const variant of set.children) {
    variant.findOne((x) => x.name === "checkbox-slot").componentPropertyReferences = { visible: boxKey };
    variant.findOne((x) => x.name === "sep-checkbox").componentPropertyReferences = { visible: boxKey };
    variant.findOne((x) => x.name === "indent").componentPropertyReferences = { visible: nestedKey };
    variant.findOne((x) => x.name === "sep-indent").componentPropertyReferences = { visible: nestedKey };
    variant.findOne((x) => x.name === "notes").componentPropertyReferences = { visible: notesKey };
  }

  const PAD = 32, GAP = 24, cell = { w: ROW_W, h: 66 };
  layoutGrid(set,
    (c) => (variantProps(c).Timer === "Yes" ? 1 : 0),
    (c) => states.indexOf(variantProps(c).State),
    cell, PAD, GAP, 2, states.length);

  const doc = await docPanel(page, v, "List Row", [
    ["Sous/Body",
      "One row for every checklist in the app. Ingredients use Checked — ticked but never struck through, because you read that list with your hands full. Steps and prep tasks use Done, which mutes and strikes the text. Current is bold. Highlighted turns the row pale burgundy and happens when you tap a running timer's banner to jump back to its step.",
      "text/primary", "description"],
    ["Sous/Body",
      "Switches: turn Checkbox off for a parent step that only groups sub-steps. Turn Nested on for a task inside a vessel like \"Small bowl\". Notes adds a muted line underneath. The divider re-aligns itself under the text as you flip Checkbox and Nested.",
      "text/primary", "usage"],
    ["Sous/Body",
      "Row text is edited directly: double-click into an instance and type. There is deliberately no Text field in the properties panel — one shared text field would force the same styling on every variant, which cost the Done row its strikethrough and the Current row its bold.",
      "text/primary", "editing"],
    ["Sous/Body",
      "Code notes: the app builds this row three separate times (IngredientRow, leafStepRowView, mepFlatRowView) — one shared row view would be the equivalent of this component. Indents also disagree: sub-steps indent 16pt per level, nested prep tasks 20pt; this component uses 20pt.",
      "text/muted", "code-debt"],
  ]);
  set.x = doc.x + doc.width + 80 + 152;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, ["No timer", "Timer"], states, cell, PAD, GAP, "row");
  const group = await buildIngredientGroupHeader();
  if (group) {
    group.x = set.x + 32;
    group.y = set.y + set.height + 48;
  }
  COMPONENT_LOG.push("List Row (" + set.children.length + " variants)");
}

async function verifyListRow() {
  const page = figma.root.children.find((p) => p.name === "List Row");
  if (!page) return check("component List Row", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "List Row");
  if (!set) return check("component List Row", false, "component set missing");
  check("List Row variant count", set.children.length === LIST_ROW_SPECS.length, String(set.children.length));

  for (const spec of LIST_ROW_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("List Row " + spec.name, false, "missing"); continue; }
    const t = "List Row " + spec.name;
    const text = c.findOne((x) => x.name === "text");
    const box = c.findOne((x) => x.name === "checkbox");
    const main = box && (await box.getMainComponentAsync());
    check(t + " checkbox", !!main && main.name === "State=" + spec.checkbox + ", Size=Default",
      main ? main.name : "none");
    const baseFill = text.getRangeFills(0, 1);
    check(t + " text color",
      Array.isArray(baseFill) && (await varNameOf(baseFill[0])) === (spec.done ? "text/muted" : "text/primary"));
    check(t + " bold only when current",
      (text.fontName.style === "Bold") === !!spec.bold, text.fontName.style);
    const deco = text.getRangeTextDecoration(0, text.characters.length);
    check(t + " struck through only when done", (deco === "STRIKETHROUGH") === !!spec.done, String(deco));
    check(t + " ticked ingredient is not struck through",
      !spec.checked || deco !== "STRIKETHROUGH");
    check(t + " highlight background",
      ((c.fills.length ? await varNameOf(c.fills[0]) : null) === "background/highlight") === !!spec.highlighted);
    if (spec.timer) {
      const i = text.characters.indexOf(TIMER_SAMPLE.time);
      const rf = text.getRangeFills(i, i + TIMER_SAMPLE.time.length);
      check(t + " timer span is burgundy", Array.isArray(rf) && (await varNameOf(rf[0])) === "text/accent");
    }
    const hair = c.findOne((x) => x.name === "hairline");
    check(t + " separator", hair && (await varNameOf(hair.fills[0])) === "border/subtle");
    check(t + " starts hidden: indent, notes",
      c.findOne((x) => x.name === "indent").visible === false &&
      c.findOne((x) => x.name === "notes").visible === false);
  }
  const props = Object.keys(set.componentPropertyDefinitions || {});
  check("List Row has no shared Text property", !props.some((k) => k.indexOf("Text#") === 0 || k === "Text"),
    props.join(","));
  for (const name of ["Checkbox", "Nested", "Notes"]) {
    check("List Row has the " + name + " property", props.some((k) => k.indexOf(name + "#") === 0 || k === name),
      props.join(","));
  }
  for (const old of ["Ingredient Row", "Step Row", "Mise en Place Row"]) {
    check("retired page " + old, !figma.root.children.some((p) => p.name === old));
  }
}

// --------------------------------------------------- Ingredient Group Header
//
// Source: RecipeCanvasView.ingredientRows — optional group heading ("FOR THE
// SAUCE"): muted ALL CAPS, padding 20 sides, 12 top, 4 bottom. Code tracks it at
// 1.0; the Sous/Section Header style uses 1.2 (0.2pt, not visible — noted as debt).

async function buildIngredientGroupHeader() {
  const page = await ensurePage("List Row");
  if (!(await clearOwned(page, "Ingredient Group Header", []))) return;
  const v = await colorVars();
  const c = figma.createComponent();
  c.name = "Ingredient Group Header";
  c.layoutMode = "HORIZONTAL";
  c.resize(ROW_W, 30);
  c.primaryAxisSizingMode = "FIXED";
  c.counterAxisSizingMode = "AUTO";
  c.fills = [];
  bindPadding(c, v, { top: "space/md", bottom: "space/xs", left: "space/gutter", right: "space/gutter" });
  const t = await textNode("Sous/Section Header", "FOR THE SAUCE", v("Sous Color", "text/muted"), "group");
  c.appendChild(t);
  page.appendChild(c);
  const groupKey = c.addComponentProperty("Group", "TEXT", "FOR THE SAUCE");
  t.componentPropertyReferences = { characters: groupKey };
  c.description = "Optional sub-heading inside INGREDIENTS (\"FOR THE SAUCE\"). Muted, ALL CAPS.\n\n" +
    "Swift: RecipeCanvasView.ingredientRows (group.header).";
  COMPONENT_LOG.push("Ingredient Group Header");
  return c;
}

// ------------------------------------------------------------- Icon Button
//
// Source: the hamburger that opens the history drawer (HistoryDrawer.swift:170,
// 44pt burgundy square, white line.3.horizontal), the drawer's settings button
// (:56, same size on the ink fill), and SousIconButton (SousTheme.swift, 32pt
// bordered, used in the chat sheet header).

const ICON_BUTTON_STYLES = [
  { style: "Accent", size: 44, fill: "accent/primary", stroke: null, icon: "text/onInverse",
    symbol: "line.3.horizontal", weight: "Medium", iconSize: "icon/large" },
  { style: "Inverse", size: 44, fill: "background/surfaceInverse", stroke: null, icon: "text/onInverse",
    symbol: "gearshape.fill", weight: "Medium", iconSize: "icon/large" },
  { style: "Bordered", size: 32, fill: null, stroke: "border/strong", icon: "text/primary",
    symbol: "gearshape", weight: "Regular", iconSize: "icon/medium" },
];

async function buildIconButton() {
  const page = await ensurePage("Icon Button");
  const owned = ["Icon Button / Documentation"]
    .concat(ICON_BUTTON_STYLES.map((s) => "iconbtn/col/" + s.style));
  if (!(await clearOwned(page, "Icon Button", owned))) return;
  const v = await colorVars();

  const comps = [];
  for (const spec of ICON_BUTTON_STYLES) {
    const c = figma.createComponent();
    c.name = "Style=" + spec.style;
    c.layoutMode = "HORIZONTAL";
    c.primaryAxisAlignItems = "CENTER";
    c.counterAxisAlignItems = "CENTER";
    c.resize(spec.size, spec.size);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "FIXED";
    c.fills = spec.fill ? [boundPaint(v("Sous Color", spec.fill))] : [];
    if (spec.stroke) {
      c.strokes = [boundPaint(v("Sous Color", spec.stroke))];
      c.strokeAlign = "INSIDE";
      c.setBoundVariable("strokeWeight", v("Sous Border", "border/hairline"));
    } else {
      c.strokes = [];
    }
    for (const k of ["topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius"]) {
      c.setBoundVariable(k, v("Sous Border", "radius/square"));
    }
    const base = await loadIconFont();
    const font = { family: base.family, style: spec.weight };
    let use = font;
    try { await figma.loadFontAsync(font); } catch (e) { use = base; }
    const icon = figma.createText();
    icon.name = "icon";
    icon.fontName = use;
    icon.characters = sfSymbol(spec.symbol);
    icon.setBoundVariable("fontSize", v("Sous Icon Sizes", spec.iconSize));
    icon.fills = [boundPaint(v("Sous Color", spec.icon))];
    c.appendChild(icon);
    icon.textAutoResize = "NONE";
    icon.layoutSizingHorizontal = "FIXED";
    icon.layoutSizingVertical = "FIXED";
    icon.resize(spec.size, spec.size);
    icon.textAlignHorizontal = "CENTER";
    icon.textAlignVertical = "CENTER";
    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Icon Button";
  set.description =
    "Square icon button. Accent = the 44pt burgundy hamburger that opens the history drawer. " +
    "Inverse = the drawer's settings button, same size on the ink fill. Bordered = the 32pt " +
    "outlined button used in the chat sheet header.\n\n" +
    "Swift: HistoryDrawer hamburger and settings buttons; SousIconButton(systemName:action:). " +
    "To change the symbol, edit the icon layer's text — glyphs come from design/sf-symbols.json.";

  const PAD = 32, GAP = 32, cell = { w: 44, h: 44 };
  layoutGrid(set, (c) => ICON_BUTTON_STYLES.findIndex((sp) => "Style=" + sp.style === c.name), () => 0,
    cell, PAD, GAP, ICON_BUTTON_STYLES.length, 1);
  const doc = await docPanel(page, v, "Icon Button", [
    ["Sous/Body",
      "Square, never round. The burgundy one sits at the top-left of the recipe canvas and opens the history drawer; it hides as you scroll down and returns when you scroll up. The ink one is the settings button inside that drawer. The small bordered one is used in the chat sheet header.",
      "text/primary", "description"],
    ["Sous/Body",
      "Filled buttons are 44pt — the minimum comfortable tap target. The bordered one is 32pt because it sits in a header row, not under a thumb.",
      "text/primary", "usage"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, ICON_BUTTON_STYLES.map((s) => s.style), [], cell, PAD, GAP, "iconbtn");
  COMPONENT_LOG.push("Icon Button (" + set.children.length + " variants)");
}

async function verifyIconButton() {
  const page = figma.root.children.find((p) => p.name === "Icon Button");
  if (!page) return check("component Icon Button", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Icon Button");
  if (!set) return check("component Icon Button", false, "component set missing");
  check("Icon Button variant count", set.children.length === ICON_BUTTON_STYLES.length, String(set.children.length));
  for (const spec of ICON_BUTTON_STYLES) {
    const c = set.children.find((x) => x.name === "Style=" + spec.style);
    if (!c) { check("Icon Button " + spec.style, false, "missing"); continue; }
    const t = "Icon Button " + spec.style;
    check(t + " size", c.width === spec.size && c.height === spec.size, c.width + "x" + c.height);
    check(t + " fill", (c.fills.length ? await varNameOf(c.fills[0]) : null) === spec.fill);
    check(t + " border", (c.strokes.length ? await varNameOf(c.strokes[0]) : null) === spec.stroke);
    const icon = c.findOne((x) => x.name === "icon");
    check(t + " icon color", icon && (await varNameOf(icon.fills[0])) === spec.icon);
    check(t + " glyph", !!icon && icon.characters.length > 0, JSON.stringify(icon && icon.characters));
  }
}

// -------------------------------------------------------- Recipe Title block
//
// Source: RecipeCanvasView header. The title is UPPERCASED by the view
// (recipe.title.uppercased()), centred, New York 28. Side padding is 76pt so the
// title clears the 44pt hamburger. The servings chip sits lower-right in burgundy,
// and a divider closes the block.

const TITLE_SPECS = [
  { name: "Servings=Yes", servings: true },
  { name: "Servings=No", servings: false },
];

async function buildRecipeTitle() {
  const page = await ensurePage("Recipe Title");
  const owned = ["Recipe Title / Documentation"].concat(TITLE_SPECS.map((s) => "title/col/" + s.name));
  if (!(await clearOwned(page, "Recipe Title", owned))) return;
  const v = await colorVars();
  const accent = v("Sous Color", "text/accent");

  const comps = [];
  for (const spec of TITLE_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "VERTICAL";
    c.resize(ROW_W, 100);
    c.primaryAxisSizingMode = "AUTO";
    c.counterAxisSizingMode = "FIXED";
    c.itemSpacing = 0;
    c.fills = [];

    const titleWrap = autoLayout("VERTICAL");
    titleWrap.name = "title-block";
    titleWrap.paddingLeft = 76;   // clears the 44pt hamburger at 16pt inset
    titleWrap.paddingRight = 76;
    titleWrap.paddingTop = 20;
    titleWrap.paddingBottom = spec.servings ? 10 : 16;
    c.appendChild(titleWrap);
    titleWrap.layoutSizingHorizontal = "FILL";
    const title = await textNode("Sous/Title", "SEARED CHICKEN THIGHS WITH LEMON",
      v("Sous Color", "text/primary"), "title");
    titleWrap.appendChild(title);
    title.layoutSizingHorizontal = "FILL";
    title.textAutoResize = "HEIGHT";
    title.textAlignHorizontal = "CENTER";

    const chipRow = hFrame("servings-row");
    chipRow.primaryAxisAlignItems = "MAX";
    chipRow.counterAxisAlignItems = "CENTER";
    bindPadding(chipRow, v, { left: "space/gutter", right: "space/gutter" });
    chipRow.paddingBottom = 14;
    c.appendChild(chipRow);
    chipRow.layoutSizingHorizontal = "FILL";
    const chip = hFrame("servings");
    chip.itemSpacing = 5;           // HStack(spacing: 5)
    chip.counterAxisAlignItems = "CENTER";
    chipRow.appendChild(chip);
    const people = figma.createText();
    people.name = "servings-icon";
    people.fontName = await loadIconFont();
    people.characters = sfSymbol("person.2");
    people.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
    people.fills = [boundPaint(accent)];
    chip.appendChild(people);
    const serves = await textNode("Sous/Section Header", "SERVES 4", accent, "servings-label");
    chip.appendChild(serves);
    chipRow.visible = spec.servings;

    const rule = hFrame("divider");
    c.appendChild(rule);
    rule.layoutSizingHorizontal = "FILL";
    const hair = figma.createRectangle();
    hair.name = "hairline";
    hair.resize(ROW_W, 1);
    hair.fills = [boundPaint(v("Sous Color", "border/subtle"))];
    rule.appendChild(hair);
    hair.layoutSizingHorizontal = "FILL";

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Recipe Title";
  set.description =
    "The head of the recipe canvas: the title in New York, centred and ALL CAPS, with the " +
    "servings chip lower-right and a divider beneath. Side padding is 76pt so the title clears " +
    "the hamburger button.\n\n" +
    "Swift: RecipeCanvasView header — the view uppercases recipe.title itself. Tapping the " +
    "title edits it; tapping the chip opens the servings picker.";
  const titleKey = set.addComponentProperty("Title", "TEXT", "SEARED CHICKEN THIGHS WITH LEMON");
  const servesKey = set.addComponentProperty("Servings", "TEXT", "SERVES 4");
  for (const variant of set.children) {
    variant.findOne((x) => x.name === "title").componentPropertyReferences = { characters: titleKey };
    variant.findOne((x) => x.name === "servings-label").componentPropertyReferences = { characters: servesKey };
  }
  const PAD = 32, GAP = 32, cell = { w: ROW_W, h: 150 };
  layoutGrid(set, (c) => TITLE_SPECS.findIndex((sp) => sp.name === c.name), () => 0,
    cell, PAD, GAP, TITLE_SPECS.length, 1);
  const doc = await docPanel(page, v, "Recipe Title", [
    ["Sous/Body",
      "The top of every recipe. The title is set in New York and centred, in capitals — the view uppercases whatever the recipe is called. The servings chip sits lower-right in burgundy and opens the servings picker; recipes without a serving count simply omit it.",
      "text/primary", "description"],
    ["Sous/Body",
      "The 76pt side padding is not decorative: it keeps a long title clear of the hamburger button in the corner. The divider below belongs to this block, not to the first ingredient row.",
      "text/primary", "usage"],
    ["Sous/Body",
      "Design spec note: the spec described a burgundy navigation bar with three icons across the top. The app has no such bar — it has the hamburger button and this title block. The spec has been corrected.",
      "text/muted", "code-debt"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, TITLE_SPECS.map((s) => s.name.replace("Servings=", "Servings ")), [],
    cell, PAD, GAP, "title");
  COMPONENT_LOG.push("Recipe Title (" + set.children.length + " variants)");
}

async function verifyRecipeTitle() {
  const page = figma.root.children.find((p) => p.name === "Recipe Title");
  if (!page) return check("component Recipe Title", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Recipe Title");
  if (!set) return check("component Recipe Title", false, "component set missing");
  check("Recipe Title variant count", set.children.length === TITLE_SPECS.length, String(set.children.length));
  for (const spec of TITLE_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Recipe Title " + spec.name, false, "missing"); continue; }
    const t = "Recipe Title " + spec.name;
    const title = c.findOne((x) => x.name === "title");
    check(t + " uses the New York title style", title.fontName.family === "New York" || title.fontName.family === "Inter",
      title.fontName.family);
    check(t + " title is centred and capitals",
      title.textAlignHorizontal === "CENTER" && title.characters === title.characters.toUpperCase(),
      title.textAlignHorizontal + " / " + title.characters);
    check(t + " clears the hamburger", c.findOne((x) => x.name === "title-block").paddingLeft === 76);
    const chipRow = c.findOne((x) => x.name === "servings-row");
    check(t + " servings row shown only when it has servings", chipRow.visible === spec.servings);
    const label = c.findOne((x) => x.name === "servings-label");
    check(t + " servings chip is burgundy", (await varNameOf(label.fills[0])) === "text/accent");
    const hair = c.findOne((x) => x.name === "hairline");
    check(t + " divider", hair && (await varNameOf(hair.fills[0])) === "border/subtle");
  }
}

// ------------------------------------------------------------ screen helpers

const CANVAS_W_ = 393;   // kept in step with CANVAS_W below

// Reserve what the phone owns. Guides, not chrome: neutral grey so nobody reads
// them as part of the design, and labelled so nobody mistakes them for a bar.
async function systemGuide(screen, v, name, y, h, label) {
  const g = figma.createFrame();
  g.name = name;
  g.resize(screen.width, h);
  g.fills = [];
  g.layoutMode = "HORIZONTAL";
  g.primaryAxisAlignItems = "CENTER";
  g.counterAxisAlignItems = "CENTER";
  g.primaryAxisSizingMode = "FIXED";
  g.counterAxisSizingMode = "FIXED";
  screen.appendChild(g);
  g.x = 0; g.y = y;
  const tint = figma.createRectangle();
  tint.name = name + "-tint";
  tint.resize(screen.width, h);
  tint.fills = [boundPaint(v("Sous Color", "text/muted"))];
  tint.opacity = 0.12;   // layer opacity: paint opacity is ignored on a bound colour
  g.appendChild(tint);
  tint.layoutPositioning = "ABSOLUTE";
  tint.x = 0; tint.y = 0;
  const t = await textNode("Sous/Caption", label, v("Sous Color", "text/muted"), name + "-label");
  g.appendChild(t);
  return g;
}

async function safeAreaGuides(screen, v) {
  const make = (name, y, h, label) => systemGuide(screen, v, name, y, h, label);
  await make("safe-area/top", 0, SAFE_TOP, "STATUS BAR — KEEP CLEAR (59)");
  await make("safe-area/bottom", screen.height - SAFE_BOTTOM, SAFE_BOTTOM, "HOME INDICATOR — KEEP CLEAR (34)");
}

// A full-width 1pt rule, as SousRule() draws it.
function hairlineRow(v, name) {
  const row = hFrame(name);
  const hair = figma.createRectangle();
  hair.name = name + "-hairline";
  hair.resize(ROW_W, 1);
  hair.fills = [boundPaint(v("Sous Color", "border/subtle"))];
  row.appendChild(hair);
  return { row, hair };
}

async function newScreen(page, name, fillToken, v) {
  for (const n of page.children.filter((x) => x.name === name)) n.remove();
  const screen = figma.createFrame();
  screen.name = name;
  screen.resize(CANVAS_W, CANVAS_H);
  screen.fills = [boundPaint(v("Sous Color", fillToken))];
  screen.clipsContent = true;
  page.appendChild(screen);
  return screen;
}

// ---------------------------------------------------------------- Bottom Bar
//
// Source: WindowButtonHost. A 1pt rule, then TALK TO SOUS and — when voice is
// available — a 60x52 mic button separated by a hairline of white at 25%, padded
// 20 sides and 12 top/bottom over the canvas colour, then a muted chevron hint
// for the ThumbDrop gesture. Voice is hidden during trial and soft-wall states.

const BOTTOM_BAR_SPECS = [
  { name: "Voice=Yes", voice: true },
  { name: "Voice=No", voice: false },
];

async function buildBottomBar() {
  const page = await ensurePage("Bottom Bar");
  const owned = ["Bottom Bar / Documentation"].concat(BOTTOM_BAR_SPECS.map((s) => "bottombar/col/" + s.name));
  if (!(await clearOwned(page, "Bottom Bar", owned))) return;
  const v = await colorVars();
  const ctaVariant = await getVariant("Button", "Button", "Style=Primary, State=Default");
  const btnSet = ctaVariant.parent;
  await figma.setCurrentPageAsync(page);
  const iconFont = await loadIconFont();
  let micFont = { family: iconFont.family, style: "Semibold" };
  try { await figma.loadFontAsync(micFont); } catch (e) { micFont = iconFont; }

  const comps = [];
  for (const spec of BOTTOM_BAR_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "VERTICAL";
    c.resize(ROW_W, 100);
    c.primaryAxisSizingMode = "AUTO";
    c.counterAxisSizingMode = "FIXED";
    c.itemSpacing = 0;
    c.fills = [boundPaint(v("Sous Color", "background/canvas"))];

    const rule = hFrame("rule");
    c.appendChild(rule);
    rule.layoutSizingHorizontal = "FILL";
    const hair = figma.createRectangle();
    hair.name = "hairline";
    hair.resize(ROW_W, 1);
    hair.fills = [boundPaint(v("Sous Color", "border/subtle"))];
    rule.appendChild(hair);
    hair.layoutSizingHorizontal = "FILL";

    const row = hFrame("buttons");
    row.itemSpacing = 0;                       // HStack(spacing: 0)
    row.counterAxisAlignItems = "CENTER";
    bindPadding(row, v, { left: "space/gutter", right: "space/gutter", top: "space/md", bottom: "space/md" });
    c.appendChild(row);
    row.layoutSizingHorizontal = "FILL";

    const cta = ctaVariant.createInstance();
    cta.name = "cta";
    row.appendChild(cta);
    cta.layoutSizingHorizontal = "FILL";
    cta.setProperties({ [propKey(btnSet, "Label")]: "TALK TO SOUS", [propKey(btnSet, "Icon")]: true });

    if (spec.voice) {
      const divider = figma.createRectangle();
      divider.name = "mic-divider";
      divider.resize(1, 52);
      divider.fills = [boundPaint(v("Sous Color", "text/onInverse"), 0.25)];  // white at 25%
      row.appendChild(divider);

      const mic = figma.createFrame();
      mic.name = "mic";
      mic.layoutMode = "HORIZONTAL";
      mic.primaryAxisAlignItems = "CENTER";
      mic.counterAxisAlignItems = "CENTER";
      mic.resize(60, 52);                      // .frame(width: 60, height: 52)
      mic.primaryAxisSizingMode = "FIXED";
      mic.counterAxisSizingMode = "FIXED";
      mic.fills = [boundPaint(v("Sous Color", "accent/primary"))];
      row.appendChild(mic);
      const micIcon = figma.createText();
      micIcon.name = "mic-icon";
      micIcon.fontName = micFont;
      micIcon.characters = sfSymbol("mic.fill");
      micIcon.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/large"));
      micIcon.fills = [boundPaint(v("Sous Color", "text/onInverse"))];
      mic.appendChild(micIcon);
      micIcon.textAutoResize = "NONE";
      micIcon.layoutSizingHorizontal = "FIXED";
      micIcon.layoutSizingVertical = "FIXED";
      micIcon.resize(60, 52);
      micIcon.textAlignHorizontal = "CENTER";
      micIcon.textAlignVertical = "CENTER";
    }

    const hintRow = hFrame("hint");
    hintRow.primaryAxisAlignItems = "CENTER";
    hintRow.paddingBottom = 8;                 // .padding(.bottom, 8)
    c.appendChild(hintRow);
    hintRow.layoutSizingHorizontal = "FILL";
    const chevron = figma.createText();
    chevron.name = "chevron";
    chevron.fontName = iconFont;
    chevron.characters = sfSymbol("chevron.down");
    chevron.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
    chevron.fills = [boundPaint(v("Sous Color", "text/muted"))];
    hintRow.appendChild(chevron);

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Bottom Bar";
  set.description =
    "The bar pinned to the bottom of cook mode: TALK TO SOUS, the mic button when voice is " +
    "available, and a muted chevron hinting that the bar can be pulled down (ThumbDrop). " +
    "Voice=No is what trial and soft-wall users see.\n\n" +
    "Swift: WindowButtonHost. Running timers stack above this bar.";
  const PAD = 32, GAP = 32, cell = { w: ROW_W, h: 110 };
  layoutGrid(set, (c) => BOTTOM_BAR_SPECS.findIndex((sp) => sp.name === c.name), () => 0,
    cell, PAD, GAP, BOTTOM_BAR_SPECS.length, 1);
  const doc = await docPanel(page, v, "Bottom Bar", [
    ["Sous/Body",
      "Always within thumb reach at the bottom of cook mode. TALK TO SOUS opens the chat; the mic opens voice mode. The two sit flush with a hairline between them, and the chevron underneath hints that you can pull the bar down out of the way.",
      "text/primary", "description"],
    ["Sous/Body",
      "Voice=No is not a disabled state — the mic is absent entirely for trial and soft-wall users. Running timers stack directly above this bar.",
      "text/primary", "usage"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, BOTTOM_BAR_SPECS.map((s) => s.name.replace("Voice=", "Voice ")), [],
    cell, PAD, GAP, "bottombar");
  COMPONENT_LOG.push("Bottom Bar (" + set.children.length + " variants)");
}

async function verifyBottomBar() {
  const page = figma.root.children.find((p) => p.name === "Bottom Bar");
  if (!page) return check("component Bottom Bar", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Bottom Bar");
  if (!set) return check("component Bottom Bar", false, "component set missing");
  check("Bottom Bar variant count", set.children.length === BOTTOM_BAR_SPECS.length, String(set.children.length));
  for (const spec of BOTTOM_BAR_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Bottom Bar " + spec.name, false, "missing"); continue; }
    const t = "Bottom Bar " + spec.name;
    const cta = c.findOne((x) => x.name === "cta");
    const main = cta && (await cta.getMainComponentAsync());
    check(t + " uses the Button component", !!main && main.name === "Style=Primary, State=Default",
      main ? main.name : "none");
    const mic = c.findOne((x) => x.name === "mic");
    check(t + " mic present only with voice", !!mic === spec.voice);
    if (mic) check(t + " mic is 60x52", mic.width === 60 && mic.height === 52, mic.width + "x" + mic.height);
    check(t + " has the chevron hint", !!c.findOne((x) => x.name === "chevron"));
    check(t + " sits on the canvas colour", (await varNameOf(c.fills[0])) === "background/canvas");
  }
}

// --------------------------------------------------------------- Chat Bubble
//
// Source: ChatBubbleView. A user message is an ink-filled bubble with cream text;
// an assistant message sits on the canvas colour with ink text. Both carry a 1pt
// ink border, 12pt side / 8pt vertical padding, and leave at least 48pt on the
// opposite side. (The design spec claimed a pale burgundy user bubble — wrong.)

const BUBBLE_SPECS = [
  { name: "Role=User", fill: "background/inverse", text: "text/inverse", align: "MAX" },
  { name: "Role=Assistant", fill: "background/canvas", text: "text/primary", align: "MIN" },
];
const BUBBLE_MAX_W = 313;   // 393 - 2x16 transcript padding - 48 minimum gutter

async function buildChatBubble() {
  const page = await ensurePage("Chat Bubble");
  const owned = ["Chat Bubble / Documentation"].concat(BUBBLE_SPECS.map((b) => "bubble/col/" + b.name));
  if (!(await clearOwned(page, "Chat Bubble", owned))) return;
  const v = await colorVars();
  const comps = [];
  for (const spec of BUBBLE_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "HORIZONTAL";
    c.primaryAxisAlignItems = spec.align;
    c.resize(ROW_W - 32, 40);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "AUTO";
    c.fills = [];

    const bubble = autoLayout("VERTICAL");
    bubble.name = "bubble";
    bindPadding(bubble, v, { left: "space/md", right: "space/md", top: "space/sm", bottom: "space/sm" });
    bubble.fills = [boundPaint(v("Sous Color", spec.fill))];
    bubble.strokes = [boundPaint(v("Sous Color", "border/strong"))];
    bubble.strokeAlign = "INSIDE";
    bubble.setBoundVariable("strokeWeight", v("Sous Border", "border/hairline"));
    c.appendChild(bubble);
    bubble.resize(Math.min(BUBBLE_MAX_W, ROW_W - 32), bubble.height);
    bubble.layoutSizingHorizontal = "FIXED";

    const text = await textNode("Sous/Body",
      spec.name === "Role=User" ? "Can I use thighs instead of breasts?"
                                : "Yes — thighs stay juicier and take a few minutes longer. Sear them skin-side down first.",
      v("Sous Color", spec.text), "text");
    bubble.appendChild(text);
    text.layoutSizingHorizontal = "FILL";
    text.textAutoResize = "HEIGHT";

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Chat Bubble";
  set.description =
    "A message in the chat transcript. User messages are ink-filled with cream text and sit to " +
    "the right; Sous's replies sit on the canvas colour to the left and render Markdown. Both " +
    "keep a 1pt ink border and leave at least 48pt on the opposite side.\n\n" +
    "Swift: ChatBubbleView. Assistant text goes through MarkdownTextView.";
  const PAD = 32, GAP = 24, cell = { w: ROW_W - 32, h: 80 };
  layoutGrid(set, () => 0, (c) => BUBBLE_SPECS.findIndex((b) => b.name === c.name),
    cell, PAD, GAP, 1, BUBBLE_SPECS.length);
  const doc = await docPanel(page, v, "Chat Bubble", [
    ["Sous/Body",
      "The two sides of the conversation. Yours is a solid ink block with cream text, right-aligned; Sous's is an outlined block on the page colour, left-aligned, and can contain Markdown — bold, italics, bullet and numbered lists.",
      "text/primary", "description"],
    ["Sous/Body",
      "Neither bubble is rounded, and neither uses burgundy: the accent is reserved for actions. The 48pt gutter on the opposite side is what makes the conversation readable at a glance.",
      "text/primary", "usage"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], BUBBLE_SPECS.map((b) => b.name.replace("Role=", "")),
    cell, PAD, GAP, "bubble");
  COMPONENT_LOG.push("Chat Bubble (" + set.children.length + " variants)");
}

async function verifyChatBubble() {
  const page = figma.root.children.find((p) => p.name === "Chat Bubble");
  if (!page) return check("component Chat Bubble", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Chat Bubble");
  if (!set) return check("component Chat Bubble", false, "component set missing");
  check("Chat Bubble variant count", set.children.length === BUBBLE_SPECS.length, String(set.children.length));
  for (const spec of BUBBLE_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Chat Bubble " + spec.name, false, "missing"); continue; }
    const b = c.findOne((x) => x.name === "bubble");
    const t = c.findOne((x) => x.name === "text");
    check("Chat Bubble " + spec.name + " fill", (await varNameOf(b.fills[0])) === spec.fill);
    check("Chat Bubble " + spec.name + " text colour", (await varNameOf(t.fills[0])) === spec.text);
    check("Chat Bubble " + spec.name + " border", (await varNameOf(b.strokes[0])) === "border/strong");
    check("Chat Bubble " + spec.name + " alignment", c.primaryAxisAlignItems === spec.align, c.primaryAxisAlignItems);
    check("Chat Bubble " + spec.name + " leaves a gutter", b.width <= BUBBLE_MAX_W, String(b.width));
  }
}

// -------------------------------------------------------------- Composer Bar
//
// Source: ChatSheetView.composerBar — camera button, the bordered field on the
// surface colour, and the send button, all 44pt, padded 16 sides / 10 vertical.
// Send inverts when it can fire and goes muted when it cannot.

const COMPOSER_SPECS = [
  { name: "Send=Enabled", enabled: true },
  { name: "Send=Disabled", enabled: false },
];

async function buildComposerBar() {
  const page = await ensurePage("Composer Bar");
  const owned = ["Composer Bar / Documentation"].concat(COMPOSER_SPECS.map((c) => "composer/col/" + c.name));
  if (!(await clearOwned(page, "Composer Bar", owned))) return;
  const v = await colorVars();
  const iconFont = await loadIconFont();

  const squareButton = async (name, symbol, iconToken, fillToken, strokeToken) => {
    const b = figma.createFrame();
    b.name = name;
    b.layoutMode = "HORIZONTAL";
    b.primaryAxisAlignItems = "CENTER";
    b.counterAxisAlignItems = "CENTER";
    b.resize(44, 44);
    b.primaryAxisSizingMode = "FIXED";
    b.counterAxisSizingMode = "FIXED";
    b.fills = fillToken ? [boundPaint(v("Sous Color", fillToken))] : [];
    b.strokes = [boundPaint(v("Sous Color", strokeToken))];
    b.strokeAlign = "INSIDE";
    b.setBoundVariable("strokeWeight", v("Sous Border", "border/hairline"));
    const i = figma.createText();
    i.name = name + "-icon";
    i.fontName = iconFont;
    i.characters = sfSymbol(symbol);
    i.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/large"));
    i.fills = [boundPaint(v("Sous Color", iconToken))];
    b.appendChild(i);
    i.textAutoResize = "NONE";
    i.layoutSizingHorizontal = "FIXED";
    i.layoutSizingVertical = "FIXED";
    i.resize(44, 44);
    i.textAlignHorizontal = "CENTER";
    i.textAlignVertical = "CENTER";
    return b;
  };

  const comps = [];
  for (const spec of COMPOSER_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "VERTICAL";
    c.itemSpacing = 0;
    c.resize(ROW_W, 65);
    c.primaryAxisSizingMode = "AUTO";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [boundPaint(v("Sous Color", "background/surface"))];

    // SousRule() above the composer — the transcript scrolls up to this line.
    const top = hairlineRow(v, "rule");
    c.appendChild(top.row);
    top.row.layoutSizingHorizontal = "FILL";
    top.hair.layoutSizingHorizontal = "FILL";

    const row = hFrame("row");
    row.counterAxisAlignItems = "MAX";        // HStack(alignment: .bottom)
    row.setBoundVariable("itemSpacing", v("Sous Spacing", "space/sm"));
    bindPadding(row, v, { left: "space/lg", right: "space/lg", top: 10, bottom: 10 });
    c.appendChild(row);
    row.layoutSizingHorizontal = "FILL";

    row.appendChild(await squareButton("camera", "camera", "text/primary", null, "border/strong"));

    const field = autoLayout("HORIZONTAL");
    field.name = "field";
    // The text needs room from the field's border. The code pads 4 and relies on
    // the text view's own inset; 8 side / 4 vertical matches what the app renders.
    field.setBoundVariable("paddingLeft", v("Sous Spacing", "space/sm"));
    field.setBoundVariable("paddingRight", v("Sous Spacing", "space/sm"));
    field.paddingTop = field.paddingBottom = 4;
    field.counterAxisAlignItems = "CENTER";
    field.fills = [boundPaint(v("Sous Color", "background/surface"))];
    field.strokes = [boundPaint(v("Sous Color", "border/strong"))];
    field.strokeAlign = "INSIDE";
    field.setBoundVariable("strokeWeight", v("Sous Border", "border/hairline"));
    row.appendChild(field);
    field.layoutSizingHorizontal = "FILL";
    field.resize(field.width, 44);
    field.layoutSizingVertical = "FIXED";
    const placeholder = await textNode("Sous/Body",
      spec.enabled ? "Can I use thighs instead?" : "Ask Sous…",
      v("Sous Color", spec.enabled ? "text/primary" : "text/muted"), "input");
    field.appendChild(placeholder);
    placeholder.layoutSizingHorizontal = "FILL";
    placeholder.textAutoResize = "HEIGHT";

    row.appendChild(await squareButton("send", "paperplane.fill",
      spec.enabled ? "text/inverse" : "text/muted",
      spec.enabled ? "background/inverse" : null,
      spec.enabled ? "border/strong" : "text/muted"));

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Composer Bar";
  set.description =
    "The chat input: camera, the bordered field, and send. Send fills with ink when there is " +
    "something to send and goes muted when there is not — it is never hidden.\n\n" +
    "Swift: ChatSheetView.composerBar. Dragging this bar down closes the sheet (ThumbDrop).";
  const PAD = 32, GAP = 24, cell = { w: ROW_W, h: 70 };
  layoutGrid(set, () => 0, (c) => COMPOSER_SPECS.findIndex((sp) => sp.name === c.name),
    cell, PAD, GAP, 1, COMPOSER_SPECS.length);
  const doc = await docPanel(page, v, "Composer Bar", [
    ["Sous/Body",
      "Where you talk to Sous. The camera adds a photo of a recipe or an ingredient; the field grows with what you type; send inverts to solid ink once there is something to send.",
      "text/primary", "description"],
    ["Sous/Body",
      "All three parts are 44pt tall — thumb-sized. Disabled send keeps its place rather than disappearing, so the bar never shifts under your finger.",
      "text/primary", "usage"],

  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], COMPOSER_SPECS.map((c) => c.name.replace("Send=", "Send ")),
    cell, PAD, GAP, "composer");
  COMPONENT_LOG.push("Composer Bar (" + set.children.length + " variants)");
}

async function verifyComposerBar() {
  const page = figma.root.children.find((p) => p.name === "Composer Bar");
  if (!page) return check("component Composer Bar", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Composer Bar");
  if (!set) return check("component Composer Bar", false, "component set missing");
  check("Composer Bar variant count", set.children.length === COMPOSER_SPECS.length, String(set.children.length));
  for (const spec of COMPOSER_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Composer Bar " + spec.name, false, "missing"); continue; }
    const t = "Composer Bar " + spec.name;
    const send = c.findOne((x) => x.name === "send");
    const cam = c.findOne((x) => x.name === "camera");
    check(t + " send fill", (send.fills.length ? await varNameOf(send.fills[0]) : null) ===
      (spec.enabled ? "background/inverse" : null));
    check(t + " send border", (await varNameOf(send.strokes[0])) === (spec.enabled ? "border/strong" : "text/muted"));
    check(t + " buttons are 44pt", cam.width === 44 && cam.height === 44 && send.width === 44,
      cam.width + "/" + send.width);
    check(t + " sits on the sheet surface", (await varNameOf(c.fills[0])) === "background/surface");
    const field = c.findOne((x) => x.name === "field");
    check(t + " text has room inside the field", field && field.paddingLeft === 8, String(field && field.paddingLeft));
    const rule = c.findOne((x) => x.name === "rule-hairline");
    check(t + " has the rule above it", !!rule && (await varNameOf(rule.fills[0])) === "border/subtle");
  }
}

// --------------------------------------------------------------- Chat Header
//
// Source: ChatSheetView.chatHeader. Fullscreen shows "SOUS" with new / recents /
// settings as bordered icon buttons; over a recipe it shows "SOUS SAYS…" and a
// burgundy CLOSE. Padded 32 sides, 14 vertical.

const CHAT_HEADER_SPECS = [
  { name: "Mode=Fullscreen", title: "SOUS", icons: ["plus", "clock", "gearshape"], rule: false },
  { name: "Mode=Over recipe", title: "SOUS SAYS…", icons: [], rule: true },
];

async function buildChatHeader() {
  const page = await ensurePage("Chat Header");
  const owned = ["Chat Header / Documentation"].concat(CHAT_HEADER_SPECS.map((c) => "chathdr/col/" + c.name));
  if (!(await clearOwned(page, "Chat Header", owned))) return;
  const v = await colorVars();
  const iconBtn = await getVariant("Icon Button", "Icon Button", "Style=Bordered");
  await figma.setCurrentPageAsync(page);
  const iconFont = await loadIconFont();

  const comps = [];
  for (const spec of CHAT_HEADER_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "VERTICAL";
    c.itemSpacing = 0;
    c.resize(ROW_W, 61);
    c.primaryAxisSizingMode = "AUTO";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [boundPaint(v("Sous Color", "background/surface"))];

    const row = hFrame("row");
    row.primaryAxisAlignItems = "SPACE_BETWEEN";
    row.counterAxisAlignItems = "CENTER";
    bindPadding(row, v, { left: "space/2xl", right: "space/2xl", top: 14, bottom: 14 });
    c.appendChild(row);
    row.layoutSizingHorizontal = "FILL";

    // Figma text layers carry the line's leading, so a hugging layer sits high
    // inside the bar. Pin the glyph box and centre it (device note, 2026-09-24).
    const centreInBar = (t) => {
      const w = t.width;
      t.textAutoResize = "NONE";
      t.resize(w, 20);
      t.textAlignVertical = "CENTER";
    };
    const title = await textNode("Sous/Button", spec.title, v("Sous Color", "text/primary"), "title");
    row.appendChild(title);
    centreInBar(title);

    if (spec.icons.length) {
      const group = hFrame("actions");
      group.setBoundVariable("itemSpacing", v("Sous Spacing", "space/sm"));
      group.counterAxisAlignItems = "CENTER";
      row.appendChild(group);
      for (const symbol of spec.icons) {
        const inst = iconBtn.createInstance();
        inst.name = symbol;
        group.appendChild(inst);
        const glyph = inst.findOne((x) => x.name === "icon");
        if (glyph) {
          await figma.loadFontAsync(glyph.fontName);
          glyph.characters = sfSymbol(symbol);
        }
      }
    } else {
      const close = await textNode("Sous/Button", "CLOSE", v("Sous Color", "text/accent"), "close");
      row.appendChild(close);
      centreInBar(close);
    }
    // SousRule() under the header — sheet mode only; fullscreen has no line.
    if (spec.rule) {
      const bottom = hairlineRow(v, "rule");
      c.appendChild(bottom.row);
      bottom.row.layoutSizingHorizontal = "FILL";
      bottom.hair.layoutSizingHorizontal = "FILL";
    }
    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Chat Header";
  set.description =
    "Top of the chat. Fullscreen (no recipe yet) shows SOUS with new recipe, recents and " +
    "settings. Over a recipe it shows SOUS SAYS… and CLOSE.\n\nSwift: ChatSheetView.chatHeader.";
  const PAD = 32, GAP = 24, cell = { w: ROW_W, h: 64 };
  layoutGrid(set, () => 0, (c) => CHAT_HEADER_SPECS.findIndex((sp) => sp.name === c.name),
    cell, PAD, GAP, 1, CHAT_HEADER_SPECS.length);
  const doc = await docPanel(page, v, "Chat Header", [
    ["Sous/Body",
      "Two headers for the same sheet. Before a recipe exists, chat is the whole screen and carries the app's controls. Once a recipe is on the canvas, chat becomes a sheet over it and only needs a way out.",
      "text/primary", "description"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], CHAT_HEADER_SPECS.map((c) => c.name.replace("Mode=", "")),
    cell, PAD, GAP, "chathdr");
  COMPONENT_LOG.push("Chat Header (" + set.children.length + " variants)");
}

async function verifyChatHeader() {
  const page = figma.root.children.find((p) => p.name === "Chat Header");
  if (!page) return check("component Chat Header", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Chat Header");
  if (!set) return check("component Chat Header", false, "component set missing");
  for (const spec of CHAT_HEADER_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Chat Header " + spec.name, false, "missing"); continue; }
    const t = "Chat Header " + spec.name;
    const titleNode = c.findOne((x) => x.name === "title");
    check(t + " title", titleNode.characters === spec.title);
    check(t + " title is vertically centred in the bar",
      titleNode.textAlignVertical === "CENTER" && titleNode.height === 20,
      titleNode.textAlignVertical + " / " + titleNode.height);
    const icons = c.findAll((x) => x.type === "INSTANCE");
    check(t + " icon buttons", icons.length === spec.icons.length, String(icons.length));
    if (!spec.icons.length) {
      const close = c.findOne((x) => x.name === "close");
      check(t + " CLOSE is burgundy", close && (await varNameOf(close.fills[0])) === "text/accent");
    }
    const rule = c.findOne((x) => x.name === "rule-hairline");
    check(t + " rule under the header only in sheet mode", !!rule === !!spec.rule);
  }
}

// --------------------------------------------------------------- Chat screen

async function buildChatScreen() {
  const page = await ensurePage("Screens");
  const v = await colorVars();
  const screen = await newScreen(page, "Chat", "background/canvas", v);
  screen.x = 40 + 600 + 120 + CANVAS_W + 80;
  screen.y = 40;

  // Chat is a SHEET over the recipe, not a full screen: it starts under the
  // status bar, and the transcript scrolls beneath the opaque header and composer.
  const sheet = figma.createFrame();
  sheet.name = "sheet";
  sheet.resize(CANVAS_W, CANVAS_H - SAFE_TOP);
  sheet.fills = [boundPaint(v("Sous Color", "background/surface"))];
  sheet.clipsContent = true;
  screen.appendChild(sheet);
  sheet.x = 0; sheet.y = SAFE_TOP;

  const header = (await getVariant("Chat Header", "Chat Header", "Mode=Over recipe")).createInstance();
  await figma.setCurrentPageAsync(page);
  header.name = "header";

  const transcript = autoLayout("VERTICAL");
  transcript.name = "transcript";
  transcript.setBoundVariable("itemSpacing", v("Sous Spacing", "space/sm"));
  bindPadding(transcript, v, { left: "space/lg", right: "space/lg", top: "space/md", bottom: "space/md" });
  transcript.fills = [];
  sheet.appendChild(transcript);          // added first so the header sits over it
  transcript.resize(CANVAS_W, transcript.height);

  const messages = [
    ["Role=Assistant", "…crumbled if you want the paste and sausage to really fuse; sliced if you want a prettier bowl with more bite."],
    ["Role=User", "Let's say sliced."],
    ["Role=Assistant", "Sliced is the move. You'll get good browning, better sauce flavour, and actual sausage pieces instead of meat confetti."],
    ["Role=User", "Perfect, thanks."],
    ["Role=Assistant", "Want me to fold that into the recipe, or keep it as a note for later?"],
    ["Role=User", "Fold it in."],
    ["Role=Assistant", "Done — step 2 now says sliced, and I've added a minute to the browning."],
  ];
  for (const [variant, text] of messages) {
    const b = (await getVariant("Chat Bubble", "Chat Bubble", variant)).createInstance();
    await figma.setCurrentPageAsync(page);
    transcript.appendChild(b);
    b.layoutSizingHorizontal = "FILL";
    const t = b.findOne((x) => x.name === "text");
    for (const f of t.getRangeAllFontNames(0, t.characters.length)) await figma.loadFontAsync(f);
    t.characters = text;
  }

  const composer = (await getVariant("Composer Bar", "Composer Bar", "Send=Enabled")).createInstance();
  await figma.setCurrentPageAsync(page);
  composer.name = "composer";
  sheet.appendChild(composer);            // opaque: the transcript runs under it
  composer.resize(CANVAS_W, composer.height);

  sheet.appendChild(header);              // last = on top of the transcript
  header.resize(CANVAS_W, header.height);
  header.x = 0; header.y = 0;

  // The keyboard is usually up in chat; reserve it like any other system space.
  const KEYBOARD_H = 336;
  const keyboardTop = CANVAS_H - KEYBOARD_H;
  composer.x = 0;
  composer.y = keyboardTop - SAFE_TOP - composer.height;

  // Scroll the transcript so the oldest message is cut off behind the header,
  // the way it looks mid-conversation.
  transcript.x = 0;
  transcript.y = composer.y - transcript.height + 24;

  await systemGuide(screen, v, "keyboard", keyboardTop, KEYBOARD_H - SAFE_BOTTOM, "KEYBOARD — SYSTEM (336)");
  await safeAreaGuides(screen, v);
  COMPONENT_LOG.push("Chat screen");
}

async function verifyChatScreen() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Chat screen", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Chat");
  if (!screen) return check("Chat screen", false, "missing");
  check("Chat screen is iPhone-sized", screen.width === CANVAS_W && screen.height === CANVAS_H,
    screen.width + "x" + screen.height);
  check("Chat screen shows the canvas behind the sheet",
    (await varNameOf(screen.fills[0])) === "background/canvas");
  const sheetFill = screen.children.find((x) => x.name === "sheet");
  check("the sheet itself is the surface colour",
    !!sheetFill && (await varNameOf(sheetFill.fills[0])) === "background/surface");
  const insts = screen.findAll((n) => n.type === "INSTANCE");
  const names = [];
  for (const i of insts) {
    const m = await i.getMainComponentAsync();
    names.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("chat screen is built from components", !names.includes("detached"), names.join(", "));
  check("chat screen has 7 bubbles, a header and a composer",
    names.filter((n) => n === "Chat Bubble").length === 7 &&
    names.filter((n) => n === "Chat Header").length === 1 &&
    names.filter((n) => n === "Composer Bar").length === 1, names.join(", "));
  const sheet = screen.children.find((x) => x.name === "sheet");
  check("chat is a sheet starting below the status bar",
    !!sheet && sheet.y === SAFE_TOP && sheet.clipsContent === true, sheet ? String(sheet.y) : "missing");
  const header = sheet && sheet.children.find((x) => x.name === "header");
  const composer = sheet && sheet.children.find((x) => x.name === "composer");
  const transcript = sheet && sheet.children.find((x) => x.name === "transcript");
  check("the header is the sheet one, without the three buttons",
    !!header && header.findAll((x) => x.type === "INSTANCE").length === 0,
    header ? String(header.findAll((x) => x.type === "INSTANCE").length) : "missing");
  check("header and composer sit above the transcript, which scrolls under them",
    !!transcript && sheet.children.indexOf(transcript) < sheet.children.indexOf(composer) &&
    sheet.children.indexOf(transcript) < sheet.children.indexOf(header));
  check("the transcript is anchored to the composer, running up under the header",
    !!transcript && Math.round(transcript.y + transcript.height) === Math.round(composer.y + 24),
    transcript ? transcript.y + transcript.height + " vs " + (composer.y + 24) : "missing");
  const keyboard = screen.children.find((x) => x.name === "keyboard");
  check("the keyboard space is reserved", !!keyboard && keyboard.y === CANVAS_H - 336,
    keyboard ? String(keyboard.y) : "missing");
  check("the composer sits directly above the keyboard",
    !!composer && Math.round(composer.y + composer.height + SAFE_TOP) === CANVAS_H - 336,
    composer ? String(composer.y + composer.height + SAFE_TOP) : "missing");
  for (const name of ["safe-area/top", "safe-area/bottom"]) {
    check("chat screen reserves " + name, !!screen.children.find((x) => x.name === name));
  }
}

// ------------------------------------------------------------------ Wordmark
//
// Source: ChatSheetView.blankStateView (SOUS + tagline, 10pt apart) and
// HistoryDrawer's header, which uses the wordmark alone.

const WORDMARK_SPECS = [
  { name: "Tagline=Yes", tagline: true },
  { name: "Tagline=No", tagline: false },
];

async function buildWordmark() {
  const page = await ensurePage("Wordmark");
  const owned = ["Wordmark / Documentation"].concat(WORDMARK_SPECS.map((w) => "wordmark/col/" + w.name));
  if (!(await clearOwned(page, "Wordmark", owned))) return;
  const v = await colorVars();
  const comps = [];
  for (const spec of WORDMARK_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "VERTICAL";
    c.primaryAxisAlignItems = "CENTER";
    c.counterAxisAlignItems = "CENTER";
    c.itemSpacing = 10;                      // VStack(spacing: 10)
    c.resize(ROW_W, 60);
    c.primaryAxisSizingMode = "AUTO";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [];
    const mark = await textNode("Sous/Logotype", "SOUS", v("Sous Color", "text/primary"), "wordmark");
    c.appendChild(mark);
    mark.textAlignHorizontal = "CENTER";
    if (spec.tagline) {
      const tag = await textNode("Sous/Caption", "YOUR COOKING COMPANION",
        v("Sous Color", "text/muted"), "tagline");
      c.appendChild(tag);
      tag.textAlignHorizontal = "CENTER";
      tag.letterSpacing = { value: 1.2, unit: "PIXELS" };
    }
    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Wordmark";
  set.description =
    "SOUS in New York, with or without the tagline. With tagline: the blank state. Without: the " +
    "history drawer header.\n\nSwift: ChatSheetView.blankStateView, HistoryDrawer header.";
  const PAD = 32, GAP = 32, cell = { w: ROW_W, h: 80 };
  layoutGrid(set, (c) => WORDMARK_SPECS.findIndex((w) => w.name === c.name), () => 0,
    cell, PAD, GAP, WORDMARK_SPECS.length, 1);
  const doc = await docPanel(page, v, "Wordmark", [
    ["Sous/Body",
      "The only place the app states its own name. New York, capitals, centred — the serif is what stops the app reading as a generic utility.",
      "text/primary", "description"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, WORDMARK_SPECS.map((w) => w.name.replace("Tagline=", "Tagline ")), [],
    cell, PAD, GAP, "wordmark");
  COMPONENT_LOG.push("Wordmark (" + set.children.length + " variants)");
}

async function verifyWordmark() {
  const page = figma.root.children.find((p) => p.name === "Wordmark");
  if (!page) return check("component Wordmark", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Wordmark");
  if (!set) return check("component Wordmark", false, "component set missing");
  for (const spec of WORDMARK_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Wordmark " + spec.name, false, "missing"); continue; }
    const mark = c.findOne((x) => x.name === "wordmark");
    check("Wordmark " + spec.name + " is the serif logotype",
      mark.fontName.family === "New York" || mark.fontName.family === "Inter", mark.fontName.family);
    check("Wordmark " + spec.name + " tagline", !!c.findOne((x) => x.name === "tagline") === spec.tagline);
  }
}

// ---------------------------------------------------------- Zero State screen

async function buildZeroStateScreen() {
  const page = await ensurePage("Screens");
  const v = await colorVars();
  const screen = await newScreen(page, "Zero State", "background/surface", v);
  screen.x = 40 + 600 + 120 + (CANVAS_W + 80) * 2;
  screen.y = 40;

  // The hamburger is app-wide, not canvas-only: it opens the history drawer from
  // the zero state too.
  const burger = (await getVariant("Icon Button", "Icon Button", "Style=Accent")).createInstance();
  await figma.setCurrentPageAsync(page);
  burger.name = "menu";
  screen.appendChild(burger);
  burger.x = 16; burger.y = SAFE_TOP + 16;

  const wordmark = (await getVariant("Wordmark", "Wordmark", "Tagline=Yes")).createInstance();
  await figma.setCurrentPageAsync(page);
  wordmark.name = "wordmark";
  screen.appendChild(wordmark);
  wordmark.resize(CANVAS_W, wordmark.height);
  wordmark.x = 0;
  wordmark.y = Math.round((CANVAS_H - wordmark.height) / 2) - 120;   // Spacer above and below

  const actions = autoLayout("VERTICAL");
  actions.name = "actions";
  actions.itemSpacing = 24;                  // VStack(spacing: 24)
  actions.primaryAxisAlignItems = "CENTER";
  actions.counterAxisAlignItems = "CENTER";
  actions.fills = [];
  screen.appendChild(actions);
  actions.resize(CANVAS_W, actions.height);

  const cta = (await getVariant("Button", "Button", "Style=Inverse, State=Default")).createInstance();
  await figma.setCurrentPageAsync(page);
  cta.name = "import";
  const btnSet = (await getVariant("Button", "Button", "Style=Inverse, State=Default")).parent;
  await figma.setCurrentPageAsync(page);
  actions.appendChild(cta);
  cta.layoutSizingHorizontal = "FILL";
  cta.setProperties({ [propKey(btnSet, "Label")]: "TALK TO A RECIPE", [propKey(btnSet, "Icon")]: true });
  cta.resize(cta.width, 46);                 // padding(.vertical, 14) around a 14pt label
  const ctaIcon = cta.findOne((x) => x.name === "icon");
  if (ctaIcon) {
    await figma.loadFontAsync(ctaIcon.fontName);
    ctaIcon.characters = sfSymbol("doc.viewfinder");
  }

  const create = autoLayout("VERTICAL");
  create.name = "create";
  create.itemSpacing = 6;                    // VStack(spacing: 6)
  create.primaryAxisAlignItems = "CENTER";
  create.counterAxisAlignItems = "CENTER";
  create.fills = [];
  actions.appendChild(create);
  const createLabel = await textNode("Sous/Caption", "OR CREATE ONE", v("Sous Color", "text/muted"), "create-label");
  create.appendChild(createLabel);
  createLabel.letterSpacing = { value: 1.0, unit: "PIXELS" };
  const createChevron = figma.createText();
  createChevron.name = "create-chevron";
  createChevron.fontName = await loadIconFont();
  createChevron.characters = sfSymbol("chevron.down");
  createChevron.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
  createChevron.fills = [boundPaint(v("Sous Color", "text/muted"))];
  create.appendChild(createChevron);

  const composer = (await getVariant("Composer Bar", "Composer Bar", "Send=Disabled")).createInstance();
  await figma.setCurrentPageAsync(page);
  composer.name = "composer";
  screen.appendChild(composer);
  composer.resize(CANVAS_W, composer.height);
  composer.x = 0;
  composer.y = CANVAS_H - SAFE_BOTTOM - composer.height;

  // actions sit just above the composer, padded 20 at the sides and 16 beneath
  actions.paddingLeft = actions.paddingRight = 20;
  actions.x = 0;
  actions.y = composer.y - actions.height - 16;

  await safeAreaGuides(screen, v);
  COMPONENT_LOG.push("Zero State screen");
}

async function verifyZeroStateScreen() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Zero State screen", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Zero State");
  if (!screen) return check("Zero State screen", false, "missing");
  check("Zero State is iPhone-sized", screen.width === CANVAS_W && screen.height === CANVAS_H);
  check("Zero State sits on the surface colour", (await varNameOf(screen.fills[0])) === "background/surface");
  const names = [];
  for (const i of screen.findAll((n) => n.type === "INSTANCE")) {
    const m = await i.getMainComponentAsync();
    names.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("Zero State is built from components", !names.includes("detached"), names.join(", "));
  check("Zero State has the wordmark, hamburger, import button and composer",
    names.filter((n) => n === "Wordmark").length === 1 &&
    names.filter((n) => n === "Button").length === 1 &&
    names.filter((n) => n === "Icon Button").length === 1 &&
    names.filter((n) => n === "Composer Bar").length === 1, names.join(", "));
  const cta = screen.findOne((x) => x.name === "import");
  const main = cta && (await cta.getMainComponentAsync());
  check("the import button is the Inverse style", !!main && main.name === "Style=Inverse, State=Default",
    main ? main.name : "missing");
  check("OR CREATE ONE sits under it", !!screen.findOne((x) => x.name === "create-label"));
  const menu = screen.children.find((x) => x.name === "menu");
  check("the hamburger is on the zero state too", !!menu && menu.y >= SAFE_TOP,
    menu ? String(menu.y) : "missing");
  const composer = screen.children.find((x) => x.name === "composer");
  check("composer clears the home indicator",
    !!composer && Math.round(composer.y + composer.height) === CANVAS_H - SAFE_BOTTOM);
}

// ------------------------------------------------------- Recent Recipe Row
//
// Source: RecentRecipesView. A saved recipe shows its title; a conversation that
// never became one shows a lightbulb and a generated summary. Both carry the age
// and a chevron, 16pt insets, 14pt vertical padding, on the canvas colour.

const DRAWER_W = 314;   // HistoryDrawer: 80% of the screen width
const RECENT_SPECS = [
  { name: "Kind=Recipe", idea: false, text: "Seared chicken thighs with lemon", age: "2 HR" },
  { name: "Kind=Idea", idea: true, text: "Something with the leftover sausage", age: "3 DAY" },
];

async function buildRecentRecipeRow() {
  const page = await ensurePage("Recent Recipe Row");
  const owned = ["Recent Recipe Row / Documentation"].concat(RECENT_SPECS.map((r) => "recent/col/" + r.name));
  if (!(await clearOwned(page, "Recent Recipe Row", owned))) return;
  const v = await colorVars();
  const iconFont = await loadIconFont();
  const muted = v("Sous Color", "text/muted");

  const comps = [];
  for (const spec of RECENT_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "VERTICAL";
    c.itemSpacing = 0;
    c.resize(DRAWER_W, 50);
    c.primaryAxisSizingMode = "AUTO";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [boundPaint(v("Sous Color", "background/canvas"))];

    const row = hFrame("row");
    row.counterAxisAlignItems = "CENTER";
    row.setBoundVariable("itemSpacing", v("Sous Spacing", "space/sm"));
    bindPadding(row, v, { left: "space/lg", right: "space/lg", top: 14, bottom: 14 });
    c.appendChild(row);
    row.layoutSizingHorizontal = "FILL";

    const titleWrap = hFrame("title");
    titleWrap.counterAxisAlignItems = "CENTER";
    titleWrap.itemSpacing = 5;               // HStack(spacing: 5)
    row.appendChild(titleWrap);
    titleWrap.layoutSizingHorizontal = "FILL";
    if (spec.idea) {
      const bulb = figma.createText();
      bulb.name = "idea-icon";
      bulb.fontName = iconFont;
      bulb.characters = sfSymbol("lightbulb.min");
      bulb.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
      bulb.fills = [boundPaint(muted)];
      titleWrap.appendChild(bulb);
    }
    const title = await textNode("Sous/Body", spec.text, v("Sous Color", "text/primary"), "label");
    titleWrap.appendChild(title);
    title.layoutSizingHorizontal = "FILL";
    title.textAutoResize = "HEIGHT";

    const age = await textNode("Sous/Caption", spec.age, muted, "age");
    row.appendChild(age);

    const chevron = figma.createText();
    chevron.name = "chevron";
    chevron.fontName = iconFont;
    chevron.characters = sfSymbol("chevron.right");
    chevron.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
    chevron.fills = [boundPaint(muted)];
    row.appendChild(chevron);

    const rule = hairlineRow(v, "rule");
    // Inset like the list's own separators — never edge to edge.
    bindPadding(rule.row, v, { left: "space/lg", right: "space/lg" });
    c.appendChild(rule.row);
    rule.row.layoutSizingHorizontal = "FILL";
    rule.hair.layoutSizingHorizontal = "FILL";

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Recent Recipe Row";
  set.description =
    "One entry in the history drawer. Recipe: the title as saved. Idea: a conversation that " +
    "never became a recipe, shown with a lightbulb and a summary Sous writes. Both show how " +
    "long ago it was and open on tap; long-press to delete.\n\nSwift: RecentRecipesView.";
  const PAD = 32, GAP = 24, cell = { w: DRAWER_W, h: 56 };
  layoutGrid(set, () => 0, (c) => RECENT_SPECS.findIndex((sp) => sp.name === c.name),
    cell, PAD, GAP, 1, RECENT_SPECS.length);
  const doc = await docPanel(page, v, "Recent Recipe Row", [
    ["Sous/Body",
      "The drawer lists everything you've cooked or started. A saved recipe shows its title; a conversation that never became one shows a lightbulb and a short summary, so a half-finished idea is still findable.",
      "text/primary", "description"],
    ["Sous/Body",
      "Ages are terse and in capitals — NOW, 20 MIN, 2 HR, 3 DAY, 2 WK, then a date. Rows are 314pt wide: the drawer covers 80% of the screen.",
      "text/primary", "usage"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], RECENT_SPECS.map((r) => r.name.replace("Kind=", "")),
    cell, PAD, GAP, "recent");
  COMPONENT_LOG.push("Recent Recipe Row (" + set.children.length + " variants)");
}

async function verifyRecentRecipeRow() {
  const page = figma.root.children.find((p) => p.name === "Recent Recipe Row");
  if (!page) return check("component Recent Recipe Row", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Recent Recipe Row");
  if (!set) return check("component Recent Recipe Row", false, "component set missing");
  for (const spec of RECENT_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Recent Recipe Row " + spec.name, false, "missing"); continue; }
    const t = "Recent Recipe Row " + spec.name;
    check(t + " width matches the drawer", c.width === DRAWER_W, String(c.width));
    check(t + " lightbulb only on ideas", !!c.findOne((x) => x.name === "idea-icon") === spec.idea);
    check(t + " age is muted", (await varNameOf(c.findOne((x) => x.name === "age").fills[0])) === "text/muted");
    check(t + " sits on the canvas colour", (await varNameOf(c.fills[0])) === "background/canvas");
    check(t + " has a separator", !!c.findOne((x) => x.name === "rule-hairline"));
    check(t + " separator is inset, not edge to edge",
      c.findOne((x) => x.name === "rule").paddingLeft === 16);
  }
}

// -------------------------------------------------------------- Sidebar screen

async function buildSidebarScreen() {
  const page = await ensurePage("Screens");
  const v = await colorVars();
  const screen = await newScreen(page, "Sidebar", "background/canvas", v);
  screen.x = 40 + 600 + 120 + (CANVAS_W + 80) * 3;
  screen.y = 40;

  // The drawer pushes the app aside rather than covering it: its left edge stays
  // visible, and tapping it closes the drawer.
  const behind = figma.createFrame();
  behind.name = "app (pushed aside)";
  behind.resize(CANVAS_W - DRAWER_W, CANVAS_H);
  behind.fills = [boundPaint(v("Sous Color", "background/surface"))];
  behind.clipsContent = true;
  screen.appendChild(behind);
  behind.x = DRAWER_W; behind.y = 0;
  const behindBubble = (await getVariant("Chat Bubble", "Chat Bubble", "Role=User")).createInstance();
  await figma.setCurrentPageAsync(page);
  behindBubble.name = "sliver-message";
  behind.appendChild(behindBubble);
  behindBubble.x = 0; behindBubble.y = Math.round(CANVAS_H * 0.62);
  const behindComposer = (await getVariant("Composer Bar", "Composer Bar", "Send=Disabled")).createInstance();
  await figma.setCurrentPageAsync(page);
  behindComposer.name = "sliver-composer";
  behind.appendChild(behindComposer);
  behindComposer.resize(CANVAS_W, behindComposer.height);
  behindComposer.x = 0;
  behindComposer.y = CANVAS_H - SAFE_BOTTOM - behindComposer.height;

  const drawer = figma.createFrame();
  drawer.name = "drawer";
  drawer.layoutMode = "VERTICAL";
  drawer.itemSpacing = 0;
  drawer.resize(DRAWER_W, CANVAS_H);
  drawer.primaryAxisSizingMode = "FIXED";
  drawer.counterAxisSizingMode = "FIXED";
  drawer.fills = [boundPaint(v("Sous Color", "background/canvas"))];
  drawer.clipsContent = true;
  screen.appendChild(drawer);
  drawer.x = 0; drawer.y = 0;


  // Header: wordmark centred, settings button pinned right
  const headerWrap = figma.createFrame();
  headerWrap.name = "header";
  headerWrap.resize(DRAWER_W, 76);
  headerWrap.fills = [];
  drawer.appendChild(headerWrap);
  headerWrap.layoutSizingHorizontal = "FILL";
  const mark = (await getVariant("Wordmark", "Wordmark", "Tagline=No")).createInstance();
  await figma.setCurrentPageAsync(page);
  mark.name = "wordmark";
  headerWrap.appendChild(mark);
  mark.resize(DRAWER_W, mark.height);
  // Below the status bar, not under it.
  mark.x = 0; mark.y = SAFE_TOP + 16;
  const gear = (await getVariant("Icon Button", "Icon Button", "Style=Inverse")).createInstance();
  await figma.setCurrentPageAsync(page);
  gear.name = "settings";
  headerWrap.appendChild(gear);
  gear.x = DRAWER_W - 44 - 16;
  gear.y = mark.y + Math.round((mark.height - gear.height) / 2);
  // The hamburger stays visible over the drawer — it is how you close it.
  const burger = (await getVariant("Icon Button", "Icon Button", "Style=Accent")).createInstance();
  await figma.setCurrentPageAsync(page);
  burger.name = "menu";
  headerWrap.appendChild(burger);
  burger.x = 16;
  burger.y = gear.y;
  headerWrap.resize(DRAWER_W, mark.y + mark.height + 16);

  const headerRule = hairlineRow(v, "header-rule");
  drawer.appendChild(headerRule.row);
  headerRule.row.layoutSizingHorizontal = "FILL";
  headerRule.hair.layoutSizingHorizontal = "FILL";

  const list = autoLayout("VERTICAL");
  list.name = "recents";
  list.itemSpacing = 0;
  list.fills = [];
  drawer.appendChild(list);
  list.layoutSizingHorizontal = "FILL";
  const entries = [
    ["Kind=Recipe", "Seared chicken thighs with lemon", "2 HR"],
    ["Kind=Recipe", "Calabrian sausage pasta", "YESTERDAY"],
    ["Kind=Idea", "Something with the leftover sausage", "3 DAY"],
    ["Kind=Recipe", "Buttermilk pancakes", "1 WK"],
    ["Kind=Recipe", "Slow-roast tomato sauce", "MAR 2"],
  ];
  for (const [variant, text, age] of entries) {
    const row = (await getVariant("Recent Recipe Row", "Recent Recipe Row", variant)).createInstance();
    await figma.setCurrentPageAsync(page);
    list.appendChild(row);
    row.layoutSizingHorizontal = "FILL";
    const label = row.findOne((x) => x.name === "label");
    const ageNode = row.findOne((x) => x.name === "age");
    for (const f of label.getRangeAllFontNames(0, label.characters.length)) await figma.loadFontAsync(f);
    label.characters = text;
    for (const f of ageNode.getRangeAllFontNames(0, ageNode.characters.length)) await figma.loadFontAsync(f);
    ageNode.characters = age;
  }

  const spacer = figma.createFrame();
  spacer.name = "spacer";
  spacer.fills = [];
  spacer.resize(DRAWER_W, 10);
  drawer.appendChild(spacer);
  spacer.layoutSizingHorizontal = "FILL";
  spacer.layoutGrow = 1;

  const footerRule = hairlineRow(v, "footer-rule");
  drawer.appendChild(footerRule.row);
  footerRule.row.layoutSizingHorizontal = "FILL";
  footerRule.hair.layoutSizingHorizontal = "FILL";

  const footer = autoLayout("VERTICAL");
  footer.name = "footer";
  bindPadding(footer, v, { left: "space/gutter", right: "space/gutter", top: "space/md", bottom: "space/md" });
  footer.fills = [];
  drawer.appendChild(footer);
  footer.layoutSizingHorizontal = "FILL";
  const btnSet = (await getVariant("Button", "Button", "Style=Primary, State=Default")).parent;
  await figma.setCurrentPageAsync(page);
  const newRecipe = (await getVariant("Button", "Button", "Style=Primary, State=Default")).createInstance();
  await figma.setCurrentPageAsync(page);
  newRecipe.name = "new-recipe";
  footer.appendChild(newRecipe);
  newRecipe.layoutSizingHorizontal = "FILL";
  newRecipe.setProperties({ [propKey(btnSet, "Label")]: "NEW RECIPE", [propKey(btnSet, "Icon")]: true });
  const nrIcon = newRecipe.findOne((x) => x.name === "icon");
  if (nrIcon) {
    await figma.loadFontAsync(nrIcon.fontName);
    nrIcon.characters = sfSymbol("plus.square.fill");
  }
  const bottomPad = figma.createFrame();
  bottomPad.name = "home-indicator-space";
  bottomPad.fills = [];
  bottomPad.resize(DRAWER_W, SAFE_BOTTOM);
  drawer.appendChild(bottomPad);
  bottomPad.layoutSizingHorizontal = "FILL";

  // The app panel sits ON TOP of the drawer and casts its shadow leftward onto it
  // — the drawer slides out from underneath, it does not float above.
  screen.appendChild(behind);   // re-append = move to the front
  behind.effects = [{
    type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.18 },
    offset: { x: -2, y: 0 }, radius: 16, spread: 0, visible: true, blendMode: "NORMAL",
  }];

  await safeAreaGuides(screen, v);
  COMPONENT_LOG.push("Sidebar screen");
}

async function verifySidebarScreen() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Sidebar screen", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Sidebar");
  if (!screen) return check("Sidebar screen", false, "missing");
  const drawer = screen.children.find((x) => x.name === "drawer");
  check("the drawer covers 80% of the screen", !!drawer && drawer.width === DRAWER_W,
    drawer ? String(drawer.width) : "missing");
  const names = [];
  for (const i of screen.findAll((n) => n.type === "INSTANCE")) {
    const m = await i.getMainComponentAsync();
    names.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("sidebar is built from components", !names.includes("detached"), names.join(", "));
  check("sidebar has the wordmark, hamburger, settings, 5 recents and NEW RECIPE",
    names.filter((n) => n === "Wordmark").length === 1 &&
    names.filter((n) => n === "Icon Button").length === 2 &&
    names.filter((n) => n === "Recent Recipe Row").length === 5 &&
    names.filter((n) => n === "Button").length === 1, names.join(", "));
  const behindFrame = screen.children.find((x) => x.name === "app (pushed aside)");
  check("a sliver of the app stays visible beside the drawer",
    !!behindFrame && behindFrame.x === DRAWER_W && behindFrame.width === CANVAS_W - DRAWER_W,
    behindFrame ? behindFrame.x + "/" + behindFrame.width : "missing");
  check("the app panel casts its shadow onto the drawer, not the other way round",
    !!behindFrame && behindFrame.effects.length === 1 &&
    behindFrame.effects[0].type === "DROP_SHADOW" && behindFrame.effects[0].offset.x < 0 &&
    (!drawer.effects || drawer.effects.length === 0),
    behindFrame ? JSON.stringify(behindFrame.effects[0] && behindFrame.effects[0].offset) : "missing");
  check("the app panel sits above the drawer",
    screen.children.indexOf(behindFrame) > screen.children.indexOf(drawer));
  const wordmarkInst = screen.findOne((x) => x.name === "wordmark");
  check("the drawer header clears the status bar", !!wordmarkInst && wordmarkInst.y >= SAFE_TOP,
    wordmarkInst ? String(wordmarkInst.y) : "missing");
  const gear = screen.findOne((x) => x.name === "settings");
  const main = gear && (await gear.getMainComponentAsync());
  check("settings uses the Inverse icon button", !!main && main.name === "Style=Inverse", main ? main.name : "missing");
}

// ----------------------------------------------------------------------- Badge
//
// Source: SettingsView's plan row — "OG" beside Bring Your Own Key, marking a
// grandfathered user who may use their own API key.

async function buildBadge() {
  const page = await ensurePage("Badge");
  if (!(await clearOwned(page, "Badge", ["Badge / Documentation"]))) return;
  const v = await colorVars();
  const c = figma.createComponent();
  c.name = "Badge";
  c.layoutMode = "HORIZONTAL";
  c.primaryAxisAlignItems = "CENTER";
  c.counterAxisAlignItems = "CENTER";
  c.paddingLeft = c.paddingRight = 6;
  c.paddingTop = c.paddingBottom = 2;
  c.primaryAxisSizingMode = "AUTO";
  c.counterAxisSizingMode = "AUTO";
  c.fills = [boundPaint(v("Sous Color", "accent/primary"))];
  for (const k of ["topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius"]) {
    c.setBoundVariable(k, v("Sous Border", "radius/square"));
  }
  const t = await textNode("Sous/Caption", "OG", v("Sous Color", "text/onInverse"), "label");
  c.appendChild(t);
  page.appendChild(c);
  const key = c.addComponentProperty("Label", "TEXT", "OG");
  t.componentPropertyReferences = { characters: key };
  c.description =
    "A small burgundy marker beside a value. Used for OG — a grandfathered user who can bring " +
    "their own API key.\n\nSwift: SettingsView account section.";
  const doc = await docPanel(page, v, "Badge", [
    ["Sous/Body",
      "Tiny, burgundy, capitals. It marks something about the value beside it rather than being an action — OG next to a plan means this account keeps privileges newer ones don't get.",
      "text/primary", "description"],
  ]);
  c.x = doc.x + doc.width + 80;
  c.y = doc.y + 40;
  COMPONENT_LOG.push("Badge");
}

async function verifyBadge() {
  const page = figma.root.children.find((p) => p.name === "Badge");
  if (!page) return check("component Badge", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const c = page.children.find((x) => x.type === "COMPONENT" && x.name === "Badge");
  if (!c) return check("component Badge", false, "missing");
  check("Badge is burgundy", (await varNameOf(c.fills[0])) === "accent/primary");
  const t = c.findOne((x) => x.name === "label");
  check("Badge text is white", t && (await varNameOf(t.fills[0])) === "text/onInverse");
  check("Badge has a Label property",
    Object.keys(c.componentPropertyDefinitions || {}).some((k) => k.indexOf("Label") === 0));
}

// ------------------------------------------------------- Segmented Control
//
// Source: SettingsView's personality and voice pickers (SwiftUI .segmented).
// This is iOS system chrome, not Sous's own language — hence the rounded track
// and the white selected pill, which the rest of the app never uses.

const SEGMENT_SPECS = [1, 2, 3, 4].map((i) => ({ name: "Selected=" + i, selected: i }));
const SEGMENT_LABELS = ["Minimal", "Normal", "Playful", "Unhinged"];

async function buildSegmentedControl() {
  const page = await ensurePage("Segmented Control");
  const owned = ["Segmented Control / Documentation"].concat(SEGMENT_SPECS.map((s) => "segment/col/" + s.name));
  if (!(await clearOwned(page, "Segmented Control", owned))) return;
  const v = await colorVars();

  const comps = [];
  for (const spec of SEGMENT_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "HORIZONTAL";
    c.counterAxisAlignItems = "CENTER";
    c.itemSpacing = 0;
    c.paddingLeft = c.paddingRight = c.paddingTop = c.paddingBottom = 2;
    c.resize(ROW_W - 40, 36);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [];
    const track = figma.createRectangle();
    track.name = "track";
    track.resize(ROW_W - 40, 36);
    track.fills = [boundPaint(v("Sous Color", "text/muted"))];
    track.opacity = 0.25;
    track.cornerRadius = 18;   // capsule: half the 36pt height
    c.appendChild(track);
    track.layoutPositioning = "ABSOLUTE";
    track.x = 0; track.y = 0;

    for (let i = 1; i <= 4; i++) {
      const seg = figma.createFrame();
      seg.name = "segment " + i;
      seg.layoutMode = "HORIZONTAL";
      seg.primaryAxisAlignItems = "CENTER";
      seg.counterAxisAlignItems = "CENTER";
      seg.primaryAxisSizingMode = "FIXED";
      seg.counterAxisSizingMode = "FIXED";
      seg.resize(60, 32);
      seg.cornerRadius = 16;   // capsule inside the track
      const isSelected = i === spec.selected;
      seg.fills = isSelected ? [boundPaint(v("Sous Color", "background/surface"))] : [];
      if (isSelected) {
        seg.effects = [{
          type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.12 },
          offset: { x: 0, y: 1 }, radius: 3, spread: 0, visible: true, blendMode: "NORMAL",
        }];
      }
      c.appendChild(seg);
      seg.layoutSizingHorizontal = "FILL";
      seg.layoutSizingVertical = "FILL";
      const t = await textNode("Sous/Body", SEGMENT_LABELS[i - 1],
        v("Sous Color", "text/primary"), "label " + i);
      seg.appendChild(t);
      // iOS draws segment labels smaller and heavier than body text: 13 semibold.
      // Deliberately not a Sous type token — this is system chrome.
      // "Semibold" in SF Pro is "Semi Bold" in Inter — try both, then Bold.
      for (const style of ["Semibold", "Semi Bold", "Bold"]) {
        try {
          await figma.loadFontAsync({ family: t.fontName.family, style: style });
          t.fontName = { family: t.fontName.family, style: style };
          break;
        } catch (e) {
          // try the next spelling
        }
      }
      t.fontSize = 13;
    }
    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Segmented Control";
  set.description =
    "iOS segmented picker, used for personality and voice in Settings. Four segments; hide the " +
    "last two for a two- or three-way choice.\n\nThis is system chrome: the rounded track and " +
    "white pill are iOS, not Sous's square language. Swift: SwiftUI Picker(.segmented).";
  const seg3 = set.addComponentProperty("Segment 3", "BOOLEAN", true);
  const seg4 = set.addComponentProperty("Segment 4", "BOOLEAN", true);
  for (const variant of set.children) {
    variant.findOne((x) => x.name === "segment 3").componentPropertyReferences = { visible: seg3 };
    variant.findOne((x) => x.name === "segment 4").componentPropertyReferences = { visible: seg4 };
  }
  const PAD = 32, GAP = 20, cell = { w: ROW_W - 40, h: 40 };
  layoutGrid(set, () => 0, (c) => SEGMENT_SPECS.findIndex((sp) => sp.name === c.name),
    cell, PAD, GAP, 1, SEGMENT_SPECS.length);
  const doc = await docPanel(page, v, "Segmented Control", [
    ["Sous/Body",
      "Where a setting has a few named choices — how Sous talks to you, which voice it uses — the app uses the iOS segmented picker rather than a list of rows.",
      "text/primary", "description"],
    ["Sous/Body",
      "Deliberately not Sous's own styling: a capsule track, a white capsule for the selection, a soft shadow. It is a system control and should keep looking like one — square corners here would look broken, not consistent. Turn off Segment 3 and 4 for shorter choices.",
      "text/muted", "system-chrome"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], SEGMENT_SPECS.map((s) => s.name.replace("Selected=", "Selected ")),
    cell, PAD, GAP, "segment");
  COMPONENT_LOG.push("Segmented Control (" + set.children.length + " variants)");
}

async function verifySegmentedControl() {
  const page = figma.root.children.find((p) => p.name === "Segmented Control");
  if (!page) return check("component Segmented Control", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Segmented Control");
  if (!set) return check("component Segmented Control", false, "component set missing");
  check("Segmented Control variant count", set.children.length === 4, String(set.children.length));
  for (const spec of SEGMENT_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Segmented Control " + spec.name, false, "missing"); continue; }
    for (let i = 1; i <= 4; i++) {
      const seg = c.findOne((x) => x.name === "segment " + i);
      const filled = seg.fills.length > 0;
      check("Segmented Control " + spec.name + " segment " + i,
        filled === (i === spec.selected), "filled " + filled);
      const lbl = seg.findOne((x) => x.name === "label " + i);
      check("Segmented Control " + spec.name + " label " + i + " is 13pt semibold",
        !!lbl && lbl.fontSize === 13 && /Semibold|Semi Bold|Bold/.test(lbl.fontName.style),
        lbl ? lbl.fontSize + " " + lbl.fontName.style : "missing");
    }
  }
}

// ------------------------------------------------------------- Settings Row
//
// Source: SettingsView's Form. A link row is a label and the system chevron; a
// value row puts the value on the right (muted when it is information rather
// than something you set). Rows sit on the canvas colour with inset separators.

const SETTINGS_ROW_SPECS = [
  { name: "Kind=Link", link: true, label: "Preferences", value: null, muted: false },
  { name: "Kind=Value", link: false, label: "Email", value: "john@example.com", muted: true },
  { name: "Kind=Setting", link: false, label: "Personality", value: "Normal", muted: false },
];

async function buildSettingsRow() {
  const page = await ensurePage("Settings Row");
  const owned = ["Settings Row / Documentation"].concat(SETTINGS_ROW_SPECS.map((r) => "settings/col/" + r.name));
  if (!(await clearOwned(page, "Settings Row", owned))) return;
  const v = await colorVars();
  const iconFont = await loadIconFont();

  const comps = [];
  for (const spec of SETTINGS_ROW_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "VERTICAL";
    c.itemSpacing = 0;
    c.resize(ROW_W, 48);
    c.primaryAxisSizingMode = "AUTO";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [boundPaint(v("Sous Color", "background/canvas"))];

    const row = hFrame("row");
    row.counterAxisAlignItems = "CENTER";
    row.setBoundVariable("itemSpacing", v("Sous Spacing", "space/sm"));
    bindPadding(row, v, { left: "space/gutter", right: "space/gutter", top: "space/md", bottom: "space/md" });
    c.appendChild(row);
    row.layoutSizingHorizontal = "FILL";

    const label = await textNode("Sous/Body", spec.label, v("Sous Color", "text/primary"), "label");
    row.appendChild(label);
    label.layoutSizingHorizontal = "FILL";
    label.textAutoResize = "HEIGHT";

    const badge = (await getVariant2("Badge", "Badge")).createInstance();
    await figma.setCurrentPageAsync(page);
    badge.name = "badge";
    row.appendChild(badge);
    badge.visible = false;
    if (spec.value) {
      const value = await textNode("Sous/Body", spec.value,
        v("Sous Color", spec.muted ? "text/muted" : "text/primary"), "value");
      row.appendChild(value);
    }
    if (spec.link) {
      const chevron = figma.createText();
      chevron.name = "chevron";
      chevron.fontName = iconFont;
      chevron.characters = sfSymbol("chevron.right");
      chevron.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
      chevron.fills = [boundPaint(v("Sous Color", "text/muted"))];
      row.appendChild(chevron);
    }

    const rule = hairlineRow(v, "rule");
    bindPadding(rule.row, v, { left: "space/gutter", right: "space/gutter" });
    c.appendChild(rule.row);
    rule.row.layoutSizingHorizontal = "FILL";
    rule.hair.layoutSizingHorizontal = "FILL";

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Settings Row";
  const badgeKey = set.addComponentProperty("Badge", "BOOLEAN", false);
  for (const variant of set.children) {
    variant.findOne((x) => x.name === "badge").componentPropertyReferences = { visible: badgeKey };
  }
  set.description =
    "A row in Settings. Link opens another screen. Value shows information you cannot change " +
    "(muted on the right). Setting shows the current choice in full strength, because you can " +
    "change it.\n\nSwift: SettingsView's Form rows.";
  const PAD = 32, GAP = 24, cell = { w: ROW_W, h: 52 };
  layoutGrid(set, () => 0, (c) => SETTINGS_ROW_SPECS.findIndex((sp) => sp.name === c.name),
    cell, PAD, GAP, 1, SETTINGS_ROW_SPECS.length);
  const doc = await docPanel(page, v, "Settings Row", [
    ["Sous/Body",
      "Three kinds of row. A link takes you somewhere and shows a chevron. A value is information — your email, your plan — and sits muted on the right. A setting shows the current choice at full strength, because tapping it changes something.",
      "text/primary", "description"],
    ["Sous/Body",
      "The muted-versus-full-strength difference is the whole signal: muted means read-only. Separators are inset to the label, never edge to edge.",
      "text/primary", "usage"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], SETTINGS_ROW_SPECS.map((r) => r.name.replace("Kind=", "")),
    cell, PAD, GAP, "settings");
  COMPONENT_LOG.push("Settings Row (" + set.children.length + " variants)");
}

async function verifySettingsRow() {
  const page = figma.root.children.find((p) => p.name === "Settings Row");
  if (!page) return check("component Settings Row", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Settings Row");
  if (!set) return check("component Settings Row", false, "component set missing");
  for (const spec of SETTINGS_ROW_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Settings Row " + spec.name, false, "missing"); continue; }
    const t = "Settings Row " + spec.name;
    check(t + " chevron only on links", !!c.findOne((x) => x.name === "chevron") === spec.link);
    const value = c.findOne((x) => x.name === "value");
    check(t + " value present", !!value === !!spec.value);
    if (value) {
      check(t + " read-only values are muted",
        (await varNameOf(value.fills[0])) === (spec.muted ? "text/muted" : "text/primary"));
    }
    const ruleRow = c.findOne((x) => x.name === "rule");
    check(t + " separator is inset on both sides",
      ruleRow.paddingLeft === 20 && ruleRow.paddingRight === 20,
      ruleRow.paddingLeft + "/" + ruleRow.paddingRight);
  }
}

// ------------------------------------------------------------ Settings screen

async function buildSettingsScreen() {
  const page = await ensurePage("Screens");
  const v = await colorVars();
  const screen = await newScreen(page, "Settings", "background/canvas", v);
  screen.x = 40 + 600 + 120 + (CANVAS_W + 80) * 4;
  screen.y = 40;

  // Settings slides up as a sheet: the app stays behind it, dimmed.
  const dim = figma.createRectangle();
  dim.name = "dimmed app";
  dim.resize(CANVAS_W, CANVAS_H);
  dim.fills = [boundPaint(v("Sous Color", "text/primary"))];
  dim.opacity = 0.35;
  screen.appendChild(dim);
  dim.x = 0; dim.y = 0;

  const SHEET_TOP = 105;   // sheet inset, leaving the app visible above it
  const sheet = figma.createFrame();
  sheet.name = "sheet";
  sheet.resize(CANVAS_W, CANVAS_H - SHEET_TOP);
  sheet.fills = [boundPaint(v("Sous Color", "background/canvas"))];
  sheet.clipsContent = true;
  // Rounded top corners are iOS sheet chrome, not Sous's square language.
  sheet.topLeftRadius = sheet.topRightRadius = 20;
  screen.appendChild(sheet);
  sheet.x = 0; sheet.y = SHEET_TOP;

  const column = autoLayout("VERTICAL");
  column.name = "content";
  column.itemSpacing = 0;
  column.fills = [];
  sheet.appendChild(column);
  column.resize(CANVAS_W, column.height);
  column.x = 0; column.y = 0;

  // Inline nav bar: title centred, DONE on the right.
  const nav = hFrame("nav");
  nav.counterAxisAlignItems = "CENTER";
  nav.primaryAxisAlignItems = "CENTER";
  bindPadding(nav, v, { left: "space/gutter", right: "space/gutter", top: "space/md", bottom: "space/md" });
  column.appendChild(nav);
  nav.layoutSizingHorizontal = "FILL";
  const navTitle = await textNode("Sous/Button", "SETTINGS", v("Sous Color", "text/primary"), "nav-title");
  nav.appendChild(navTitle);
  navTitle.layoutSizingHorizontal = "FILL";
  navTitle.textAlignHorizontal = "CENTER";
  const donePill = figma.createFrame();
  donePill.name = "done";
  donePill.layoutMode = "HORIZONTAL";
  donePill.primaryAxisAlignItems = "CENTER";
  donePill.counterAxisAlignItems = "CENTER";
  donePill.paddingLeft = donePill.paddingRight = 16;
  donePill.paddingTop = donePill.paddingBottom = 8;
  donePill.primaryAxisSizingMode = "AUTO";
  donePill.counterAxisSizingMode = "AUTO";
  donePill.fills = [boundPaint(v("Sous Color", "background/surface"))];
  donePill.cornerRadius = 20;   // system chrome: a capsule, not Sous's square
  donePill.effects = [{
    type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.12 },
    offset: { x: 0, y: 1 }, radius: 4, spread: 0, visible: true, blendMode: "NORMAL",
  }];
  nav.appendChild(donePill);
  const done = await textNode("Sous/Button", "DONE", v("Sous Color", "text/primary"), "done-label");
  donePill.appendChild(done);
  const navRule = hairlineRow(v, "nav-rule");
  column.appendChild(navRule.row);
  navRule.row.layoutSizingHorizontal = "FILL";
  navRule.hair.layoutSizingHorizontal = "FILL";

  const addSegments = async (labels, selected) => {
    const seg = (await getVariant("Segmented Control", "Segmented Control",
      "Selected=" + selected)).createInstance();
    await figma.setCurrentPageAsync(page);
    seg.name = "picker:" + labels.join("/");
    const wrap = autoLayout("VERTICAL");
    wrap.name = "picker-wrap";
    bindPadding(wrap, v, { left: "space/gutter", right: "space/gutter", top: "space/sm", bottom: "space/sm" });
    wrap.fills = [];
    column.appendChild(wrap);
    wrap.layoutSizingHorizontal = "FILL";
    wrap.appendChild(seg);
    seg.layoutSizingHorizontal = "FILL";
    const segSet = (await getVariant("Segmented Control", "Segmented Control", "Selected=" + selected)).parent;
    await figma.setCurrentPageAsync(page);
    seg.setProperties({
      [propKey(segSet, "Segment 3")]: labels.length > 2,
      [propKey(segSet, "Segment 4")]: labels.length > 3,
    });
    for (let i = 0; i < labels.length; i++) {
      const t = seg.findOne((x) => x.name === "label " + (i + 1));
      if (!t) continue;
      for (const f of t.getRangeAllFontNames(0, t.characters.length)) await figma.loadFontAsync(f);
      t.characters = labels[i];
    }
  };

  const sectionHeaderOnly = async (title) => {
    const head = (await getVariant("Section Header", "Section Header", "State=Static")).createInstance();
    await figma.setCurrentPageAsync(page);
    head.name = "section:" + title;
    column.appendChild(head);
    head.layoutSizingHorizontal = "FILL";
    const headText = head.findOne((x) => x.name === "title");
    for (const f of headText.getRangeAllFontNames(0, headText.characters.length)) await figma.loadFontAsync(f);
    headText.characters = title;
  };

  const footnoteOnly = async (title, footnote) => {
    const foot = autoLayout("VERTICAL");
    foot.name = "footnote:" + title;
    bindPadding(foot, v, { left: "space/gutter", right: "space/gutter", top: "space/sm", bottom: "space/lg" });
    foot.fills = [];
    column.appendChild(foot);
    foot.layoutSizingHorizontal = "FILL";
    const ft = await textNode("Sous/Caption", footnote, v("Sous Color", "text/muted"), "footnote-text");
    foot.appendChild(ft);
    ft.layoutSizingHorizontal = "FILL";
    ft.textAutoResize = "HEIGHT";
  };

  const section = async (title, rows, footnote) => {
    const head = (await getVariant("Section Header", "Section Header", "State=Static")).createInstance();
    await figma.setCurrentPageAsync(page);
    head.name = "section:" + title;
    column.appendChild(head);
    head.layoutSizingHorizontal = "FILL";
    const headText = head.findOne((x) => x.name === "title");
    for (const f of headText.getRangeAllFontNames(0, headText.characters.length)) await figma.loadFontAsync(f);
    headText.characters = title;
    for (const [variant, label, value, badge] of rows) {
      const r = (await getVariant("Settings Row", "Settings Row", variant)).createInstance();
      await figma.setCurrentPageAsync(page);
      r.name = "row:" + label;
      column.appendChild(r);
      r.layoutSizingHorizontal = "FILL";
      const l = r.findOne((x) => x.name === "label");
      for (const f of l.getRangeAllFontNames(0, l.characters.length)) await figma.loadFontAsync(f);
      l.characters = label;
      const val = r.findOne((x) => x.name === "value");
      if (val && value) {
        for (const f of val.getRangeAllFontNames(0, val.characters.length)) await figma.loadFontAsync(f);
        val.characters = value;
      }
      if (badge) {
        const rowSet = (await getVariant("Settings Row", "Settings Row", variant)).parent;
        await figma.setCurrentPageAsync(page);
        r.setProperties({ [propKey(rowSet, "Badge")]: true });
      }
    }
    const foot = autoLayout("VERTICAL");
    foot.name = "footnote:" + title;
    bindPadding(foot, v, { left: "space/gutter", right: "space/gutter", top: "space/sm", bottom: "space/lg" });
    foot.fills = [];
    column.appendChild(foot);
    foot.layoutSizingHorizontal = "FILL";
    const ft = await textNode("Sous/Caption", footnote, v("Sous Color", "text/muted"), "footnote-text");
    foot.appendChild(ft);
    ft.layoutSizingHorizontal = "FILL";
    ft.textAutoResize = "HEIGHT";
  };

  await section("YOUR KITCHEN", [
    ["Kind=Link", "Preferences", null],
    ["Kind=Link", "Memories", null],
  ], "Dietary restrictions, default servings, equipment, custom instructions, and saved memories.");

  await sectionHeaderOnly("PERSONALITY");
  await addSegments(["Minimal", "Normal", "Playful", "Unhinged"], 4);
  await footnoteOnly("PERSONALITY",
    "Controls how Sous talks to you. Minimal is direct and no-frills. Normal is warm and conversational. Playful is opinionated and a little funny. Unhinged is chaos gremlin energy.");

  await sectionHeaderOnly("VOICE");
  await addSegments(["Female", "Male"], 2);
  await addSegments(["American", "Australian", "British"], 3);
  await footnoteOnly("VOICE", "The voice and accent Sous uses when you talk to it hands-free.");

  await section("ACCOUNT", [
    ["Kind=Value", "Name", "John Kneeland"],
    ["Kind=Value", "Email", "john.kneeland@gmail.com"],
    ["Kind=Value", "Plan", "Bring Your Own Key", true],
  ], "Using your own API key · No limits apply");

  await safeAreaGuides(screen, v);
  COMPONENT_LOG.push("Settings screen");
}

async function verifySettingsScreen() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Settings screen", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Settings");
  if (!screen) return check("Settings screen", false, "missing");
  const names = [];
  for (const i of screen.findAll((n) => n.type === "INSTANCE")) {
    const m = await i.getMainComponentAsync();
    names.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("settings is built from components", !names.includes("detached"), names.join(", "));
  check("settings has 4 section headers, 5 rows and 3 pickers",
    names.filter((n) => n === "Section Header").length === 4 &&
    names.filter((n) => n === "Settings Row").length === 5 &&
    names.filter((n) => n === "Segmented Control").length === 3, names.join(", "));
  const sheet = screen.children.find((x) => x.name === "sheet");
  check("settings slides up as a sheet over the dimmed app",
    !!sheet && sheet.y > SAFE_TOP && sheet.topLeftRadius === 20 &&
    !!screen.children.find((x) => x.name === "dimmed app"),
    sheet ? sheet.y + "/" + sheet.topLeftRadius : "missing");
  const donePill2 = screen.findOne((x) => x.name === "done");
  check("DONE is a rounded system button", !!donePill2 && donePill2.cornerRadius === 20,
    donePill2 ? String(donePill2.cornerRadius) : "missing");
  const plan = screen.findOne((x) => x.name === "row:Plan");
  const badge = plan && plan.findOne((x) => x.name === "badge");
  check("the plan row carries the OG badge", !!badge && badge.visible === true,
    badge ? String(badge.visible) : "missing");
}

// ------------------------------------------------------------------ Diff Row
//
// Source: PatchReviewView.changeRowView. A 2pt bar in the margin and the text in
// the same colour: burgundy and struck through for what goes, green for what
// arrives. An edit is the two stacked, old above new.

const DIFF_SPECS = [
  { name: "Kind=Removed", token: "text/accent", bar: "accent/primary", strike: true,
    text: "4 chicken breasts" },
  { name: "Kind=Added", token: "status/added", bar: "status/added", strike: false,
    text: "4 duck legs" },
];

async function buildDiffRow() {
  const page = await ensurePage("Diff Row");
  const owned = ["Diff Row / Documentation"].concat(DIFF_SPECS.map((d) => "diff/col/" + d.name));
  if (!(await clearOwned(page, "Diff Row", owned))) return;
  const v = await colorVars();

  const comps = [];
  for (const spec of DIFF_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "HORIZONTAL";
    c.counterAxisAlignItems = "MIN";
    c.itemSpacing = 0;
    c.resize(ROW_W - 40, 44);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "AUTO";
    c.fills = [];

    const bar = figma.createRectangle();
    bar.name = "bar";
    bar.resize(2, 40);                       // Rectangle().frame(width: 2)
    bar.fills = [boundPaint(v("Sous Color", spec.bar))];
    c.appendChild(bar);
    bar.layoutSizingVertical = "FILL";

    const textWrap = autoLayout("VERTICAL");
    textWrap.name = "text-wrap";
    textWrap.paddingLeft = 12;
    textWrap.paddingTop = textWrap.paddingBottom = 10;
    textWrap.fills = [];
    c.appendChild(textWrap);
    textWrap.layoutSizingHorizontal = "FILL";
    const t = await textNode("Sous/Body", spec.text, v("Sous Color", spec.token), "text");
    textWrap.appendChild(t);
    t.layoutSizingHorizontal = "FILL";
    t.textAutoResize = "HEIGHT";
    if (spec.strike) t.setRangeTextDecoration(0, t.characters.length, "STRIKETHROUGH");

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Diff Row";
  set.description =
    "One line of a proposed change. Removed: burgundy, struck through, burgundy bar. Added: " +
    "green, green bar. An edited line is a Removed stacked on an Added.\n\n" +
    "Swift: PatchReviewView.changeRowView. Green appears nowhere else in Sous — it only ever " +
    "means 'this is being added'.";
  const PAD = 32, GAP = 16, cell = { w: ROW_W - 40, h: 48 };
  layoutGrid(set, () => 0, (c) => DIFF_SPECS.findIndex((d) => d.name === c.name),
    cell, PAD, GAP, 1, DIFF_SPECS.length);
  const doc = await docPanel(page, v, "Diff Row", [
    ["Sous/Body",
      "How Sous shows what it wants to change before you agree to it. The old line stays visible, struck through in burgundy; the new one sits beneath in green. Nothing changes in the recipe until you accept.",
      "text/primary", "description"],
    ["Sous/Body",
      "Green is used nowhere else in the app. Here it means exactly one thing: this line is being added. The 2pt bar in the margin is what lets you scan a long diff without reading it.",
      "text/primary", "usage"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], DIFF_SPECS.map((d) => d.name.replace("Kind=", "")),
    cell, PAD, GAP, "diff");
  COMPONENT_LOG.push("Diff Row (" + set.children.length + " variants)");
}

async function verifyDiffRow() {
  const page = figma.root.children.find((p) => p.name === "Diff Row");
  if (!page) return check("component Diff Row", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Diff Row");
  if (!set) return check("component Diff Row", false, "component set missing");
  for (const spec of DIFF_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Diff Row " + spec.name, false, "missing"); continue; }
    const t = "Diff Row " + spec.name;
    const bar = c.findOne((x) => x.name === "bar");
    const text = c.findOne((x) => x.name === "text");
    check(t + " bar colour", (await varNameOf(bar.fills[0])) === spec.bar);
    check(t + " bar is 2pt", bar.width === 2, String(bar.width));
    check(t + " text colour", (await varNameOf(text.getRangeFills(0, 1)[0])) === spec.token);
    check(t + " struck through only when removed",
      (text.getRangeTextDecoration(0, text.characters.length) === "STRIKETHROUGH") === spec.strike);
  }
}

// -------------------------------------------------------- Accept / Reject bar
//
// Source: PatchReviewView's bottom bar. Two halves, 56pt tall, separated by a
// hairline: REJECT in burgundy on the canvas, ACCEPT reversed on ink. Accept
// greys out while the patch is invalid.

const REVIEW_BAR_SPECS = [];
for (const valid of [true, false]) {
  for (const safe of [true, false]) {
    REVIEW_BAR_SPECS.push({
      name: "State=" + (valid ? "Ready" : "Invalid") + ", Safe area=" + (safe ? "Yes" : "No"),
      valid: valid, safe: safe,
    });
  }
}

async function buildReviewBar() {
  const page = await ensurePage("Review Bar");
  const owned = ["Review Bar / Documentation"].concat(REVIEW_BAR_SPECS.map((r) => "reviewbar/col/" + r.name.replace("State=", "")));
  if (!(await clearOwned(page, "Review Bar", owned))) return;
  const v = await colorVars();

  const comps = [];
  for (const spec of REVIEW_BAR_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "HORIZONTAL";
    c.itemSpacing = 0;
    c.counterAxisAlignItems = "CENTER";
    c.resize(ROW_W, spec.safe ? 56 + SAFE_BOTTOM : 56);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [boundPaint(v("Sous Color", "background/canvas"))];

    const half = async (name, label, fillToken, textToken) => {
      const f = figma.createFrame();
      f.name = name;
      f.layoutMode = "HORIZONTAL";
      f.primaryAxisAlignItems = "CENTER";
      f.counterAxisAlignItems = "CENTER";
      f.resize(Math.floor(ROW_W / 2), spec.safe ? 56 + SAFE_BOTTOM : 56);
      f.primaryAxisSizingMode = "FIXED";
      f.counterAxisSizingMode = "FIXED";
      // With Safe area on, the colour bleeds under the home indicator while the
      // label stays in the top 56pt where a thumb can reach it.
      if (spec.safe) f.paddingBottom = SAFE_BOTTOM;
      f.fills = fillToken ? [boundPaint(v("Sous Color", fillToken))] : [];
      c.appendChild(f);
      f.layoutSizingHorizontal = "FILL";
      f.layoutSizingVertical = "FILL";
      const t = await textNode("Sous/Button", label, v("Sous Color", textToken), name + "-label");
      f.appendChild(t);
      return f;
    };
    await half("reject", "REJECT", null, "text/accent");
    const divider = figma.createRectangle();
    divider.name = "divider";
    divider.resize(1, spec.safe ? 56 + SAFE_BOTTOM : 56);
    divider.fills = [boundPaint(v("Sous Color", "border/subtle"))];
    c.appendChild(divider);
    divider.layoutSizingVertical = "FILL";
    // ACCEPT is the dark green — the same green the added lines use, so the
    // button and the thing it adds read as one idea (decision, 2026-09-24).
    await half("accept", "ACCEPT",
      spec.valid ? "status/added" : "background/disabled", "text/onInverse");

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Review Bar";
  set.description =
    "The decision bar under a proposed change. REJECT is quiet — burgundy text on the page. " +
    "ACCEPT is filled with the same green the added lines use, and greys out when the change " +
    "cannot be applied (the recipe moved on underneath it). Safe area=Yes bleeds the colour " +
    "under the home indicator, which is how it sits on a real screen.\n\n" +
    "Swift: PatchReviewView bottom bar — still ink-filled there; the green is a design decision " +
    "for the code to follow (docs/KnownIssues.md).";
  const PAD = 32, GAP = 20, cell = { w: ROW_W, h: 96 };
  layoutGrid(set, () => 0, (c) => REVIEW_BAR_SPECS.findIndex((sp) => sp.name === c.name),
    cell, PAD, GAP, 1, REVIEW_BAR_SPECS.length);
  const doc = await docPanel(page, v, "Review Bar", [
    ["Sous/Body",
      "Nothing in the recipe changes until you press ACCEPT. The two halves are equal width and full height so neither is easier to hit by accident, and REJECT is deliberately the quieter of the two without being hidden.",
      "text/primary", "description"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], REVIEW_BAR_SPECS.map((r) => r.name.replace("State=", "")),
    cell, PAD, GAP, "reviewbar");
  COMPONENT_LOG.push("Review Bar (" + set.children.length + " variants)");
}

async function verifyReviewBar() {
  const page = figma.root.children.find((p) => p.name === "Review Bar");
  if (!page) return check("component Review Bar", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Review Bar");
  if (!set) return check("component Review Bar", false, "component set missing");
  for (const spec of REVIEW_BAR_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Review Bar " + spec.name, false, "missing"); continue; }
    const t = "Review Bar " + spec.name;
    const accept = c.findOne((x) => x.name === "accept");
    const reject = c.findOne((x) => x.name === "reject");
    check(t + " accept is the added-green when ready",
      (await varNameOf(accept.fills[0])) === (spec.valid ? "status/added" : "background/disabled"));
    check(t + " reject has no fill", reject.fills.length === 0);
    check(t + " halves are equal", Math.abs(accept.width - reject.width) <= 1,
      accept.width + "/" + reject.width);
    check(t + " bleeds under the home indicator only with Safe area on",
      (c.height === 56 + SAFE_BOTTOM) === spec.safe, String(c.height));
  }
}

// ------------------------------------------------- Change Suggestion screen

async function buildChangeSuggestionScreen() {
  const page = await ensurePage("Screens");
  const v = await colorVars();
  const screen = await newScreen(page, "Change Suggestion", "background/canvas", v);
  screen.x = 40 + 600 + 120 + (CANVAS_W + 80) * 5;
  screen.y = 40;

  const column = autoLayout("VERTICAL");
  column.name = "content";
  column.itemSpacing = 0;
  column.fills = [];
  screen.appendChild(column);
  column.resize(CANVAS_W, column.height);
  column.x = 0; column.y = SAFE_TOP;

  // No recipe title here, by decision (2026-09-24): the hamburger clips it, and
  // the revision line is the part that matters while reviewing a change.
  const revWrap = autoLayout("VERTICAL");
  revWrap.name = "revision";
  bindPadding(revWrap, v, { left: 76, right: "space/gutter", top: "space/gutter", bottom: "space/md" });
  revWrap.fills = [];
  column.appendChild(revWrap);
  revWrap.layoutSizingHorizontal = "FILL";
  const rev = await textNode("Sous/Caption", "REV. 2 → 3", v("Sous Color", "text/muted"), "revision-label");
  revWrap.appendChild(rev);

  const revRule = hairlineRow(v, "revision-rule");
  column.appendChild(revRule.row);
  revRule.row.layoutSizingHorizontal = "FILL";
  revRule.hair.layoutSizingHorizontal = "FILL";

  const changesHeader = (await getVariant("Section Header", "Section Header", "State=Static")).createInstance();
  await figma.setCurrentPageAsync(page);
  changesHeader.name = "changes-header";
  column.appendChild(changesHeader);
  changesHeader.layoutSizingHorizontal = "FILL";
  const chText = changesHeader.findOne((x) => x.name === "title");
  for (const f of chText.getRangeAllFontNames(0, chText.characters.length)) await figma.loadFontAsync(f);
  chText.characters = "CHANGES";

  const diffs = autoLayout("VERTICAL");
  diffs.name = "diffs";
  diffs.itemSpacing = 0;
  bindPadding(diffs, v, { left: "space/gutter", right: "space/gutter" });
  diffs.fills = [];
  column.appendChild(diffs);
  diffs.layoutSizingHorizontal = "FILL";
  // One group per change: the old line, the new line, then a divider.
  const changeGroups = [
    [["Kind=Removed", "4 chicken breasts"], ["Kind=Added", "4 duck legs"]],
    [["Kind=Removed", "Sear the chicken in butter over medium-high heat until golden, about 4 min per side. Remove and set aside."],
     ["Kind=Added", "Sear the duck legs in butter over medium heat until the skin is deep golden and the fat has rendered, about 6 to 8 min per side. Remove and set aside."]],
    [["Kind=Removed", "Return the chicken to the pan, spoon sauce over, and simmer 5 min."],
     ["Kind=Added", "Return the duck legs to the pan, spoon sauce over, and simmer until cooked through and tender, 15 to 20 min."]],
  ];
  for (let g = 0; g < changeGroups.length; g++) {
    for (const [variant, text] of changeGroups[g]) {
      const row = (await getVariant("Diff Row", "Diff Row", variant)).createInstance();
      await figma.setCurrentPageAsync(page);
      diffs.appendChild(row);
      row.layoutSizingHorizontal = "FILL";
      const t = row.findOne((x) => x.name === "text");
      for (const f of t.getRangeAllFontNames(0, t.characters.length)) await figma.loadFontAsync(f);
      t.characters = text;
      if (variant === "Kind=Removed") t.setRangeTextDecoration(0, text.length, "STRIKETHROUGH");
    }
    if (g < changeGroups.length - 1) {
      const sep = hairlineRow(v, "change-rule-" + g);
      diffs.appendChild(sep.row);
      sep.row.layoutSizingHorizontal = "FILL";
      sep.hair.layoutSizingHorizontal = "FILL";
    }
  }

  // Sous Says, on the sheet surface, with the review bar beneath it
  const says = autoLayout("VERTICAL");
  says.name = "sous-says";
  says.itemSpacing = 0;
  says.fills = [boundPaint(v("Sous Color", "background/surface"))];
  screen.appendChild(says);
  says.resize(CANVAS_W, says.height);
  const saysRule = hairlineRow(v, "says-rule");
  says.appendChild(saysRule.row);
  saysRule.row.layoutSizingHorizontal = "FILL";
  saysRule.hair.layoutSizingHorizontal = "FILL";
  // A tight label rather than the Section Header component: that carries 20pt of
  // top padding, which is too much air in a bar pinned above the buttons.
  const saysHeadWrap = autoLayout("VERTICAL");
  saysHeadWrap.name = "says-header";
  bindPadding(saysHeadWrap, v, { left: "space/gutter", right: "space/gutter", top: 10, bottom: 6 });
  saysHeadWrap.fills = [];
  says.appendChild(saysHeadWrap);
  saysHeadWrap.layoutSizingHorizontal = "FILL";
  const shText = await textNode("Sous/Section Header", "SOUS SAYS…",
    v("Sous Color", "text/accent"), "says-title");
  saysHeadWrap.appendChild(shText);
  const bubbleWrap = autoLayout("HORIZONTAL");
  bubbleWrap.name = "says-body";
  bindPadding(bubbleWrap, v, { left: "space/gutter", right: "space/gutter", bottom: 10 });
  bubbleWrap.fills = [];
  says.appendChild(bubbleWrap);
  bubbleWrap.layoutSizingHorizontal = "FILL";
  const bubble = (await getVariant("Chat Bubble", "Chat Bubble", "Role=Assistant")).createInstance();
  await figma.setCurrentPageAsync(page);
  bubble.name = "says-message";
  bubbleWrap.appendChild(bubble);
  bubble.layoutSizingHorizontal = "FILL";
  const bubbleText = bubble.findOne((x) => x.name === "text");
  for (const f of bubbleText.getRangeAllFontNames(0, bubbleText.characters.length)) await figma.loadFontAsync(f);
  bubbleText.characters =
    "Swapped the chicken for duck legs and adjusted the cook flow so it actually makes sense for " +
    "duck instead of pretending chicken rules apply. If you want, I can also tune the sauce to be " +
    "a little richer and less clingy, which duck loves.";

  const bar = (await getVariant("Review Bar", "Review Bar",
    "State=Ready, Safe area=Yes")).createInstance();
  await figma.setCurrentPageAsync(page);
  bar.name = "review-bar";
  screen.appendChild(bar);
  bar.resize(CANVAS_W, bar.height);
  bar.x = 0;
  bar.y = CANVAS_H - bar.height;   // bleeds to the very bottom of the screen
  says.x = 0;
  says.y = bar.y - says.height;

  const burger = (await getVariant("Icon Button", "Icon Button", "Style=Accent")).createInstance();
  await figma.setCurrentPageAsync(page);
  burger.name = "menu";
  screen.appendChild(burger);
  burger.x = 16; burger.y = SAFE_TOP + 16;

  await safeAreaGuides(screen, v);
  COMPONENT_LOG.push("Change Suggestion screen");
}

async function verifyChangeSuggestionScreen() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Change Suggestion screen", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Change Suggestion");
  if (!screen) return check("Change Suggestion screen", false, "missing");
  const names = [];
  for (const i of screen.findAll((n) => n.type === "INSTANCE")) {
    const m = await i.getMainComponentAsync();
    names.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("change suggestion is built from components", !names.includes("detached"), names.join(", "));
  check("it has 6 diff rows, a section header, a message and the review bar",
    names.filter((n) => n === "Diff Row").length === 6 &&
    names.filter((n) => n === "Section Header").length === 1 &&
    names.filter((n) => n === "Chat Bubble").length === 1 &&
    names.filter((n) => n === "Review Bar").length === 1, names.join(", "));
  check("the recipe title is deliberately absent",
    !names.includes("Recipe Title"), names.join(", "));
  check("the revision line is kept", !!screen.findOne((x) => x.name === "revision-label"));
  const bar = screen.children.find((x) => x.name === "review-bar");
  check("the review bar bleeds to the bottom of the screen",
    !!bar && Math.round(bar.y + bar.height) === CANVAS_H,
    bar ? String(bar.y + bar.height) : "missing");
  const changeRules = screen.findAll(
    (x) => x.type === "FRAME" && x.name && x.name.indexOf("change-rule-") === 0);
  check("changes are separated by dividers", changeRules.length === 2, String(changeRules.length));
}

// ------------------------------------------------------------------ Voice Bar
//
// Source: VoiceBarView. A burgundy bar over the recipe: a centred state label in
// mono, an exit button top-right, and a 28pt strip along the bottom that is
// either two rows of pulsing dots (ready, thinking) or reactive bars (listening,
// speaking). Patch pending swaps the label for REJECT / ACCEPT CHANGES.
//
// Strip geometry from DesignSpec: 3pt unit, 2pt gap, 5pt pitch; dots 3x3 in two
// rows 2pt apart.

const VOICE_SPECS = [
  { name: "State=Ready", label: "○ ready", colour: "voice/labelWarm", strip: "dots" },
  { name: "State=Listening", label: "● listening", colour: "voice/labelBright", strip: "bars",
    barColour: "voice/labelBright" },
  { name: "State=Thinking", label: "○ thinking", colour: "voice/labelWarm", strip: "dots" },
  { name: "State=Speaking", label: "● speaking", colour: "voice/labelSpeaking", strip: "bars",
    barColour: "voice/labelSpeaking", second: "say 'stop' to interrupt" },
  { name: "State=Patch pending", label: "say 'accept' or 'reject'", colour: "voice/labelSpeaking",
    strip: "dots", buttons: true },
];
const STRIP_H = 28, STRIP_PITCH = 5, STRIP_UNIT = 3;

// Deterministic pseudo-random so every rebuild draws the same strip.
function stripWave(i, seed) {
  const x = Math.sin((i + 1) * seed) * 10000;
  return x - Math.floor(x);
}

async function buildVoiceBar() {
  const page = await ensurePage("Voice Bar");
  const owned = ["Voice Bar / Documentation"].concat(VOICE_SPECS.map((s) => "voice/col/" + s.name));
  if (!(await clearOwned(page, "Voice Bar", owned))) return;
  const v = await colorVars();
  const iconFont = await loadIconFont();

  const comps = [];
  for (const spec of VOICE_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "VERTICAL";
    c.itemSpacing = 0;
    c.resize(ROW_W, 120);
    c.primaryAxisSizingMode = "AUTO";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [boundPaint(v("Sous Color", "accent/primary"))];
    c.clipsContent = true;

    const labelWrap = autoLayout("VERTICAL");
    labelWrap.name = "label-wrap";
    labelWrap.primaryAxisAlignItems = "CENTER";
    labelWrap.counterAxisAlignItems = "CENTER";
    labelWrap.itemSpacing = 6;               // VStack(spacing: 6)
    labelWrap.paddingLeft = labelWrap.paddingRight = 52;
    bindPadding(labelWrap, v, { top: "space/gutter", bottom: "space/gutter" });
    labelWrap.fills = [];
    c.appendChild(labelWrap);
    labelWrap.layoutSizingHorizontal = "FILL";
    const label = await textNode("Sous/Voice Label", spec.label, v("Sous Color", spec.colour), "state-label");
    labelWrap.appendChild(label);
    label.textAlignHorizontal = "CENTER";
    if (spec.second) {
      const second = await textNode("Sous/Voice Label", spec.second,
        v("Sous Color", "voice/labelWarm"), "hint");
      labelWrap.appendChild(second);
      second.textAlignHorizontal = "CENTER";
    }

    if (spec.buttons) {
      const row = hFrame("patch-buttons");
      row.itemSpacing = 0;
      c.appendChild(row);
      row.layoutSizingHorizontal = "FILL";
      const patchHalf = async (name, text, colourToken) => {
        const f = autoLayout("HORIZONTAL");
        f.name = name;
        f.primaryAxisAlignItems = "CENTER";
        f.counterAxisAlignItems = "CENTER";
        f.paddingTop = f.paddingBottom = 14;
        f.fills = [whiteAlpha(0.08)];          // Color.white.opacity(0.08)
        row.appendChild(f);
        f.layoutSizingHorizontal = "FILL";
        const t = await textNode("Sous/Voice Button", text, v("Sous Color", colourToken), name + "-label");
        f.appendChild(t);
      };
      await patchHalf("reject", "REJECT", "voice/labelWarm");
      const divider = figma.createRectangle();
      divider.name = "patch-divider";
      divider.resize(1, 44);
      divider.fills = [whiteAlpha(0.15)];
      row.appendChild(divider);
      divider.layoutSizingVertical = "FILL";
      await patchHalf("accept", "ACCEPT CHANGES", "voice/labelSpeaking");
    }

    // The animation strip, flush to the bottom edge.
    const strip = figma.createFrame();
    strip.name = "strip";
    strip.resize(ROW_W, STRIP_H);
    strip.fills = [];
    strip.clipsContent = true;
    c.appendChild(strip);
    strip.layoutSizingHorizontal = "FILL";
    // Count from the strip's real width after it fills, so the marks always run
    // edge to edge rather than stopping at a guessed width.
    const count = Math.ceil(strip.width / STRIP_PITCH);
    for (let i = 0; i < count; i++) {
      const x = i * STRIP_PITCH;
      if (spec.strip === "dots") {
        for (const [row2, y] of [[0, STRIP_H / 2 - STRIP_UNIT - 1], [1, STRIP_H / 2 + 1]]) {
          const d = figma.createRectangle();
          d.name = "dot";
          d.resize(STRIP_UNIT, STRIP_UNIT);
          d.fills = [whiteAlpha(1)];
          // Layer opacity, not paint opacity: the pulse is the whole point, and
          // paint opacity is ignored on a bound colour.
          d.opacity = 0.2 + stripWave(i + row2 * 97, 12.9898) * 0.7;
          strip.appendChild(d);
          d.x = x; d.y = y;
        }
      } else {
        const h = 4 + Math.round(stripWave(i, 78.233) * (STRIP_H - 6));
        const b = figma.createRectangle();
        b.name = "bar";
        b.resize(STRIP_UNIT, h);
        b.fills = [boundPaint(v("Sous Color", spec.barColour))];
        strip.appendChild(b);
        b.x = x; b.y = STRIP_H - h;
      }
    }

    // Exit button, pinned top-right over everything.
    const exit = figma.createFrame();
    exit.name = "exit";
    exit.layoutMode = "HORIZONTAL";
    exit.primaryAxisAlignItems = "CENTER";
    exit.counterAxisAlignItems = "CENTER";
    exit.resize(28, 28);
    exit.primaryAxisSizingMode = "FIXED";
    exit.counterAxisSizingMode = "FIXED";
    exit.fills = [];
    exit.strokes = [whiteAlpha(0.2)];          // Color.white.opacity(0.2)
    exit.strokeAlign = "INSIDE";
    exit.cornerRadius = 4;                     // RoundedRectangle(cornerRadius: 4)
    exit.setBoundVariable("strokeWeight", v("Sous Border", "border/hairline"));
    c.appendChild(exit);
    exit.layoutPositioning = "ABSOLUTE";
    exit.x = ROW_W - 28 - 16;
    exit.y = 16;
    const xmark = figma.createText();
    xmark.name = "exit-icon";
    xmark.fontName = iconFont;
    xmark.characters = sfSymbol("xmark");
    xmark.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
    xmark.fills = [boundPaint(v("Sous Color", "voice/labelSpeaking"))];
    exit.appendChild(xmark);

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Voice Bar";
  set.description =
    "Hands-free mode, over the recipe. The label says what Sous is doing in lower-case mono; the " +
    "strip along the bottom is the only moving thing in the app — pulsing dots while it waits or " +
    "thinks, reactive bars while it hears you or speaks. Patch pending swaps the label for spoken " +
    "REJECT / ACCEPT CHANGES, with the diff showing on the canvas above.\n\n" +
    "Swift: VoiceBarView. The strip is drawn here as a still frame: 3pt units on a 5pt pitch.";
  const PAD = 32, GAP = 24, cell = { w: ROW_W, h: 130 };
  layoutGrid(set, () => 0, (c) => VOICE_SPECS.findIndex((sp) => sp.name === c.name),
    cell, PAD, GAP, 1, VOICE_SPECS.length);
  const doc = await docPanel(page, v, "Voice Bar", [
    ["Sous/Body",
      "Cooking with your hands full. The bar takes the bottom of the screen and never covers the step you are on. Everything it says is lower-case and quiet: ○ ready, ● listening, ○ thinking, ● speaking — the filled circle means Sous has the floor.",
      "text/primary", "description"],
    ["Sous/Body",
      "The strip is the only animation in Sous, and it earns its place: it is how you know you are being heard across a noisy kitchen. Dots pulse while waiting or thinking; bars react to sound while listening or speaking. While speaking, a second line reminds you that saying 'stop' interrupts.",
      "text/primary", "usage"],
    ["Sous/Body",
      "Voice is hidden entirely during the trial and after the paywall — see BillingGate.isVoiceAvailable.",
      "text/muted", "code-debt"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], VOICE_SPECS.map((s) => s.name.replace("State=", "")),
    cell, PAD, GAP, "voice");
  COMPONENT_LOG.push("Voice Bar (" + set.children.length + " variants)");
}

async function verifyVoiceBar() {
  const page = figma.root.children.find((p) => p.name === "Voice Bar");
  if (!page) return check("component Voice Bar", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Voice Bar");
  if (!set) return check("component Voice Bar", false, "component set missing");
  check("Voice Bar variant count", set.children.length === VOICE_SPECS.length, String(set.children.length));
  for (const spec of VOICE_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Voice Bar " + spec.name, false, "missing"); continue; }
    const t = "Voice Bar " + spec.name;
    check(t + " is burgundy", (await varNameOf(c.fills[0])) === "accent/primary");
    const label = c.findOne((x) => x.name === "state-label");
    check(t + " label colour", (await varNameOf(label.fills[0])) === spec.colour);
    check(t + " label is monospaced", /Mono|Menlo|Inter/.test(label.fontName.family), label.fontName.family);
    const strip = c.findOne((x) => x.name === "strip");
    const marks = strip.findAll((x) => x.name === (spec.strip === "dots" ? "dot" : "bar"));
    check(t + " strip is " + spec.strip, marks.length > 40, String(marks.length));
    const rightmost = marks.reduce((m, n) => Math.max(m, n.x + n.width), 0);
    check(t + " strip runs edge to edge", rightmost >= strip.width - STRIP_PITCH,
      rightmost + " of " + strip.width);
    if (spec.strip === "dots") {
      const opacities = new Set(marks.map((n) => Math.round(n.opacity * 100)));
      check(t + " dots vary in strength, so the pulse reads", opacities.size > 5,
        String(opacities.size));
    }
    check(t + " strip is 28pt tall", strip.height === STRIP_H, String(strip.height));
    check(t + " has an exit button", !!c.findOne((x) => x.name === "exit"));
    check(t + " patch buttons only when pending",
      !!c.findOne((x) => x.name === "patch-buttons") === !!spec.buttons);
    if (spec.second) check(t + " interrupt hint", !!c.findOne((x) => x.name === "hint"));
  }
}

// ----------------------------------------------------------- Voice Mode screen

async function buildVoiceModeScreen() {
  const page = await ensurePage("Screens");
  const v = await colorVars();
  const screen = await newScreen(page, "Voice Mode", "background/canvas", v);
  screen.x = 40 + 600 + 120 + (CANVAS_W + 80) * 6;
  screen.y = 40;

  const column = autoLayout("VERTICAL");
  column.name = "content";
  column.itemSpacing = 0;
  column.fills = [];
  screen.appendChild(column);
  column.resize(CANVAS_W, column.height);
  column.x = 0; column.y = SAFE_TOP;

  const title = (await getVariant("Recipe Title", "Recipe Title", "Servings=Yes")).createInstance();
  await figma.setCurrentPageAsync(page);
  title.name = "title";
  column.appendChild(title);
  title.layoutSizingHorizontal = "FILL";
  const tset = (await getVariant("Recipe Title", "Recipe Title", "Servings=Yes")).parent;
  await figma.setCurrentPageAsync(page);
  title.setProperties({ [propKey(tset, "Title")]: "SEARED CHICKEN THIGHS WITH LEMON",
                        [propKey(tset, "Servings")]: "SERVES 4" });

  const header = (await getVariant("Section Header", "Section Header", "State=Expanded")).createInstance();
  await figma.setCurrentPageAsync(page);
  header.name = "procedure-header";
  column.appendChild(header);
  header.layoutSizingHorizontal = "FILL";
  const hText = header.findOne((x) => x.name === "title");
  for (const f of hText.getRangeAllFontNames(0, hText.characters.length)) await figma.loadFontAsync(f);
  hText.characters = "PROCEDURE";

  const steps = [
    ["State=Done, Timer=No", "Pat the thighs dry and season both sides with salt."],
    ["State=Current, Timer=Yes", null],
    ["State=To Do, Timer=No", "Flip, add the thyme and lemon, and baste with the pan juices."],
  ];
  for (const [variant, text] of steps) {
    const row = (await getVariant("List Row", "List Row", variant)).createInstance();
    await figma.setCurrentPageAsync(page);
    column.appendChild(row);
    row.layoutSizingHorizontal = "FILL";
    if (text) {
      const t = row.findOne((x) => x.name === "text");
      for (const f of t.getRangeAllFontNames(0, t.characters.length)) await figma.loadFontAsync(f);
      t.characters = text;
      if (variant.indexOf("Done") !== -1) t.setRangeTextDecoration(0, text.length, "STRIKETHROUGH");
    }
  }

  const bar = (await getVariant("Voice Bar", "Voice Bar", "State=Listening")).createInstance();
  await figma.setCurrentPageAsync(page);
  bar.name = "voice-bar";
  screen.appendChild(bar);
  bar.resize(CANVAS_W, bar.height);
  bar.x = 0;
  bar.y = CANVAS_H - SAFE_BOTTOM - bar.height;

  const burger = (await getVariant("Icon Button", "Icon Button", "Style=Accent")).createInstance();
  await figma.setCurrentPageAsync(page);
  burger.name = "menu";
  screen.appendChild(burger);
  burger.x = 16; burger.y = SAFE_TOP + 16;

  await safeAreaGuides(screen, v);
  COMPONENT_LOG.push("Voice Mode screen");
}

async function verifyVoiceModeScreen() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Voice Mode screen", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Voice Mode");
  if (!screen) return check("Voice Mode screen", false, "missing");
  const names = [];
  for (const i of screen.findAll((n) => n.type === "INSTANCE")) {
    const m = await i.getMainComponentAsync();
    names.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("voice screen is built from components", !names.includes("detached"), names.join(", "));
  check("voice screen shows the recipe with the bar over it",
    names.filter((n) => n === "Voice Bar").length === 1 &&
    names.filter((n) => n === "List Row").length === 3 &&
    names.filter((n) => n === "Recipe Title").length === 1, names.join(", "));
  const bar = screen.children.find((x) => x.name === "voice-bar");
  check("the voice bar clears the home indicator",
    !!bar && Math.round(bar.y + bar.height) === CANVAS_H - SAFE_BOTTOM,
    bar ? String(bar.y + bar.height) : "missing");
}

// ----------------------------------------------------------- Import Option Row
//
// Source: RecipeImportSheet.importOption — a 22pt icon in a 28pt column, an
// ALL CAPS title over a muted subtitle, and a chevron. 20pt sides, 16pt vertical.

const IMPORT_SPECS = [
  { name: "Kind=Camera", symbol: "camera", title: "CAMERA",
    subtitle: "Photograph a cookbook page or recipe card" },
  { name: "Kind=Photo library", symbol: "photo.on.rectangle", title: "PHOTO LIBRARY",
    subtitle: "Select a screenshot or saved photo" },
  { name: "Kind=Paste text", symbol: "doc.on.clipboard", title: "PASTE TEXT",
    subtitle: "Paste raw recipe text directly" },
];

async function buildImportOptionRow() {
  const page = await ensurePage("Import Option Row");
  const owned = ["Import Option Row / Documentation"]
    .concat(IMPORT_SPECS.map((i) => "import/col/" + i.name));
  if (!(await clearOwned(page, "Import Option Row", owned))) return;
  const v = await colorVars();
  const iconFont = await loadIconFont();

  const comps = [];
  for (const spec of IMPORT_SPECS) {
    const c = figma.createComponent();
    c.name = spec.name;
    c.layoutMode = "HORIZONTAL";
    c.counterAxisAlignItems = "CENTER";
    c.setBoundVariable("itemSpacing", v("Sous Spacing", "space/lg"));
    bindPadding(c, v, { left: "space/gutter", right: "space/gutter", top: "space/lg", bottom: "space/lg" });
    c.resize(ROW_W, 72);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "AUTO";
    c.fills = [];

    const icon = figma.createText();
    icon.name = "icon";
    icon.fontName = iconFont;
    icon.characters = sfSymbol(spec.symbol);
    icon.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/xLarge"));
    icon.fills = [boundPaint(v("Sous Color", "text/primary"))];
    c.appendChild(icon);
    icon.textAutoResize = "NONE";
    icon.layoutSizingHorizontal = "FIXED";
    icon.resize(28, 28);                     // .frame(width: 28)
    icon.textAlignHorizontal = "CENTER";
    icon.textAlignVertical = "CENTER";

    const stack = autoLayout("VERTICAL");
    stack.name = "labels";
    stack.itemSpacing = 3;                   // VStack(spacing: 3)
    stack.fills = [];
    c.appendChild(stack);
    stack.layoutSizingHorizontal = "FILL";
    const title = await textNode("Sous/Button", spec.title, v("Sous Color", "text/primary"), "title");
    stack.appendChild(title);
    const sub = await textNode("Sous/Caption", spec.subtitle, v("Sous Color", "text/muted"), "subtitle");
    stack.appendChild(sub);
    sub.layoutSizingHorizontal = "FILL";
    sub.textAutoResize = "HEIGHT";

    const chevron = figma.createText();
    chevron.name = "chevron";
    chevron.fontName = iconFont;
    chevron.characters = sfSymbol("chevron.right");
    chevron.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/small"));
    chevron.fills = [boundPaint(v("Sous Color", "text/muted"))];
    c.appendChild(chevron);

    page.appendChild(c);
    comps.push(c);
  }
  const set = figma.combineAsVariants(comps, page);
  set.name = "Import Option Row";
  set.description =
    "One way to get a recipe into Sous: photograph it, pick a screenshot, or paste the text. " +
    "Title in caps, what it does underneath in muted caption.\n\n" +
    "Swift: RecipeImportSheet.importOption.";
  const PAD = 32, GAP = 16, cell = { w: ROW_W, h: 76 };
  layoutGrid(set, () => 0, (c) => IMPORT_SPECS.findIndex((sp) => sp.name === c.name),
    cell, PAD, GAP, 1, IMPORT_SPECS.length);
  const doc = await docPanel(page, v, "Import Option Row", [
    ["Sous/Body",
      "Three ways in, and the subtitle does the work: each one names a real situation — a cookbook open on the counter, a screenshot from a friend, text copied from a website.",
      "text/primary", "description"],
  ]);
  set.x = doc.x + doc.width + 80;
  set.y = doc.y + 40;
  await gridLabels(page, v, set, [], IMPORT_SPECS.map((i) => i.name.replace("Kind=", "")),
    cell, PAD, GAP, "import");
  COMPONENT_LOG.push("Import Option Row (" + set.children.length + " variants)");
}

async function verifyImportOptionRow() {
  const page = figma.root.children.find((p) => p.name === "Import Option Row");
  if (!page) return check("component Import Option Row", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const set = page.children.find((x) => x.type === "COMPONENT_SET" && x.name === "Import Option Row");
  if (!set) return check("component Import Option Row", false, "component set missing");
  for (const spec of IMPORT_SPECS) {
    const c = set.children.find((x) => x.name === spec.name);
    if (!c) { check("Import Option Row " + spec.name, false, "missing"); continue; }
    const t = "Import Option Row " + spec.name;
    check(t + " title", c.findOne((x) => x.name === "title").characters === spec.title);
    check(t + " subtitle is muted",
      (await varNameOf(c.findOne((x) => x.name === "subtitle").fills[0])) === "text/muted");
    check(t + " icon column is 28pt", c.findOne((x) => x.name === "icon").width === 28);
    check(t + " has a chevron", !!c.findOne((x) => x.name === "chevron"));
  }
}

// ------------------------------------------------ Talk to a Recipe screen

async function buildImportScreen() {
  const page = await ensurePage("Screens");
  const v = await colorVars();
  const screen = await newScreen(page, "Talk to a Recipe", "background/canvas", v);
  screen.x = 40 + 600 + 120 + (CANVAS_W + 80) * 7;
  screen.y = 40;

  // The app behind it — import is launched from the zero state.
  const behindMark = (await getVariant("Wordmark", "Wordmark", "Tagline=Yes")).createInstance();
  await figma.setCurrentPageAsync(page);
  behindMark.name = "behind-wordmark";
  screen.appendChild(behindMark);
  behindMark.resize(CANVAS_W, behindMark.height);
  behindMark.x = 0;
  behindMark.y = Math.round((CANVAS_H - behindMark.height) / 2) - 120;
  const behindMenu = (await getVariant("Icon Button", "Icon Button", "Style=Accent")).createInstance();
  await figma.setCurrentPageAsync(page);
  behindMenu.name = "behind-menu";
  screen.appendChild(behindMenu);
  behindMenu.x = 16; behindMenu.y = SAFE_TOP + 16;

  const dim = figma.createRectangle();
  dim.name = "dimmed app";
  dim.resize(CANVAS_W, CANVAS_H);
  dim.fills = [boundPaint(v("Sous Color", "text/primary"))];
  dim.opacity = 0.3;
  screen.appendChild(dim);
  dim.x = 0; dim.y = 0;

  // A floating card at the BOTTOM of the screen, hugging its content rather than
  // stretching up: it is an action sheet, not a full-height pane.
  const INSET = 10, CARD_BOTTOM_MARGIN = 10;
  const card = figma.createFrame();
  card.name = "card";
  card.layoutMode = "VERTICAL";
  card.itemSpacing = 0;
  card.resize(CANVAS_W - INSET * 2, 300);
  card.primaryAxisSizingMode = "AUTO";       // hug the three options
  card.counterAxisSizingMode = "FIXED";
  card.fills = [boundPaint(v("Sous Color", "background/canvas"))];
  card.cornerRadius = 20;                    // system sheet chrome
  card.clipsContent = true;
  card.effects = [{
    type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.18 },
    offset: { x: 0, y: 4 }, radius: 24, spread: 0, visible: true, blendMode: "NORMAL",
  }];
  screen.appendChild(card);
  card.x = INSET;

  // Grabber
  const grabWrap = autoLayout("HORIZONTAL");
  grabWrap.name = "grabber-wrap";
  grabWrap.primaryAxisAlignItems = "CENTER";
  grabWrap.paddingTop = 8;
  grabWrap.paddingBottom = 8;
  grabWrap.fills = [];
  card.appendChild(grabWrap);
  grabWrap.layoutSizingHorizontal = "FILL";
  const grabber = figma.createRectangle();
  grabber.name = "grabber";
  grabber.resize(36, 5);
  grabber.cornerRadius = 3;
  grabber.fills = [boundPaint(v("Sous Color", "text/muted"))];
  grabber.opacity = 0.5;
  grabWrap.appendChild(grabber);

  // Header: title centred, CANCEL right, with a spacer left to balance it
  const header = hFrame("header");
  header.counterAxisAlignItems = "CENTER";
  bindPadding(header, v, { left: "space/gutter", right: "space/gutter", top: "space/md", bottom: "space/md" });
  card.appendChild(header);
  header.layoutSizingHorizontal = "FILL";
  const spacerL = figma.createFrame();
  spacerL.name = "balance";
  spacerL.resize(32, 32);
  spacerL.fills = [];
  header.appendChild(spacerL);
  const hTitle = await textNode("Sous/Button", "TALK TO A RECIPE", v("Sous Color", "text/primary"), "title");
  header.appendChild(hTitle);
  hTitle.layoutSizingHorizontal = "FILL";
  hTitle.textAlignHorizontal = "CENTER";
  const cancel = await textNode("Sous/Button", "CANCEL", v("Sous Color", "text/accent"), "cancel");
  header.appendChild(cancel);

  const headRule = hairlineRow(v, "header-rule");
  card.appendChild(headRule.row);
  headRule.row.layoutSizingHorizontal = "FILL";
  headRule.hair.layoutSizingHorizontal = "FILL";

  const options = autoLayout("VERTICAL");
  options.name = "options";
  options.itemSpacing = 0;
  options.paddingTop = 8;                    // .padding(.top, 8)
  options.fills = [];
  card.appendChild(options);
  options.layoutSizingHorizontal = "FILL";
  const kinds = ["Kind=Camera", "Kind=Photo library", "Kind=Paste text"];
  for (let i = 0; i < kinds.length; i++) {
    const row = (await getVariant("Import Option Row", "Import Option Row", kinds[i])).createInstance();
    await figma.setCurrentPageAsync(page);
    row.name = "option:" + kinds[i];
    options.appendChild(row);
    row.layoutSizingHorizontal = "FILL";
    if (i < kinds.length - 1) {
      const sep = hairlineRow(v, "option-rule-" + i);
      options.appendChild(sep.row);
      sep.row.layoutSizingHorizontal = "FILL";
      sep.hair.layoutSizingHorizontal = "FILL";
    }
  }

  // A little breathing room under the last option, then pin to the bottom.
  const tail = figma.createFrame();
  tail.name = "tail";
  tail.resize(card.width, 24);
  tail.fills = [];
  card.appendChild(tail);
  tail.layoutSizingHorizontal = "FILL";
  card.y = CANVAS_H - CARD_BOTTOM_MARGIN - card.height;

  await safeAreaGuides(screen, v);
  COMPONENT_LOG.push("Talk to a Recipe screen");
}

async function verifyImportScreen() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Talk to a Recipe screen", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Talk to a Recipe");
  if (!screen) return check("Talk to a Recipe screen", false, "missing");
  const card = screen.children.find((x) => x.name === "card");
  check("it is a floating card, inset from the edges",
    !!card && card.x === 10 && card.width === CANVAS_W - 20 && card.cornerRadius === 20,
    card ? card.x + "/" + card.width + "/" + card.cornerRadius : "missing");
  check("the card sits at the bottom and hugs its content",
    !!card && Math.round(card.y + card.height) === CANVAS_H - 10 && card.height < CANVAS_H / 2,
    card ? card.y + " + " + card.height : "missing");
  check("the card floats above the dimmed app",
    !!card && card.effects.length === 1 && !!screen.children.find((x) => x.name === "dimmed app"));
  check("it has a grabber", !!screen.findOne((x) => x.name === "grabber"));
  const names = [];
  for (const i of screen.findAll((n) => n.type === "INSTANCE")) {
    const m = await i.getMainComponentAsync();
    names.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("three import options, all from the component",
    names.filter((n) => n === "Import Option Row").length === 3 && !names.includes("detached"),
    names.join(", "));
  check("CANCEL is burgundy",
    (await varNameOf(screen.findOne((x) => x.name === "cancel").fills[0])) === "text/accent");
}

// -------------------------------------------------------------------- Form kit
//
// Source: PreferencesView. Sous's own inputs are square and bordered (text field,
// text area); the toggle and stepper are iOS controls, tinted burgundy — system
// chrome, so they keep their capsule shapes.

const FIELD_SPECS = [
  { name: "State=Empty", filled: false, text: "e.g. cilantro, shellfish, nuts" },
  { name: "State=Filled", filled: true, text: "cilantro, shellfish" },
];

async function buildFormKit() {
  const page = await ensurePage("Form Kit");
  const owned = ["Form Kit / Documentation", "formkit/col/Text Field", "formkit/col/Text Area",
                 "formkit/col/Toggle", "formkit/col/Stepper", "formkit/col/Back Button"];
  for (const setName of ["Text Field", "Text Area", "Toggle", "Stepper", "Back Button"]) {
    if (!(await clearOwned(page, setName, owned))) return;
  }
  const v = await colorVars();
  const iconFont = await loadIconFont();
  const made = {};

  // --- Text Field: square, 1pt ink border, placeholder muted when empty
  {
    const comps = [];
    for (const spec of FIELD_SPECS) {
      const c = figma.createComponent();
      c.name = spec.name;
      c.layoutMode = "HORIZONTAL";
      c.counterAxisAlignItems = "CENTER";
      c.paddingLeft = c.paddingRight = c.paddingTop = c.paddingBottom = 8;   // .padding(8)
      c.resize(ROW_W - 40, 40);
      c.primaryAxisSizingMode = "FIXED";
      c.counterAxisSizingMode = "AUTO";
      c.fills = [];
      c.strokes = [boundPaint(v("Sous Color", "border/strong"))];
      c.strokeAlign = "INSIDE";
      c.setBoundVariable("strokeWeight", v("Sous Border", "border/hairline"));
      for (const k of ["topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius"]) {
        c.setBoundVariable(k, v("Sous Border", "radius/square"));
      }
      const t = await textNode("Sous/Body", spec.text,
        v("Sous Color", spec.filled ? "text/primary" : "text/muted"), "text");
      c.appendChild(t);
      t.layoutSizingHorizontal = "FILL";
      t.textAutoResize = "HEIGHT";
      page.appendChild(c);
      comps.push(c);
    }
    const set = figma.combineAsVariants(comps, page);
    set.name = "Text Field";
    set.description = "Single-line input. Square, 1pt ink border, 8pt padding. The placeholder " +
      "is muted; typed text is full strength.\n\nSwift: PreferencesView TextField.";
    made["Text Field"] = set;
  }

  // --- Text Area: the same, taller, for custom instructions
  {
    const c = figma.createComponent();
    c.name = "Text Area";
    c.layoutMode = "VERTICAL";
    c.paddingLeft = c.paddingRight = c.paddingTop = c.paddingBottom = 4;    // .padding(4)
    c.resize(ROW_W - 40, 80);                                              // .frame(minHeight: 80)
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [];
    c.strokes = [boundPaint(v("Sous Color", "border/strong"))];
    c.strokeAlign = "INSIDE";
    c.setBoundVariable("strokeWeight", v("Sous Border", "border/hairline"));
    for (const k of ["topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius"]) {
      c.setBoundVariable(k, v("Sous Border", "radius/square"));
    }
    const t = await textNode("Sous/Body", "", v("Sous Color", "text/primary"), "text");
    c.appendChild(t);
    t.layoutSizingHorizontal = "FILL";
    t.textAutoResize = "HEIGHT";
    page.appendChild(c);
    const key = c.addComponentProperty("Text", "TEXT", "");
    t.componentPropertyReferences = { characters: key };
    c.description = "Multi-line input, at least 80pt tall. Same border as the text field.\n\n" +
      "Swift: PreferencesView TextEditor (custom instructions).";
    made["Text Area"] = c;
  }

  // --- Toggle: iOS switch, tinted burgundy when on
  {
    const comps = [];
    for (const on of [true, false]) {
      const c = figma.createComponent();
      c.name = "On=" + (on ? "Yes" : "No");
      c.resize(51, 31);                    // UISwitch
      c.fills = [boundPaint(v("Sous Color", on ? "accent/primary" : "text/muted"))];
      if (!on) c.opacity = 0.6;
      c.cornerRadius = 16;                 // system chrome: a capsule
      const knob = figma.createEllipse();
      knob.name = "knob";
      knob.resize(27, 27);
      knob.fills = [boundPaint(v("Sous Color", "text/onInverse"))];
      knob.effects = [{
        type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.15 },
        offset: { x: 0, y: 1 }, radius: 3, spread: 0, visible: true, blendMode: "NORMAL",
      }];
      c.appendChild(knob);
      knob.x = on ? 51 - 27 - 2 : 2;
      knob.y = 2;
      page.appendChild(c);
      comps.push(c);
    }
    const set = figma.combineAsVariants(comps, page);
    set.name = "Toggle";
    set.description = "iOS switch, tinted burgundy when on. System chrome — it keeps its " +
      "capsule shape.\n\nSwift: Toggle(...).tint(Color.sousTerracotta).";
    made["Toggle"] = set;
  }

  // --- Stepper: the iOS minus/plus capsule
  {
    const c = figma.createComponent();
    c.name = "Stepper";
    c.layoutMode = "HORIZONTAL";
    c.counterAxisAlignItems = "CENTER";
    c.itemSpacing = 0;
    c.resize(94, 32);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [];
    c.cornerRadius = 16;                 // capsule: half the 32pt height, as iOS draws it
    const track = figma.createRectangle();
    track.name = "track";
    track.resize(94, 32);
    track.cornerRadius = 16;
    track.fills = [boundPaint(v("Sous Color", "text/muted"))];
    track.opacity = 0.25;
    c.appendChild(track);
    track.layoutPositioning = "ABSOLUTE";
    track.x = 0; track.y = 0;
    const halfBtn = async (name, glyph) => {
      const f = autoLayout("HORIZONTAL");
      f.name = name;
      f.primaryAxisAlignItems = "CENTER";
      f.counterAxisAlignItems = "CENTER";
      f.fills = [];
      c.appendChild(f);
      f.layoutSizingHorizontal = "FILL";
      f.layoutSizingVertical = "FILL";
      const t = await textNode("Sous/Body", glyph, v("Sous Color", "text/primary"), name + "-glyph");
      f.appendChild(t);
    };
    await halfBtn("minus", "−");
    const sep = figma.createRectangle();
    sep.name = "stepper-divider";
    sep.resize(1, 18);
    sep.fills = [boundPaint(v("Sous Color", "text/muted"))];
    sep.opacity = 0.5;
    c.appendChild(sep);
    await halfBtn("plus", "+");
    page.appendChild(c);
    c.description = "iOS stepper: minus and plus either side of a divider. System chrome.\n\n" +
      "Swift: Stepper(value:in:).";
    made["Stepper"] = c;
  }

  // --- Back Button: the push equivalent of the DONE pill
  {
    const c = figma.createComponent();
    c.name = "Back Button";
    c.layoutMode = "HORIZONTAL";
    c.primaryAxisAlignItems = "CENTER";
    c.counterAxisAlignItems = "CENTER";
    c.resize(40, 40);
    c.primaryAxisSizingMode = "FIXED";
    c.counterAxisSizingMode = "FIXED";
    c.fills = [boundPaint(v("Sous Color", "background/surface"))];
    c.cornerRadius = 20;                   // system chrome: a circle
    c.effects = [{
      type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.12 },
      offset: { x: 0, y: 1 }, radius: 4, spread: 0, visible: true, blendMode: "NORMAL",
    }];
    const icon = figma.createText();
    icon.name = "icon";
    icon.fontName = iconFont;
    icon.characters = sfSymbol("chevron.left");
    icon.setBoundVariable("fontSize", v("Sous Icon Sizes", "icon/medium"));
    icon.fills = [boundPaint(v("Sous Color", "text/primary"))];
    c.appendChild(icon);
    page.appendChild(c);
    c.description = "Back out of a pushed screen. The push equivalent of the DONE pill — " +
      "system chrome, so it is round.\n\nSwift: navigation back button.";
    made["Back Button"] = c;
  }

  // Lay the kit out in a column with labels.
  const doc = await docPanel(page, v, "Form Kit", [
    ["Sous/Body",
      "The inputs Preferences is built from. Sous's own fields are square and bordered like everything else in the app. The toggle, stepper and back button are iOS controls — they stay rounded, because a square switch would read as broken rather than considered.",
      "text/primary", "description"],
    ["Sous/Body",
      "The toggle is tinted burgundy when on, which is the only place the accent appears in a form.",
      "text/primary", "usage"],
  ]);
  let y = doc.y + 40;
  const order = ["Text Field", "Text Area", "Toggle", "Stepper", "Back Button"];
  for (const name of order) {
    const node = made[name];
    if (node.type === "COMPONENT_SET") {
      const PAD = 32, GAP = 16;
      const cell = { w: node.children[0].width, h: node.children[0].height + 8 };
      layoutGrid(node, () => 0, (c) => node.children.indexOf(c), cell, PAD, GAP, 1, node.children.length);
    }
    node.x = doc.x + doc.width + 80;
    node.y = y;
    const label = await textNode("Sous/Caption", name, v("Sous Color", "text/muted"), "formkit/col/" + name);
    page.appendChild(label);
    label.x = node.x - 150;
    label.y = node.y + 8;
    y += node.height + 48;
  }
  COMPONENT_LOG.push("Form Kit (text field, text area, toggle, stepper, back button)");
}

async function verifyFormKit() {
  const page = figma.root.children.find((p) => p.name === "Form Kit");
  if (!page) return check("Form Kit", false, "page missing");
  await figma.setCurrentPageAsync(page);
  const find = (n) => page.children.find((x) => x.name === n);
  for (const name of ["Text Field", "Text Area", "Toggle", "Stepper", "Back Button"]) {
    check("Form Kit has " + name, !!find(name));
  }
  const field = find("Text Field");
  if (field) {
    const empty = field.children.find((x) => x.name === "State=Empty");
    const filled = field.children.find((x) => x.name === "State=Filled");
    check("Text Field placeholder is muted",
      (await varNameOf(empty.findOne((x) => x.name === "text").fills[0])) === "text/muted");
    check("Text Field typed text is full strength",
      (await varNameOf(filled.findOne((x) => x.name === "text").fills[0])) === "text/primary");
    check("Text Field is square and bordered",
      empty.topLeftRadius === 0 && empty.strokes.length === 1, String(empty.topLeftRadius));
  }
  const toggle = find("Toggle");
  if (toggle) {
    const on = toggle.children.find((x) => x.name === "On=Yes");
    check("Toggle is burgundy when on", (await varNameOf(on.fills[0])) === "accent/primary");
    check("Toggle keeps its capsule shape", on.cornerRadius === 16, String(on.cornerRadius));
    const knob = on.findOne((x) => x.name === "knob");
    check("Toggle knob sits right when on", knob.x + knob.width / 2 > on.width / 2,
      knob.x + " of " + on.width);
  }
  const stepper = find("Stepper");
  if (stepper) {
    check("Stepper is a capsule", stepper.cornerRadius === 16, String(stepper.cornerRadius));
    const track = stepper.findOne((x) => x.name === "track");
    check("Stepper track is a capsule too", track && track.cornerRadius === 16,
      track ? String(track.cornerRadius) : "missing");
  }
  const back = find("Back Button");
  if (back) {
    check("Back Button is round", back.cornerRadius === 20, String(back.cornerRadius));
    check("Back Button has a chevron", !!back.findOne((x) => x.name === "icon"));
  }
}

// --------------------------------------------------------- Preferences screen

async function buildPreferencesScreen() {
  const page = await ensurePage("Screens");
  const v = await colorVars();
  const screen = await newScreen(page, "Preferences", "background/canvas", v);
  screen.x = 40 + 600 + 120 + (CANVAS_W + 80) * 8;
  screen.y = 40;

  const dim = figma.createRectangle();
  dim.name = "dimmed app";
  dim.resize(CANVAS_W, CANVAS_H);
  dim.fills = [boundPaint(v("Sous Color", "text/primary"))];
  dim.opacity = 0.35;
  screen.appendChild(dim);
  dim.x = 0; dim.y = 0;

  // Pushed inside the Settings sheet, so it keeps the sheet's shape.
  const SHEET_TOP = 105;
  const sheet = figma.createFrame();
  sheet.name = "sheet";
  sheet.resize(CANVAS_W, CANVAS_H - SHEET_TOP);
  sheet.fills = [boundPaint(v("Sous Color", "background/canvas"))];
  sheet.clipsContent = true;
  sheet.topLeftRadius = sheet.topRightRadius = 20;
  screen.appendChild(sheet);
  sheet.x = 0; sheet.y = SHEET_TOP;

  const column = autoLayout("VERTICAL");
  column.name = "content";
  column.itemSpacing = 0;
  column.fills = [];
  sheet.appendChild(column);
  column.resize(CANVAS_W, column.height);
  column.x = 0; column.y = 0;

  const nav = hFrame("nav");
  nav.counterAxisAlignItems = "CENTER";
  bindPadding(nav, v, { left: "space/gutter", right: "space/gutter", top: "space/md", bottom: "space/md" });
  column.appendChild(nav);
  nav.layoutSizingHorizontal = "FILL";
  const back = (await getVariant2("Form Kit", "Back Button")).createInstance();
  await figma.setCurrentPageAsync(page);
  back.name = "back";
  nav.appendChild(back);
  const navTitle = await textNode("Sous/Button", "PREFERENCES", v("Sous Color", "text/primary"), "nav-title");
  nav.appendChild(navTitle);
  navTitle.layoutSizingHorizontal = "FILL";
  navTitle.textAlignHorizontal = "CENTER";
  const balance = figma.createFrame();
  balance.name = "balance";
  balance.resize(40, 40);
  balance.fills = [];
  nav.appendChild(balance);

  const navRule = hairlineRow(v, "nav-rule");
  column.appendChild(navRule.row);
  navRule.row.layoutSizingHorizontal = "FILL";
  navRule.hair.layoutSizingHorizontal = "FILL";

  const header = async (title) => {
    const h = (await getVariant("Section Header", "Section Header", "State=Static")).createInstance();
    await figma.setCurrentPageAsync(page);
    h.name = "section:" + title;
    column.appendChild(h);
    h.layoutSizingHorizontal = "FILL";
    const t = h.findOne((x) => x.name === "title");
    for (const f of t.getRangeAllFontNames(0, t.characters.length)) await figma.loadFontAsync(f);
    t.characters = title;
  };
  const footnote = async (title, text) => {
    const f = autoLayout("VERTICAL");
    f.name = "footnote:" + title;
    bindPadding(f, v, { left: "space/gutter", right: "space/gutter", top: "space/sm", bottom: "space/lg" });
    f.fills = [];
    column.appendChild(f);
    f.layoutSizingHorizontal = "FILL";
    const t = await textNode("Sous/Caption", text, v("Sous Color", "text/muted"), "footnote-text");
    f.appendChild(t);
    t.layoutSizingHorizontal = "FILL";
    t.textAutoResize = "HEIGHT";
  };
  const inset = (node, name) => {
    const wrap = autoLayout("VERTICAL");
    wrap.name = name;
    bindPadding(wrap, v, { left: "space/gutter", right: "space/gutter", top: "space/sm", bottom: "space/sm" });
    wrap.fills = [];
    column.appendChild(wrap);
    wrap.layoutSizingHorizontal = "FILL";
    wrap.appendChild(node);
    node.layoutSizingHorizontal = "FILL";
    return wrap;
  };
  const fieldWith = async (variant, text, name) => {
    const f = (await getVariant("Form Kit", "Text Field", variant)).createInstance();
    await figma.setCurrentPageAsync(page);
    f.name = name;
    inset(f, name + "-wrap");
    const t = f.findOne((x) => x.name === "text");
    for (const ff of t.getRangeAllFontNames(0, t.characters.length)) await figma.loadFontAsync(ff);
    t.characters = text;
  };

  await header("INGREDIENTS TO ALWAYS AVOID");
  await fieldWith("State=Empty", "e.g. cilantro, shellfish, nuts", "avoid-field");
  await footnote("avoid", "Separate items with commas. Sous will never suggest these.");

  await header("MEASUREMENT UNITS");
  const units = (await getVariant("Segmented Control", "Segmented Control", "Selected=1")).createInstance();
  await figma.setCurrentPageAsync(page);
  units.name = "units";
  inset(units, "units-wrap");
  const unitSet = (await getVariant("Segmented Control", "Segmented Control", "Selected=1")).parent;
  await figma.setCurrentPageAsync(page);
  units.setProperties({ [propKey(unitSet, "Segment 3")]: false, [propKey(unitSet, "Segment 4")]: false });
  for (const [i, label] of [["1", "Imperial"], ["2", "Metric"]]) {
    const t = units.findOne((x) => x.name === "label " + i);
    for (const f of t.getRangeAllFontNames(0, t.characters.length)) await figma.loadFontAsync(f);
    t.characters = label;
  }
  await footnote("units", "Sous will use these units in all new recipes and edits.");

  await header("DEFAULT SERVINGS");
  const toggleRow = hFrame("toggle-row");
  toggleRow.counterAxisAlignItems = "CENTER";
  bindPadding(toggleRow, v, { left: "space/gutter", right: "space/gutter", top: "space/md", bottom: "space/md" });
  column.appendChild(toggleRow);
  toggleRow.layoutSizingHorizontal = "FILL";
  const toggleLabel = await textNode("Sous/Body", "Set a default", v("Sous Color", "text/primary"), "toggle-label");
  toggleRow.appendChild(toggleLabel);
  toggleLabel.layoutSizingHorizontal = "FILL";
  const toggle = (await getVariant("Form Kit", "Toggle", "On=Yes")).createInstance();
  await figma.setCurrentPageAsync(page);
  toggle.name = "toggle";
  toggleRow.appendChild(toggle);
  const toggleRule = hairlineRow(v, "toggle-rule");
  bindPadding(toggleRule.row, v, { left: "space/gutter", right: "space/gutter" });
  column.appendChild(toggleRule.row);
  toggleRule.row.layoutSizingHorizontal = "FILL";
  toggleRule.hair.layoutSizingHorizontal = "FILL";

  const stepRow = hFrame("stepper-row");
  stepRow.counterAxisAlignItems = "CENTER";
  bindPadding(stepRow, v, { left: "space/gutter", right: "space/gutter", top: "space/md", bottom: "space/md" });
  column.appendChild(stepRow);
  stepRow.layoutSizingHorizontal = "FILL";
  const stepLabel = await textNode("Sous/Body", "4 people", v("Sous Color", "text/primary"), "stepper-label");
  stepRow.appendChild(stepLabel);
  stepLabel.layoutSizingHorizontal = "FILL";
  const stepper = (await getVariant2("Form Kit", "Stepper")).createInstance();
  await figma.setCurrentPageAsync(page);
  stepper.name = "stepper";
  stepRow.appendChild(stepper);
  await footnote("servings", "Sous will scale new recipes to this size unless you say otherwise.");

  await header("KITCHEN EQUIPMENT");
  await fieldWith("State=Empty", "e.g. cast iron, air fryer, stand mixer", "equipment-field");
  await footnote("equipment", "Separate items with commas. Sous will suggest techniques that match what you have.");

  await header("CUSTOM INSTRUCTIONS");
  const area = (await getVariant2("Form Kit", "Text Area")).createInstance();
  await figma.setCurrentPageAsync(page);
  area.name = "instructions";
  inset(area, "instructions-wrap");
  await footnote("instructions", "Anything else you want Sous to always keep in mind.");

  await safeAreaGuides(screen, v);
  COMPONENT_LOG.push("Preferences screen");
}

async function verifyPreferencesScreen() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Preferences screen", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Preferences");
  if (!screen) return check("Preferences screen", false, "missing");
  const names = [];
  for (const i of screen.findAll((n) => n.type === "INSTANCE")) {
    const m = await i.getMainComponentAsync();
    names.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("preferences is built from components", !names.includes("detached"), names.join(", "));
  check("it uses the form kit: 2 fields, a text area, a toggle, a stepper and a back button",
    names.filter((n) => n === "Text Field").length === 2 &&
    names.filter((n) => n === "Text Area").length === 1 &&
    names.filter((n) => n === "Toggle").length === 1 &&
    names.filter((n) => n === "Stepper").length === 1 &&
    names.filter((n) => n === "Back Button").length === 1, names.join(", "));
  check("it has five sections",
    names.filter((n) => n === "Section Header").length === 5, names.join(", "));
  check("units are a two-way picker",
    names.filter((n) => n === "Segmented Control").length === 1, names.join(", "));
  const sheet = screen.children.find((x) => x.name === "sheet");
  check("preferences keeps the settings sheet shape",
    !!sheet && sheet.topLeftRadius === 20 && sheet.y === 105,
    sheet ? sheet.y + "/" + sheet.topLeftRadius : "missing");
}

// ------------------------------------------------------- Recipe Canvas screen
//
// The first assembled screen: a 375 x 812 iPhone frame built only from library
// components. If a screen cannot be built from the components, the components
// are wrong — that is what this is for.

const CANVAS_W = 393, CANVAS_H = 852;   // iPhone 15/16
const SAFE_TOP = 59;    // status bar + Dynamic Island
const SAFE_BOTTOM = 34; // home indicator

function propKey(set, name) {
  const defs = Object.keys(set.componentPropertyDefinitions || {});
  const key = defs.find((k) => k === name || k.indexOf(name + "#") === 0);
  if (!key) throw new Error("No component property " + name + " on " + set.name);
  return key;
}

// Instance text is overridden by writing the layer directly. Writing characters
// flattens per-character styling, so anything special is re-applied afterwards.
async function setRowText(inst, chars, opts) {
  const text = inst.findOne((x) => x.name === "text");
  const fonts = text.getRangeAllFontNames(0, text.characters.length);
  for (const f of fonts) await figma.loadFontAsync(f);
  text.characters = chars;
  if (opts && opts.done) text.setRangeTextDecoration(0, chars.length, "STRIKETHROUGH");
  if (opts && opts.timerSpan) {
    const i = chars.indexOf(opts.timerSpan);
    if (i >= 0) {
      const v = await colorVars();
      text.setRangeFills(i, i + opts.timerSpan.length, [boundPaint(v("Sous Color", "text/accent"))]);
    }
  }
  return text;
}

const CANVAS_INGREDIENTS = [
  { state: "To Do", text: "4 bone-in, skin-on chicken thighs" },
  { state: "Checked", text: "2 tbsp olive oil" },
  { state: "To Do", text: "1 lemon, halved" },
  { state: "To Do", text: "3 sprigs thyme" },
];
const CANVAS_STEPS = [
  { state: "Done", timer: false, text: "Pat the thighs dry and season both sides with salt." },
  { state: "Current", timer: true, text: "Sear skin-side down for 10 minutes, without moving them.", span: "10 minutes" },
  { state: "To Do", timer: false, text: "Flip, add the thyme and lemon, and baste with the pan juices." },
  { state: "To Do", timer: false, text: "Rest for five minutes, then serve with the pan juices." },
];

async function buildRecipeCanvas() {
  const rowVariant = async (name) => getVariant("List Row", "List Row", name);
  const page = await ensurePage("Screens");
  if (!(await clearOwned(page, "Recipe Canvas", ["Recipe Canvas / Documentation"]))) return;
  for (const n of page.children.filter((x) => x.name === "Recipe Canvas")) n.remove();
  const v = await colorVars();

  const screen = figma.createFrame();
  screen.name = "Recipe Canvas";
  screen.resize(CANVAS_W, CANVAS_H);
  screen.fills = [boundPaint(v("Sous Color", "background/canvas"))];
  screen.clipsContent = true;
  page.appendChild(screen);

  await safeAreaGuides(screen, v);

  const column = autoLayout("VERTICAL");
  column.name = "content";
  column.itemSpacing = 0;
  column.fills = [];
  screen.appendChild(column);
  column.resize(CANVAS_W, column.height);
  column.x = 0; column.y = SAFE_TOP;

  const add = async (pageName, setName, variantName) => {
    const variant = await getVariant(pageName, setName, variantName);
    const inst = variant.createInstance();
    await figma.setCurrentPageAsync(page);
    column.appendChild(inst);
    inst.layoutSizingHorizontal = "FILL";
    return inst;
  };

  // Title
  const titleSet = (figma.root.children.find((p) => p.name === "Recipe Title"));
  const title = await add("Recipe Title", "Recipe Title", "Servings=Yes");
  await figma.setCurrentPageAsync(page);
  const tset = (await getVariant("Recipe Title", "Recipe Title", "Servings=Yes")).parent;
  await figma.setCurrentPageAsync(page);
  title.setProperties({ [propKey(tset, "Title")]: "SEARED CHICKEN THIGHS WITH LEMON",
                        [propKey(tset, "Servings")]: "SERVES 4" });

  // INGREDIENTS
  const secSet = (await getVariant("Section Header", "Section Header", "State=Expanded")).parent;
  await figma.setCurrentPageAsync(page);
  const ingHeader = await add("Section Header", "Section Header", "State=Expanded");
  ingHeader.setProperties({ [propKey(secSet, "Title")]: "INGREDIENTS" });
  for (const row of CANVAS_INGREDIENTS) {
    const inst = await add("List Row", "List Row", "State=" + row.state + ", Timer=No");
    await setRowText(inst, row.text, {});
  }

  // PROCEDURE
  const procHeader = await add("Section Header", "Section Header", "State=Expanded");
  procHeader.setProperties({ [propKey(secSet, "Title")]: "PROCEDURE" });
  for (const step of CANVAS_STEPS) {
    const inst = await add("List Row", "List Row",
      "State=" + step.state + ", Timer=" + (step.timer ? "Yes" : "No"));
    await setRowText(inst, step.text, { done: step.state === "Done", timerSpan: step.span });
  }

  // Hamburger, floating over the title, inside the safe area
  const burger = (await getVariant("Icon Button", "Icon Button", "Style=Accent")).createInstance();
  await figma.setCurrentPageAsync(page);
  burger.name = "menu";
  screen.appendChild(burger);
  burger.x = 16; burger.y = SAFE_TOP + 16;

  // The bottom bar sits above the home indicator, as the app does
  const bar = (await getVariant("Bottom Bar", "Bottom Bar", "Voice=Yes")).createInstance();
  await figma.setCurrentPageAsync(page);
  bar.name = "bottom bar";
  screen.appendChild(bar);
  bar.resize(CANVAS_W, bar.height);
  bar.x = 0;
  bar.y = CANVAS_H - SAFE_BOTTOM - bar.height;

  const doc = await docPanel(page, v, "Recipe Canvas", [
    ["Sous/Body",
      "The cook-mode screen at iPhone 15/16 size, 393 × 852, assembled only from library components: the hamburger, the recipe title, two section headers, eight list rows and the bottom bar. Nothing here is drawn by hand — if a screen cannot be built from the components, the components are wrong.",
      "text/primary", "description"],
    ["Sous/Body",
      "It shows the states together, which is the point: a ticked ingredient stays readable, a done step is struck through, the current step is bold with its burgundy timer, and upcoming steps are plain. Content is clipped at the frame edge the way a scrolled screen is.",
      "text/primary", "usage"],
    ["Sous/Body",
      "The two tinted bands are guides, not design: the top 59pt belongs to the clock and Dynamic Island, the bottom 34pt to the home indicator. Keep content out of both. The screen is regenerated on every plugin run — duplicate it before drawing on it.",
      "text/muted", "guides"],
  ]);
  screen.x = doc.x + doc.width + 120;
  screen.y = doc.y;
  COMPONENT_LOG.push("Recipe Canvas screen");
}

async function verifyRecipeCanvas() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return check("Recipe Canvas", false, "Screens page missing");
  await figma.setCurrentPageAsync(page);
  const screen = page.children.find((x) => x.name === "Recipe Canvas");
  if (!screen) return check("Recipe Canvas", false, "screen missing");
  check("Recipe Canvas is iPhone-sized", screen.width === CANVAS_W && screen.height === CANVAS_H,
    screen.width + "x" + screen.height);

  const instances = screen.findAll((n) => n.type === "INSTANCE");
  const mains = [];
  for (const i of instances) {
    const m = await i.getMainComponentAsync();
    mains.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
  }
  check("every part of the screen is a library component", !mains.includes("detached"), mains.join(", "));
  const count = (name) => mains.filter((m) => m === name).length;
  check("screen has 8 list rows", count("List Row") === 8, String(count("List Row")));
  check("screen has 2 section headers", count("Section Header") === 2, String(count("Section Header")));
  check("screen has the title, menu and bottom bar",
    count("Recipe Title") === 1 && count("Icon Button") === 1 && count("Bottom Bar") === 1,
    mains.join(", "));
  for (const [name, y, h] of [["safe-area/top", 0, SAFE_TOP],
                              ["safe-area/bottom", CANVAS_H - SAFE_BOTTOM, SAFE_BOTTOM]]) {
    const g = screen.children.find((x) => x.name === name);
    check("screen reserves " + name, !!g && g.y === y && g.height === h,
      g ? g.y + "/" + g.height : "missing");
    const tint = g && g.findOne((x) => x.name === name + "-tint");
    check(name + " is a neutral, translucent guide",
      !!tint && (await varNameOf(tint.fills[0])) === "text/muted" && Math.abs(tint.opacity - 0.12) < 0.001,
      tint ? (await varNameOf(tint.fills[0])) + " @ " + tint.opacity : "missing tint");
  }
  const bar = screen.children.find((x) => x.name === "bottom bar");
  check("bottom bar clears the home indicator",
    !!bar && Math.round(bar.y + bar.height) === CANVAS_H - SAFE_BOTTOM,
    bar ? String(bar.y + bar.height) : "missing");
  const menu = screen.children.find((x) => x.name === "menu");
  check("menu button sits below the status bar", !!menu && menu.y >= SAFE_TOP, menu ? String(menu.y) : "missing");
  const content = screen.children.find((x) => x.name === "content");
  check("content starts below the status bar", !!content && content.y === SAFE_TOP,
    content ? String(content.y) : "missing");

  const texts = screen.findAll((n) => n.type === "TEXT" && n.name === "text");
  const done = texts.find((t) => t.characters.indexOf("Pat the thighs") === 0);
  check("done step kept its strikethrough after the text was set",
    !!done && done.getRangeTextDecoration(0, done.characters.length) === "STRIKETHROUGH",
    done ? String(done.getRangeTextDecoration(0, done.characters.length)) : "missing");
  const timed = texts.find((t) => t.characters.indexOf("Sear skin-side") === 0);
  if (timed) {
    const i = timed.characters.indexOf("10 minutes");
    const fills = timed.getRangeFills(i, i + 10);
    check("timer duration stayed burgundy",
      Array.isArray(fills) && (await varNameOf(fills[0])) === "text/accent");
  } else {
    check("timed step present", false, "missing");
  }
}

// ----------------------------------------------------------------- registry

// Order matters: a component may only be built after everything it nests. The
// same order, reversed, is how they are cleared — otherwise a component holding
// an instance of another (Bottom Bar holds a Button) would keep it "in use" and
// silently freeze it.
const COMPONENTS = [
  { name: "Checkbox", page: "Checkbox", sets: ["Checkbox"], build: buildCheckbox, verify: verifyCheckbox },
  { name: "Button", page: "Button", sets: ["Button"], build: buildButton, verify: verifyButton },
  { name: "Section Header", page: "Section Header", sets: ["Section Header"],
    build: buildSectionHeader, verify: verifySectionHeader },
  { name: "List Row", page: "List Row", sets: ["List Row", "Ingredient Group Header"],
    build: buildListRow, verify: verifyListRow },
  { name: "Icon Button", page: "Icon Button", sets: ["Icon Button"],
    build: buildIconButton, verify: verifyIconButton },
  { name: "Recipe Title", page: "Recipe Title", sets: ["Recipe Title"],
    build: buildRecipeTitle, verify: verifyRecipeTitle },
  { name: "Bottom Bar", page: "Bottom Bar", sets: ["Bottom Bar"],
    build: buildBottomBar, verify: verifyBottomBar },
  { name: "Chat Bubble", page: "Chat Bubble", sets: ["Chat Bubble"],
    build: buildChatBubble, verify: verifyChatBubble },
  { name: "Composer Bar", page: "Composer Bar", sets: ["Composer Bar"],
    build: buildComposerBar, verify: verifyComposerBar },
  { name: "Chat Header", page: "Chat Header", sets: ["Chat Header"],
    build: buildChatHeader, verify: verifyChatHeader },
  { name: "Wordmark", page: "Wordmark", sets: ["Wordmark"], build: buildWordmark, verify: verifyWordmark },
  { name: "Recent Recipe Row", page: "Recent Recipe Row", sets: ["Recent Recipe Row"],
    build: buildRecentRecipeRow, verify: verifyRecentRecipeRow },
  { name: "Badge", page: "Badge", sets: ["Badge"], build: buildBadge, verify: verifyBadge },
  { name: "Diff Row", page: "Diff Row", sets: ["Diff Row"], build: buildDiffRow, verify: verifyDiffRow },
  { name: "Review Bar", page: "Review Bar", sets: ["Review Bar"],
    build: buildReviewBar, verify: verifyReviewBar },
  { name: "Voice Bar", page: "Voice Bar", sets: ["Voice Bar"],
    build: buildVoiceBar, verify: verifyVoiceBar },
  { name: "Import Option Row", page: "Import Option Row", sets: ["Import Option Row"],
    build: buildImportOptionRow, verify: verifyImportOptionRow },
  { name: "Form Kit", page: "Form Kit",
    sets: ["Text Field", "Text Area", "Toggle", "Stepper", "Back Button"],
    build: buildFormKit, verify: verifyFormKit },
  { name: "Segmented Control", page: "Segmented Control", sets: ["Segmented Control"],
    build: buildSegmentedControl, verify: verifySegmentedControl },
  { name: "Settings Row", page: "Settings Row", sets: ["Settings Row"],
    build: buildSettingsRow, verify: verifySettingsRow },
  { name: "Recipe Canvas", page: "Screens", sets: [], build: buildRecipeCanvas, verify: verifyRecipeCanvas },
  { name: "Chat", page: "Screens", sets: [], build: buildChatScreen, verify: verifyChatScreen },
  { name: "Zero State", page: "Screens", sets: [], build: buildZeroStateScreen, verify: verifyZeroStateScreen },
  { name: "Sidebar", page: "Screens", sets: [], build: buildSidebarScreen, verify: verifySidebarScreen },
  { name: "Settings", page: "Screens", sets: [], build: buildSettingsScreen, verify: verifySettingsScreen },
  { name: "Change Suggestion", page: "Screens", sets: [],
    build: buildChangeSuggestionScreen, verify: verifyChangeSuggestionScreen },
  { name: "Voice Mode", page: "Screens", sets: [],
    build: buildVoiceModeScreen, verify: verifyVoiceModeScreen },
  { name: "Talk to a Recipe", page: "Screens", sets: [],
    build: buildImportScreen, verify: verifyImportScreen },
  { name: "Preferences", page: "Screens", sets: [],
    build: buildPreferencesScreen, verify: verifyPreferencesScreen },
];

// Generated screens are rebuilt from the library on every run, so they are
// cleared first: otherwise their instances would mark every component "in use"
// and block the component rebuilds. Anything you want to keep, duplicate — a
// copy is not generated, so it is never touched.
const GENERATED_SCREENS = ["Recipe Canvas", "Chat", "Zero State", "Sidebar", "Settings", "Change Suggestion", "Voice Mode", "Talk to a Recipe", "Preferences"];

async function clearGeneratedScreens() {
  const page = figma.root.children.find((p) => p.name === "Screens");
  if (!page) return;
  await page.loadAsync();
  for (const n of page.children.filter((x) => GENERATED_SCREENS.includes(x.name))) n.remove();
}

// Clear every generated component, deepest consumer first, so nothing is held
// "in use" by something this plugin also generates. A component still used by
// something the plugin did NOT generate is left alone by clearOwned, which says so.
async function clearGenerated() {
  for (const page of figma.root.children) await page.loadAsync();
  await clearGeneratedScreens();
  for (const entry of COMPONENTS.slice().reverse()) {
    const page = figma.root.children.find((p) => p.name === entry.page);
    if (!page) continue;
    await page.loadAsync();
    for (const setName of entry.sets) {
      if (setName === "Checkbox") continue;  // build-if-missing: never cleared
      await clearOwned(page, setName, [], true);
    }
  }
}

async function buildComponents() {
  await clearGenerated();
  for (const c of COMPONENTS) await c.build();
}

async function verifyComponents() {
  for (const c of COMPONENTS) await c.verify();
}


// ----------------------------------------------------------------------- main

(async () => {
  let report;
  try {
    const primitives = await buildPrimitives();
    await buildSemantic(primitives);
    await buildTextStyles();
    await buildNumbers("Sous Icon Sizes", TOKENS.icon, "icon");
    await buildNumbers("Sous Spacing", TOKENS.spacing, "space");
    await buildNumbers("Sous Border", TOKENS.border, null);
    await buildComponents();

    const result = await verify();
    await verifyComponents();
    report = buildReport(result);
  } catch (err) {
    report =
      "SOUS DESIGN TOKENS — import failed\n\n" +
      (err && err.stack ? err.stack : String(err)) +
      "\n\nProgress before the failure: " + (log.join(", ") || "none") + ".";
  }

  console.log(report);
  figma.showUI(__html__, { width: 520, height: 460, title: "Sous Design Tokens" });
  figma.ui.postMessage({ report: report });
  figma.ui.onmessage = (msg) => {
    if (msg === "close") figma.closePlugin();
  };
})();
