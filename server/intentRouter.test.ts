/**
 * Unit tests for Intent Router
 *
 * Run with: npx tsx server/intentRouter.test.ts
 */

import { intentRouter } from './intentRouter'
import assert from 'node:assert'

// Test helper
function test(name: string, fn: () => void) {
  try {
    fn()
    console.log(`✓ ${name}`)
  } catch (err) {
    console.error(`✗ ${name}`)
    console.error(err)
    process.exitCode = 1
  }
}

console.log('\n=== Intent Router Tests ===\n')

// ─────────────────────────────────────────────────────────────
// COMMIT SIGNALS (should return intent: "commit_to_option")
// ─────────────────────────────────────────────────────────────

console.log('Commit signals:')

test('"let\'s do option 2" → commit_to_option', () => {
  const result = intentRouter({ messageText: "let's do option 2", hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
  assert.strictEqual(result.selectedOptionId, '2')
})

test('"make the French one" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'make the French one', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"generate that" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'generate that', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"ok do #3" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'ok do #3', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
  assert.strictEqual(result.selectedOptionId, '3')
})

test('"go with option 1" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'go with option 1', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"pick that one" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'pick that one', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"choose #2" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'choose #2', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"start the recipe" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'start the recipe', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"lets do it" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'lets do it', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"2)" → commit_to_option', () => {
  const result = intentRouter({ messageText: '2)', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
  assert.strictEqual(result.selectedOptionId, '2')
})

test('UI selectedOptionId provided → commit_to_option', () => {
  const result = intentRouter({ messageText: 'anything', hasCanvas: false, selectedOptionId: 'opt-123' })
  assert.strictEqual(result.intent, 'commit_to_option')
  assert.strictEqual(result.selectedOptionId, 'opt-123')
})

test('"1" (bare option number) → commit_to_option with selectedOptionId', () => {
  const result = intentRouter({ messageText: '1', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
  assert.strictEqual(result.selectedOptionId, '1')
})

test('"make a garlic pasta recipe" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'make a garlic pasta recipe', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"just make the recipe" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'just make the recipe', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"give me the recipe" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'give me the recipe', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

test('"write the recipe" → commit_to_option', () => {
  const result = intentRouter({ messageText: 'write the recipe', hasCanvas: false })
  assert.strictEqual(result.intent, 'commit_to_option')
})

// ─────────────────────────────────────────────────────────────
// NON-COMMIT SIGNALS (should return intent: "explore")
// ─────────────────────────────────────────────────────────────

console.log('\nNon-commit signals:')

test('"what are some options" → explore', () => {
  const result = intentRouter({ messageText: 'what are some options', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"something garlicky" → explore', () => {
  const result = intentRouter({ messageText: 'something garlicky', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"more French ideas" → explore', () => {
  const result = intentRouter({ messageText: 'more French ideas', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"suggest 3 dishes" → explore', () => {
  const result = intentRouter({ messageText: 'suggest 3 dishes', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"I want something quick" → explore', () => {
  const result = intentRouter({ messageText: 'I want something quick', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"what can I make with chicken" → explore', () => {
  const result = intentRouter({ messageText: 'what can I make with chicken', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"I\'ll take more ideas" → explore (loose phrase excluded)', () => {
  const result = intentRouter({ messageText: "I'll take more ideas", hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"sure" → explore (vague affirmation)', () => {
  const result = intentRouter({ messageText: 'sure', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"ok" → explore (vague affirmation)', () => {
  const result = intentRouter({ messageText: 'ok', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"1 cup olive oil" → explore (number in ingredient context)', () => {
  const result = intentRouter({ messageText: '1 cup olive oil', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"30 cloves garlic" → explore (number in ingredient context)', () => {
  const result = intentRouter({ messageText: '30 cloves garlic', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

test('"more options" → explore', () => {
  const result = intentRouter({ messageText: 'more options', hasCanvas: false })
  assert.strictEqual(result.intent, 'explore')
})

// ─────────────────────────────────────────────────────────────
// EDIT MODE (hasCanvas: true)
// ─────────────────────────────────────────────────────────────

console.log('\nEdit mode (canvas exists):')

test('any message with hasCanvas=true → edit_existing_recipe', () => {
  const result = intentRouter({ messageText: 'I forgot onions', hasCanvas: true })
  assert.strictEqual(result.intent, 'edit_existing_recipe')
})

test('commit phrase with hasCanvas=true → still edit_existing_recipe', () => {
  const result = intentRouter({ messageText: 'generate a new recipe', hasCanvas: true })
  assert.strictEqual(result.intent, 'edit_existing_recipe')
})

console.log('\n=== All tests passed ===\n')
