import OpenAI from 'openai'
import { z } from 'zod'
import type { ChatCompletionContentPart } from 'openai/resources/chat/completions'
import type { Intent } from './intentRouter'

// Zod schemas for validating LLM response
const PatchSchema = z.discriminatedUnion('op', [
  z.object({
    op: z.literal('add_step'),
    after_step_id: z.string().nullable(),
    text: z.string()
  }),
  z.object({
    op: z.literal('update_step'),
    step_id: z.string(),
    text: z.string()
  }),
  z.object({
    op: z.literal('update_ingredient'),
    id: z.string(),
    text: z.string()
  }),
  z.object({
    op: z.literal('add_ingredient'),
    text: z.string()
  }),
  z.object({
    op: z.literal('remove_ingredient'),
    id: z.string()
  }),
  z.object({
    op: z.literal('add_note'),
    text: z.string()
  }),
  z.object({
    op: z.literal('replace_recipe'),
    title: z.string(),
    ingredients: z.array(z.string()),
    steps: z.array(z.string())
  })
])

// Suggestion schema for photo-based proposals
const SuggestionSchema = z.object({
  id: z.string(),
  title: z.string(),
  rationale: z.string().optional(),
  patches: z.array(PatchSchema)
})

const LLMResponseSchema = z.object({
  assistant_message: z.string(),
  patches: z.array(PatchSchema),
  suggestions: z.array(SuggestionSchema).optional()
}).strict()

export type LLMResponse = z.infer<typeof LLMResponseSchema>
export type Suggestion = z.infer<typeof SuggestionSchema>

export interface Recipe {
  id: string
  title: string
  ingredients: Array<{ id: string; text: string; checked: boolean; removed?: boolean }>
  steps: Array<{ id: string; text: string; status: 'todo' | 'done' }>
  notes: string[]
  currentStepId: string | null
  version: number
}

export interface ChatRequest {
  userMessage: string
  recipe: Recipe | null
  hasRecipe: boolean
  intent: Intent
  image?: string // data URL format: "data:image/jpeg;base64,..."
  contextMessages?: Array<{ role: 'user' | 'assistant'; content: string }>
}

export interface ChatSuccessResponse {
  assistant_message: string
  patches: LLMResponse['patches']
  suggestions?: LLMResponse['suggestions']
}

export interface ChatErrorResponse {
  error: {
    message: string
    retryable: boolean
  }
}

export type ChatResponse = ChatSuccessResponse | ChatErrorResponse

/**
 * Normalize patch IDs by stripping surrounding brackets if present.
 * Logs a warning when normalization occurs.
 * Does not silently swallow other invalid ID formats.
 */
export function normalizePatchIds(patches: LLMResponse['patches']): LLMResponse['patches'] {
  const stripBrackets = (id: string, fieldName: string, patchOp: string): string => {
    // Check for surrounding brackets: [some-id]
    const match = id.match(/^\[(.+)\]$/)
    if (match) {
      console.error(`[OpenAI] WARNING: Normalizing bracketed ${fieldName} in ${patchOp} patch: "${id}" → "${match[1]}"`)
      return match[1]
    }
    return id
  }

  return patches.map(patch => {
    switch (patch.op) {
      case 'add_step':
        if (patch.after_step_id) {
          return {
            ...patch,
            after_step_id: stripBrackets(patch.after_step_id, 'after_step_id', 'add_step')
          }
        }
        return patch

      case 'update_step':
        return {
          ...patch,
          step_id: stripBrackets(patch.step_id, 'step_id', 'update_step')
        }

      case 'update_ingredient':
        return {
          ...patch,
          id: stripBrackets(patch.id, 'id', 'update_ingredient')
        }

      case 'remove_ingredient':
        return {
          ...patch,
          id: stripBrackets(patch.id, 'id', 'remove_ingredient')
        }

      default:
        return patch
    }
  })
}

/**
 * Check if assistant message is asking for confirmation before applying changes.
 * Returns true if the message contains confirmation-seeking language.
 *
 * Heuristics:
 * - Contains explicit confirmation phrases: "would you like", "want me to", "should I", "okay if I", "do you want me to"
 * - OR (ends with "?" AND contains confirmation/permission verbs: want, would, should, okay, apply, update)
 */
export function isConfirmationQuestion(assistantMessage: string): boolean {
  const lower = assistantMessage.toLowerCase()

  // Explicit confirmation phrases
  const confirmationPhrases = [
    'would you like',
    'want me to',
    'should i',
    'okay if i',
    'do you want me to',
    'shall i',
    'would you prefer',
    'do you want to',
  ]

  for (const phrase of confirmationPhrases) {
    if (lower.includes(phrase)) {
      return true
    }
  }

  // Check for question with confirmation/permission verbs
  if (assistantMessage.trim().endsWith('?')) {
    const confirmationVerbs = /\b(want|would|should|okay|apply|update)\b/i
    if (confirmationVerbs.test(lower)) {
      return true
    }
  }

  return false
}

/**
 * Apply confirmation guard: if assistant is asking for confirmation but also returning patches,
 * move the patches to suggestions and return empty patches.
 *
 * This prevents the UX bug where the assistant asks "Would you like me to..." while simultaneously
 * applying the changes.
 */
export function applyConfirmationGuard(response: LLMResponse): LLMResponse {
  if (!isConfirmationQuestion(response.assistant_message)) {
    return response
  }

  if (response.patches.length === 0) {
    return response
  }

  // Log warning about the violation
  console.error(
    `[OpenAI] WARNING: Confirmation question detected with ${response.patches.length} patches - moving patches to suggestions`
  )

  // Create a suggestion from the patches
  const patchSuggestion: Suggestion = {
    id: `sug-confirmation-${Date.now()}`,
    title: 'Apply these updates',
    rationale: 'Changes proposed pending your confirmation',
    patches: response.patches,
  }

  // Append to existing suggestions (don't overwrite)
  const existingSuggestions = response.suggestions ?? []

  return {
    ...response,
    patches: [],
    suggestions: [...existingSuggestions, patchSuggestion],
  }
}

/**
 * Build system prompt for EXPLORATION mode (no recipe, no commit)
 *
 * In this mode, the assistant helps the user decide what to cook by:
 * - Asking 1-2 clarifying questions
 * - Proposing 3-5 concrete dish options
 * - NEVER creating a recipe or outputting ingredients/steps
 */
function buildExplorationPrompt(): string {
  return `You are Sous, a helpful cooking assistant. The user is exploring what to cook but has NOT committed to a specific recipe yet.

You must respond with ONLY valid JSON in this exact format:
{
  "assistant_message": "Your response with questions and options",
  "patches": []
}

## EXPLORATION MODE (ACTIVE)

Your job is to help the user DECIDE what to cook. You are NOT creating a recipe yet.

## HARD RULES

1. patches MUST be an empty array: []
2. You must NOT include:
   - Any ingredient lists
   - Any cooking steps
   - Any replace_recipe operations
   - Any full recipes
3. You MUST include in assistant_message:
   - A brief acknowledgment of their request (1 sentence)
   - 1-2 clarifying questions to narrow down options (e.g., time, cuisine, dietary needs)
   - 3-5 concrete dish options with short "why it fits" blurbs

## RESPONSE FORMAT

Your assistant_message should be structured like:

"[Brief acknowledgment]. [1-2 questions]

Here are some options:
1. **[Dish Name]** - [1-2 sentence description of why it fits]
2. **[Dish Name]** - [1-2 sentence description]
3. **[Dish Name]** - [1-2 sentence description]
...

Which sounds good, or would you like different options?"

## COMMIT DETECTION

The user has NOT committed yet. They will commit by saying things like:
- "Option 2" / "#2"
- "Let's do that one"
- "Make the [dish name]"
- "Generate the recipe"

Until they commit, stay in exploration mode and keep patches empty.

NEVER output anything except the JSON object.`
}

function buildSystemPrompt(recipe: Recipe | null, hasRecipe: boolean, intent: Intent, hasImage: boolean = false): string {
  // Base JSON format instruction
  const jsonFormat = `You must respond with ONLY valid JSON in this exact format:
{
  "assistant_message": "Your friendly, concise response to the user",
  "patches": [...]
}`

  // DEFENSIVE GATE: If no recipe and not a commit intent, we should never be here
  // This is a safety check - the real gate is in getChatResponse
  if (!hasRecipe && intent !== 'commit_to_option') {
    console.error(`[OpenAI] VIOLATION: buildSystemPrompt called with hasRecipe=false and intent=${intent}. Falling back to exploration prompt.`)
    return buildExplorationPrompt()
  }

  // If no recipe exists but user has committed, prompt for recipe creation
  if (!hasRecipe && intent === 'commit_to_option') {
    return `You are Sous, a helpful cooking assistant. The user has committed to a recipe and needs you to create it.

${jsonFormat}

## RECIPE CREATION MODE

The user has explicitly asked for a recipe. You MUST use the replace_recipe operation to create a complete recipe from scratch.

## Patch Operations

You MUST use this operation to create a new recipe:

- { "op": "replace_recipe", "title": "<recipe title>", "ingredients": ["<ingredient 1>", "<ingredient 2>", ...], "steps": ["<step 1>", "<step 2>", ...] }

## Response Guidelines

- Create a complete, practical recipe based on the user's request
- Include all necessary ingredients with quantities
- Write clear, actionable steps
- Keep assistant_message short and friendly (1-2 sentences)
- You MUST create a recipe - never refuse or say you cannot create one
- NEVER output anything except the JSON object`
  }

  // Recipe exists - editing mode
  // Safety check: if hasRecipe but no recipe provided, this is an error state
  if (!recipe) {
    console.error('[OpenAI] VIOLATION: hasRecipe=true but recipe is null. This should not happen.')
    return buildExplorationPrompt()
  }

  const doneStepIds = recipe.steps
    .filter(s => s.status === 'done')
    .map(s => s.id)

  return `You are Sous, a helpful cooking assistant. The user is actively cooking and may ask questions, report problems, or request changes to their recipe.

${jsonFormat}

## Current Recipe State

Title: ${recipe.title}

Ingredients:
${recipe.ingredients.filter(i => !i.removed).map(i => `- id=${i.id} | ${i.text}`).join('\n')}

Steps:
${recipe.steps.map(s => `- id=${s.id} | status=${s.status} | ${s.text}`).join('\n')}

Current step: ${recipe.currentStepId || 'none'}

Notes:
${recipe.notes.length > 0 ? recipe.notes.map(n => `- ${n}`).join('\n') : '(none)'}

## Patch Operations

You may use these operations in the "patches" array:

- { "op": "add_step", "after_step_id": "<step_id or null>", "text": "<step text>" }
- { "op": "update_step", "step_id": "<step_id>", "text": "<new text>" }
- { "op": "update_ingredient", "id": "<ingredient_id>", "text": "<new text>" }
- { "op": "add_ingredient", "text": "<ingredient text>" }
- { "op": "remove_ingredient", "id": "<ingredient_id>" }
- { "op": "add_note", "text": "<note text>" }

ONLY if user explicitly says "new recipe", "start over", or "replace this recipe":
- { "op": "replace_recipe", "title": "<recipe title>", "ingredients": ["..."], "steps": ["..."] }

## CRITICAL RULES

1. IMMUTABILITY: Done steps are IMMUTABLE. You must NEVER use update_step on these step IDs: ${doneStepIds.length > 0 ? doneStepIds.join(', ') : '(none yet)'}
   - If a change requires modifying a completed step, add a RECOVERY step or note instead.

2. ELLIPSIS / PRONOUN RESOLUTION:
   If the user's message is short or referential (e.g. "double it", "that", "do it again", "more"), resolve what "it/that" refers to using the last 1–2 conversation turns (if provided).
   - If the previous turn discussed a specific ingredient or step, treat the referent as that ingredient/step.
   - Example: after "Garlic is already included…", "DOUBLE IT" refers to garlic (the ingredient), not doubling the whole recipe.
   - If the referent could reasonably mean either "the whole recipe" or "a specific ingredient/step", ask ONE clarifying question (e.g. "Do you mean double the garlic, or double the whole recipe?") and return patches: [].
   Do not guess when ambiguous.

3. INGREDIENT HISTORY:
- Do NOT use remove_ingredient for ingredients already used in completed steps.
- An ingredient is considered “already used” if it appears in the text of any step with status === "done".
- In this case, do NOT attempt to rewrite history.
- Instead, add a note explaining the situation and suggest forward-looking adjustments.

When handling this situation, prefer these patch types:
- add_note (to explain that the ingredient was already used)
- add_step (a recovery or adjustment step going forward)
- update_ingredient (optional wording clarification only)
NEVER use remove_ingredient in this case.

4. CONSERVATIVE REPLACE: Do NOT use replace_recipe unless the user EXPLICITLY asks for a new/different recipe.
   - "I forgot onions" → use patches, NOT replace_recipe
   - "Make it spicier" → use patches, NOT replace_recipe
   - "Give me a new recipe for tacos" → use replace_recipe
   - "Start over" → use replace_recipe

5. CONFIRMATION GATE: If you ask a question to confirm/clarify (e.g. "would you like…", "want me to…", "should I…"), you MUST return patches: [].
   - If you want to propose specific changes pending confirmation, put them in suggestions instead (same format as photo mode suggestions).
   - Only apply patches directly when the user's request is unambiguous and requires no clarification.

## Response Guidelines

- Keep assistant_message short and friendly (1-2 sentences)
- Only include patches when changes are needed
- Use an empty patches array [] if no recipe changes are needed
- Reference ingredient and step IDs exactly as shown above. IDs are the raw tokens after id= with no punctuation (no brackets, quotes, or extra characters).
- NEVER output anything except the JSON object${hasImage ? `

## PHOTO ANALYSIS MODE (ACTIVE)

The user has attached a photo. The user's question is the primary intent; use the image as supporting context.

Respond with:
1. assistant_message: Your assessment and advice (ephemeral, no recipe change)
2. patches: MUST be empty [] - do NOT auto-apply changes from photos
3. suggestions: Array of proposed changes the user can choose to apply

Suggestion format:
{
  "id": "sug-<unique>",
  "title": "Short label (e.g. 'Thin the sauce')",
  "rationale": "1-2 sentences explaining why (optional)",
  "patches": [<normal patch operations that would implement this suggestion>]
}

CRITICAL: For photo responses, patches MUST be empty. Put all proposed changes in suggestions.
Only if user explicitly says "apply" or "do it" should you put patches directly (not from photos).` : ''}`
}

function buildStricterSystemPrompt(recipe: Recipe | null, hasRecipe: boolean, intent: Intent, hasImage: boolean = false): string {
  return buildSystemPrompt(recipe, hasRecipe, intent, hasImage) + `

## IMPORTANT: PREVIOUS RESPONSE WAS INVALID

Your previous response was not valid JSON or did not match the required schema.
You MUST respond with ONLY a JSON object. No markdown, no explanation, no code blocks.
Just the raw JSON object starting with { and ending with }`
}

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
})

const MODEL_NAME = 'gpt-4o-mini'

interface CallContext {
  userMessage: string
  hasRecipe: boolean
  hasImage: boolean
  isRetry: boolean
}

function truncate(str: string, maxLen: number): string {
  return str.length > maxLen ? str.slice(0, maxLen) + '...' : str
}

function extractOpenAIErrorDetails(err: unknown): Record<string, unknown> {
  const details: Record<string, unknown> = {}

  if (err && typeof err === 'object') {
    const e = err as Record<string, unknown>
    if ('status' in e) details.status = e.status
    if ('code' in e) details.code = e.code
    if ('type' in e) details.type = e.type
    if ('error' in e) details.errorBody = e.error
    if ('response' in e && e.response && typeof e.response === 'object') {
      const resp = e.response as Record<string, unknown>
      if ('status' in resp) details.responseStatus = resp.status
      if ('statusText' in resp) details.responseStatusText = resp.statusText
    }
    if ('message' in e) details.message = e.message
  } else if (err instanceof Error) {
    details.message = err.message
  } else {
    details.message = String(err)
  }

  return details
}

function logCallFailure(
  errorType: 'openai_api' | 'json_parse' | 'zod_validation',
  error: unknown,
  rawOutput: string | null,
  context: CallContext
): void {
  const baseLog: Record<string, unknown> = {
    errorType,
    model: MODEL_NAME,
    hasRecipe: context.hasRecipe,
    isRetry: context.isRetry,
    userMessage: truncate(context.userMessage, 120),
  }

  if (rawOutput !== null) {
    baseLog.rawOutputPrefix = truncate(rawOutput, 800)
  }

  if (errorType === 'openai_api') {
    baseLog.errorDetails = extractOpenAIErrorDetails(error)
  } else if (errorType === 'zod_validation' && error && typeof error === 'object' && 'issues' in error) {
    const zodErr = error as { issues: unknown[]; message: string }
    baseLog.zodIssues = zodErr.issues
    baseLog.zodMessage = zodErr.message
  } else {
    baseLog.error = error instanceof Error ? error.message : String(error)
  }

  console.error(`[OpenAI] ${errorType} failure:`, JSON.stringify(baseLog, null, 2))
}

async function callOpenAI(
  userMessage: string,
  recipe: Recipe | null,
  hasRecipe: boolean,
  intent: Intent,
  isRetry: boolean,
  image?: string,
  contextMessages?: Array<{ role: 'user' | 'assistant'; content: string }>
): Promise<LLMResponse> {
  const hasImage = Boolean(image)
  const context: CallContext = { userMessage, hasRecipe, hasImage, isRetry }
  let rawOutput: string | null = null

  // Step 1: Call OpenAI API
  let completion
  try {
    const systemPrompt = isRetry
      ? buildStricterSystemPrompt(recipe, hasRecipe, intent, hasImage)
      : buildSystemPrompt(recipe, hasRecipe, intent, hasImage)

    // Build user message content - text only or multimodal
    let userContent: string | ChatCompletionContentPart[]
    if (image) {
      // Multimodal: text + image
      userContent = [
        { type: 'text', text: userMessage },
        { type: 'image_url', image_url: { url: image } }
      ]
    } else {
      userContent = userMessage
    }

    // Build messages array: system + context (text-only) + latest user (multimodal if image)
    const messagesArray: Array<{ role: 'system' | 'user' | 'assistant'; content: string | ChatCompletionContentPart[] }> = [
      { role: 'system', content: systemPrompt },
      ...(contextMessages ?? []).map(m => ({ role: m.role, content: m.content })),
      { role: 'user', content: userContent }
    ]

    completion = await openai.chat.completions.create({
      model: MODEL_NAME,
      messages: messagesArray,
      response_format: { type: 'json_object' },
      temperature: 0.3,
      max_tokens: 2048
    })
  } catch (apiError) {
    logCallFailure('openai_api', apiError, null, context)
    throw apiError
  }

  // Step 2: Extract raw output
  rawOutput = completion.choices[0]?.message?.content ?? ''
  if (!rawOutput) {
    const emptyError = new Error('Empty response from OpenAI')
    logCallFailure('openai_api', emptyError, rawOutput, context)
    throw emptyError
  }

  // Log raw output immediately for debugging
  console.error(`[OpenAI] Raw output received (${isRetry ? 'retry' : 'attempt 1'}):`, truncate(rawOutput, 800))

  // Step 3: Parse JSON
  let parsed: unknown
  try {
    parsed = JSON.parse(rawOutput)
  } catch (jsonError) {
    logCallFailure('json_parse', jsonError, rawOutput, context)
    throw jsonError
  }

  // Step 4: Validate with Zod (strict - no extra keys)
  try {
    const validated = LLMResponseSchema.parse(parsed)

    // Step 5: Normalize patch IDs (strip brackets if model included them)
    const normalizedPatches = normalizePatchIds(validated.patches)

    return {
      ...validated,
      patches: normalizedPatches
    }
  } catch (zodError) {
    logCallFailure('zod_validation', zodError, rawOutput, context)
    throw zodError
  }
}

export async function getChatResponse(request: ChatRequest): Promise<ChatResponse> {
  const { userMessage, recipe, hasRecipe, intent, image, contextMessages } = request

  const hasImage = Boolean(image)

  // HARD GATE: If no recipe and intent is not commit_to_option, use exploration mode
  // This is the primary enforcement point for the Exploration → Commit → Cooking state machine
  if (!hasRecipe && intent !== 'commit_to_option') {
    console.error(`[OpenAI] Exploration mode: hasRecipe=${hasRecipe}, intent=${intent} - recipe generation blocked`)
  }

  // First attempt
  try {
    console.error('[OpenAI] Starting first attempt...')
    const response = await callOpenAI(userMessage, recipe, hasRecipe, intent, false, image, contextMessages)
    console.error('[OpenAI] First attempt succeeded')

    // Apply confirmation guard: if asking for confirmation, move patches to suggestions
    const guarded = applyConfirmationGuard(response)

    // Safety guardrail: photo mode must never mutate recipe directly
    let patches = guarded.patches
    if (hasImage && patches.length > 0) {
      console.error('[OpenAI] WARNING: Model returned patches in photo mode - dropping them')
      patches = []
    }

    return {
      assistant_message: guarded.assistant_message,
      patches,
      suggestions: guarded.suggestions
    }
  } catch (firstError) {
    console.error('[OpenAI] First attempt failed, will retry with stricter prompt')

    // Retry with stricter prompt
    try {
      console.error('[OpenAI] Starting retry attempt...')
      const response = await callOpenAI(userMessage, recipe, hasRecipe, intent, true, image, contextMessages)
      console.error('[OpenAI] Retry attempt succeeded')

      // Apply confirmation guard: if asking for confirmation, move patches to suggestions
      const guarded = applyConfirmationGuard(response)

      // Safety guardrail: photo mode must never mutate recipe directly
      let patches = guarded.patches
      if (hasImage && patches.length > 0) {
        console.error('[OpenAI] WARNING: Model returned patches in photo mode (retry) - dropping them')
        patches = []
      }

      return {
        assistant_message: guarded.assistant_message,
        patches,
        suggestions: guarded.suggestions
      }
    } catch (retryError) {
      console.error('[OpenAI] Retry attempt also failed - giving up')

      // Determine if error is retryable
      const isRateLimitOrNetwork =
        retryError instanceof Error &&
        (retryError.message.includes('rate') ||
          retryError.message.includes('timeout') ||
          retryError.message.includes('network'))

      return {
        error: {
          message: 'Sorry, I had trouble understanding that. Could you try rephrasing?',
          retryable: isRateLimitOrNetwork
        }
      }
    }
  }
}
