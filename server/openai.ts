import OpenAI from 'openai'
import { z } from 'zod'

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

const LLMResponseSchema = z.object({
  assistant_message: z.string(),
  patches: z.array(PatchSchema)
}).strict()

export type LLMResponse = z.infer<typeof LLMResponseSchema>

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
}

export interface ChatSuccessResponse {
  assistant_message: string
  patches: LLMResponse['patches']
}

export interface ChatErrorResponse {
  error: {
    message: string
    retryable: boolean
  }
}

export type ChatResponse = ChatSuccessResponse | ChatErrorResponse

function buildSystemPrompt(recipe: Recipe | null, hasRecipe: boolean): string {
  // Base JSON format instruction
  const jsonFormat = `You must respond with ONLY valid JSON in this exact format:
{
  "assistant_message": "Your friendly, concise response to the user",
  "patches": [...]
}`

  // If no recipe exists, prompt for recipe creation
  if (!hasRecipe) {
    return `You are Sous, a helpful cooking assistant. The user does not have a recipe yet and needs you to create one.

${jsonFormat}

## RECIPE CREATION MODE

The user needs a new recipe. You MUST use the replace_recipe operation to create a complete recipe from scratch.

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
  // Safety check: if hasRecipe but no recipe provided, fall back to creation mode
  if (!recipe) {
    return buildSystemPrompt(null, false)
  }

  const doneStepIds = recipe.steps
    .filter(s => s.status === 'done')
    .map(s => s.id)

  return `You are Sous, a helpful cooking assistant. The user is actively cooking and may ask questions, report problems, or request changes to their recipe.

${jsonFormat}

## Current Recipe State

Title: ${recipe.title}

Ingredients:
${recipe.ingredients.filter(i => !i.removed).map(i => `- [${i.id}] ${i.text}`).join('\n')}

Steps:
${recipe.steps.map(s => `- [${s.id}] (${s.status}) ${s.text}`).join('\n')}

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

2. CONSERVATIVE REPLACE: Do NOT use replace_recipe unless the user EXPLICITLY asks for a new/different recipe.
   - "I forgot onions" → use patches, NOT replace_recipe
   - "Make it spicier" → use patches, NOT replace_recipe
   - "Give me a new recipe for tacos" → use replace_recipe
   - "Start over" → use replace_recipe

## Response Guidelines

- Keep assistant_message short and friendly (1-2 sentences)
- Only include patches when changes are needed
- Use an empty patches array [] if no recipe changes are needed
- Reference ingredient and step IDs exactly as shown above
- NEVER output anything except the JSON object`
}

function buildStricterSystemPrompt(recipe: Recipe | null, hasRecipe: boolean): string {
  return buildSystemPrompt(recipe, hasRecipe) + `

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
  isRetry: boolean
): Promise<LLMResponse> {
  const context: CallContext = { userMessage, hasRecipe, isRetry }
  let rawOutput: string | null = null

  // Step 1: Call OpenAI API
  let completion
  try {
    const systemPrompt = isRetry
      ? buildStricterSystemPrompt(recipe, hasRecipe)
      : buildSystemPrompt(recipe, hasRecipe)

    completion = await openai.chat.completions.create({
      model: MODEL_NAME,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessage }
      ],
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
    return validated
  } catch (zodError) {
    logCallFailure('zod_validation', zodError, rawOutput, context)
    throw zodError
  }
}

export async function getChatResponse(request: ChatRequest): Promise<ChatResponse> {
  const { userMessage, recipe, hasRecipe } = request

  // First attempt
  try {
    console.error('[OpenAI] Starting first attempt...')
    const response = await callOpenAI(userMessage, recipe, hasRecipe, false)
    console.error('[OpenAI] First attempt succeeded')
    return {
      assistant_message: response.assistant_message,
      patches: response.patches
    }
  } catch (firstError) {
    console.error('[OpenAI] First attempt failed, will retry with stricter prompt')

    // Retry with stricter prompt
    try {
      console.error('[OpenAI] Starting retry attempt...')
      const response = await callOpenAI(userMessage, recipe, hasRecipe, true)
      console.error('[OpenAI] Retry attempt succeeded')
      return {
        assistant_message: response.assistant_message,
        patches: response.patches
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
