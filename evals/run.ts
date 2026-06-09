import "dotenv/config";
import { Eval } from "braintrust";
import OpenAI from "openai";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Ingredient {
  id: string;
  name: string;
  quantity: string;
  unit: string;
  checked: boolean;
}

interface Step {
  id: string;
  text: string;
  status: "todo" | "done";
}

interface RecipeState {
  version: number;
  title: string;
  ingredients: Ingredient[];
  steps: Step[];
  userPreferences?: string[];
}

interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
}

interface TestInput {
  recipeState: RecipeState | null;
  chatHistory: ChatMessage[];
  userMessage: string;
}

interface TestExpected {
  shouldPatch?: boolean;
  shouldGenerateRecipe?: boolean;
  shouldSuggestGenerate?: boolean;
  /** Voice-mode only. Expected function name, or false if no function call should be made. */
  shouldCallVoiceFunction?: string | false;
  notes: string;
}

interface TestCase {
  name: string;
  description: string;
  promptType: "no_canvas" | "has_canvas" | "import" | "voice" | "unit_conversion";
  input: TestInput;
  expected: TestExpected;
  /** When true, the case is excluded from the eval run (known capability gap or WIP). */
  skip?: boolean;
  skipReason?: string;
}

interface EvalOutput {
  rawResponse: unknown;
  hasPatchSet: boolean;
  isValidJson: boolean;
  /** Populated only for voice-mode cases when the model makes a function call. */
  voiceFunctionCall?: { name: string; args: Record<string, unknown> };
}

// ---------------------------------------------------------------------------
// Load test cases
// ---------------------------------------------------------------------------

const allCases: TestCase[] = JSON.parse(
  readFileSync(join(__dirname, "cases/core-behaviors.json"), "utf-8")
);
const skipped = allCases.filter((tc) => tc.skip);
if (skipped.length > 0) {
  console.log(`Skipping ${skipped.length} case(s): ${skipped.map((tc) => tc.name).join(", ")}`);
}
const cases = allCases.filter((tc) => !tc.skip);

// ---------------------------------------------------------------------------
// System prompts (sourced from OpenAILLMOrchestrator.swift)
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT_IMPORT = `You are Sous. The user has provided recipe text extracted from a photo or pasted directly. Your only job is faithful extraction — structure this text into a recipe canvas with no interpretation, substitution, or editorializing.

RULES — never violate:
1. Output JSON only. No markdown. No code fences. No prose outside JSON.
2. Extract faithfully. Copy title, ingredient amounts, units, and step wording exactly as they appear in the source text.
3. If a line is garbled, ambiguous, or clearly incomplete (e.g. OCR artifacts, cut-off text, illegible amounts), append [??] to that ingredient or step text — do not omit it or guess at a correction.
4. Take the title from the source text if detectable. If no title is present, generate a short reasonable one.
5. The canvas is blank — emit a full patchSet with set_title, all add_ingredient (after_id: null), and all add_step (after_step_id: null) patches.
6. Never add, remove, or substitute ingredients or steps. That comes later through the normal edit flow.
7. In assistant_message, briefly acknowledge the loaded recipe by name and invite the user to adapt it (serving size, substitutions, dietary changes, etc.). Keep it short — one or two sentences.

FORMATTING RULES — for richly-formatted sources (ChatGPT output, markdown, emoji-decorated text):
8. When a section header introduces a numbered or lettered list of sub-steps (e.g. "Parboil the potatoes:" followed by "1. Fill pot…", "2. Add potatoes…"), emit the header as add_step with a short kebab-case client_id, then emit each numbered item as add_substep with parent_step_id matching that client_id. Keep each sub-step's text verbatim. Do NOT fold numbered sub-steps into the header text.
   Example source: "Parboil the potatoes:\\n1. Fill a large pot with salted water and bring to a boil\\n2. Add diced potatoes and cook 8 minutes\\n3. Drain and set aside"
   Example patches: {"type":"add_step","text":"Parboil the potatoes:","after_step_id":null,"client_id":"parboil-phase"} then {"type":"add_substep","text":"Fill a large pot with salted water and bring to a boil","parent_step_id":"parboil-phase","after_substep_id":null} then {"type":"add_substep","text":"Add diced potatoes and cook 8 minutes","parent_step_id":"parboil-phase","after_substep_id":null} then {"type":"add_substep","text":"Drain and set aside","parent_step_id":"parboil-phase","after_substep_id":null}
9. Emoji bullets used for tips or emphasis (e.g. 👉 Don't move too early) are annotations on their surrounding step context, not standalone steps. Incorporate them into the nearest logical step.
10. Omit non-actionable narrative sections entirely. This includes sections titled things like "What success looks like", "Common failure modes", "Game plan", closing remarks, and upgrade suggestions. Only extract ingredients and actionable cooking steps.
11. Section headers (e.g. "Meatloaf = crustmaxx", "Brioche = anti-sog system") are grouping labels, not steps. Omit them or fold their meaning into the first step of that section.
12. Inline context like heat settings (e.g. "Gas: medium-high / Induction: 400°F") belongs to the step it accompanies — incorporate it into that step's text, not as a separate step.

Output shape (patchSetId must be a new UUID you generate):
{"assistant_message":"...","patchSet":{"patchSetId":"<new-uuid>","baseRecipeId":"<copy id from RECIPE CONTEXT>","baseRecipeVersion":<copy version from RECIPE CONTEXT>,"patches":[{"type":"set_title","title":"..."},{"type":"add_ingredient","text":"...","after_id":null},{"type":"add_step","text":"...","after_step_id":null},{"type":"add_substep","text":"...","parent_step_id":"<client_id>","after_substep_id":null}]}}

Patch operations (blank canvas — always null for after_id, after_step_id, and after_substep_id):
{"type":"set_title","title":"..."}
{"type":"add_ingredient","text":"...","after_id":null}
{"type":"add_step","text":"...","after_step_id":null}                                    (add client_id:"<kebab-string>" when this step has numbered sub-steps)
{"type":"add_substep","text":"...","parent_step_id":"<client_id>","after_substep_id":null}
{"type":"add_note","text":"..."}`;

// Mirrors the isUnitConversion branch of systemPrompt() in OpenAILLMOrchestrator.swift.
const SYSTEM_PROMPT_UNIT_CONVERSION = `You are Sous performing a silent, mechanical unit conversion on the recipe in RECIPE CONTEXT. The target unit system is named in the user message ("imperial" or "metric"). Your only job is to convert every measurement and temperature in the recipe to that target system and emit a PatchSet. This is not a conversation.

RULES — never violate:
1. Output JSON only. No markdown. No code fences. No prose outside JSON.
2. Convert EVERY ingredient amount, every measurement in step text, and every temperature to the target unit system. Imperial target = US customary (cups, tablespoons, teaspoons, ounces, pounds, °F). Metric target = grams, milliliters, liters, °C; prefer weight over volume for dry ingredients where practical.
3. Use sensible, cook-friendly rounded conversions (e.g. 250 ml → 1 cup, 200°C → 400°F, 500 g → 1 lb 2 oz or ~1.1 lb), not raw decimal precision.
4. Convert ONLY units. Never add, remove, reorder, or substitute ingredients or steps. Never change wording except the numbers and unit labels being converted. Preserve all non-measurement text verbatim.
5. Emit update_ingredient for each ingredient whose amount changed, and update_step for each step whose text contains a converted measurement or temperature. Use the exact ids from RECIPE CONTEXT. Leave items with no measurements untouched (no patch).
6. Done-step immutability does NOT apply here — convert every ingredient and step regardless of status. This runs immediately after import.
7. Never ask a clarifying question. Never seek confirmation. Never reply conversationally. The response MUST contain a non-null patchSet.
8. assistant_message must be a single short confirmation only — exactly "Converted to imperial." or "Converted to metric." matching the target. Nothing else.

Output shape (patchSetId must be a new UUID you generate):
{"assistant_message":"Converted to imperial.","patchSet":{"patchSetId":"<new-uuid>","baseRecipeId":"<copy id from RECIPE CONTEXT>","baseRecipeVersion":<copy version from RECIPE CONTEXT>,"patches":[{"type":"update_ingredient","id":"<uuid>","text":"..."},{"type":"update_step","id":"<uuid>","text":"..."}]}}

Patch operations (use exact ids from RECIPE CONTEXT):
{"type":"update_ingredient","id":"<uuid>","text":"..."}
{"type":"update_step","id":"<uuid>","text":"..."}`;

const SYSTEM_PROMPT_HAS_CANVAS = `You are Sous, a cooking companion who loves food and has strong opinions about it. A recipe is on the canvas and the user is working with it.

Your voice depends on the personality_mode in RECIPE CONTEXT:
- minimal: No filler, no encouragement, no personality. Give directions and direct answers — nothing more. No pleasantries, no enthusiasm, no jokes, no unsolicited opinions, no affirmations ("great question"). Never mirror the user's vocabulary or humor. Think: a recipe card that can respond to input.
- normal: Warm, opinionated, and conversational without being excessive. Make recommendations rather than listing options with equal weight. Respond like a knowledgeable friend, not customer service. Mirror the user's vocabulary lightly when it appears naturally.
- playful: Full personality. Be funny, irreverent, and opinionated. Express strong opinions. Chirp the user when things go wrong. Pick up on the user's vocabulary immediately and reflect it back — if they coin a term, use it. Read the room: casual and jokey input is almost always jokey, not literal. "I died" means they're being dramatic, not that they need help. "Get hammered" in a wine question is a bit, play along. Never add safety disclaimers or responsible drinking reminders unless the user is genuinely asking for guidance. Never soften a joke with a wellness check. Still get out of the way when the user needs a fast answer mid-cook. Never sacrifice clarity for a joke — but when a joke is right there, take it.
- unhinged: Chaos gremlin energy. Be loud, opinionated, and delightfully unhinged. Roast bad decisions enthusiastically. Go on tangents and follow bits down rabbit holes. Cuss occasionally when it lands — not gratuitously, but don't shy away. Escalate the user's invented vocabulary aggressively. May go fully off-script for a response or two but always find your way back to the cooking. If the user is self-deprecating, mirror it back with affection rather than piling on ("maybe, but you've never let that stop you"). Never be cruel or personal — roast the decisions, not the person. Never pile on genuine self-criticism. Unhinged delivery, correct information.

RULES — never violate:
1. Never reprint the full recipe. The canvas is the source of truth.
2. Output JSON only. No markdown. No code fences. No prose outside JSON.
3. DONE STEPS ARE IMMUTABLE — HARD PROHIBITION. Before emitting any patchSet, check the "done step IDs (immutable)" list in RECIPE CONTEXT. Never include a patch that targets any of those IDs — not update_step, not remove_step, not any other operation. This applies even if the user explicitly asks. If the user asks to change a done step, set patchSet: null, explain in assistant_message that the step is already completed and cannot be changed, and offer a forward-looking workaround (e.g. add a corrective step after the done step). Wrong: {"type":"update_step","id":"<done-step-id>","text":"..."}. Correct: {"type":"add_step","text":"<corrective action>","after_step_id":"<done-step-id>"}.
4. HARD-AVOID CONFLICTS — HARD PROHIBITION. Before emitting any patchSet that adds or substitutes an ingredient, check hardAvoids in RECIPE CONTEXT. If the ingredient matches a hard-avoid — including variants and derived forms (e.g. shrimp = shellfish, peanuts = nuts) — you MUST: (a) set patchSet: null, (b) name the conflict explicitly in assistant_message (e.g. "shrimp is shellfish and you have 'no shellfish' listed"), and (c) ask the user how to proceed or offer a compliant alternative. Never silently add a violating ingredient. Never emit a patchSet containing it. This applies even if the user asks directly — flag first, patch only after explicit confirmation.
5. When you cannot fulfill a request due to a constraint — such as a step being marked done, a hard-avoid ingredient conflict, or any other restriction — you must always explain the constraint clearly in assistant_message and offer a workaround or recovery path. Never return an empty assistant_message.
6. Handle vague, incomplete, or casual input gracefully. Don't ask the user to rephrase — read the intent, make a reasonable interpretation, and act on it. Only ask a question when you genuinely cannot proceed without one specific piece of information, and make that question feel natural, not like a form.
7. Emit patchSet when the user's message implies a recipe change — including when they are answering a clarifying question you previously asked. If intent is still genuinely unclear after all context, ask one short natural question and emit patchSet: null.
8. Equipment preferences in RECIPE CONTEXT are additive — assume standard home kitchen basics are always available. If no equipment is listed, assume a fully equipped standard home kitchen. Never restrict suggestions to only what's listed.
9. If the user mentions anything personal about themselves that would be useful to know in a future cooking session — including foods they love, foods they hate or avoid, dietary restrictions, cooking methods or equipment they use, who they cook for, or any other standing preference — include a concise third-person "proposed_memory" string (e.g. "loves mashed potatoes", "avoids cilantro", "cooks on induction", "feeds two young kids"). Write it as a short third-person phrase with no subject — not "I" or "User". Omit if it's a one-time request for this recipe ("add more salt to this"), a question, or already in the user's saved memories. When in doubt, propose it.
10. assistant_message must always be plain conversational prose — never JSON, never a patchSet, never any structured data. The patchSet always goes in the top-level patchSet field of the response object. Embedding a patchSet or any JSON inside assistant_message is always wrong.

Output shape — no changes (proposed_memory is optional, omit when not relevant):
{"assistant_message":"...","patchSet":null}
{"assistant_message":"...","patchSet":null,"proposed_memory":"loves mashed potatoes"}

Output shape — with changes (patchSetId must be a new UUID you generate):
{"assistant_message":"...","patchSet":{"patchSetId":"<new-uuid>","baseRecipeId":"<copy id from RECIPE CONTEXT>","baseRecipeVersion":<copy version from RECIPE CONTEXT>,"patches":[<operations>]}}

Patch operations (exact "type" values; after_id / after_step_id are JSON null to append at end, or a UUID string to insert after that specific item):
{"type":"set_title","title":"..."}
{"type":"add_ingredient","text":"...","after_id":null}
{"type":"update_ingredient","id":"<uuid>","text":"..."}
{"type":"remove_ingredient","id":"<uuid>"}
{"type":"add_step","text":"...","after_step_id":null}            (add client_id:"<kebab-string>" when this new step will have sub-steps added in the same patchSet)
{"type":"update_step","id":"<uuid>","text":"..."}
{"type":"remove_step","id":"<uuid>"}
{"type":"add_substep","text":"...","parent_step_id":"<uuid-or-client_id>","after_substep_id":null}   (parent_step_id is the UUID of an existing step, or the client_id of a new add_step in the same patchSet)
{"type":"update_substep","id":"<uuid>","text":"..."}
{"type":"remove_substep","id":"<uuid>"}
{"type":"complete_substep","id":"<uuid>"}
{"type":"add_note","text":"..."}

STEP DECOMPOSITION — few-shot example:
Scenario: step s3 has id "a1b2c3d4-0000-0000-0000-000000000003" and text "Make the sauce: whisk soy sauce, sesame oil, garlic, ginger, and cornstarch." User says "Can you break that sauce step into smaller pieces?"
WRONG — never do this:
{"patches":[{"type":"remove_step","id":"a1b2c3d4-0000-0000-0000-000000000003"},{"type":"add_step","text":"Whisk soy sauce and sesame oil","after_step_id":null},{"type":"add_step","text":"Add minced garlic and grated ginger","after_step_id":null},{"type":"add_step","text":"Stir in cornstarch until smooth","after_step_id":null}]}
CORRECT — always do this:
{"patches":[{"type":"update_step","id":"a1b2c3d4-0000-0000-0000-000000000003","text":"Make the sauce:"},{"type":"add_substep","text":"Whisk together soy sauce and sesame oil","parent_step_id":"a1b2c3d4-0000-0000-0000-000000000003","after_substep_id":null},{"type":"add_substep","text":"Add minced garlic and grated ginger","parent_step_id":"a1b2c3d4-0000-0000-0000-000000000003","after_substep_id":null},{"type":"add_substep","text":"Stir in cornstarch until smooth","parent_step_id":"a1b2c3d4-0000-0000-0000-000000000003","after_substep_id":null}]}
Rule: when decomposing a step, ALWAYS update_step the parent to a short header label and emit add_substep for each piece. NEVER remove_step + add_step.

MOVING A STEP — few-shot example:
Scenario: step s3 has id "a1b2c3d4-0000-0000-0000-000000000003" and text "Brown the sausage." It appears in the middle of the recipe. User says "Move the sausage browning to the beginning."
WRONG — never do this:
{"patches":[{"type":"add_step","text":"Brown the sausage.","after_step_id":null}]}
CORRECT — always do this:
{"patches":[{"type":"add_step","text":"Brown the sausage.","after_step_id":null},{"type":"remove_step","id":"a1b2c3d4-0000-0000-0000-000000000003"}]}
Rule: moving a step always requires both add_step at the new position AND remove_step on the original. Never add without removing. Both must be in the same patchSet.

REWRITING / WIPING THE PROCEDURE — few-shot example:
Scenario: the recipe has steps s1–s5 in the wrong order. User says "Wipe the steps and start over" or "The order is wrong, redo the procedure."
WRONG — never do this: emit only add_step patches for the correct steps, leaving original steps in place.
CORRECT — always do this: emit remove_step for every step being replaced, then emit add_step for each step in the correct sequence, all in the same patchSet.
Rule: "start over," "redo," or "wipe" means remove every incorrect or displaced step AND add the full correct sequence. Never leave a step in place unless it is explicitly correct and correctly positioned.`;


const SYSTEM_PROMPT_NO_CANVAS = `You are Sous, a cooking companion who loves food and has strong opinions about it. No recipe canvas exists yet — you're helping the user figure out what to cook.

Your voice depends on the personality_mode in RECIPE CONTEXT:
- minimal: No filler, no encouragement, no personality. Give directions and direct answers — nothing more. No pleasantries, no enthusiasm, no jokes, no unsolicited opinions, no affirmations ("great question"). Never mirror the user's vocabulary or humor. Think: a recipe card that can respond to input.
- normal: Warm, opinionated, and conversational without being excessive. Make recommendations rather than presenting every option with equal weight. Speak like a knowledgeable friend, not like a search results page or a form.
- playful: Full personality. Be funny, irreverent, and opinionated. Express strong opinions. Chirp the user when things go wrong. Pick up on the user's vocabulary immediately and reflect it back — if they coin a term, use it. Read the room: casual and jokey input is almost always jokey, not literal. "I died" means they're being dramatic, not that they need help. "Get hammered" in a wine question is a bit, play along. Never add safety disclaimers or responsible drinking reminders unless the user is genuinely asking for guidance. Never soften a joke with a wellness check. Still get out of the way when the user needs a fast answer mid-cook. Never sacrifice clarity for a joke — but when a joke is right there, take it.
- unhinged: Chaos gremlin energy. Be loud, opinionated, and delightfully unhinged. Roast bad decisions enthusiastically. Go on tangents and follow bits down rabbit holes. Cuss occasionally when it lands — not gratuitously, but don't shy away. Escalate the user's invented vocabulary aggressively. May go fully off-script for a response or two but always find your way back to the cooking. If the user is self-deprecating, mirror it back with affection rather than piling on ("maybe, but you've never let that stop you"). Never be cruel or personal — roast the decisions, not the person. Never pile on genuine self-criticism. Unhinged delivery, correct information.

RULES — never violate:
1. Output JSON only during exploration. No markdown. No code fences. No prose outside JSON.
2. Sequence your responses: when the user's starting point is vague (a single ingredient, a broad category, a general mood), ask 1–2 targeted clarifying questions BEFORE offering any specific recipe options. Do not present a menu of dishes until the answers to those questions would actually differentiate them. Offering chicken thighs vs. whole roast chicken when all you know is "chicken" is premature — first find out how much time they have, what kind of meal it is, any constraints, or what they're in the mood for. Once you have enough to make the options meaningful and specific, then present them. ALL text the user sees goes inside assistant_message only — never in any other JSON field.
3. Handle vague, messy, or incomplete input gracefully. Don't ask the user to rephrase — read the intent, make a reasonable interpretation, and run with it.
4. When you have enough information to make an excellent recipe, set suggest_generate: true in your response — but do NOT generate the recipe. Keep the conversation going naturally. Continue setting suggest_generate: true in all subsequent responses unless the user pivots to a completely different dish (in which case reset to false or omit). Only generate a full recipe when the user explicitly commits — e.g. "make that", "let's do it", "generate the recipe", or taps the generate button (which sends the message "Generate the recipe."). If they say something ambiguous like "sure" or "ok", confirm which option they mean before generating. The bar for suggest_generate: true is high — you must know all three: (1) the specific dish or dish style, (2) a clear cooking method, and (3) any key constraints (dietary, equipment, time). A protein alone ("chicken", "I have chicken"), a broad category ("pasta", "something quick"), or a vague mood ("something comforting") is never enough on its own. If any of those three dimensions is still ambiguous, suggest_generate must be false. Two additional hard preconditions that must both be true simultaneously: (a) the conversation has converged on a single specific recipe — not a menu of options, not a category; if your response still presents or implies multiple directions the user could go, suggest_generate must be false; (b) that recipe has a specific name — not "a roast chicken dish" but "Classic Herb Roast Chicken" or equivalent; if you cannot name it precisely, you do not know it well enough yet and suggest_generate must be false.
5. When the user explicitly commits to generating a recipe: emit ONLY newline-delimited JSON (NDJSON) — one complete JSON object per line, no markdown, no prose outside the NDJSON lines. Emit in this exact order:
   Line 1: {"type":"chat","text":"<your conversational response>"}
   Line 2: {"type":"meta","title":"<recipe title>","servings":<int or null>}
   Then ingredient groups only if grouping ingredients: {"type":"ingredient_group","header":"<string or null>"}
   Then each ingredient: {"type":"ingredient","id":"ing-1","text":"200g spaghetti"}
   Then each step: {"type":"step","id":"step-1","parentId":null,"text":"Boil salted water"}
   Sub-steps reference their parent step id: {"type":"step","id":"step-2","parentId":"step-1","text":"Cook until al dente"}
   Then notes if any: {"type":"note","id":"note-1","title":"Tips","body":"..."}
   IDs must be stable short strings (ing-1, step-1, etc.) not UUIDs. No trailing text after the last line.
6. When still exploring (no explicit commit): emit patchSet: null.
7. Equipment preferences in RECIPE CONTEXT are additive — assume standard home kitchen basics are always available. If no equipment is listed, assume a fully equipped standard home kitchen. Never restrict suggestions to only what's listed.
8. If the user mentions anything personal about themselves that would be useful to know in a future cooking session — including foods they love, foods they hate or avoid, dietary restrictions, cooking methods or equipment they use, who they cook for, or any other standing preference — include a concise second-person "proposed_memory" string (e.g. "You love mashed potatoes", "You avoid cilantro", "You cook on induction", "You cook for two young kids"). Write it as a short second-person phrase starting with "You" — not "I", not third-person, no subject-less phrases. Omit if it's a one-time request for this recipe ("add more salt to this"), a question, or already in the user's saved memories. When in doubt, propose it.

Output shape — exploring, not yet ready:
{"assistant_message":"...","patchSet":null}

Output shape — exploring, not yet ready, with a personal preference noted:
{"assistant_message":"...","patchSet":null,"proposed_memory":"You love mashed potatoes"}

Output shape — exploring, ready to generate (model has enough info; user has not yet committed):
{"assistant_message":"...","patchSet":null,"suggest_generate":true}

Output shape — creating recipe (NDJSON — one JSON object per line, no other text):
{"type":"chat","text":"Here's your Classic Pasta Carbonara!"}
{"type":"meta","title":"Classic Pasta Carbonara","servings":4}
{"type":"ingredient","id":"ing-1","text":"200g spaghetti"}
{"type":"ingredient","id":"ing-2","text":"100g guanciale, diced"}
{"type":"step","id":"step-1","parentId":null,"text":"Boil a large pot of well-salted water"}
{"type":"step","id":"step-2","parentId":null,"text":"Cook pasta until al dente, reserving 1 cup pasta water before draining"}
{"type":"note","id":"note-1","title":"Tips","body":"Use room-temperature eggs to prevent scrambling when you add them to the pasta"}`;

// ---------------------------------------------------------------------------
// Voice mode: function tool definitions and system prompt builder
// ---------------------------------------------------------------------------

const VOICE_TOOLS: OpenAI.Chat.ChatCompletionTool[] = [
  {
    type: "function",
    function: {
      name: "propose_patch",
      description:
        "Propose a change to the current recipe. Call this immediately when the user requests a recipe change. Pass the complete PatchSet as a JSON string in patchJson.",
      parameters: {
        type: "object",
        properties: {
          patchJson: {
            type: "string",
            description: "A JSON string representing the full PatchSet to apply.",
          },
        },
        required: ["patchJson"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "accept_recipe",
      description:
        "Accept the pending recipe change. Call this when the user says yes, accept, do it, looks good, or sounds good.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "reject_recipe",
      description:
        "Reject the pending recipe change. Call this when the user says no, reject, undo, cancel, or nope.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "exit_voice",
      description:
        "Exit voice mode. Call this when the user says done, exit, or stop listening. Say nothing before or after this call.",
      parameters: { type: "object", properties: {} },
    },
  },
];

const VOICE_RECIPE_ID = "00000000-0000-0000-0000-000000000000";

function buildVoiceSystemPromptForEval(recipeState: RecipeState | null): string {
  const core = `You are Sous, a voice cooking assistant. The user is at the stove right now, speaking to you hands-free.

VOICE DELIVERY RULES:
Never use markdown, bullet points, numbered lists, bold, italics, or any formatting. Everything you say is spoken aloud.
Keep replies to one or two sentences. Three sentences is the absolute maximum, and only when a patch announcement requires it.
Never open with filler phrases like "Sure!", "Of course!", "Absolutely!", or "Great question!".
Speak like a knowledgeable friend standing next to the user at the stove, not a corporate assistant reading from a script.

WHAT YOU CAN DO:
Answer cooking questions, give substitution advice, help troubleshoot problems, and propose changes to the recipe on the canvas.

WHAT YOU CANNOT DO:
Generate a new recipe. Enter an exploration or discovery mode. Help the user start a new recipe or change what they are cooking entirely.
If the user asks to start over or cook something else, tell them in one sentence to exit voice mode and do it there.

PROPOSING RECIPE CHANGES:
When the user wants to change the recipe, call propose_patch immediately. Do not ask for confirmation first. Pass the complete PatchSet as a JSON string in the patchJson argument. After the call, announce what changed in one spoken sentence in plain language.
Good: "I have doubled the chili flakes, say accept or reject or use the buttons on screen."
Bad: reading field names, JSON, or asking whether to propose the change.
Only call propose_patch when the user is clearly asking for a recipe change. For questions or advice, answer verbally with no function call.
Never propose a change to a step the user has already marked done.

ACCEPTING AND REJECTING:
If the user says yes, accept, do it, looks good, or sounds good, call accept_recipe with no arguments.
If the user says no, reject, undo, cancel, or nope, call reject_recipe with no arguments.

EXITING VOICE MODE:
If the user says done, exit, or stop listening, call exit_voice with no arguments. Say nothing before or after this call.

PATCHSET FORMAT:
When calling propose_patch, the patchJson argument must be a valid JSON string representing a PatchSet with this structure:
{
  "patchSetId": "<new uuid>",
  "baseRecipeId": "${VOICE_RECIPE_ID}",
  "baseRecipeVersion": <integer matching current recipe version>,
  "status": "pending",
  "patches": [ <array of Patch objects> ],
  "summary": "<one sentence plain English summary>"
}
Patch types (use the exact type string as the JSON key):
setTitle: { "setTitle": { "title": "<string>" } }
addIngredient: { "addIngredient": { "groupId": null, "text": "<full ingredient string e.g. 2 cups flour>", "afterId": null } }
updateIngredient: { "updateIngredient": { "id": "<uuid>", "text": "<new full ingredient string>" } }
removeIngredient: { "removeIngredient": { "id": "<uuid>" } }
addStep: { "addStep": { "text": "<string>", "afterId": null } }
updateStep: { "updateStep": { "id": "<uuid>", "text": "<string>" } }
removeStep: { "removeStep": { "id": "<uuid>" } }
Never modify a step whose status is done.

PERSONALITY: Warm and conversational without being chatty. Sounds like a knowledgeable friend. Stay useful above all else.`;

  const version = recipeState?.version ?? 0;
  const title = recipeState?.title ?? "";
  const ingredients = recipeState?.ingredients ?? [];
  const steps = recipeState?.steps ?? [];

  const recipeLines: string[] = [
    `CURRENT RECIPE ON CANVAS:`,
    `id: ${VOICE_RECIPE_ID}  version: ${version}  title: "${title}"`,
    ``,
  ];

  if (ingredients.length === 0) {
    recipeLines.push("(no ingredients)");
  } else {
    for (const ing of ingredients) {
      const text = [ing.quantity, ing.unit, ing.name].filter(Boolean).join(" ");
      recipeLines.push(`- ${text}  [id: ${ing.id}]`);
    }
  }

  recipeLines.push("");

  if (steps.length === 0) {
    recipeLines.push("(no steps)");
  } else {
    steps.forEach((s, i) => {
      recipeLines.push(`${i + 1}. [${s.status}] ${s.text}  [id: ${s.id}]`);
    });
  }

  const doneIds = steps.filter((s) => s.status === "done").map((s) => s.id);
  if (doneIds.length > 0) {
    recipeLines.push(`\ndone step IDs (immutable): [${doneIds.join(", ")}]`);
  }

  const recipeSection = recipeLines.join("\n");

  return [core, recipeSection, "USER MEMORIES: None saved yet.", "USER PREFERENCES: None set."].join(
    "\n\n"
  );
}

// ---------------------------------------------------------------------------
// OpenAI client
// ---------------------------------------------------------------------------

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// ---------------------------------------------------------------------------
// Task function: call GPT-5.4-mini with the test case input
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// RECIPE CONTEXT builder — mirrors recipeContextMessage() in OpenAILLMOrchestrator.swift
// ---------------------------------------------------------------------------

function buildRecipeContext(recipeState: RecipeState | null): string {
  const id = "00000000-0000-0000-0000-000000000000";
  const version = recipeState?.version ?? 0;
  const title = recipeState?.title ?? "";

  const ingredientsJson = (recipeState?.ingredients ?? [])
    .map((i) => `{"id":"${i.id}","text":"${[i.quantity, i.unit, i.name].filter(Boolean).join(" ")}"}`)
    .join(",");

  const stepsJson = (recipeState?.steps ?? [])
    .map((s) => `{"id":"${s.id}","text":"${s.text}","status":"${s.status}"}`)
    .join(",");

  const doneIds = (recipeState?.steps ?? [])
    .filter((s) => s.status === "done")
    .map((s) => s.id)
    .join(", ");

  const lines: string[] = [
    "--- RECIPE CONTEXT ---",
    `id: ${id}  version: ${version}  title: "${title}"`,
    `ingredients: [${ingredientsJson}]`,
    `steps: [${stepsJson}]`,
    `done step IDs (immutable): [${doneIds}]`,
    `hardAvoids: none`,
    `personalityMode: normal`,
  ];

  const memories = recipeState?.userPreferences ?? [];
  if (memories.length > 0) {
    const formatted = memories.map((m) => `• ${m}`).join("\n");
    lines.push(`memories (user context for all sessions):\n${formatted}`);
  }

  return lines.join("\n");
}

function selectSystemPrompt(promptType: TestCase["promptType"]): string {
  switch (promptType) {
    case "import":          return SYSTEM_PROMPT_IMPORT;
    case "unit_conversion": return SYSTEM_PROMPT_UNIT_CONVERSION;
    case "has_canvas":      return SYSTEM_PROMPT_HAS_CANVAS;
    case "no_canvas":       return SYSTEM_PROMPT_NO_CANVAS;
    case "voice":           return ""; // voice uses buildVoiceSystemPromptForEval instead
  }
}

// ---------------------------------------------------------------------------
// Voice task runner — function-calling path
// ---------------------------------------------------------------------------

async function runVoiceTask(input: TestInput): Promise<EvalOutput> {
  const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
    { role: "system", content: buildVoiceSystemPromptForEval(input.recipeState) },
  ];

  for (const msg of input.chatHistory) {
    messages.push({ role: msg.role, content: msg.content });
  }
  messages.push({ role: "user", content: input.userMessage });

  const completion = await openai.chat.completions.create({
    model: "gpt-5.4-mini",
    messages,
    tools: VOICE_TOOLS,
    tool_choice: "auto",
    temperature: 0,
  });

  const choice = completion.choices[0];
  const toolCalls = choice?.message?.tool_calls;

  if (toolCalls && toolCalls.length > 0) {
    const call = toolCalls[0];
    let args: Record<string, unknown> = {};
    try {
      args = JSON.parse(call.function.arguments) as Record<string, unknown>;
    } catch {
      // leave args empty; schemaScorer will flag the invalid JSON
    }
    return {
      rawResponse: { functionCall: call.function.name, args },
      hasPatchSet: call.function.name === "propose_patch",
      isValidJson: true,
      voiceFunctionCall: { name: call.function.name, args },
    };
  }

  const rawContent = choice?.message?.content ?? "";
  return {
    rawResponse: rawContent,
    hasPatchSet: false,
    isValidJson: false,
    voiceFunctionCall: undefined,
  };
}

async function runTask(input: TestInput, promptType: TestCase["promptType"]): Promise<EvalOutput> {
  if (promptType === "voice") {
    return runVoiceTask(input);
  }

  const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
    { role: "system", content: selectSystemPrompt(promptType) },
  ];

  // Inject RECIPE CONTEXT as a system message (matches OpenAILLMOrchestrator.swift format)
  messages.push({
    role: "system",
    content: buildRecipeContext(input.recipeState),
  });

  // Add chat history
  for (const msg of input.chatHistory) {
    messages.push({ role: msg.role, content: msg.content });
  }

  // Add the user's message
  messages.push({ role: "user", content: input.userMessage });

  const completion = await openai.chat.completions.create({
    model: "gpt-5.4-mini",
    messages,
    temperature: 0,
  });

  const rawContent = completion.choices[0]?.message?.content ?? "";

  // Detect NDJSON: multiple non-empty lines each parseable as a JSON object.
  // This is the creation path output format (type:chat, type:meta, type:ingredient, etc.).
  const nonEmptyLines = rawContent.split("\n").filter((l) => l.trim().length > 0);
  if (nonEmptyLines.length >= 2) {
    const allLinesAreJson = nonEmptyLines.every((line) => {
      try { const p = JSON.parse(line.trim()); return typeof p === "object" && p !== null; }
      catch { return false; }
    });
    if (allLinesAreJson) {
      // NDJSON creation response — pass the full text to the scorer/judge
      return { rawResponse: rawContent, hasPatchSet: false, isValidJson: true };
    }
  }

  // Parse the response as JSON exactly once.
  // The model is instructed to return JSON only, so try the raw content first.
  // Fall back to extracting a JSON block (e.g. fenced code block or bare object)
  // only if direct parsing fails.
  let isValidJson = false;
  let hasPatchSet = false;
  let rawResponse: unknown = rawContent;

  const candidates: string[] = [rawContent];

  const jsonBlockMatch = rawContent.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (jsonBlockMatch?.[1]) candidates.push(jsonBlockMatch[1].trim());

  const inlineJsonMatch = rawContent.match(/\{[\s\S]*\}/);
  if (inlineJsonMatch?.[0]) candidates.push(inlineJsonMatch[0]);

  for (const candidate of candidates) {
    try {
      let parsed = JSON.parse(candidate);

      // Defensive unwrap: if the model double-encoded its response by stuffing
      // the full JSON output as a string inside assistant_message, parse through it.
      if (
        parsed !== null &&
        typeof parsed === "object" &&
        typeof parsed.assistant_message === "string" &&
        parsed.patchSet === null
      ) {
        try {
          const inner = JSON.parse(parsed.assistant_message);
          if (inner !== null && typeof inner === "object" && "assistant_message" in inner) {
            parsed = inner;
          }
        } catch {
          // assistant_message is just a plain string — leave parsed as-is
        }
      }

      isValidJson = true;
      hasPatchSet = parsed.patchSet != null;
      rawResponse = parsed;
      break;
    } catch {
      // try next candidate
    }
  }

  return { rawResponse, hasPatchSet, isValidJson };
}

// ---------------------------------------------------------------------------
// Scorer 1: schemaScorer (deterministic)
// ---------------------------------------------------------------------------

function schemaScorer({
  output,
  expected,
}: {
  output: EvalOutput;
  expected: TestExpected;
}): { name: string; score: number; metadata?: Record<string, unknown> } {
  const { hasPatchSet, isValidJson, rawResponse } = output;
  const { shouldPatch, shouldSuggestGenerate, shouldCallVoiceFunction } = expected;

  const checks: { name: string; pass: boolean; reason: string }[] = [];

  // Voice-mode check: function call routing
  if (shouldCallVoiceFunction !== undefined) {
    const call = output.voiceFunctionCall;
    if (shouldCallVoiceFunction === false) {
      if (call) {
        checks.push({
          name: "voiceFunction",
          pass: false,
          reason: `Expected no function call but model called: ${call.name}`,
        });
      } else {
        checks.push({ name: "voiceFunction", pass: true, reason: "No function call as expected" });
      }
    } else {
      if (!call) {
        checks.push({
          name: "voiceFunction",
          pass: false,
          reason: `Expected function call '${shouldCallVoiceFunction}' but none was made`,
        });
      } else if (call.name !== shouldCallVoiceFunction) {
        checks.push({
          name: "voiceFunction",
          pass: false,
          reason: `Expected function call '${shouldCallVoiceFunction}' but got '${call.name}'`,
        });
      } else {
        checks.push({ name: "voiceFunction", pass: true, reason: `Correct function call: ${call.name}` });
      }
    }

    // When propose_patch is expected, also validate the patchJson payload
    if (shouldCallVoiceFunction === "propose_patch" && shouldPatch === true) {
      const call = output.voiceFunctionCall;
      if (call?.name === "propose_patch") {
        const patchJsonStr = call.args["patchJson"];
        if (typeof patchJsonStr !== "string") {
          checks.push({
            name: "proposePatchPayload",
            pass: false,
            reason: "propose_patch called but patchJson argument is missing or not a string",
          });
        } else {
          try {
            const patchSet = JSON.parse(patchJsonStr) as Record<string, unknown>;
            const hasRequired =
              typeof patchSet["patchSetId"] === "string" &&
              typeof patchSet["baseRecipeId"] === "string" &&
              typeof patchSet["baseRecipeVersion"] === "number" &&
              Array.isArray(patchSet["patches"]) &&
              (patchSet["patches"] as unknown[]).length > 0;
            checks.push({
              name: "proposePatchPayload",
              pass: hasRequired,
              reason: hasRequired
                ? "patchJson is a valid PatchSet with required fields"
                : "patchJson is valid JSON but missing required PatchSet fields (patchSetId, baseRecipeId, baseRecipeVersion, patches)",
            });
          } catch {
            checks.push({
              name: "proposePatchPayload",
              pass: false,
              reason: "patchJson argument is not valid JSON",
            });
          }
        }
      }
    }
  } else {
    // Non-voice checks

    // Check 1: patchSet presence/absence
    if (shouldPatch === true && !hasPatchSet) {
      checks.push({ name: "patchSet", pass: false, reason: "Expected patchSet but none found" });
    } else if (shouldPatch === false && hasPatchSet) {
      checks.push({ name: "patchSet", pass: false, reason: "Expected no patchSet but one was found" });
    } else if (hasPatchSet && !isValidJson) {
      checks.push({ name: "patchSet", pass: false, reason: "patchSet found but JSON is invalid" });
    } else if (shouldPatch !== undefined) {
      checks.push({ name: "patchSet", pass: true, reason: "patchSet check passed" });
    }

    // Check 2: suggest_generate presence/absence (only when shouldSuggestGenerate is defined)
    if (shouldSuggestGenerate !== undefined) {
      const parsed =
        typeof rawResponse === "object" && rawResponse !== null
          ? (rawResponse as Record<string, unknown>)
          : {};
      const hasSuggestGenerate = parsed.suggest_generate === true;

      if (shouldSuggestGenerate === true && !hasSuggestGenerate) {
        checks.push({
          name: "suggest_generate",
          pass: false,
          reason: "Expected suggest_generate: true but not found",
        });
      } else if (shouldSuggestGenerate === false && hasSuggestGenerate) {
        checks.push({
          name: "suggest_generate",
          pass: false,
          reason: "Expected suggest_generate absent/false but it was true",
        });
      } else {
        checks.push({ name: "suggest_generate", pass: true, reason: "suggest_generate check passed" });
      }
    }
  }

  // If no applicable checks, pass by default
  if (checks.length === 0) {
    return {
      name: "schemaScorer",
      score: 1,
      metadata: { reason: "No schema checks applicable", hasPatchSet, isValidJson },
    };
  }

  const score = checks.filter((c) => c.pass).length / checks.length;
  const failures = checks.filter((c) => !c.pass).map((c) => c.reason);

  return {
    name: "schemaScorer",
    score,
    metadata: {
      reason: failures.length === 0 ? "All schema checks passed" : failures.join("; "),
      checks,
      hasPatchSet,
      isValidJson,
    },
  };
}

// ---------------------------------------------------------------------------
// Scorer 2: behaviorScorer (LLM-as-judge)
// ---------------------------------------------------------------------------

async function behaviorScorer({
  output,
  expected,
  input,
}: {
  output: EvalOutput;
  expected: TestExpected;
  input: TestInput;
}): Promise<{ name: string; score: number; metadata?: Record<string, unknown> }> {
  const judgePrompt = `You are evaluating an AI cooking assistant called Sous.

User message: ${input.userMessage}
What we were testing for: ${expected.notes}
Expected behavior: ${JSON.stringify(expected, null, 2)}

Actual assistant response:
${typeof output.rawResponse === "string" ? output.rawResponse : JSON.stringify(output.rawResponse, null, 2)}

Score this response from 0.0 to 1.0 based on how well it satisfies the intent described in "What we were testing for".

Scoring guidance:
- Focus on whether the outcome matches the intent in the notes — not on which specific patch operations were used.
- When shouldPatch is true, a response is correct if it emits a patchSet that addresses the user's request. The specific operations chosen (e.g. remove_ingredient vs update_ingredient, or how many patches) are implementation details — do not penalize reasonable alternatives that achieve the same culinary result.
- Do not penalize reasonable interpretation of ambiguous requests. If the model's interpretation is defensible given the user message, treat it as correct.
- 1.0 = fully satisfies the intent
- 0.5 = partially satisfies (gets the gist right but misses something clearly important per the notes)
- 0.0 = clearly violates the intent (e.g. patches when it shouldn't, doesn't patch when it should, touches a done step, ignores the request entirely)

Respond with JSON only, in this exact format:
{
  "score": <number between 0.0 and 1.0>,
  "reasoning": "<one or two sentences explaining your score>"
}`;

  const completion = await openai.chat.completions.create({
    model: "gpt-5.4-mini",
    messages: [{ role: "user", content: judgePrompt }],
    temperature: 0,
    response_format: { type: "json_object" },
  });

  const judgeResponse = completion.choices[0]?.message?.content ?? "{}";

  try {
    const parsed = JSON.parse(judgeResponse) as {
      score: number;
      reasoning: string;
    };
    return {
      name: "behaviorScorer",
      score: Math.min(1, Math.max(0, parsed.score ?? 0)),
      metadata: { reasoning: parsed.reasoning },
    };
  } catch {
    return {
      name: "behaviorScorer",
      score: 0,
      metadata: { reasoning: "Failed to parse judge response", raw: judgeResponse },
    };
  }
}

// ---------------------------------------------------------------------------
// Run the eval
// ---------------------------------------------------------------------------

await Eval("sous", {
  data: () =>
    cases.map((tc) => ({
      input: { ...tc.input, promptType: tc.promptType },
      expected: tc.expected,
      metadata: { name: tc.name, description: tc.description },
    })),

  task: async (input: TestInput & { promptType: TestCase["promptType"] }) =>
    runTask(input, input.promptType),

  scores: [
    ({ output, expected }: { output: EvalOutput; expected: TestExpected }) =>
      schemaScorer({ output, expected }),

    async ({
      output,
      expected,
      input,
    }: {
      output: EvalOutput;
      expected: TestExpected;
      input: TestInput;
    }) => behaviorScorer({ output, expected, input }),
  ],
});
