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
  set fills(v) { this._fills = v; }
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
  remove() {
    if (this.parent) this.parent._children = this.parent._children.filter((c) => c !== this);
    this.parent = null;
    const mark = (n) => { n.removed = true; n._children.forEach(mark); };
    mark(this);   // a deleted frame takes its instances with it, as in Figma
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
    expect("report verifies components too", /^VERIFIED/m.test(report) && /Button \(7 variants\)/.test(report), report);
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
    expect("the three old row pages are gone",
      !["Ingredient Row", "Step Row", "Mise en Place Row"].some(
        (n) => figma.root.children.some((p) => p.name === n)),
      figma.root.children.map((p) => p.name).join(", "));

    const sh = figma.root.children.find((p) => p.name === "Section Header").children.find((n) => n.type === "COMPONENT_SET");
    const collapsed = sh.children.find((c) => c.name === "State=Collapsed").findOne((x) => x.name === "chevron");
    expect("Collapsed chevron turned -90°", collapsed.rotation === -90, String(collapsed.rotation));

    expect("report lists the chrome components",
      /Icon Button \(3 variants\)/.test(report) && /Recipe Title \(2 variants\)/.test(report), report);

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
    figma._instances.push({ mainComponent: liveSet.children[0] });
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
      /Button \(7 variants\)/.test(again.report) && /List Row \(7 variants\)/.test(again.report) &&
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
    figma._instances.push({ mainComponent: variant });
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
