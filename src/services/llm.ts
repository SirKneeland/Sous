import { Recipe, LLMResponse, RejectionEvent, Patch } from '../types/recipe'

/**
 * Stubbed LLM service that returns predetermined responses based on user input.
 * This simulates the LLM behavior for Milestone 2 before wiring a real API.
 */

/**
 * Send a rejection event to the LLM.
 * Currently stubbed - logs to console and stores locally.
 * Will be wired to actual LLM API in the future.
 */
export function sendRejectionEvent(
  rejectedPatches: Patch[],
  reason?: string
): RejectionEvent {
  const event: RejectionEvent = {
    type: 'user_rejected_suggestion',
    rejectedPatches,
    reason,
    timestamp: Date.now()
  }

  // Stub implementation: log to console
  console.log('[LLM Event] User rejected suggestion:', event)

  // In the future, this would send to the actual LLM API
  // await fetch('/api/llm/feedback', { method: 'POST', body: JSON.stringify(event) })

  return event
}
export async function getStubbedLLMResponse(
  userMessage: string,
  recipe: Recipe
): Promise<LLMResponse> {
  // Simulate network delay
  await new Promise(resolve => setTimeout(resolve, 500))

  const lowerMessage = userMessage.toLowerCase()

  // Handle "I forgot onions" / "no onions" scenarios
  if (lowerMessage.includes('onion') && (lowerMessage.includes('forgot') || lowerMessage.includes('out of') || lowerMessage.includes('no '))) {
    const onionIngredient = recipe.ingredients.find(i =>
      i.text.toLowerCase().includes('onion')
    )

    // Find step 2 (onion step) to check if it's done
    const onionStep = recipe.steps.find(s =>
      s.text.toLowerCase().includes('onion')
    )

    if (onionStep && onionStep.status === 'done') {
      return {
        assistant_message: "No worries! Since you've already completed that step, the dish will still turn out fine. The other aromatics will carry the flavor.",
        patches: [
          { op: 'add_note', text: 'Onion was skipped - dish will still be delicious!' }
        ]
      }
    }

    const patches: LLMResponse['patches'] = []

    if (onionIngredient) {
      patches.push({ op: 'remove_ingredient', id: onionIngredient.id })
    }
    patches.push({ op: 'add_ingredient', text: '1 bell pepper, diced (onion substitute)' })

    if (onionStep && onionStep.status === 'todo') {
      patches.push({
        op: 'update_step',
        step_id: onionStep.id,
        text: 'Add diced bell pepper to the pot. Cook until slightly softened (3-4 minutes).'
      })
    }

    return {
      assistant_message: "No problem! We can substitute bell pepper for the onion. It'll add a nice sweetness to the chili.",
      patches
    }
  }

  // Handle "burned the garlic" scenario
  if (lowerMessage.includes('burn') && lowerMessage.includes('garlic')) {
    return {
      assistant_message: "Don't worry, burned garlic happens! Remove what you can and let's add some recovery steps.",
      patches: [
        { op: 'add_ingredient', text: '2 additional cloves garlic, minced (recovery)' },
        {
          op: 'add_step',
          after_step_id: recipe.currentStepId,
          text: 'RECOVERY: Scoop out any burned garlic bits. Add fresh garlic and cook briefly (15 seconds).'
        },
        { op: 'add_note', text: 'Added extra garlic to compensate for burned batch.' }
      ]
    }
  }

  // Handle "make it spicier" scenario
  if (lowerMessage.includes('spic') || lowerMessage.includes('heat') || lowerMessage.includes('hot')) {
    const chiliPowder = recipe.ingredients.find(i =>
      i.text.toLowerCase().includes('chili powder')
    )

    const patches: LLMResponse['patches'] = []

    if (chiliPowder) {
      patches.push({
        op: 'update_ingredient',
        id: chiliPowder.id,
        text: '3 tbsp chili powder (extra spicy!)'
      })
    }
    patches.push({ op: 'add_ingredient', text: '1/2 tsp cayenne pepper' })
    patches.push({ op: 'add_note', text: 'Boosted the heat as requested!' })

    return {
      assistant_message: "Let's turn up the heat! I've increased the chili powder and added some cayenne.",
      patches
    }
  }

  // Handle "double the recipe" / "more servings"
  if (lowerMessage.includes('double') || lowerMessage.includes('more serving')) {
    return {
      assistant_message: "I can help you scale up! I'll double the key ingredients.",
      patches: [
        { op: 'update_ingredient', id: 'ing-1', text: '2 lbs ground beef' },
        { op: 'update_ingredient', id: 'ing-4', text: '2 cans (14 oz each) diced tomatoes' },
        { op: 'update_ingredient', id: 'ing-5', text: '2 cans (15 oz each) kidney beans, drained' },
        { op: 'update_ingredient', id: 'ing-10', text: '2 cups beef broth' },
        { op: 'add_note', text: 'Recipe doubled - cooking time may need to increase slightly.' }
      ]
    }
  }

  // Default response for unrecognized input
  return {
    assistant_message: "I hear you! For now I can help with: forgetting ingredients (try 'I forgot the onions'), kitchen mishaps (try 'I burned the garlic'), or adjusting spice levels (try 'make it spicier').",
    patches: []
  }
}
