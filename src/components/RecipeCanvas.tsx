import { Recipe, ChangeSet } from '../types/recipe'
import { IngredientItem } from './IngredientItem'
import { StepItem } from './StepItem'

interface RecipeCanvasProps {
  recipe: Recipe
  onToggleIngredient: (id: string) => void
  onMarkStepDone: (id: string) => void
  onSetCurrentStep: (id: string) => void
  pendingChangeSet?: ChangeSet | null
  onApproveChanges?: () => void
  onRejectChanges?: () => void
}

export function RecipeCanvas({
  recipe,
  onToggleIngredient,
  onMarkStepDone,
  onSetCurrentStep,
  pendingChangeSet,
  onApproveChanges,
  onRejectChanges
}: RecipeCanvasProps) {
  const completedSteps = recipe.steps.filter(s => s.status === 'done').length
  const totalSteps = recipe.steps.length
  const progress = totalSteps > 0 ? (completedSteps / totalSteps) * 100 : 0

  // Helper to check if an ingredient is highlighted
  const getIngredientHighlight = (id: string): { isHighlighted: boolean; type?: 'changed' | 'added' | 'removed' } => {
    if (!pendingChangeSet) return { isHighlighted: false }
    if (pendingChangeSet.addedIngredientIds.includes(id)) {
      return { isHighlighted: true, type: 'added' }
    }
    if (pendingChangeSet.removedIngredientIds.includes(id)) {
      return { isHighlighted: true, type: 'removed' }
    }
    if (pendingChangeSet.changedIngredientIds.includes(id)) {
      return { isHighlighted: true, type: 'changed' }
    }
    return { isHighlighted: false }
  }

  // Filter ingredients: show removed ones only during pending review
  const visibleIngredients = recipe.ingredients.filter(ing => {
    if (!ing.removed) return true
    // Show removed ingredients only during pending review
    return pendingChangeSet !== null
  })

  // Helper to check if a step is highlighted
  const getStepHighlight = (id: string): { isHighlighted: boolean; type?: 'changed' | 'added' } => {
    if (!pendingChangeSet) return { isHighlighted: false }
    if (pendingChangeSet.addedStepIds.includes(id)) {
      return { isHighlighted: true, type: 'added' }
    }
    if (pendingChangeSet.changedStepIds.includes(id)) {
      return { isHighlighted: true, type: 'changed' }
    }
    return { isHighlighted: false }
  }

  // Check if a note is highlighted
  const isNoteHighlighted = (index: number): boolean => {
    if (!pendingChangeSet) return false
    return pendingChangeSet.addedNoteIndices.includes(index)
  }

  const hasChanges = pendingChangeSet !== null

  return (
    <div className="recipe-canvas">
      {/* Sticky Review Bar */}
      {hasChanges && onApproveChanges && onRejectChanges && (
        <div className="review-bar">
          <span className="review-bar-text">AI made changes to your recipe</span>
          <div className="review-bar-buttons">
            <button className="approve-btn" onClick={onApproveChanges}>
              Approve
            </button>
            <button className="reject-btn" onClick={onRejectChanges}>
              Reject
            </button>
          </div>
        </div>
      )}

      <header className="recipe-header">
        <h1 className="recipe-title">{recipe.title}</h1>
        <div className="recipe-progress">
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: `${progress}%` }} />
          </div>
          <span className="progress-text">{completedSteps}/{totalSteps} steps</span>
        </div>
      </header>

      <section className="recipe-section">
        <h2>Ingredients</h2>
        <div className="ingredients-list">
          {visibleIngredients.map(ing => {
            const highlight = getIngredientHighlight(ing.id)
            return (
              <IngredientItem
                key={ing.id}
                ingredient={ing}
                onToggle={onToggleIngredient}
                isHighlighted={highlight.isHighlighted}
                highlightType={highlight.type}
              />
            )
          })}
        </div>
      </section>

      <section className="recipe-section">
        <h2>Steps</h2>
        <div className="steps-list">
          {recipe.steps.map((step, index) => {
            const highlight = getStepHighlight(step.id)
            return (
              <StepItem
                key={step.id}
                step={step}
                stepNumber={index + 1}
                isCurrent={step.id === recipe.currentStepId}
                onMarkDone={onMarkStepDone}
                onSetCurrent={onSetCurrentStep}
                isHighlighted={highlight.isHighlighted}
                highlightType={highlight.type}
              />
            )
          })}
        </div>
      </section>

      {recipe.notes.length > 0 && (
        <section className="recipe-section">
          <h2>Notes</h2>
          <ul className="notes-list">
            {recipe.notes.map((note, index) => (
              <li
                key={index}
                className={isNoteHighlighted(index) ? 'highlight-added' : ''}
              >
                {note}
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}
