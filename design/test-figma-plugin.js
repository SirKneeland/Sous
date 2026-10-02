// Runs figma/code.js against a stub of the Figma plugin API.
//
//     node design/test-figma-plugin.js
//
// This cannot prove Figma's real API behaves as documented, but it does prove the
// plugin's own logic: that it creates every token, aliases semantics to primitives,
// survives a plan with no variable modes, is safe to run twice, and that its
// self-verification actually catches a bad write.

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const CODE = fs.readFileSync(path.join(__dirname, "..", "figma", "code.js"), "utf8");

// --- minimal scene graph: just enough of Figma's node model for the builders ---
const MIXED = Symbol("figma.mixed");
let nodeSeq = 0;
class Node {
  constructor(type, figmaRef) {
    this.id = "n" + ++nodeSeq;
    this.type = type;
    this.name = "";
    this._children = [];
    this._loaded = false;
    this.parent = null;
    this.x = 0; this.y = 0; this.width = 100; this.height = 100;
    this._fills = []; this.strokes = [];
    this._ranges = []; this._decoRanges = [];
    this.boundVariables = {};
    this.visible = true;
    this._figma = figmaRef;
  }
  get children() {
    if (this.type === "PAGE" && !this._loaded && this._figma.currentPage !== this) {
      throw new Error("Cannot access children of an unloaded page: call page.loadAsync() first");
    }
    return this._children;
  }
  set children(v) { this._children = v; }
  async loadAsync() {
    if (this.type !== "PAGE") throw new Error("loadAsync is a page method");
    this._loaded = true;
  }
  get componentPropertyReferences() { return this._propRefs || null; }
  set componentPropertyReferences(v) {
    // Two behaviours the operator's 2026-09-24 reports exposed: attaching a TEXT
    // property flattens per-character styling, and every layer bound to the same
    // property then shares one styling.
    if (v && v.characters) {
      this._ranges = []; this._decoRanges = [];
      const reg = this._figma._textProps;
      reg[v.characters] = (reg[v.characters] || []).concat([this]);
    }
    this._propRefs = v;
  }
  _sharers() {
    const key = this._propRefs && this._propRefs.characters;
    if (!key) return [];
    return (this._figma._textProps[key] || []).filter((n) => n !== this);
  }
  get fontName() { return this._fontName; }
  set fontName(v) {
    this._fontName = v;
    for (const n of this._sharers()) n._fontName = v;
  }
  get fills() {
    // Figma reports figma.mixed when any character range differs from the node.
    return this._ranges.length ? MIXED : this._fills;
  }
  // Figma stores opacity as a 32-bit float, so 0.2 reads back as 0.20000000298023224.
  // Modelled here because the stub used to keep full double precision, so a check
  // written with === passed locally and failed in the operator's file (2026-09-27).
  // Values that are exact in float32 — 0.5, 0.25 — round-trip unchanged, which is
  // why only the 0.2 ever showed it.
  get opacity() { return this._opacity === undefined ? 1 : this._opacity; }
  set opacity(v) { this._opacity = typeof v === "number" ? Math.fround(v) : v; }
  set fills(v) {
    // Figma ignores a paint's own opacity once its colour is bound to a variable —
    // the value is silently dropped and reads back as 1. Modelled here because the
    // stub used to carry it through, so a Progress Bar track written that way passed
    // every test and then failed in the operator's real file (2026-09-27). Tint the
    // layer instead.
    this._fills = Array.isArray(v)
      ? v.map((p) => (p && p.boundVariables && p.boundVariables.color && p.opacity !== undefined
          ? Object.assign({}, p, { opacity: 1 })
          : p))
      : v;
  }
  get textDecoration() {
    if (this._decoRanges.length === 1 &&
        this._decoRanges[0].start === 0 && this._decoRanges[0].end === (this.characters || "").length) {
      return this._decoRanges[0].value;
    }
    return this._decoRanges.length ? MIXED : "NONE";
  }
  set textDecoration(_v) {
    // A node-level write is ignored while a text style is applied — the bug the
    // operator's Figma report caught. Silently dropping it here keeps the test
    // honest: only setRangeTextDecoration works.
    if (!this.textStyleId) this._decoRanges = [{ start: 0, end: (this.characters || "").length, value: _v }];
  }
  setRangeTextDecoration(start, end, value) {
    if (this.type !== "TEXT") throw new Error("setRangeTextDecoration on non-text");
    if (start < 0 || end > this.characters.length || start >= end) throw new Error("bad range");
    this._decoRanges = [{ start, end, value }];
    for (const n of this._sharers()) n._decoRanges = [{ start: 0, end: (n.characters || "").length, value }];
  }
  getRangeTextDecoration(start, end) {
    const r = this._decoRanges.find((x) => x.start <= start && x.end >= end);
    return r ? r.value : "NONE";
  }
  appendChild(child) {
    if (child.parent) child.parent._children = child.parent._children.filter((c) => c !== child);
    child.parent = this;
    this._children.push(child);
  }
  insertChild(index, child) {
    if (child.parent) child.parent._children = child.parent._children.filter((c) => c !== child);
    child.parent = this;
    this._children.splice(index, 0, child);
  }
  remove() {
    if (this.parent) this.parent._children = this.parent._children.filter((c) => c !== this);
    this.parent = null;
    // Real Figma marks only the node you removed. Instances *inside* it keep
    // removed = false and still show up in getInstancesAsync(), orphaned — their
    // parent chain no longer reaches a page. Observed in the operator's file on
    // 2026-09-27, where 9 such Icon Button instances blocked a rebuild and the
    // report could only call them "unknown page". The stub used to mark
    // descendants too, which was more generous than Figma and hid the bug.
    this.removed = true;
  }
  resize(w, h) { this.width = w; this.height = h; }
  resizeWithoutConstraints(w, h) { this.width = w; this.height = h; }
  setBoundVariable(field, variable) {
    if (!variable || !variable.id) throw new Error("setBoundVariable: no variable for " + field);
    this.boundVariables[field] = { type: "VARIABLE_ALIAS", id: variable.id };
    // Figma keeps the resolved number readable on the node itself.
    if (variable.resolvedType === "FLOAT") {
      const modes = Object.keys(variable.valuesByMode || {});
      if (modes.length) this[field] = variable.valuesByMode[modes[0]];
    }
  }
  findAll(pred) {
    const out = [];
    const walk = (n) => { for (const c of n.children) { if (pred(c)) out.push(c); walk(c); } };
    walk(this);
    return out;
  }
  findOne(pred) { return this.findAll(pred)[0] || null; }
  async getInstancesAsync() {
    // Figma keeps deleted instances in this list until the run commits; they
    // carry removed = true. The plugin must filter them itself.
    return this._figma._instances.filter((i) => i.mainComponent === this);
  }
  async setTextStyleIdAsync(id) {
    const style = this._figma._textStyles.find((s) => s.id === id);
    if (!style) throw new Error("unknown text style " + id);
    this.textStyleId = id;
    this.fontName = style.fontName;
    this.fontSize = style.fontSize;
  }
  setRangeFills(start, end, fills) {
    if (this.type !== "TEXT") throw new Error("setRangeFills on non-text");
    if (start < 0 || end > this.characters.length || start >= end) throw new Error("bad range " + start + "-" + end);
    this._ranges = this._ranges.concat([{ start, end, fills }]);
    for (const n of this._sharers()) n._ranges = this._ranges.slice();
  }
  getRangeFills(start, end) {
    const r = this._ranges.find((x) => x.start <= start && x.end >= end);
    return r ? r.fills : this._fills;
  }
  _cloneInto(target) {
    // Figma instances carry a copy of the component's layers; the builders reach
    // into them by layer name, so the stub has to copy them too.
    for (const key of ["name", "characters", "fontName", "textStyleId", "visible", "width", "height",
                       "mainComponent",   // nested instances stay linked, as in Figma
                       "textAutoResize", "textAlignHorizontal", "textAlignVertical", "layoutMode",
                       "paddingLeft", "paddingTop", "rotation", "_propRefs"]) {
      if (this[key] !== undefined) target[key] = this[key];
    }
    target._fills = (this._fills || []).slice();
    target.strokes = (this.strokes || []).slice();
    target._ranges = (this._ranges || []).slice();
    target._decoRanges = (this._decoRanges || []).slice();
    target.boundVariables = Object.assign({}, this.boundVariables);
    for (const child of this._children) {
      const copy = new Node(child.type, this._figma);
      child._cloneInto(copy);
      target.appendChild(copy);
    }
  }
  createInstance() {
    if (this.type !== "COMPONENT") throw new Error("only components can be instanced");
    const inst = new Node("INSTANCE", this._figma);
    inst.mainComponent = this;
    this._cloneInto(inst);
    // Figma names an instance after the component SET, not the variant.
    inst.name = this.parent && this.parent.type === "COMPONENT_SET" ? this.parent.name : this.name;
    this._figma._instances.push(inst);
    return inst;
  }
  getRangeAllFontNames(start, end) {
    if (this.type !== "TEXT") throw new Error("getRangeAllFontNames on non-text");
    return [this.fontName || { family: "Inter", style: "Regular" }];
  }
  async getMainComponentAsync() { return this.mainComponent || null; }
  setProperties(props) {
    const set = this.mainComponent && this.mainComponent.parent;
    if (!set || set.type !== "COMPONENT_SET") throw new Error("not a variant instance");
    // Component properties (keyed "Name#id") drive bound layers; the rest are variants.
    const variantProps = {}, componentProps = {};
    for (const [k, val] of Object.entries(props)) {
      (k.indexOf("#") === -1 ? variantProps : componentProps)[k] = val;
    }
    for (const [key, val] of Object.entries(componentProps)) {
      if (!(key in (set.componentPropertyDefinitions || {}))) {
        throw new Error("unknown component property " + key);
      }
      for (const node of this.findAll(() => true)) {
        const refs = node.componentPropertyReferences;
        if (!refs) continue;
        if (refs.characters === key) node.characters = val;
        if (refs.visible === key) node.visible = val;
      }
    }
    if (!Object.keys(variantProps).length) return;
    const want = Object.assign({}, variantPropsOf(this.mainComponent), variantProps);
    const match = set.children.find((c) => {
      const got = variantPropsOf(c);
      return Object.keys(want).every((k) => got[k] === want[k]);
    });
    if (!match) throw new Error("no variant matching " + JSON.stringify(want));
    this.mainComponent = match;
    const ownName = this.name;   // swapping a variant keeps the layer's own name
    this._children = [];
    match._cloneInto(this);
    this.name = ownName;
  }
  addComponentProperty(name, type, defaultValue) {
    const isVariant = this.type === "COMPONENT" && this.parent && this.parent.type === "COMPONENT_SET";
    if (!(this.type === "COMPONENT_SET" || (this.type === "COMPONENT" && !isVariant))) {
      throw new Error("properties belong on the set or a standalone component");
    }
    const key = name + "#" + ++nodeSeq + ":0";
    this.componentPropertyDefinitions = this.componentPropertyDefinitions || {};
    this.componentPropertyDefinitions[key] = { type, defaultValue };
    return key;
  }
}

function variantPropsOf(node) {
  const out = {};
  for (const part of node.name.split(", ")) { const [k, v] = part.split("="); out[k] = v; }
  return out;
}

function makeFigma({ allowModes, fonts }) {
  let seq = 0;
  const collections = [];
  const variables = [];
  const textStyles = [];

  const makeCollection = (name) => {
    const c = {
      id: "c" + ++seq,
      name,
      modes: [{ modeId: "m" + ++seq, name: "Mode 1" }],
      addMode(modeName) {
        if (!allowModes) throw new Error("Limited to 1 mode in this plan.");
        const mode = { modeId: "m" + ++seq, name: modeName };
        this.modes.push(mode);
        return mode.modeId;
      },
      renameMode(modeId, newName) {
        const m = this.modes.find((x) => x.modeId === modeId);
        if (!m) throw new Error("no such mode");
        m.name = newName;
      },
    };
    collections.push(c);
    return c;
  };

  const figma = {
    variables: {
      createVariableCollection: makeCollection,
      getLocalVariableCollectionsAsync: async () => collections.slice(),
      setBoundVariableForPaint(paint, field, variable) {
        if (!variable || !variable.id) throw new Error("paint bound to missing variable");
        // Frozen, as Figma's is: later mutation of this object is silently lost.
        return Object.freeze(
          Object.assign({}, paint, { boundVariables: { [field]: { type: "VARIABLE_ALIAS", id: variable.id } } })
        );
      },
      getLocalVariablesAsync: async () => variables.slice(),
      createVariable(name, collection, resolvedType) {
        if (typeof collection !== "object" || !collection.id) {
          throw new Error("createVariable expects a VariableCollection");
        }
        const v = {
          id: "v" + ++seq,
          name,
          variableCollectionId: collection.id,
          resolvedType,
          valuesByMode: {},
          description: "",
          _scopes: ["ALL_SCOPES"],   // Figma's real default
          get scopes() { return this._scopes; },
          // Real Figma returns scopes in its own canonical order, not insertion order.
          set scopes(list) { this._scopes = list.slice().sort().reverse(); },
          codeSyntax: {},
          setVariableCodeSyntax(platform, value) {
            if (!["WEB", "ANDROID", "iOS"].includes(platform)) throw new Error("bad platform");
            this.codeSyntax[platform] = value;
          },
          setValueForMode(modeId, value) {
            if (!collection.modes.some((m) => m.modeId === modeId)) {
              throw new Error("unknown modeId for this collection");
            }
            this.valuesByMode[modeId] = value;
          },
        };
        variables.push(v);
        return v;
      },
      getVariableByIdAsync: async (id) => variables.find((v) => v.id === id) || null,
      createVariableAlias: (v) => {
        if (!v || !v.id) throw new Error("alias target missing");
        return { type: "VARIABLE_ALIAS", id: v.id };
      },
    },
    variablesForPaint: null,
    createTextStyle() {
      const s = {
        id: "s" + ++seq,
        name: "",
        fontName: { family: "Inter", style: "Regular" },
        fontSize: 12,
        textCase: "ORIGINAL",
        letterSpacing: { value: 0, unit: "PIXELS" },
        description: "",
      };
      textStyles.push(s);
      return s;
    },
    getLocalTextStylesAsync: async () => textStyles.slice(),
    async loadFontAsync({ family, style }) {
      const available = fonts[family];
      if (!available || !available.includes(style)) {
        throw new Error(`font not available: ${family} ${style}`);
      }
    },
    root: null,
    currentPage: null,
    _instances: [],
    _textProps: {},
    _textStyles: textStyles,
    createPage() { const p = new Node("PAGE", figma); figma.root.appendChild(p); return p; },
    async setCurrentPageAsync(p) { p._loaded = true; figma.currentPage = p; },
    createFrame() { return new Node("FRAME", figma); },
    createComponent() { return new Node("COMPONENT", figma); },
    createText() { const t = new Node("TEXT", figma); t.characters = ""; return t; },
    createRectangle() { return new Node("RECTANGLE", figma); },
    createEllipse() { return new Node("ELLIPSE", figma); },
    combineAsVariants(comps, parent) {
      if (!comps.length) throw new Error("no components");
      const set = new Node("COMPONENT_SET", figma);
      parent.appendChild(set);
      for (const c of comps) set.appendChild(c);
      return set;
    },
    util: { getSfSymbolCharacter: (name) => "\u{100000}" + name },
    showUI() {},
    ui: { postMessage() {}, set onmessage(_) {} },
    closePlugin() {},
  };
  figma.root = new Node("DOCUMENT", figma);
  figma.createPage().name = "Cover";
  return { figma, state: { collections, variables, textStyles } };
}

async function run(options, existing, mutateCode) {
  const { figma, state } = existing || makeFigma(options);
  let report = null;
  figma.ui.postMessage = (msg) => { report = msg.report; };

  const sandbox = { figma, console: { log() {}, warn() {}, error() {} }, __html__: "" };
  vm.createContext(sandbox);
  vm.runInContext(mutateCode ? mutateCode(CODE) : CODE, sandbox);

  // The plugin's top-level IIFE is async; drain the microtask queue.
  for (let i = 0; i < 200 && report === null; i++) await new Promise((r) => setImmediate(r));
  if (report === null) throw new Error("plugin never reported");
  return { report, state, figma };
}

const MAC = { "New York": ["Bold"], "SF Pro": ["Regular", "Semibold", "Bold", "Medium"],
              "SF Pro Text": ["Regular", "Semibold", "Bold", "Medium"],
              "SF Mono": ["Regular", "Semibold", "Bold"], Inter: ["Regular"] };
const BROWSER = { Inter: ["Regular", "Semi Bold", "Bold", "Medium"] };

// A live instance is one a user can actually see: its parent chain reaches a page.
// Pushing a bare { mainComponent } models an orphan, not a live instance, and since
// 2026-09-27 the plugin correctly ignores those.
function placeInstance(figma, mainComponent, pageName) {
  const page = figma.root.children.find((p) => p.name === pageName) || figma.root.children[0];
  const inst = { type: "INSTANCE", name: "instance", mainComponent: mainComponent,
                 removed: false, parent: page };
  figma._instances.push(inst);
  return inst;
}

let failures = 0;
function expect(label, condition, detail) {
  if (condition) {
    console.log("  PASS  " + label);
  } else {
    failures++;
    console.log("  FAIL  " + label + (detail ? "\n          " + detail : ""));
  }
}

(async () => {
  console.log("\n1. Paid plan (modes available), Mac fonts");
  {
    const { report, state } = await run({ allowModes: true, fonts: MAC });
    expect("self-verification passes", /^VERIFIED/m.test(report), report);
    expect("one colour collection with two modes",
      state.collections.some((c) => c.name === "Sous Color" && c.modes.length === 2));
    expect("modes named Light and Dark",
      state.collections.some((c) => c.name === "Sous Color" &&
        c.modes.map((m) => m.name).sort().join() === "Dark,Light"));
    expect("no Sous Color Dark collection",
      !state.collections.some((c) => c.name === "Sous Color Dark"));
    expect("uses the real Apple faces", /New York/.test(report) && /SF Pro x8/.test(report), report);
    const prims = state.collections.find((c) => c.name === "Sous Primitives");
    expect("primitives hidden from pickers",
      state.variables.filter((v) => v.variableCollectionId === prims.id)
        .every((v) => v.scopes.length === 0));
    const canvas = state.variables.find((v) => v.name === "background/canvas");
    expect("semantic colors carry their Swift name",
      canvas.codeSyntax.iOS === "Color.sousBackground", JSON.stringify(canvas.codeSyntax));
    const small = state.variables.find((v) => v.name === "icon/small");
    expect("icon sizes carry their Swift name and font-size scope",
      small.codeSyntax.iOS === "SousIconSize.small" && small.scopes.includes("FONT_SIZE"));
    expect("no variable left on ALL_SCOPES",
      state.variables.every((v) => !v.scopes.includes("ALL_SCOPES")),
      state.variables.filter((v) => v.scopes.includes("ALL_SCOPES")).map((v) => v.name).join(", "));
  }

  console.log("\n2. Starter plan (no modes), Mac fonts");
  let starter;
  {
    const r = await run({ allowModes: false, fonts: MAC });
    starter = r;
    expect("self-verification passes", /^VERIFIED/m.test(r.report), r.report);
    expect("falls back to two collections",
      r.state.collections.some((c) => c.name === "Sous Color") &&
      r.state.collections.some((c) => c.name === "Sous Color Dark"));
    expect("report explains the fallback", /Starter plan, no modes/.test(r.report), r.report);
    const dark = r.state.collections.find((c) => c.name === "Sous Color Dark");
    const canvas = r.state.variables.find(
      (v) => v.name === "background/canvas" && v.variableCollectionId === dark.id);
    const ink = r.state.variables.find((v) => v.name === "ink/900");
    expect("dark background/canvas aliases ink/900",
      canvas && canvas.valuesByMode[dark.modes[0].modeId].id === ink.id);
  }

  console.log("\n3. Running twice does not duplicate");
  {
    const before = starter.state.variables.length;
    await run(null, starter);
    expect("variable count unchanged after a second run",
      starter.state.variables.length === before,
      `was ${before}, now ${starter.state.variables.length}`);
    expect("text style count unchanged", starter.state.textStyles.length === 17,
      `got ${starter.state.textStyles.length}`);
  }

  console.log("\n4. Browser (Apple fonts unavailable)");
  {
    const { report } = await run({ allowModes: true, fonts: BROWSER });
    expect("still verifies", /^VERIFIED/m.test(report), report);
    expect("warns about substituted fonts", /substituted/.test(report), report);
  }

  console.log("\n5. The self-check actually catches a bad write");
  {
    const { figma, state } = makeFigma({ allowModes: true, fonts: MAC });
    const realCreate = figma.variables.createVariable;
    figma.variables.createVariable = function (name, collection, type) {
      const v = realCreate.call(this, name, collection, type);
      if (name === "burgundy/700") {
        v.setValueForMode = function (modeId, _value) {
          this.valuesByMode[modeId] = { r: 0, g: 1, b: 0, a: 1 };  // sabotage
        };
      }
      return v;
    };
    const { report } = await run(null, { figma, state });
    expect("reports FAILED", /^FAILED/m.test(report), report);
    expect("names the sabotaged token", /burgundy\/700/.test(report), report);
  }

  console.log("\n6. Components: Button");
  {
    const { report, state, figma } = await run({ allowModes: false, fonts: MAC });
    expect("report verifies components too", /^VERIFIED/m.test(report) && /Button \(12 variants\)/.test(report), report);
    expect("report lists every component",
      /Section Header \(3 variants\)/.test(report) && /Ingredient Group Header/.test(report) &&
      /List Row \(7 variants\)/.test(report), report);
    const rowSet = figma.root.children.find((p) => p.name === "List Row").children
      .find((n) => n.type === "COMPONENT_SET" && n.name === "List Row");
    const byName = (n) => rowSet.children.find((c) => c.name === n);
    const textOf = (n) => byName(n).findOne((x) => x.name === "text");
    const deco = (n) => textOf(n).getRangeTextDecoration(0, textOf(n).characters.length);

    expect("ticked ingredient is NOT struck through",
      deco("State=Checked, Timer=No") !== "STRIKETHROUGH" &&
      byName("State=Checked, Timer=No").findOne((x) => x.name === "checkbox").mainComponent.name
        === "State=Checked, Size=Default");
    expect("Done row is struck through and nothing else is",
      deco("State=Done, Timer=No") === "STRIKETHROUGH" &&
      deco("State=To Do, Timer=No") !== "STRIKETHROUGH" &&
      deco("State=Checked, Timer=No") !== "STRIKETHROUGH" &&
      deco("State=Current, Timer=No") !== "STRIKETHROUGH",
      "to do " + deco("State=To Do, Timer=No") + ", checked " + deco("State=Checked, Timer=No"));
    expect("List Row has no shared Text property (it would flatten the variants)",
      !Object.keys(rowSet.componentPropertyDefinitions || {}).some((k) => k.indexOf("Text") === 0),
      Object.keys(rowSet.componentPropertyDefinitions || {}).join(","));
    expect("done step IS struck through and muted",
      deco("State=Done, Timer=No") === "STRIKETHROUGH" &&
      state.variables.find((v) => v.id === textOf("State=Done, Timer=No").getRangeFills(0, 1)[0].boundVariables.color.id).name === "text/muted");
    expect("current row is bold", textOf("State=Current, Timer=No").fontName.style === "Bold");
    expect("no timer on Checked or Done rows",
      !rowSet.children.some((c) => /State=(Checked|Done), Timer=Yes/.test(c.name)));
    const timed = textOf("State=To Do, Timer=Yes");
    expect("timer duration burgundy, with the glyph",
      /\u{100431}/u.test(timed.characters) &&
      state.variables.find((v) => v.id === timed.getRangeFills(
        timed.characters.indexOf("10 minutes"), timed.characters.indexOf("10 minutes") + 10)[0].boundVariables.color.id).name === "text/accent");
    const todo = byName("State=To Do, Timer=No");
    expect("indent and notes start hidden, checkbox shown",
      todo.findOne((x) => x.name === "indent").visible === false &&
      todo.findOne((x) => x.name === "notes").visible === false &&
      todo.findOne((x) => x.name === "checkbox-slot").visible === true);
    expect("separator spacers follow the same switches as the row",
      todo.findOne((x) => x.name === "sep-indent").componentPropertyReferences.visible ===
        todo.findOne((x) => x.name === "indent").componentPropertyReferences.visible &&
      todo.findOne((x) => x.name === "sep-checkbox").componentPropertyReferences.visible ===
        todo.findOne((x) => x.name === "checkbox-slot").componentPropertyReferences.visible);
    // Page order: Screens is the library's output, so it sits directly under Cover
    // rather than wherever its builder happened to run. Only those two positions
    // are asserted — the component pages keep their own relative order.
    expect("Cover is first and Screens is second",
      figma.root.children[0].name === "Cover" && figma.root.children[1].name === "Screens",
      figma.root.children.slice(0, 4).map((p) => p.name).join(", "));
    expect("ordering moved Screens rather than duplicating it",
      figma.root.children.filter((p) => p.name === "Screens").length === 1,
      String(figma.root.children.filter((p) => p.name === "Screens").length));

    expect("the three old row pages are gone",
      !["Ingredient Row", "Step Row", "Mise en Place Row"].some(
        (n) => figma.root.children.some((p) => p.name === n)),
      figma.root.children.map((p) => p.name).join(", "));

    const sh = figma.root.children.find((p) => p.name === "Section Header").children.find((n) => n.type === "COMPONENT_SET");
    const collapsed = sh.children.find((c) => c.name === "State=Collapsed").findOne((x) => x.name === "chevron");
    expect("Collapsed chevron turned -90°", collapsed.rotation === -90, String(collapsed.rotation));

    // Icon Button gained a fourth scheme, On Accent, with the timer banner: the
    // 32pt square on burgundy rather than on cream.
    expect("report lists the chrome components",
      /Icon Button \(4 variants\)/.test(report) && /Recipe Title \(2 variants\)/.test(report), report);

    // Sign In / Paywall — the billing-and-onboarding pair, added 2026-09-24.
    expect("report lists the sign-in and paywall pieces",
      /Apple Sign In Button \(2 variants\)/.test(report) && /Benefit Row/.test(report) &&
      /Sign In screen/.test(report) && /Paywall screen/.test(report), report);
    const screensPage = figma.root.children.find((p) => p.name === "Screens");
    const signIn = screensPage.children.find((x) => x.name === "Sign In");
    const paywall = screensPage.children.find((x) => x.name === "Paywall");
    expect("Sign In and Paywall are both on the Screens page", !!signIn && !!paywall,
      screensPage.children.map((c) => c.name).join(", "));
    const appleSet = figma.root.children.find((p) => p.name === "Apple Sign In Button").children
      .find((n) => n.type === "COMPONENT_SET");
    const light = appleSet.children.find((c) => c.name === "Scheme=Light");
    expect("Apple's button is square, at Sous's size, in Apple's own colour",
      light.width === 345 && light.height === 50 && light.topLeftRadius === 0 &&
      !!(light.boundVariables && light.boundVariables.topLeftRadius) &&
      !(light.fills[0].boundVariables && light.fills[0].boundVariables.color),
      light.width + "x" + light.height + " r" + light.topLeftRadius);
    expect("Paywall lists four benefits",
      paywall.findAll((n) => /^benefit-\d+$/.test(n.name)).length === 4,
      String(paywall.findAll((n) => /^benefit-\d+$/.test(n.name)).length));
    const ctaNode = paywall.findOne((x) => x.name === "cta");
    expect("Paywall CTA is 52pt tall in the 20pt gutter",
      !!ctaNode && Math.round(ctaNode.height) === 52 && ctaNode.x === 20,
      ctaNode ? ctaNode.height + " @ " + ctaNode.x : "missing");

    // Cap Reached — built entirely from the Paywall's parts, which is the point of it.
    expect("report lists the Cap Reached screen", /Cap Reached screen/.test(report), report);

    // Timer Banner — the running bar and the done panel, measured on device.
    expect("report lists the Timer Banner", /Timer Banner \(2 variants\)/.test(report), report);
    const tbSet = figma.root.children.find((p) => p.name === "Timer Banner").children
      .find((n) => n.type === "COMPONENT_SET");
    const tbRunning = tbSet.children.find((c) => c.name === "State=Running");
    const tbDone = tbSet.children.find((c) => c.name === "State=Done");
    expect("Timer Banner heights match the device: 52pt running, 300pt done",
      tbRunning.height === 52 && tbDone.height === 300,
      tbRunning.height + " / " + tbDone.height);
    expect("the running banner's pencil is an Icon Button instance, not a redrawn square",
      !!tbRunning.findOne((x) => x.name === "adjust" && x.type === "INSTANCE"));
    // On Accent's border is white at 50% and deliberately unbound — Sous has no
    // white-on-accent chrome token. If someone later binds it to a colour variable
    // this fails, which is the point: that would be inventing a token by accident.
    const onAccent = figma.root.children.find((p) => p.name === "Icon Button").children
      .find((n) => n.type === "COMPONENT_SET").children.find((c) => c.name === "Style=On Accent");
    expect("On Accent is a 32pt square bordered in unbound white at 50%",
      onAccent.width === 32 && onAccent.height === 32 &&
      Math.abs(onAccent.strokes[0].opacity - 0.5) < 1e-6 && onAccent.strokes[0].color.r === 1 &&
      !(onAccent.strokes[0].boundVariables && onAccent.strokes[0].boundVariables.color),
      JSON.stringify(onAccent.strokes[0]));
    // Import: the three modes behind the chooser, plus the header they share.
    expect("report lists the import pieces",
      /Import Sheet Header \(2 variants\)/.test(report) && /Progress Bar/.test(report) &&
      /Import Paste screen/.test(report) && /Import Loading screen/.test(report) &&
      /Import Error screen/.test(report), report);
    for (const n of ["Import Paste", "Import Loading", "Import Error"]) {
      expect(n + " is on the Screens page",
        screensPage.children.some((c) => c.name === n),
        screensPage.children.map((c) => c.name).join(", "));
    }
    // The chooser was drawn with its own inline header until the component existed.
    // If it ever goes back to drawing one, this fails.
    const chooser = screensPage.children.find((x) => x.name === "Talk to a Recipe");
    const chooserHeader = chooser.findOne((x) => x.name === "header");
    expect("the chooser reuses the shared header rather than drawing its own",
      !!chooserHeader && chooserHeader.type === "INSTANCE",
      chooserHeader ? chooserHeader.type : "no header");
    // The back button is Icon Button with a different glyph — not a second square.
    const hdrSet = figma.root.children.find((p) => p.name === "Import Sheet Header").children
      .find((n) => n.type === "COMPONENT_SET");
    const backVariant = hdrSet.children.find((c) => c.name === "Back=Yes");
    expect("the import back button is an Icon Button instance, not a redrawn square",
      !!backVariant.findOne((x) => x.name === "back" && x.type === "INSTANCE"));
    // Camera and library are Apple's pickers: documented, never drawn.
    expect("no camera or library screen was invented",
      !screensPage.children.some((c) => /^Import (Camera|Library)$/.test(c.name)),
      screensPage.children.map((c) => c.name).join(", "));
    const bar = figma.root.children.find((p) => p.name === "Progress Bar").children
      .find((n) => n.type === "COMPONENT");
    expect("the progress bar is 2pt, as measured on device", bar.height === 2, String(bar.height));

    // The chat sheet's last furniture: the attachment strip and the quoted chip.
    expect("report lists the chat furniture",
      /Attachment Strip \(3 variants\)/.test(report) && /Quoted Context Chip/.test(report),
      report);
    const stripSet = figma.root.children.find((p) => p.name === "Attachment Strip").children
      .find((n) => n.type === "COMPONENT_SET");
    // Idle draws nothing, so it must NOT become a fourth, empty variant.
    expect("the attachment strip has three variants, not four",
      stripSet.children.length === 3 &&
      !stripSet.children.some((c) => /Idle/.test(c.name)),
      stripSet.children.map((c) => c.name).join(", "));
    const chip = figma.root.children.find((p) => p.name === "Quoted Context Chip").children
      .find((n) => n.type === "COMPONENT");
    const stripe = chip.findOne((x) => x.name === "accent-stripe");
    // Absolute, or it stretches the row — the note the component carries.
    expect("the chip's stripe is an absolute overlay 3pt wide",
      stripe.layoutPositioning === "ABSOLUTE" && stripe.width === 3,
      stripe.layoutPositioning + " w" + stripe.width);
    const chipProps = Object.keys(chip.componentPropertyDefinitions || {}).map((k) => k.split("#")[0]);
    expect("the chip carries Kind and Quote as separate text properties",
      chipProps.includes("Kind") && chipProps.includes("Quote"), chipProps.join(", "));

    // Mise en place: the modal, and the Split Action Bar it shares with the wheel sheets.
    expect("report lists the mise en place pieces",
      /Split Action Bar \(2 variants\)/.test(report) && /Mise en Place screen/.test(report),
      report);
    const splitSet = figma.root.children.find((p) => p.name === "Split Action Bar").children
      .find((n) => n.type === "COMPONENT_SET");
    for (const tone of ["Tone=Accent", "Tone=Ink"]) {
      const bar = splitSet.children.find((c) => c.name === tone);
      const left = bar.findOne((x) => x.name === "left");
      const right = bar.findOne((x) => x.name === "right");
      // The left half must carry no border of its own. The mise en place modal used
      // to draw one inside the outer border: invisible, both being ink, but a stroke
      // straddles its path so that half rendered fractionally wider.
      expect(tone + ": the quiet half has no border of its own",
        left.strokes.length === 0, JSON.stringify(left.strokes));
      expect(tone + ": both halves grow equally",
        left.layoutGrow === 1 && right.layoutGrow === 1);
      expect(tone + ": split by a 1pt hairline",
        !!bar.findOne((x) => x.name === "divider" && x.width === 1));
    }
    const mep = screensPage.children.find((x) => x.name === "Mise en Place");
    expect("the modal is assembled from components, not redrawn",
      !!mep.findOne((x) => x.name === "actions" && x.type === "INSTANCE") &&
      !!mep.findOne((x) => x.name === "checkbox" && x.type === "INSTANCE"));
    // Picker Sheet keeps drawing its own bar on purpose: a component property cannot
    // be forwarded into a nested instance, so instancing would cost it Left/Right
    // and with them its ability to serve all three wheel sheets.
    const wheelSet = figma.root.children.find((p) => p.name === "Picker Sheet").children
      .find((n) => n.type === "COMPONENT_SET");
    const pickerProps = Object.keys(wheelSet.componentPropertyDefinitions || {})
      .map((k) => k.split("#")[0]);
    expect("Picker Sheet keeps its own Left and Right properties",
      pickerProps.includes("Left") && pickerProps.includes("Right"), pickerProps.join(", "));

    // Photo acquisition: the one control Sous draws inside Apple's viewfinder.
    expect("report lists the photo acquisition pieces",
      /Camera Overlay Button/.test(report) && /Photo Acquisition screen/.test(report) &&
      /Photo Acquisition Failed screen/.test(report), report);
    const overlay = figma.root.children.find((p) => p.name === "Camera Overlay Button").children
      .find((n) => n.type === "COMPONENT");
    // Round on purpose — the single deliberate exception to Sous's square rule.
    expect("the camera overlay button is round, at 50pt",
      overlay.width === 50 && overlay.height === 50 && overlay.cornerRadius === 25,
      overlay.width + "x" + overlay.height + " r" + overlay.cornerRadius);
    // Its fill stands in for a system blur, so it must not claim to be a token.
    expect("its fill is an unbound white standing in for .ultraThinMaterial",
      overlay.fills[0].color.r === 1 &&
      Math.abs(overlay.fills[0].opacity - 0.18) < 1e-6 &&
      !(overlay.fills[0].boundVariables && overlay.fills[0].boundVariables.color),
      JSON.stringify(overlay.fills[0]));
    const camScreen = screensPage.children.find((x) => x.name === "Photo Acquisition");
    expect("the viewfinder is recorded as a note, never redrawn",
      !!camScreen.findOne((x) => x.name === "apple-note"));
    expect("the overlay button is placed at the offsets the app uses",
      !!camScreen.findOne((x) => x.name === "library-button" && x.x === 30));
    // The failure sheet is always black, so nothing on it may use a mode-aware accent:
    // in light mode that resolves to #8B2E3F, which measures 2.56:1 on black.
    const failScreen = screensPage.children.find((x) => x.name === "Photo Acquisition Failed");
    const dismiss = failScreen.findOne((x) => x.name === "dismiss");
    const dismissVar = state.variables.find(
      (v) => dismiss && dismiss.fills[0].boundVariables &&
             v.id === dismiss.fills[0].boundVariables.color.id);
    expect("DISMISS is white, not the accent that would measure 2.56:1 on black",
      !!dismissVar && dismissVar.name === "text/onInverse",
      dismissVar ? dismissVar.name : "unbound");

    // The label and countdown must read as one line, and the label must stay in
    // sentence case — it is the recipe step, not a button label, even though it
    // borrows Sous/Button's metrics.
    const tbLabel = tbRunning.findOne((x) => x.name === "label");
    const tbReadout = tbRunning.findOne((x) => x.name === "readout");
    expect("banner label and countdown are both vertically centred",
      tbLabel.textAlignVertical === "CENTER" && tbReadout.textAlignVertical === "CENTER",
      tbLabel.textAlignVertical + " / " + tbReadout.textAlignVertical);
    expect("the banner label is not uppercased",
      tbLabel.textCase === "ORIGINAL", String(tbLabel.textCase));
    // Four separate text properties, not two shared ones: Running's label is
    // Sous/Button and Done's heading is Sous/Title, and a shared TEXT property
    // would force one styling across both.
    const tbProps = Object.keys(tbSet.componentPropertyDefinitions || {}).map((k) => k.split("#")[0]);
    expect("Timer Banner keeps its four text properties separate",
      ["Label", "Readout", "Heading", "Done Readout"].every((n) => tbProps.includes(n)),
      tbProps.join(", "));

    // Picker Sheet — the three wheel sheets collapsed into one component.
    expect("report lists the Picker Sheet", /Picker Sheet \(2 variants\)/.test(report), report);

    // List Row's Roomy switch — the canvas keeps its compact rows, iOS-laid-out lists
    // get more air. Structure is shared; density is not.
    const lrSet = figma.root.children.find((p) => p.name === "List Row").children
      .find((n) => n.type === "COMPONENT_SET");
    const lrDefs = Object.keys(lrSet.componentPropertyDefinitions || {});
    // Swipe actions are documented, not drawn: iOS owns the capsule, Sous owns the tint.
    const lrPage = figma.root.children.find((p) => p.name === "List Row");
    expect("List Row documents its swipe tints",
      !!lrPage.children.find((x) => x.name === "List Row / Swipe tints"),
      lrPage.children.map((c) => c.name).join(", "));
    const tintPanel = lrPage.children.find((x) => x.name === "List Row / Swipe tints");
    expect("both swipe tints are named — the green Done and the burgundy Ask Sous",
      !!tintPanel.findOne((x) => x.name === "chip status/added") &&
      !!tintPanel.findOne((x) => x.name === "chip accent/primary"));

    expect("List Row exposes Roomy", lrDefs.some((k) => k === "Roomy" || k.indexOf("Roomy#") === 0),
      lrDefs.join(", "));
    const lrVariant = lrSet.children[0];
    expect("Roomy is off by default — the canvas is where this row mostly lives",
      lrVariant.findOne((x) => x.name === "air-top").visible === false);
    const memScreen = screensPage.children.find((x) => x.name === "Memories");
    expect("Memories turns Roomy on",
      !!memScreen && memScreen.findOne((x) => x.name === "memory-1")
        .findOne((x) => x.name === "air-top").visible === true);
    const pickerSet = figma.root.children.find((p) => p.name === "Picker Sheet").children
      .find((n) => n.type === "COMPONENT_SET");
    const one = pickerSet.children.find((c) => c.name === "Wheels=One");
    const two = pickerSet.children.find((c) => c.name === "Wheels=Two");
    expect("Picker Sheet has a one-wheel and a two-wheel variant", !!one && !!two,
      pickerSet.children.map((c) => c.name).join(", "));
    expect("one wheel counts people, two count hours and minutes",
      one.findAll((n) => n.name.indexOf("wheel ") === 0).length === 1 &&
      two.findAll((n) => n.name.indexOf("wheel ") === 0).length === 2);
    const pickerActions = two.findOne((x) => x.name === "actions");
    expect("both actions sit inside one ink border, not two buttons",
      !!pickerActions && pickerActions.strokes.length === 1 &&
      state.variables.find((v) => v.id === pickerActions.strokes[0].boundVariables.color.id).name === "border/strong");
    expect("the readout and footer are off by default",
      two.findOne((x) => x.name === "readout").visible === false &&
      two.findOne((x) => x.name === "footer").visible === false);
    const cap = screensPage.children.find((x) => x.name === "Cap Reached");
    expect("Cap Reached is on the Screens page", !!cap,
      screensPage.children.map((c) => c.name).join(", "));
    const capMains = [];
    for (const i of cap.findAll((n) => n.type === "INSTANCE")) {
      const m = i.mainComponent;
      capMains.push(m ? (m.parent && m.parent.type === "COMPONENT_SET" ? m.parent.name : m.name) : "detached");
    }
    expect("Cap Reached adds no new components — two Buttons, an Icon Button, a Section Header",
      capMains.filter((n) => n === "Button").length === 2 &&
      capMains.filter((n) => n === "Icon Button").length === 1 &&
      capMains.filter((n) => n === "Section Header").length === 1 &&
      !capMains.includes("detached"), capMains.join(", "));
    const capNote = cap.findOne((x) => x.name === "body");
    const capMsg = cap.findOne((x) => x.name === "message");
    expect("Cap Reached note clears its buttons",
      !!capNote && !!capMsg && capNote.y + capNote.height <= capMsg.y,
      capNote && capMsg ? Math.round(capNote.y + capNote.height) + " vs " + Math.round(capMsg.y) : "missing");
    const ib = figma.root.children.find((p) => p.name === "Icon Button").children
      .find((n) => n.type === "COMPONENT_SET");
    const accent = ib.children.find((c) => c.name === "Style=Accent");
    expect("hamburger is a 44pt burgundy square with a glyph",
      accent.width === 44 && accent.height === 44 &&
      state.variables.find((v) => v.id === accent.fills[0].boundVariables.color.id).name === "accent/primary" &&
      // SF Symbol glyphs sit above U+FFFF, so JS counts each as two code units.
      Array.from(accent.findOne((x) => x.name === "icon").characters).length === 1,
      accent.width + "x" + accent.height);
    expect("bordered icon button is 32pt with no fill",
      ib.children.find((c) => c.name === "Style=Bordered").width === 32 &&
      ib.children.find((c) => c.name === "Style=Bordered").fills.length === 0);
    const rt = figma.root.children.find((p) => p.name === "Recipe Title").children
      .find((n) => n.type === "COMPONENT_SET");
    const withServings = rt.children.find((c) => c.name === "Servings=Yes");
    const without = rt.children.find((c) => c.name === "Servings=No");
    expect("servings row only on the Servings=Yes variant",
      withServings.findOne((x) => x.name === "servings-row").visible === true &&
      without.findOne((x) => x.name === "servings-row").visible === false);
    expect("title is centred, capitals, and clears the hamburger",
      withServings.findOne((x) => x.name === "title").textAlignHorizontal === "CENTER" &&
      withServings.findOne((x) => x.name === "title-block").paddingLeft === 76);

    expect("report lists the assembled screen", /Recipe Canvas screen/.test(report), report);
    const screen = figma.root.children.find((p) => p.name === "Screens").children
      .find((n) => n.name === "Recipe Canvas");
    expect("screen is iPhone-sized, 393 x 852", screen.width === 393 && screen.height === 852,
      screen.width + "x" + screen.height);
    const insts = screen.findAll((n) => n.type === "INSTANCE");
    const setOf = (i) => (i.mainComponent.parent && i.mainComponent.parent.type === "COMPONENT_SET"
      ? i.mainComponent.parent.name : i.mainComponent.name);
    const tally = insts.reduce((acc, i) => {
      const k = setOf(i); acc[k] = (acc[k] || 0) + 1; return acc;
    }, {});
    expect("screen is built only from components — 8 rows, 2 headers, title, menu, bottom bar",
      insts.every((i) => !!i.mainComponent) && tally["List Row"] === 8 &&
      tally["Section Header"] === 2 && tally["Recipe Title"] === 1 &&
      tally["Icon Button"] === 1 && tally["Bottom Bar"] === 1 && tally["Checkbox"] === 8,
      JSON.stringify(tally));
    const rowTexts = screen.findAll((n) => n.type === "TEXT" && n.name === "text");
    const doneRow = rowTexts.find((t) => t.characters.indexOf("Pat the thighs") === 0);
    expect("the done step is struck through on the screen itself",
      doneRow.getRangeTextDecoration(0, doneRow.characters.length) === "STRIKETHROUGH");
    const seared = rowTexts.find((t) => t.characters.indexOf("Sear skin-side") === 0);
    expect("the current step keeps bold text and a burgundy duration",
      seared.fontName.style === "Bold" &&
      state.variables.find((v) => v.id === seared.getRangeFills(
        seared.characters.indexOf("10 minutes"), seared.characters.indexOf("10 minutes") + 10)[0]
        .boundVariables.color.id).name === "text/accent",
      seared.fontName.style);
    expect("ingredient text was actually replaced",
      rowTexts.some((t) => t.characters === "4 bone-in, skin-on chicken thighs"),
      rowTexts.map((t) => t.characters.slice(0, 20)).join(" | "));

    const page = figma.root.children.find((p) => p.name === "Button");
    const childCount = page.children.length;

    // Re-run with nothing using the Button: rebuilt in place, no duplicates.
    const again = await run(null, { figma, state });
    expect("re-run rebuilds without duplicating", page.children.length === childCount &&
      page.children.filter((n) => n.type === "COMPONENT_SET").length === 1,
      page.children.map((n) => n.name).join(" | "));
    expect("re-run still verifies", /^VERIFIED/m.test(again.report), again.report);

    // Once something uses the Button, the plugin must refuse to rebuild it.
    const liveSet = page.children.find((n) => n.type === "COMPONENT_SET");
    placeInstance(figma, liveSet.children[0], "Button");
    const guarded = await run(null, { figma, state });
    expect("in-use Button is left alone", page.children.includes(liveSet), "set was replaced");
    expect("report explains why and where", /not rebuilt: 1 instance\(s\) still use it/.test(guarded.report), guarded.report);
  }

  console.log("\n6a. Symbols come from the table, and an existing Checkbox is preserved");
  {
    const { report, figma, state } = await run({ allowModes: false, fonts: MAC });
    expect("symbols drawn from the table", /SF Symbols: \d+ of \d+ drawn; table has 34/.test(report), report);
    expect("no blank symbols", !/blank:/.test(report), report);
    expect("first run builds the Checkbox", /Checkbox \(4 variants\)/.test(report), report);
    // An existing Checkbox is never rebuilt, so corrections must reach it in place.
    const cb = figma.root.children.find((p) => p.name === "Checkbox").children
      .find((n) => n.type === "COMPONENT_SET");
    cb.children.forEach((c) => { c.strokeAlign = "CENTER"; });       // simulate the old one
    const repaired = await run(null, { figma, state });
    expect("an existing Checkbox still gets border fixes",
      cb.children.every((c) => c.strokeAlign === "INSIDE") && /borders squared up/.test(repaired.report),
      repaired.report);
    const cbSet = figma.root.children.find((p) => p.name === "Checkbox").children
      .find((n) => n.type === "COMPONENT_SET");
    const firstIds = cbSet.children.map((c) => c.id);
    const again = await run(null, { figma, state });
    expect("nothing is blocked by instances deleted earlier in the same run",
      !/not rebuilt/.test(again.report), again.report);
    expect("a second run still rebuilds every component despite the assembled screen",
      /Button \(12 variants\)/.test(again.report) && /List Row \(7 variants\)/.test(again.report) &&
      /Recipe Canvas screen/.test(again.report) && !/not rebuilt/.test(again.report), again.report);
    expect("second run keeps it untouched",
      /Checkbox \(kept/.test(again.report) &&
      figma.root.children.find((p) => p.name === "Checkbox").children
        .find((n) => n.type === "COMPONENT_SET").children.map((c) => c.id).join() === firstIds.join(),
      again.report);
    const stepText = figma.root.children.find((p) => p.name === "List Row").children
      .find((n) => n.type === "COMPONENT_SET" && n.name === "List Row").children
      .find((c) => c.name === "State=To Do, Timer=Yes").findOne((x) => x.name === "text");
    expect("timer glyph now in the step text", /\u{100431}/u.test(stepText.characters), JSON.stringify(stepText.characters));
  }

  console.log("\n6c. The rebuilt Checkbox carries a real checkmark");
  {
    const { figma, state } = makeFigma({ allowModes: true, fonts: MAC });
    const { report } = await run(null, { figma, state });
    expect("Checkbox built when missing", /Checkbox \(4 variants\)/.test(report), report);
    expect("still verifies", /^VERIFIED/m.test(report), report);
    const cb = figma.root.children.find((p) => p.name === "Checkbox").children
      .find((n) => n.type === "COMPONENT_SET").children
      .find((c) => c.name === "State=Checked, Size=Default").findOne((x) => x.name === "checkmark");
    expect("checkmark glyph present and visible", cb.visible && /\u{100185}/u.test(cb.characters), JSON.stringify(cb.characters));
  }

  console.log("\n6b. SF Symbols unavailable in this Figma app");
  {
    const { figma, state } = makeFigma({ allowModes: true, fonts: MAC });
    delete figma.util.getSfSymbolCharacter;
    const { report } = await run(null, { figma, state }, (code) =>
      code.replace('"message": "100324",\n', ""));   // drop one name from the table
    expect("missing symbol is named and counted",
      /blank: message/.test(report) && /"message" is blank — not in design\/sf-symbols\.json/.test(report), report);
    expect("says why once, not once per use",
      (report.match(/"message" is blank/g) || []).length === 1, report);
    expect("everything else still verifies", /^VERIFIED/m.test(report), report);
  }

  console.log("\n6e. An in-use Icon Button must not take the whole import down with it");
  {
    // This is the operator's real file on 2026-09-27: Icon Button had instances
    // placed by hand, so it could not be rebuilt, so its new On Accent variant
    // never appeared — and Timer Banner, which instances it, threw and aborted
    // the run after the tokens had landed but before any component did.
    const { figma, state } = await run({ allowModes: false, fonts: MAC });
    const ibSet = figma.root.children.find((p) => p.name === "Icon Button").children
      .find((n) => n.type === "COMPONENT_SET");
    // Pin an instance on it and drop the variant this run would have added, which
    // is exactly the state a stale file is in before the plugin runs.
    placeInstance(figma, ibSet.children[0], "Icon Button");
    const onAccent = ibSet.children.find((c) => c.name === "Style=On Accent");
    if (onAccent) ibSet.children.splice(ibSet.children.indexOf(onAccent), 1);

    const blocked = await run(null, { figma, state });
    expect("the import still completes instead of aborting",
      !/import failed/.test(blocked.report), blocked.report);
    expect("it still verifies rather than reporting FAILED",
      /^VERIFIED/m.test(blocked.report), blocked.report);
    expect("the report says Icon Button was not rebuilt, and where",
      /Icon Button was not rebuilt: 1 instance\(s\) still use it/.test(blocked.report),
      blocked.report);
    expect("the report says Timer Banner was skipped, and why",
      /Timer Banner was not built: it needs Icon Button's On Accent variant/.test(blocked.report),
      blocked.report);
    expect("a half-built Timer Banner is never left behind",
      !/Timer Banner \(\d+ variants\)/.test(blocked.report), blocked.report);
  }

  console.log("\n6g. Instances orphaned inside a deleted screen must not block a rebuild");
  {
    // The operator's file, 2026-09-27: the generated screens are cleared at the
    // start of every run, and the Buttons, Icon Buttons and Badges inside them are
    // then orphaned — Figma leaves them removed = false and still lists them, so
    // they looked like live users of those components and blocked all three. The
    // report could only call them "unknown page", which is the tell.
    const { figma, state } = await run({ allowModes: false, fonts: MAC });
    const ibSet = figma.root.children.find((p) => p.name === "Icon Button").children
      .find((n) => n.type === "COMPONENT_SET");
    const screens = figma.root.children.find((p) => p.name === "Screens");
    const screen = screens.children[0];
    const orphan = { type: "INSTANCE", name: "hamburger", mainComponent: ibSet.children[0],
                     removed: false, parent: screen };
    figma._instances.push(orphan);
    screen.remove();                        // as clearGeneratedScreens does each run

    expect("Figma leaves the orphan looking alive", orphan.removed === false);
    const after = await run(null, { figma, state });
    expect("an orphaned instance does not block the rebuild",
      !/Icon Button was not rebuilt/.test(after.report), after.report);
    expect("Icon Button rebuilds with all four schemes",
      /Icon Button \(4 variants\)/.test(after.report), after.report);
    expect("and Timer Banner builds off the back of it",
      /Timer Banner \(2 variants\)/.test(after.report), after.report);
    expect("the report no longer says 'unknown page'",
      !/unknown page/.test(after.report), after.report);
  }

  console.log("\n6f. A genuine failure still names itself in the report");
  {
    // One component throwing must not cost the run: it is reported as a named
    // failed check, and everything after it still builds.
    const { report } = await run({ allowModes: true, fonts: MAC }, null, (code) =>
      code.replace("async function buildTimerBanner() {",
        "async function buildTimerBanner() { throw new Error('a very specific explosion');"));
    expect("a thrown component error reaches the report",
      /a very specific explosion/.test(report), report);
    expect("it is reported as a failure, not swallowed",
      /^FAILED/m.test(report) && /component Timer Banner built/.test(report), report);
    expect("the components after it still build",
      /Progress Bar/.test(report) && /Memories screen/.test(report), report);
    expect("and the run completes rather than aborting",
      !/import failed/.test(report), report);
  }

  console.log("\n6h. A fatal error outside the component loop still reports its message");
  {
    // The abort the operator saw printed only "at getVariant(...)" with no message,
    // which is unactionable. Whatever throws, the message must reach the report.
    const { report } = await run({ allowModes: true, fonts: MAC }, null, (code) =>
      code.replace("async function buildTextStyles() {",
        "async function buildTextStyles() { throw new Error('a very specific explosion');"));
    expect("a fatal error's message reaches the report",
      /a very specific explosion/.test(report), report);
    expect("the report still says how far it got",
      /Progress before the failure/.test(report), report);
  }

  console.log("\n6d. Retiring the three old row pages (as they exist in SousWork)");
  {
    const { figma, state } = makeFigma({ allowModes: false, fonts: MAC });
    await run(null, { figma, state });

    // Recreate the pages the merge replaces, left UNLOADED — the state a real
    // file is in, and the one that crashed the plugin on 2026-09-24.
    const legacy = {};
    for (const name of ["Ingredient Row", "Step Row", "Mise en Place Row"]) {
      const p = figma.createPage();
      p.name = name;
      const set = new Node("COMPONENT_SET", figma);
      set.name = name;
      p.appendChild(set);
      const variant = new Node("COMPONENT", figma);
      variant.name = "State=To Do";
      set.appendChild(variant);
      p._loaded = false;
      legacy[name] = { page: p, variant };
    }
    const retired = await run(null, { figma, state });
    expect("all three pages retired", !["Ingredient Row", "Step Row", "Mise en Place Row"]
      .some((n) => figma.root.children.some((p) => p.name === n)),
      figma.root.children.map((p) => p.name).join(", "));
    expect("report says so and still verifies",
      /retired page Ingredient Row/.test(retired.report) && /^VERIFIED/m.test(retired.report), retired.report);

    // A page whose component is in use must be left alone, not deleted.
    const p = figma.createPage();
    p.name = "Step Row";
    const set = new Node("COMPONENT_SET", figma);
    set.name = "Step Row";
    p.appendChild(set);
    const variant = new Node("COMPONENT", figma);
    variant.name = "State=To Do";
    set.appendChild(variant);
    placeInstance(figma, variant, "Step Row");
    p._loaded = false;
    const kept = await run(null, { figma, state });
    expect("in-use old page is kept", figma.root.children.some((x) => x.name === "Step Row"));
    expect("report explains why", /still has components in use/.test(kept.report), kept.report);
  }

  console.log("\n7. The self-check catches a bad component");
  {
    const { figma, state } = makeFigma({ allowModes: true, fonts: MAC });
    const realCombine = figma.combineAsVariants;
    figma.combineAsVariants = function (comps, parent) {
      const set = realCombine(comps, parent);
      const p = set.children.find((c) => c.name === "Style=Primary, State=Default");
      if (p) p.fills = [];   // sabotage the Button only: Primary loses its burgundy fill
      return set;
    };
    const { report } = await run(null, { figma, state });
    expect("reports FAILED", /^FAILED/m.test(report), report);
    expect("names the broken variant", /Button Style=Primary, State=Default fill/.test(report), report);
  }

  console.log(failures === 0
    ? `\nAll checks passed.\n`
    : `\n${failures} check(s) failed.\n`);
  process.exit(failures === 0 ? 0 : 1);
})();
