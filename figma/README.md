# Sous Design Tokens — Figma plugin

Creates the Sous variable collections and text styles in a Figma file, straight from
`design/tokens.json`. Safe to run as many times as you like: it matches variables by name and
updates them in place rather than making duplicates.

## Loading it (once)

You need the **Figma desktop app on a Mac** — see the font note below. Plugin development
works on every Figma plan, including Starter.

1. Open the Figma desktop app.
2. **Create or open a design file first.** This is the step that trips people up — there is no
   Plugins menu on the file browser / home screen, only inside an open file. It also has to be
   a Figma *design* file, not FigJam or Slides.
3. In the toolbar at the bottom of the window, click the **Resources** icon — the blue square
   with a plus, to the right of the shape and text tools.
4. Choose the **Plugins & widgets** tab, then set the dropdown on the right to **Development**.
5. Click **Import from manifest…** and choose `figma/manifest.json` in this repo.

Figma confirms with "Sous Design Tokens has been imported", and the plugin then appears in that
same list for any design file you open. **Click its row to run it.**

The older menu path still works if you prefer it: the **Figma logo in the top-left corner of
the app window** (an in-app menu, not the macOS menu bar) → **Plugins → Development**.

## Running it

1. Open (or create) the design file that should hold the Sous design system.
2. **Plugins → Development → Sous Design Tokens.** (Plugins and Widgets are separate menu items,
   each with its own Development submenu — this is a plugin, so use Plugins.) The Resources
   icon in the toolbar works too: **Plugins & widgets** tab → **Development** filter → click the row.
3. It writes the tokens, then **reads them all back and verifies them**, and shows you a
   report. Hit **Copy report** and paste it back to Claude Code — that's the confirmation
   that the import actually worked.

A good report ends with `VERIFIED — all N checks passed.` The count grows as components are
added, so compare it with the previous run rather than a fixed number. A bad one says `FAILED`
and names every token or variant that's wrong, which is enough to fix it without any guesswork.

## What it creates

| Collection | Contents |
|---|---|
| **Sous Primitives** | 16 raw palette colors — `cream/100`, `burgundy/700`, and so on. Nothing in a design should reference these directly. |
| **Sous Color** | 18 semantic colors — `background/canvas`, `text/primary`, `accent/primary`. These alias the primitives, so changing a primitive updates everything downstream. |
| **Sous Icon Sizes** | The 5-step SF Symbol scale. |
| **Sous Spacing** | The 8-step spacing scale. Advisory — see the note below. |
| **Sous Border** | Hairline width and the two permitted corner radii. |

**Components**, each on its own page with a documentation panel:

| Component | Variants |
|---|---|
| **Recipe Canvas** (screen) | On the **Screens** page: a 375 × 812 iPhone screen assembled only from the components below. |
| **Bottom Bar** | Voice Yes / No — TALK TO SOUS, the mic button, and the pull-down chevron. |
| **Icon Button** | Accent (44pt burgundy hamburger), Inverse (44pt ink settings), Bordered (32pt). |
| **Recipe Title** | Servings Yes / No. Properties: Title, Servings. |
| **Screens** | Recipe Canvas, Chat, Zero State, Sidebar, Settings, Change Suggestion, Voice Mode, Talk to a Recipe, Preferences, Sign In, Paywall, Cap Reached, Memories, Memories Empty — all on the **Screens** page, assembled only from components. |
| **Form Kit** | Text Field, Text Area, Toggle, Stepper, Back Button. |
| **Voice Bar** | Ready, Listening, Thinking, Speaking, Patch pending. |
| **Diff Row / Review Bar** | Removed / Added; Ready / Invalid × Safe area. |
| **Chat Bubble / Composer Bar / Chat Header** | The chat sheet. |
| **Settings Row / Segmented Control / Badge** | Settings and its pickers. |
| **Recent Recipe Row / Wordmark / Import Option Row** | Sidebar and import. |
| **Picker Sheet** | Wheels One / Two. The wheel sheet behind servings, a new timer and adjusting a running one. Properties: Title, Left, Right, Readout, Footer. |
| **Apple Sign In Button** | Scheme Light / Dark. Apple's own control at Sous's size and shape (345 × 50, square via Apple's `cornerRadius` API) — a reserved space, never a redrawn Apple mark. |
| **Benefit Row** | One paywall claim: burgundy tick plus body text, top-aligned. Property: Benefit. |
| **Checkbox** | Unchecked, Checked × Default (20pt), Small (18pt). Built only if missing, so an existing one is never replaced. |
| **Button** | Primary, Inverse, Secondary, Secondary Accent, Text — plus Disabled for Inverse and Secondary. Properties: Label, Icon. |
| **Section Header** | Expanded, Collapsed, Static. Property: Title. |
| **List Row** | The row behind ingredients, steps and mise en place — and, Roomy, the Memories list. To Do, Checked, Current, Done, Highlighted, plus three Timer variants. Switches: Checkbox, Nested, Timer, Notes, Roomy. Plus **Ingredient Group Header**. |

Re-running rebuilds a component from scratch **only while nothing uses it**. Once you've placed
an instance of it anywhere, the plugin leaves it alone and says so in the report, because
rebuilding would break those designs.

Plus **17 text styles** under `Sous/` — Title, Body, Section Header, Readout, and the rest.
Each one's description names the Swift token it corresponds to, so you can trace any style back
to the code.

## Two things to know

**Light and dark.** Two modes in one collection is the right structure, but modes are a paid
Figma feature. On the Starter plan the plugin falls back to two collections — `Sous Color`
(light) and `Sous Color Dark`. If you ever move to a paid plan, just run the plugin again: it
will create the Dark mode and merge them. You don't have to redo anything by hand.

**Icons.** SF Symbols are drawn from `design/sf-symbols.json`, which maps each symbol name to the
character Apple assigns it. The desktop plugin API has no way to look a symbol up by name — that
exists only in Figma's remote (MCP) runtime — so the table is generated once and committed. To add
a symbol, follow `howToAdd` in that file.

**Fonts.** Sous uses New York, SF Pro and SF Mono — Apple system faces. SF Pro is hosted by
Figma itself, so it works everywhere. New York and SF Mono only exist if they're installed on the
Mac running Figma — which also means Claude's remote Figma tools, which run on Figma's servers,
cannot create text in them. **SF Mono is not exposed to third-party apps by default**,
so Figma falls back to Menlo for the seven monospace styles (the timer readouts, pickers and
voice labels).

To get exact parity, install SF Mono once:

1. Download `SF-Mono.dmg` from <https://developer.apple.com/fonts/> (free, from Apple).
2. Install it, then quit and reopen Figma.
3. Re-run the plugin. The report should then say `SF Mono x7` instead of `Menlo x7`.

Menlo is a perfectly reasonable stand-in if you'd rather skip this — but its digits are a
different width from SF Mono's, so a timer mocked up in Figma won't line up with the real app.

Running it in a **browser** rather than the desktop app is worse: none of the Apple faces are
available and everything falls back to Inter. Sizes, weights, letter-spacing and casing stay
correct in every case; only the letterforms change.

**Spacing is advisory.** The spacing scale is imported for reference, but the app deliberately
does not conform to it yet — see `design/TOKEN-DECISIONS.md`, decision 13.

## Testing it without Figma

`design/test-figma-plugin.js` runs the real `figma/code.js` against a stub of Figma's plugin
API, so the logic can be checked without opening Figma at all:

```bash
node design/test-figma-plugin.js
```

It covers both plan shapes (with and without variable modes), both font situations (Mac desktop
and browser), that running twice doesn't duplicate anything, and — importantly — that the
plugin's self-verification actually fails when a token is written wrong. That last test exists
so the `VERIFIED` line can be trusted.

What it can't prove is that Figma's real API behaves the way its documentation says. Only
running it in Figma shows that.

## Keeping it in sync

`figma/code.js` is generated from `design/tokens.json`, `design/figma-plugin-template.js` and `design/figma-components.js`. After changing any of them:

```bash
python3 design/build-figma-plugin.py
```

Then re-run the plugin in Figma. `design/check-tokens.py` fails if you forget the first step.

Sync is one-way by design: `design/tokens.json` is the source of truth, and Figma is a mirror
of it. Editing a variable inside Figma will be silently overwritten the next time the plugin
runs. Figma's Variables REST API — the thing that would let a script read changes back out of
Figma — is available only on the Enterprise plan.
