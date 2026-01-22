/**
 * Intent Router for Sous
 *
 * Deterministic classifier that routes user messages to the appropriate
 * conversation mode: explore, commit_to_option, or edit_existing_recipe.
 *
 * This is a hard gate - recipe generation is forbidden unless intent === "commit_to_option"
 */

export type Intent = 'explore' | 'commit_to_option' | 'edit_existing_recipe'

export interface IntentRouterInput {
  messageText: string
  hasCanvas: boolean
  selectedOptionId?: string | null
}

export interface IntentRouterOutput {
  intent: Intent
  selectedOptionId?: string
  reason: string
}

/**
 * Commit detection patterns (strict)
 *
 * These patterns indicate the user is explicitly committing to generate a recipe.
 * We intentionally exclude loose phrases like "I'll take X" to avoid false commits.
 */
const COMMIT_PATTERNS: Array<{ pattern: RegExp; description: string }> = [
  // Numbered option references: "option 2", "#2", "2)", "number 2"
  { pattern: /\b(?:option|number)\s*([1-5])\b/i, description: 'numbered option reference' },
  { pattern: /#([1-5])\b/i, description: 'hashtag option reference' },
  { pattern: /\b([1-5])\s*\)/i, description: 'numbered option with paren' },

  // "let's do ..." / "lets do ..."
  { pattern: /\blet'?s\s+do\b/i, description: "let's do" },

  // "make the ... one"
  { pattern: /\bmake\s+(?:the\s+)?(?:\w+\s+)?one\b/i, description: 'make the X one' },

  // "go with ..."
  { pattern: /\bgo\s+with\b/i, description: 'go with' },

  // "pick ..." / "choose ..."
  { pattern: /\b(?:pick|choose)\s+(?:that|this|option|the|#?\d)/i, description: 'pick/choose' },

  // "generate" (the recipe, that, this, etc.)
  { pattern: /\bgenerate\b/i, description: 'generate' },

  // "start the recipe" / "start cooking"
  { pattern: /\bstart\s+(?:the\s+)?(?:recipe|cooking)\b/i, description: 'start the recipe' },

  // "do #3" / "do option 3" / "ok do that"
  { pattern: /\bdo\s+(?:#?\d|option|that|this|it)\b/i, description: 'do X' },

  // "make ... recipe" / "make the recipe" / "make a garlic pasta recipe"
  { pattern: /\bmake\b[\s\S]{0,40}\brecipe\b/i, description: 'make ... recipe' },

  // "give me the recipe" / "write the recipe"
  { pattern: /\b(?:give|write)\b[\s\S]{0,40}\brecipe\b/i, description: 'give/write ... recipe' },
]

/**
 * Check if the message contains a commit signal
 */
function detectCommitSignal(messageText: string): { isCommit: boolean; matchedPattern?: string } {
  const normalized = messageText.trim()

  // Check for bare option number first: "1", "2", etc.
  if (/^[1-5]$/.test(normalized)) {
    return { isCommit: true, matchedPattern: 'bare option number' }
  }

  for (const { pattern, description } of COMMIT_PATTERNS) {
    if (pattern.test(normalized)) {
      return { isCommit: true, matchedPattern: description }
    }
  }

  return { isCommit: false }
}

/**
 * Extract option ID from message if present
 * Returns the option number as a string (e.g., "1", "2", etc.)
 */
function extractOptionId(messageText: string): string | undefined {
  // Check for bare option number first: "1", "2", etc.
  const bareMatch = messageText.trim().match(/^([1-5])$/)
  if (bareMatch) {
    return bareMatch[1]
  }

  // Match patterns like "option 2", "#2", "2)", "number 2"
  const patterns = [
    /\b(?:option|number)\s*([1-5])\b/i,
    /#([1-5])\b/i,  // # is not a word char, so no \b before it
    /\b([1-5])\s*\)/i,
  ]

  for (const pattern of patterns) {
    const match = messageText.match(pattern)
    if (match && match[1]) {
      return match[1]
    }
  }

  return undefined
}

/**
 * Route user message to the appropriate intent
 *
 * Rules:
 * - If hasCanvas === true → edit_existing_recipe (user is cooking)
 * - If hasCanvas === false and selectedOptionId provided → commit_to_option
 * - If hasCanvas === false and commit signal detected → commit_to_option
 * - Otherwise → explore (default, no recipe generation allowed)
 */
export function intentRouter(input: IntentRouterInput): IntentRouterOutput {
  const { messageText, hasCanvas, selectedOptionId } = input

  // If canvas exists, user is editing their recipe
  if (hasCanvas) {
    return {
      intent: 'edit_existing_recipe',
      reason: 'Canvas exists - routing to edit mode'
    }
  }

  // If UI provided a selectedOptionId (button tap), that's an explicit commit
  if (selectedOptionId) {
    return {
      intent: 'commit_to_option',
      selectedOptionId,
      reason: `UI provided selectedOptionId: ${selectedOptionId}`
    }
  }

  // Check for commit signal in message text
  const { isCommit, matchedPattern } = detectCommitSignal(messageText)

  if (isCommit) {
    const extractedOptionId = extractOptionId(messageText)
    return {
      intent: 'commit_to_option',
      selectedOptionId: extractedOptionId,
      reason: `Commit signal detected: ${matchedPattern}`
    }
  }

  // Default: exploration mode - no recipe generation allowed
  return {
    intent: 'explore',
    reason: 'No canvas and no commit signal - staying in exploration mode'
  }
}
