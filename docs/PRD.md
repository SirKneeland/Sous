# Sous — Product Requirements Document

## Product Vision

Cooking with today's AI tools is frustrating because chat is ephemeral and recipes are stateful. Every correction, substitution, or mistake forces users to scroll, reprint, or mentally reconcile versions.

Sous turns a recipe into a *living document* that an AI co-authors in real time. The user chats naturally ("I'm out of onions," "Can this be spicier?" "I burned the garlic"), and the AI mutates a persistent recipe canvas accordingly—without rewriting history.

The result feels like cooking *with* a competent expert, not *talking to* one.

**Emotional promise:**
"Cooking is fun because I have a competent expert with me."

---

## Target User

A home cook who:
- Uses LLMs for recipes today
- Cooks with their phone on the counter
- Improvises mid-cook
- Frequently changes plans or makes mistakes

They are not trying to become a chef.
They are trying to get dinner on the table without friction.

---

## Core Jobs-To-Be-Done

1. Decide what to cook.
2. Generate a recipe that fits constraints.
3. Adapt the recipe in the moment.
4. Never lose place or context.
5. Track progress through steps.
6. Recover gracefully from mistakes.
7. Avoid restating known constraints every time.
8. Return to a previous recipe without starting over.

---

## UX Model

Phone-first, mode-based layout (not a true dual-pane split view).

Sous has three explicit UI modes:

1. **Cook Mode (default)**
2. **Chat Mode**
3. **Patch Review Mode**

The recipe canvas is always the single source of truth and the primary surface.
Chat is a temporary interaction mode layered on top of the recipe.

### Cook Mode

- Full recipe canvas visible and scrollable.
- A 'Talk to Sous' button is pinned to the bottom of the screen and always visible regardless of recipe length. Swiping down on this button or anywhere in the bottom 25% of the screen triggers the ThumbDrop gesture to open Chat Mode.
- No chat transcript visible.
- No scrim.

### Chat Mode

- Chat appears as a bottom sheet overlay.
- Recipe is dimmed using a scrim (semi-transparent black overlay).
- Recipe is not interactive while scrim is active.
- Only chat scrolls; recipe does not scroll in this mode.
- Chat sheet opens scrolled to the most recent message.
- Chat sheet supports detents (collapsed / medium / large).
- Swiping down on the input bar or anywhere in the bottom 25% of the screen triggers the ThumbDrop gesture to dismiss the chat sheet and return to Cook Mode.

The scrim ensures clear hierarchy and prevents dual-surface scroll conflicts.

### Patch Review Mode

Patch Review Mode is entered automatically when a patch arrives — there is no intermediate "pending validation" step shown to the user.

- Chat sheet collapses.
- Scrim disappears.
- Recipe becomes primary surface again.
- All proposed changes are rendered visually in-place (see Interaction Model).
- A fixed bottom action bar is pinned to the bottom of the screen with two equal CTAs:
  - **Reject**
  - **Accept Changes**

The Accept and Reject buttons are always visible regardless of recipe length.
The user must explicitly choose one.

---

## Recipe Canvas

Structure:
- Title
- Ingredients (checkable)
- Steps (numbered, large text, each with status: todo|done)
- Optional notes/tips

Rules:
- Users can mark steps "Done".
- The AI is forbidden from editing any step marked `done`.
- If a user request would require altering a completed step:
  - The AI must add a recovery step or note *after* the current step.
- Ingredient checkboxes tick without applying strikethrough — legibility is preserved for shopping/reference use. Step and Mise en Place checkboxes apply strikethrough on check. Checkboxes remain visually active (full opacity) regardless of checked state for all item types.
- The Ingredients section is collapsible. Collapsed state persists per session. The section auto-expands when an accepted patch modifies ingredients.
- Steps support nested sub-steps. Sub-steps are independently checkable and rendered indented below their parent.

---

## Interaction Model

User speaks naturally:
- "I forgot onions."
- "I burned the garlic."
- "Can this be spicier?"

AI responds with:
1. A short conversational reply.
2. A structured `patchSet` (if mutation is appropriate).

The AI must never emit a full recipe once a canvas exists.

If the AI proposes recipe mutations, the user is taken directly to Patch Review Mode and must explicitly Accept or Reject before Recipe State changes.

- Accept applies the PatchSet atomically and removes diff artifacts.
- Reject discards the PatchSet, sends the rejection as context to the server, and returns the user to Chat Mode.

### Patch Lifecycle

When the assistant proposes changes:

1. The response includes a `patchSet`.
2. The app validates and stores it as `pendingPatchSet`.
3. The user is taken directly into Patch Review Mode.
4. Only one `patchSet` may be pending at a time; any new proposal must invalidate or replace the existing pending `patchSet`.

### Patch Review Rendering Requirements

Patch Review Mode must render full diff coverage for both Ingredients and Steps.

For each section:

- **Added items** → highlighted as new.
- **Modified items** → rendered in final proposed state with an "Edited" indicator.
- **Removed items** → rendered in original position as ghost/struck entries.

The user must see the complete end-state if accepted.
The recipe must not mutate until acceptance.

### Accept / Reject Behavior

**Accept Changes**
- Apply entire PatchSet atomically.
- Increment recipe version.
- Clear highlights.
- Exit to Cook Mode.

**Reject**
- Discard entire PatchSet.
- Clear highlights.
- Send rejection as hidden context to the server for the next LLM request.
- Return to Chat Mode.

The rejection must be recorded in session state.

---

## New Recipe Flow

The user can start a fresh recipe at any time without restarting the app.

- A "New" button is available from the recipe canvas and from within the chat sheet.
- Tapping "New" from the canvas resets immediately (no confirmation — intent is clear).
- Tapping "New" from the chat sheet shows a confirmation dialog before resetting.
- After reset, the app returns to the blank starting state with no canvas and exploration mode active.
- The reset wipes session state cleanly — no orphaned recipe data, patch state, or chat history.

---

## Recent Recipes

The app persists multiple recipe sessions and allows the user to return to previous ones.

- A recent recipes list shows saved sessions, most recent first.
- Each entry in the list represents a self-contained session: its own recipe canvas and its own chat history.
- Tapping a recent recipe restores both the recipe and the chat history for that session.
- Starting a new recipe while one is in progress prompts the user before replacing the current session.

---

## Safety + Determinism

- All model outputs that modify the recipe must be represented as structured PatchSets.
- Client-side validation is mandatory before entering Patch Review Mode.
- A PatchSet is atomic: fully applied or fully rejected.
- Completed steps are immutable (never edited).
- Session/UI state must never be treated as authoritative recipe data.
- When a proposal is rejected, the next model request includes one-shot metadata indicating the rejection (not user-visible text).

---

## LLM Integration Principles

- Provider: OpenAI (for now).
- Prefer structured JSON output; tolerate malformed output via limited self-repair and bounded retries.
- Try hard to avoid dead-end "sorry, can't do that" responses; ask targeted clarifying questions instead.
- Never crash due to model output.
- Debug builds show quiet telemetry for retries, validation failures, and missing API key states.
- The AI should feel like a knowledgeable, opinionated friend — not a corporate assistant reading from a menu. It makes recommendations, handles messy input gracefully, and maintains a consistent warm personality across all modes.

### Hidden Rejection Context

When a PatchSet is accepted or rejected, the decision must be recorded as a `PatchDecision` in session state.

On the next LLM request, the app must include structured metadata:

```ts
context: {
  llm?: {
    lastPatchDecision?: {
      patchSetId: string
      decision: "accepted" | "rejected"
      summary?: PatchSet["summary"]
    }
  }
}
```

---

## Conversation State and Recipe Creation Gate

Sous has two high-level modes:

1. **Creation mode** (no recipe canvas yet)
2. **Cooking/Edit mode** (a recipe canvas exists)

Creation mode is split into two phases:

- **Exploration phase (default):** the assistant helps the user *decide what to cook* by asking 1–2 targeted questions and proposing a small menu of options. **No recipe canvas is created in this phase.**
- **Commit phase:** only after the user explicitly commits to an option may the assistant create the recipe canvas.

**Hard rule:** The assistant must never create a recipe canvas (or output a full recipe) unless the user has explicitly committed.

### Commit signals

Examples that count as commit:

- "Let's do that / this one"
- "Make the French one"
- "Option 2"
- "Generate the recipe"
- A UI action like tapping a specific option card or a "Generate recipe" button

If the user is vague ("sure", "ok"), the assistant should confirm which option they mean *without* generating the recipe yet.

### Exploration response shape

In Exploration phase, the assistant response should:

1. Reflect the request in one sentence.
2. Ask **1–2 branching questions** (max).
3. Provide **3–5 options** with short "why it fits" blurbs.
4. Invite the user to pick one or refine.

### Routing (implementation note)

Determine:

- `has_canvas`: whether a recipe canvas exists
- `intent`: explore | commit_to_option | edit_existing_recipe | cooking_help

Routing rules:

- If `has_canvas=false` and `intent=explore` → Exploration response shape (no canvas)
- If `has_canvas=false` and `intent=commit_to_option` → Generate recipe canvas
- If `has_canvas=true` → Patch-based edits + "no past edits" rule

---

## Persistent Preferences

Sous supports explicit, persistent user-declared preferences that are applied automatically to recipe creation.

Preferences are:
- Explicitly set by the user (never inferred)
- Persisted across sessions
- Applied silently to all new recipes
- Overridable per recipe only by explicit user instruction

### Preference Fields

- **Portions** — default number of portions to cook (purely quantitative)
- **Hard-avoid ingredients or food categories** — must never appear unless explicitly overridden
- **Kitchen equipment** — tools and appliances available (e.g. cast iron, induction plate, air fryer, stand mixer). Treated as additive context, not an exhaustive inventory. If no equipment is listed, assume a standard home kitchen. If some equipment is listed, assume standard basics are also available.
- **Custom instructions** — free-form persistent instructions applied to all recipes (e.g. "always give me stove settings for both gas and induction")

### Preference Rules

- Hard-avoid violations require explicit user confirmation before proceeding.
- Preferences must never retroactively modify completed recipe steps.
- Overrides apply only to the current recipe unless the user explicitly updates their preferences.

---

## Memories

Sous can remember things the user expresses in conversation and apply them as context in future sessions.

### Memory Proposal Flow

- When the AI detects a memorable preference or fact in chat, it proposes adding a memory.
- A toast notification appears at the top of the chat with the proposed memory text and three inline buttons: **Save**, **Edit**, and **Skip**.
- Save commits the memory immediately.
- Edit opens an edit flow before saving.
- Skip dismisses the toast without saving.
- The toast has a 10-second timeout. Default timeout behavior is to save. The timeout pauses as soon as the user taps anywhere on the toast.
- Haptic feedback fires when a memory is proposed and when one is saved.

### Memory Format

Memories are phrased in third person (e.g. "hates cilantro", "cooking for two young kids").

### Memory Management

- Memories are visible and editable in a dedicated section in Settings.
- Users can tap a memory to edit it.
- Users can swipe left on a memory to delete it.
- Memories are included as context in future AI requests.
- Memories never override hard preferences.

---

## Step Timers

Sous detects time references in recipe steps and surfaces them as tappable timer
affordances inline in the step text.

### Detection and Affordance

- When a step contains a time reference (e.g. "cook for 5 minutes", "rest for
  1–2 hours"), the time text is highlighted and rendered with an inline timer SF
  Symbol.
- Tapping the affordance starts the timer immediately for exact durations.
- For ambiguous ranges (e.g. "1–2 hours"), a duration picker sheet appears first.
- The tap target covers both the icon and the time text as a single unit.

### Timer Behavior

- A running timer displays a banner above the Talk to Sous button.
- Multiple timers can run simultaneously; banners stack above the button.
- Each banner shows a short on-device AI-generated label (2–4 words, action and
  ingredient only — e.g. "cook lamb") and the live countdown.
- The banner stack never pushes the Talk to Sous button down; it overlays the
  canvas with the button anchored at its fixed position.
- A step with an active timer cannot be marked done until the timer completes or
  is deleted.

### Timer Sheet Controls

- **Pause / Resume** — pauses and resumes a running timer without dismissing the
  sheet.
- **Adjust** — hours/minutes pickers to change the remaining time.
- **Delete Timer** — removes the timer from the step entirely.
- The live countdown is displayed right-justified in the sheet header row
  alongside the "ADJUST TIMER" label.

### Background Behavior

- When the app is backgrounded, a local notification fires on timer completion.
- Notifications are cleared cleanly on New Recipe and app relaunch (no stale
  alerts).

### On-Device Summarization

- Timer banner labels are generated on-device using Apple Foundation Models
  (iOS 26+).
- If unavailable, the step text is truncated as a fallback.
- Summarization is asynchronous; the banner appears immediately with a
  placeholder and updates when the summary resolves.

---

## Mise en Place

Users can request a Mise en Place extraction from the recipe canvas at any time
before cooking begins.

- A tappable trigger (carrot icon) appears in the recipe canvas header once a
  recipe canvas exists.
- Tapping it calls the LLM to extract prep work from the Procedure and surface
  it in a dedicated MISE EN PLACE section between INGREDIENTS and PROCEDURE.
- Extracted steps are removed from the Procedure to avoid duplication.
- The trigger is hidden once the Mise en Place section exists.

### Vessel Grouping

- The LLM groups ingredients needed simultaneously into named vessels (e.g.
  "Spice Bowl", "Meat Plate").
- Vessels are numbered only when the same type appears more than once (e.g.
  "Bowl 1", "Bowl 2").
- Each component within a vessel group is independently checkable.
- A group header auto-completes when all its components are checked.

### First-Time Confirmation

- On first use, a confirmation modal explains what Mise en Place does and offers
  a "Don't show again" checkbox.
- Subsequent triggers skip the modal.

### Rules

- Mise en Place extraction skips Patch Review — user intent is explicit.
- No explicit undo. If the user wants to revert, they start a new recipe.
- Mise en Place item states (checked/unchecked) are reset on New Recipe, but the
  section itself persists if the session is restored from Recent Recipes.

---

## Recipe Import

Users can bring an existing recipe into Sous from outside the app. Import is
available only from the zero state screen (no active recipe canvas).

### Entry Points

- **Camera** — capture a photo of a physical recipe card, cookbook page, or
  packaging.
- **Photo Library** — select a saved screenshot or photo.
- **Paste Text** — paste raw recipe text from any source.

### Extraction Behavior

- The AI faithfully extracts the recipe as written. It must not alter,
  substitute, or editorialize during extraction.
- Any line where confidence is low is flagged with [??] inline.
- A two-stage progress indicator shows: "Analyzing image…" then "Sous-ing up
  the recipe…"

### Post-Import

- Import skips the Exploration phase entirely and routes directly into
  cooking/edit mode.
- The AI sends a first chat message acknowledging the loaded recipe and inviting
  adaptations.
- All subsequent changes go through the normal patch flow.

### On-Device OCR

- Photo imports use an on-device Apple Vision OCR pipeline before sending to the
  LLM, reducing API payload size.
- Non-Latin scripts (e.g. Japanese, Chinese) pass through the OCR layer and are
  handled by the LLM.

---

## ThumbDrop Gesture

ThumbDrop is the named gesture for transitioning between Cook Mode and Chat Mode.
It is a consistent downward swipe in both directions — always toward the bottom
of the screen.

- **Cook Mode → Chat Mode**: swipe down on the Talk to Sous button at the bottom
  of the recipe canvas.
- **Chat Mode → Cook Mode**: swipe down on the input bar (camera button + text
  field + send button row) at the bottom of the chat sheet.

### Trigger Zone

- The gesture is active across the bottom 25% of the screen in both modes, not
  just the button or input bar itself.
- A root-level UIPanGestureRecognizer detects swipes originating anywhere in
  this zone and routes them through the ThumbDrop logic.
- The recognizer runs simultaneously with scroll and tap recognizers — it never
  blocks chat scrolling, tap targets, or long-press actions.

### Visual Feedback

- The primary action element (Talk to Sous button in Cook Mode; input bar in
  Chat Mode) translates downward with the thumb during the gesture as visual
  confirmation.
- On commit, the element snaps back as the mode transition fires.
- On cancel, the element springs back to its original position.

### Haptic Sequence

ThumbDrop uses a slingshot haptic sequence that builds tension during the drag:

- Gesture recognized: .light impact
- 30pt of travel: .light impact
- 60pt of travel: .medium impact
- 90pt of travel: .rigid impact
- Commit: .medium impact

Each band fires once per gesture and does not re-fire if the thumb reverses.

### Commit Thresholds

Commit triggers on either condition:
- Downward translation ≥ 50pt, or
- Peak downward velocity ≥ 400pt/s (tracked during drag, not at lift)

---

## Non-Goals (current)

Out of scope until explicitly added to the roadmap:

- Social sharing
- Public recipe discovery
- Nutrition tracking
- Grocery delivery integrations
- Multi-canvas workspaces
- Collaboration with other users
- Monetization or paywalls
- Preference inference or automated learning
- Inline generated image display in chat responses (future paid feature)
- Generated images (future paid feature)
- Voice input/output (future paid feature)
