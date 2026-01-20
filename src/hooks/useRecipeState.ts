import { useState, useEffect, useCallback, useRef } from 'react'
import { Recipe, Patch, ChangeSet } from '../types/recipe'
import { applyPatches, PatchResult } from '../utils/patches'

const STORAGE_KEY = 'sous-recipe-state'
const MAX_HISTORY_SIZE = 20

export function useRecipeState(initialRecipe: Recipe) {
  const [recipe, setRecipe] = useState<Recipe>(() => {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored) {
      try {
        const parsed = JSON.parse(stored)
        if (parsed.id === initialRecipe.id) {
          return parsed
        }
      } catch {
        // Invalid JSON, use initial
      }
    }
    return initialRecipe
  })

  // History stack for undo functionality
  const historyRef = useRef<Recipe[]>([])

  // Track pending changes awaiting review
  const [pendingChangeSet, setPendingChangeSet] = useState<ChangeSet | null>(null)

  // Persist to localStorage on every change
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(recipe))
  }, [recipe])

  const toggleIngredient = useCallback((ingredientId: string) => {
    setRecipe(prev => ({
      ...prev,
      version: prev.version + 1,
      ingredients: prev.ingredients.map(ing =>
        ing.id === ingredientId
          ? { ...ing, checked: !ing.checked }
          : ing
      )
    }))
  }, [])

  const markStepDone = useCallback((stepId: string) => {
    setRecipe(prev => {
      const stepIndex = prev.steps.findIndex(s => s.id === stepId)
      if (stepIndex === -1) return prev

      const step = prev.steps[stepIndex]
      if (step.status === 'done') return prev // Already done, no change

      const newSteps = prev.steps.map(s =>
        s.id === stepId ? { ...s, status: 'done' as const } : s
      )

      // Find next todo step to set as current
      const nextTodoStep = newSteps.find(s => s.status === 'todo')

      return {
        ...prev,
        version: prev.version + 1,
        steps: newSteps,
        currentStepId: nextTodoStep?.id ?? null
      }
    })
  }, [])

  const setCurrentStep = useCallback((stepId: string) => {
    setRecipe(prev => {
      const step = prev.steps.find(s => s.id === stepId)
      if (!step || step.status === 'done') return prev

      return {
        ...prev,
        currentStepId: stepId
      }
    })
  }, [])

  const resetRecipe = useCallback(() => {
    setRecipe(initialRecipe)
    historyRef.current = []
    localStorage.removeItem(STORAGE_KEY)
  }, [initialRecipe])

  // Apply patches from LLM response
  const applyRecipePatches = useCallback((patches: Patch[]): PatchResult => {
    let result: PatchResult = {
      recipe,
      appliedPatches: [],
      rejectedPatches: [],
      changeSet: {
        changedIngredientIds: [],
        addedIngredientIds: [],
        removedIngredientIds: [],
        changedStepIds: [],
        addedStepIds: [],
        addedNoteIndices: [],
        patches: [],
        previousRecipe: recipe
      }
    }

    setRecipe(prev => {
      // Save current state to history for undo
      historyRef.current = [prev, ...historyRef.current].slice(0, MAX_HISTORY_SIZE)

      result = applyPatches(prev, patches)

      // Set pending changeSet if any patches were applied
      if (result.appliedPatches.length > 0) {
        setPendingChangeSet(result.changeSet)
      }

      return result.recipe
    })

    return result
  }, [recipe])

  // Undo last patch application
  const undo = useCallback((): boolean => {
    if (historyRef.current.length === 0) {
      return false
    }

    const [previousState, ...rest] = historyRef.current
    historyRef.current = rest
    setRecipe(previousState)
    return true
  }, [])

  // Check if undo is available
  const canUndo = historyRef.current.length > 0

  // Approve pending changes - permanently removes soft-deleted ingredients and clears pending state
  const approveChanges = useCallback(() => {
    // Permanently remove soft-deleted ingredients
    setRecipe(prev => ({
      ...prev,
      ingredients: prev.ingredients.filter(ing => !ing.removed)
    }))
    setPendingChangeSet(null)
  }, [])

  // Reject pending changes - reverts to previous recipe and returns the rejected changeSet
  const rejectChanges = useCallback((): ChangeSet | null => {
    if (!pendingChangeSet) return null

    const rejectedChangeSet = pendingChangeSet

    // Revert to the previous recipe state
    setRecipe(pendingChangeSet.previousRecipe)

    // Remove the most recent history entry since we're reverting
    if (historyRef.current.length > 0) {
      historyRef.current = historyRef.current.slice(1)
    }

    // Clear the pending state
    setPendingChangeSet(null)

    return rejectedChangeSet
  }, [pendingChangeSet])

  // Check if there are changes pending review
  const hasPendingReview = pendingChangeSet !== null

  return {
    recipe,
    toggleIngredient,
    markStepDone,
    setCurrentStep,
    resetRecipe,
    applyRecipePatches,
    undo,
    canUndo,
    pendingChangeSet,
    hasPendingReview,
    approveChanges,
    rejectChanges
  }
}
