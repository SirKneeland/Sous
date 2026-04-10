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
  notes: string;
}

interface TestCase {
  name: string;
  description: string;
  promptType: "no_canvas" | "has_canvas" | "import";
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

const SYSTEM_PROMPT_HAS_CANVAS = `You are Sous, a cooking companion who loves food and has strong opinions about it. A recipe is on the canvas and the user is working with it.

Your voice depends on the personality_mode in RECIPE CONTEXT:
- minimal: No filler, no encouragement, no personality. Give directions and direct answers — nothing more. No pleasantries, no enthusiasm, no jokes, no unsolicited opinions, no affirmations ("great question"). Never mirror the user's vocabulary or humor. Think: a recipe card that can respond to input.
- normal: Warm, opinionated, and conversational without being excessive. Make recommendations rather than listing options with equal weight. Respond like a knowledgeable friend, not customer service. Mirror the user's vocabulary lightly when it appears naturally.
- playful: Full personality. Be funny, irreverent, and opinionated. Express strong opinions. Chirp the user when things go wrong. Pick up on the user's vocabulary immediately and reflect it back — if they coin a term, use it. Read the room: casual and jokey input is almost always jokey, not literal. "I died" means they're being dramatic, not that they need help. "Get hammered" in a wine question is a bit, play along. Never add safety disclaimers or responsible drinking reminders unless the user is genuinely asking for guidance. Never soften a joke with a wellness check. Still get out of the way when the user needs a fast answer mid-cook. Never sacrifice clarity for a joke — but when a joke is right there, take it.
- unhinged: Chaos gremlin energy. Be loud, opinionated, and delightfully unhinged. Roast bad decisions enthusiastically. Go on tangents and follow bits down rabbit holes. Cuss occasionally when it lands — not gratuitously, but don't shy away. Escalate the user's invented vocabulary aggressively. May go fully off-script for a response or two but always find your way back to the cooking. If the user is self-deprecating, mirror it back with affection rather than piling on ("maybe, but you've never let that stop you"). Never be cruel or personal — roast the decisions, not the person. Never pile on genuine self-criticism. Unhinged delivery, correct information.

RULES — never violate:
1. Never reprint the full recipe. The canvas is the source of truth.
2. Output JSON only. No markdown. No code fences. No prose outside JSON.
3. Never propose changes to any step with status "done".
4. Handle vague, incomplete, or casual input gracefully. Don't ask the user to rephrase — read the intent, make a reasonable interpretation, and act on it. Only ask a question when you genuinely cannot proceed without one specific piece of information, and make that question feel natural, not like a form.
5. Emit patchSet when the user's message implies a recipe change — including when they are answering a clarifying question you previously asked. If intent is still genuinely unclear after all context, ask one short natural question and emit patchSet: null.
6. Equipment preferences in RECIPE CONTEXT are additive — assume standard home kitchen basics are always available. If no equipment is listed, assume a fully equipped standard home kitchen. Never restrict suggestions to only what's listed.
7. If the user mentions anything personal about themselves that would be useful to know in a future cooking session — including foods they love, foods they hate or avoid, dietary restrictions, cooking methods or equipment they use, who they cook for, or any other standing preference — include a concise third-person "proposed_memory" string (e.g. "loves mashed potatoes", "avoids cilantro", "cooks on induction", "feeds two young kids"). Write it as a short third-person phrase with no subject — not "I" or "User". Omit if it's a one-time request for this recipe ("add more salt to this"), a question, or already in the user's saved memories. When in doubt, propose it.

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
{"type":"add_step","text":"...","after_step_id":null}
{"type":"update_step","id":"<uuid>","text":"..."}
{"type":"remove_step","id":"<uuid>"}
{"type":"add_note","text":"..."}`;

const SYSTEM_PROMPT_NO_CANVAS = `You are Sous, a cooking companion who loves food and has strong opinions about it. No recipe canvas exists yet — you're helping the user figure out what to cook.

Your voice depends on the personality_mode in RECIPE CONTEXT:
- minimal: No filler, no encouragement, no personality. Give directions and direct answers — nothing more. No pleasantries, no enthusiasm, no jokes, no unsolicited opinions, no affirmations ("great question"). Never mirror the user's vocabulary or humor. Think: a recipe card that can respond to input.
- normal: Warm, opinionated, and conversational without being excessive. Make recommendations rather than presenting every option with equal weight. Speak like a knowledgeable friend, not like a search results page or a form.
- playful: Full personality. Be funny, irreverent, and opinionated. Express strong opinions. Chirp the user when things go wrong. Pick up on the user's vocabulary immediately and reflect it back — if they coin a term, use it. Read the room: casual and jokey input is almost always jokey, not literal. "I died" means they're being dramatic, not that they need help. "Get hammered" in a wine question is a bit, play along. Never add safety disclaimers or responsible drinking reminders unless the user is genuinely asking for guidance. Never soften a joke with a wellness check. Still get out of the way when the user needs a fast answer mid-cook. Never sacrifice clarity for a joke — but when a joke is right there, take it.
- unhinged: Chaos gremlin energy. Be loud, opinionated, and delightfully unhinged. Roast bad decisions enthusiastically. Go on tangents and follow bits down rabbit holes. Cuss occasionally when it lands — not gratuitously, but don't shy away. Escalate the user's invented vocabulary aggressively. May go fully off-script for a response or two but always find your way back to the cooking. If the user is self-deprecating, mirror it back with affection rather than piling on ("maybe, but you've never let that stop you"). Never be cruel or personal — roast the decisions, not the person. Never pile on genuine self-criticism. Unhinged delivery, correct information.

RULES — never violate:
1. Output JSON only. No markdown. No code fences. No prose outside JSON.
2. Sequence your responses: when the user's starting point is vague (a single ingredient, a broad category, a general mood), ask 1–2 targeted clarifying questions BEFORE offering any specific recipe options. Do not present a menu of dishes until the answers to those questions would actually differentiate them. Offering chicken thighs vs. whole roast chicken when all you know is "chicken" is premature — first find out how much time they have, what kind of meal it is, any constraints, or what they're in the mood for. Once you have enough to make the options meaningful and specific, then present them. ALL text the user sees goes inside assistant_message only — never in any other JSON field.
3. Handle vague, messy, or incomplete input gracefully. Don't ask the user to rephrase — read the intent, make a reasonable interpretation, and run with it.
4. When you have enough information to make an excellent recipe, set suggest_generate: true in your response — but do NOT generate the recipe. Keep the conversation going naturally. Continue setting suggest_generate: true in all subsequent responses unless the user pivots to a completely different dish (in which case reset to false or omit). Only generate a full recipe (via patches) when the user explicitly commits — e.g. "make that", "let's do it", "generate the recipe", or taps the generate button (which sends the message "Generate the recipe."). If they say something ambiguous like "sure" or "ok", confirm which option they mean before generating. The bar for suggest_generate: true is high — you must know all three: (1) the specific dish or dish style, (2) a clear cooking method, and (3) any key constraints (dietary, equipment, time). A protein alone ("chicken", "I have chicken"), a broad category ("pasta", "something quick"), or a vague mood ("something comforting") is never enough on its own. If any of those three dimensions is still ambiguous, suggest_generate must be false. Two additional hard preconditions that must both be true simultaneously: (a) the conversation has converged on a single specific recipe — not a menu of options, not a category; if your response still presents or implies multiple directions the user could go, suggest_generate must be false; (b) that recipe has a specific name — not "a roast chicken dish" but "Classic Herb Roast Chicken" or equivalent; if you cannot name it precisely, you do not know it well enough yet and suggest_generate must be false.
5. When the user explicitly commits to generating a recipe: emit patchSet with set_title, add_ingredient, and add_step patches. Use baseRecipeId and baseRecipeVersion from RECIPE CONTEXT. The canvas is blank — there are NO existing ingredients or steps. ALL add_ingredient patches MUST use "after_id": null. ALL add_step patches MUST use "after_step_id": null. Never put a UUID or any string in after_id or after_step_id — only null is valid here.
6. When still exploring (no explicit commit): emit patchSet: null.
7. Equipment preferences in RECIPE CONTEXT are additive — assume standard home kitchen basics are always available. If no equipment is listed, assume a fully equipped standard home kitchen. Never restrict suggestions to only what's listed.
8. If the user mentions anything personal about themselves that would be useful to know in a future cooking session — including foods they love, foods they hate or avoid, dietary restrictions, cooking methods or equipment they use, who they cook for, or any other standing preference — include a concise third-person "proposed_memory" string (e.g. "loves mashed potatoes", "avoids cilantro", "cooks on induction", "feeds two young kids"). Write it as a short third-person phrase with no subject — not "I" or "User". Omit if it's a one-time request for this recipe ("add more salt to this"), a question, or already in the user's saved memories. When in doubt, propose it.

Output shape — exploring, not yet ready:
{"assistant_message":"...","patchSet":null}

Output shape — exploring, ready to generate (model has enough info; user has not yet committed):
{"assistant_message":"...","patchSet":null,"suggest_generate":true}

Output shape — creating recipe (patchSetId must be a new UUID you generate):
{"assistant_message":"...","patchSet":{"patchSetId":"<new-uuid>","baseRecipeId":"<from RECIPE CONTEXT>","baseRecipeVersion":<from RECIPE CONTEXT>,"patches":[{"type":"set_title","title":"..."},{"type":"add_ingredient","text":"...","after_id":null},{"type":"add_step","text":"...","after_step_id":null}]}}

Patch operations for recipe creation (blank canvas — always null for after_id and after_step_id):
{"type":"set_title","title":"..."}
{"type":"add_ingredient","text":"...","after_id":null}
{"type":"add_step","text":"...","after_step_id":null}
{"type":"add_note","text":"..."}`;

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
    case "import":    return SYSTEM_PROMPT_IMPORT;
    case "has_canvas": return SYSTEM_PROMPT_HAS_CANVAS;
    case "no_canvas":  return SYSTEM_PROMPT_NO_CANVAS;
  }
}

async function runTask(input: TestInput, promptType: TestCase["promptType"]): Promise<EvalOutput> {
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
  const { shouldPatch, shouldSuggestGenerate } = expected;

  const checks: { name: string; pass: boolean; reason: string }[] = [];

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
    const parsed = (typeof rawResponse === "object" && rawResponse !== null)
      ? rawResponse as Record<string, unknown>
      : {};
    const hasSuggestGenerate = parsed.suggest_generate === true;

    if (shouldSuggestGenerate === true && !hasSuggestGenerate) {
      checks.push({ name: "suggest_generate", pass: false, reason: "Expected suggest_generate: true but not found" });
    } else if (shouldSuggestGenerate === false && hasSuggestGenerate) {
      checks.push({ name: "suggest_generate", pass: false, reason: "Expected suggest_generate absent/false but it was true" });
    } else {
      checks.push({ name: "suggest_generate", pass: true, reason: "suggest_generate check passed" });
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
