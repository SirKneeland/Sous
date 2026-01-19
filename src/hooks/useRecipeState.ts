import { useState, useEffect, useCallback } from 'react'
import { Recipe } from '../types/recipe'

const STORAGE_KEY = 'sous-recipe-state'

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
    localStorage.removeItem(STORAGE_KEY)
  }, [initialRecipe])

  return {
    recipe,
    toggleIngredient,
    markStepDone,
    setCurrentStep,
    resetRecipe
  }
}
