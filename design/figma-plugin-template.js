// Sous Design Tokens — Figma plugin
//
// GENERATED FILE. Do not edit by hand.
// Regenerate with:  python3 design/build-figma-plugin.py
// tokens.json digest: __DIGEST__
//
// Running this creates (or updates) the Sous variable collections and text
// styles in the current Figma file. It is safe to run repeatedly — variables are
// matched by name and updated in place, never duplicated.

const TOKENS = __TOKENS__;

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
  lines.push("tokens.json digest: __DIGEST__");
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

// __COMPONENTS__

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
