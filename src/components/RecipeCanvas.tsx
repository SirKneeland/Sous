import { Recipe } from '../types/recipe'
import { IngredientItem } from './IngredientItem'
import { StepItem } from './StepItem'

interface RecipeCanvasProps {
  recipe: Recipe
  onToggleIngredient: (id: string) => void
  onMarkStepDone: (id: string) => void
  onSetCurrentStep: (id: string) => void
}

export function RecipeCanvas({
  recipe,
  onToggleIngredient,
  onMarkStepDone,
  onSetCurrentStep
}: RecipeCanvasProps) {
  const completedSteps = recipe.steps.filter(s => s.status === 'done').length
  const totalSteps = recipe.steps.length
  const progress = totalSteps > 0 ? (completedSteps / totalSteps) * 100 : 0

  return (
    <div className="recipe-canvas">
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
          {recipe.ingredients.map(ing => (
            <IngredientItem
              key={ing.id}
              ingredient={ing}
              onToggle={onToggleIngredient}
            />
          ))}
        </div>
      </section>

      <section className="recipe-section">
        <h2>Steps</h2>
        <div className="steps-list">
          {recipe.steps.map((step, index) => (
            <StepItem
              key={step.id}
              step={step}
              stepNumber={index + 1}
              isCurrent={step.id === recipe.currentStepId}
              onMarkDone={onMarkStepDone}
              onSetCurrent={onSetCurrentStep}
            />
          ))}
        </div>
      </section>

      {recipe.notes.length > 0 && (
        <section className="recipe-section">
          <h2>Notes</h2>
          <ul className="notes-list">
            {recipe.notes.map((note, index) => (
              <li key={index}>{note}</li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}
