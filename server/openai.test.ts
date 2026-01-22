/**
 * Unit tests for OpenAI module utilities
 *
 * Run with: OPENAI_API_KEY=test npx tsx server/openai.test.ts
 */

import { normalizePatchIds, isConfirmationQuestion, applyConfirmationGuard } from './openai'
import assert from 'node:assert'

// Capture console.error calls for testing warnings
const warnings: string[] = []
const originalConsoleError = console.error
console.error = (...args: unknown[]) => {
  const msg = args.map(a => String(a)).join(' ')
  if (msg.includes('WARNING:')) {
    warnings.push(msg)
  }
  // Still log to console for visibility
  originalConsoleError.apply(console, args)
}

// Test helper
function test(name: string, fn: () => void) {
  warnings.length = 0 // Reset warnings before each test
  try {
    fn()
    console.log(`✓ ${name}`)
  } catch (err) {
    console.error(`✗ ${name}`)
    console.error(err)
    process.exitCode = 1
  }
}

console.log('\n=== normalizePatchIds Tests ===\n')

// ─────────────────────────────────────────────────────────────
// BRACKETED IDS (should be normalized with warning)
// ─────────────────────────────────────────────────────────────

console.log('Bracketed IDs (should normalize with warning):')

test('update_step with bracketed step_id gets normalized', () => {
  const patches = normalizePatchIds([
    { op: 'update_step', step_id: '[step-1]', text: 'New text' }
  ])

  assert.strictEqual(patches.length, 1)
  assert.strictEqual(patches[0].op, 'update_step')
  if (patches[0].op === 'update_step') {
    assert.strictEqual(patches[0].step_id, 'step-1')
  }
  assert.strictEqual(warnings.length, 1)
  assert.ok(warnings[0].includes('[step-1]'))
  assert.ok(warnings[0].includes('step-1'))
})

test('update_ingredient with bracketed id gets normalized', () => {
  const patches = normalizePatchIds([
    { op: 'update_ingredient', id: '[ing-garlic]', text: '4 cloves garlic' }
  ])

  assert.strictEqual(patches.length, 1)
  if (patches[0].op === 'update_ingredient') {
    assert.strictEqual(patches[0].id, 'ing-garlic')
  }
  assert.strictEqual(warnings.length, 1)
  assert.ok(warnings[0].includes('[ing-garlic]'))
})

test('remove_ingredient with bracketed id gets normalized', () => {
  const patches = normalizePatchIds([
    { op: 'remove_ingredient', id: '[ing-onion]' }
  ])

  assert.strictEqual(patches.length, 1)
  if (patches[0].op === 'remove_ingredient') {
    assert.strictEqual(patches[0].id, 'ing-onion')
  }
  assert.strictEqual(warnings.length, 1)
})

test('add_step with bracketed after_step_id gets normalized', () => {
  const patches = normalizePatchIds([
    { op: 'add_step', after_step_id: '[step-2]', text: 'New step' }
  ])

  assert.strictEqual(patches.length, 1)
  if (patches[0].op === 'add_step') {
    assert.strictEqual(patches[0].after_step_id, 'step-2')
  }
  assert.strictEqual(warnings.length, 1)
})

test('multiple bracketed IDs in same batch all get normalized', () => {
  const patches = normalizePatchIds([
    { op: 'update_step', step_id: '[step-1]', text: 'Updated' },
    { op: 'update_ingredient', id: '[ing-salt]', text: '2 tsp salt' },
    { op: 'remove_ingredient', id: '[ing-pepper]' }
  ])

  assert.strictEqual(patches.length, 3)
  if (patches[0].op === 'update_step') {
    assert.strictEqual(patches[0].step_id, 'step-1')
  }
  if (patches[1].op === 'update_ingredient') {
    assert.strictEqual(patches[1].id, 'ing-salt')
  }
  if (patches[2].op === 'remove_ingredient') {
    assert.strictEqual(patches[2].id, 'ing-pepper')
  }
  assert.strictEqual(warnings.length, 3)
})

// ─────────────────────────────────────────────────────────────
// CLEAN IDS (should pass through unchanged, no warnings)
// ─────────────────────────────────────────────────────────────

console.log('\nClean IDs (should pass through unchanged):')

test('update_step with clean step_id passes through', () => {
  const patches = normalizePatchIds([
    { op: 'update_step', step_id: 'step-1', text: 'New text' }
  ])

  assert.strictEqual(patches.length, 1)
  if (patches[0].op === 'update_step') {
    assert.strictEqual(patches[0].step_id, 'step-1')
  }
  assert.strictEqual(warnings.length, 0)
})

test('update_ingredient with clean id passes through', () => {
  const patches = normalizePatchIds([
    { op: 'update_ingredient', id: 'ing-garlic', text: '4 cloves garlic' }
  ])

  assert.strictEqual(patches.length, 1)
  if (patches[0].op === 'update_ingredient') {
    assert.strictEqual(patches[0].id, 'ing-garlic')
  }
  assert.strictEqual(warnings.length, 0)
})

test('add_step with null after_step_id passes through', () => {
  const patches = normalizePatchIds([
    { op: 'add_step', after_step_id: null, text: 'First step' }
  ])

  assert.strictEqual(patches.length, 1)
  if (patches[0].op === 'add_step') {
    assert.strictEqual(patches[0].after_step_id, null)
  }
  assert.strictEqual(warnings.length, 0)
})

// ─────────────────────────────────────────────────────────────
// OTHER PATCH TYPES (should pass through unchanged)
// ─────────────────────────────────────────────────────────────

console.log('\nOther patch types (should pass through unchanged):')

test('add_ingredient passes through unchanged', () => {
  const patches = normalizePatchIds([
    { op: 'add_ingredient', text: '1 cup flour' }
  ])

  assert.strictEqual(patches.length, 1)
  assert.strictEqual(patches[0].op, 'add_ingredient')
  if (patches[0].op === 'add_ingredient') {
    assert.strictEqual(patches[0].text, '1 cup flour')
  }
  assert.strictEqual(warnings.length, 0)
})

test('add_note passes through unchanged', () => {
  const patches = normalizePatchIds([
    { op: 'add_note', text: 'Serve immediately' }
  ])

  assert.strictEqual(patches.length, 1)
  assert.strictEqual(patches[0].op, 'add_note')
  assert.strictEqual(warnings.length, 0)
})

test('replace_recipe passes through unchanged', () => {
  const patches = normalizePatchIds([
    { op: 'replace_recipe', title: 'New Recipe', ingredients: ['1 egg'], steps: ['Crack egg'] }
  ])

  assert.strictEqual(patches.length, 1)
  assert.strictEqual(patches[0].op, 'replace_recipe')
  assert.strictEqual(warnings.length, 0)
})

test('empty patches array passes through', () => {
  const patches = normalizePatchIds([])
  assert.strictEqual(patches.length, 0)
  assert.strictEqual(warnings.length, 0)
})

// ─────────────────────────────────────────────────────────────
// isConfirmationQuestion TESTS
// ─────────────────────────────────────────────────────────────

console.log('\n=== isConfirmationQuestion Tests ===\n')

console.log('Confirmation questions (should return true):')

test('"Would you like me to update the garlic?" → true', () => {
  assert.strictEqual(isConfirmationQuestion('Would you like me to update the garlic?'), true)
})

test('"Should I add more salt?" → true', () => {
  assert.strictEqual(isConfirmationQuestion('Should I add more salt?'), true)
})

test('"Want me to double it?" → true', () => {
  assert.strictEqual(isConfirmationQuestion('Want me to double it?'), true)
})

test('"Do you want me to make it spicier?" → true', () => {
  assert.strictEqual(isConfirmationQuestion('Do you want me to make it spicier?'), true)
})

test('"Is it okay if I remove the onions?" → true', () => {
  assert.strictEqual(isConfirmationQuestion('Is it okay if I remove the onions?'), true)
})

test('"Shall I update the recipe?" → true', () => {
  assert.strictEqual(isConfirmationQuestion('Shall I update the recipe?'), true)
})

test('"Would you prefer less garlic?" → true', () => {
  assert.strictEqual(isConfirmationQuestion('Would you prefer less garlic?'), true)
})

test('"Do you want to apply these changes?" → true (question with "apply")', () => {
  assert.strictEqual(isConfirmationQuestion('Do you want to apply these changes?'), true)
})

console.log('\nNon-confirmation messages (should return false):')

test('"Here\'s the updated recipe." → false', () => {
  assert.strictEqual(isConfirmationQuestion("Here's the updated recipe."), false)
})

test('"I\'ve added the garlic." → false', () => {
  assert.strictEqual(isConfirmationQuestion("I've added the garlic."), false)
})

test('"What ingredients do you have?" → false (question but no confirmation verb)', () => {
  assert.strictEqual(isConfirmationQuestion('What ingredients do you have?'), false)
})

test('"Done! The recipe is updated." → false', () => {
  assert.strictEqual(isConfirmationQuestion('Done! The recipe is updated.'), false)
})

test('"No problem, I removed the onions." → false', () => {
  assert.strictEqual(isConfirmationQuestion('No problem, I removed the onions.'), false)
})

test('"How spicy do you like it?" → false (question but no confirmation verb)', () => {
  assert.strictEqual(isConfirmationQuestion('How spicy do you like it?'), false)
})

// ─────────────────────────────────────────────────────────────
// applyConfirmationGuard TESTS
// ─────────────────────────────────────────────────────────────

console.log('\n=== applyConfirmationGuard Tests ===\n')

console.log('Guard behavior:')

test('moves patches to suggestions when confirmation detected', () => {
  const response = {
    assistant_message: 'Would you like me to update the garlic?',
    patches: [{ op: 'update_ingredient' as const, id: 'ing-garlic', text: '4 cloves garlic' }],
    suggestions: undefined
  }

  const guarded = applyConfirmationGuard(response)

  assert.strictEqual(guarded.patches.length, 0)
  assert.ok(guarded.suggestions)
  assert.strictEqual(guarded.suggestions!.length, 1)
  assert.strictEqual(guarded.suggestions![0].title, 'Apply these updates')
  assert.strictEqual(guarded.suggestions![0].patches.length, 1)
  assert.strictEqual(warnings.length, 1)
  assert.ok(warnings[0].includes('Confirmation question detected'))
})

test('appends to existing suggestions when confirmation detected', () => {
  const response = {
    assistant_message: 'Should I also add more salt?',
    patches: [{ op: 'add_ingredient' as const, text: '1 tsp salt' }],
    suggestions: [{
      id: 'existing-sug',
      title: 'Existing suggestion',
      patches: [{ op: 'add_note' as const, text: 'Some note' }]
    }]
  }

  const guarded = applyConfirmationGuard(response)

  assert.strictEqual(guarded.patches.length, 0)
  assert.ok(guarded.suggestions)
  assert.strictEqual(guarded.suggestions!.length, 2)
  assert.strictEqual(guarded.suggestions![0].title, 'Existing suggestion')
  assert.strictEqual(guarded.suggestions![1].title, 'Apply these updates')
})

test('passes through unchanged when no confirmation detected', () => {
  const response = {
    assistant_message: "Done! I've updated the recipe.",
    patches: [{ op: 'update_ingredient' as const, id: 'ing-garlic', text: '4 cloves garlic' }],
    suggestions: undefined
  }

  const guarded = applyConfirmationGuard(response)

  assert.strictEqual(guarded.patches.length, 1)
  assert.strictEqual(guarded.suggestions, undefined)
  assert.strictEqual(warnings.length, 0)
})

test('passes through unchanged when patches already empty', () => {
  const response = {
    assistant_message: 'Would you like me to update the garlic?',
    patches: [],
    suggestions: undefined
  }

  const guarded = applyConfirmationGuard(response)

  assert.strictEqual(guarded.patches.length, 0)
  assert.strictEqual(guarded.suggestions, undefined)
  assert.strictEqual(warnings.length, 0)
})

console.log('\n=== All tests passed ===\n')

// Restore console.error
console.error = originalConsoleError
