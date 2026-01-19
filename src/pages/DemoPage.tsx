import { useRecipeState } from '../hooks/useRecipeState'
import { demoRecipe } from '../data/demoRecipe'
import { RecipeCanvas } from '../components/RecipeCanvas'
import { ChatPane } from '../components/ChatPane'

export function DemoPage() {
  const {
    recipe,
    toggleIngredient,
    markStepDone,
    setCurrentStep,
    resetRecipe
  } = useRecipeState(demoRecipe)

  return (
    <div className="app-container">
      <div className="canvas-pane">
        <RecipeCanvas
          recipe={recipe}
          onToggleIngredient={toggleIngredient}
          onMarkStepDone={markStepDone}
          onSetCurrentStep={setCurrentStep}
        />
      </div>
      <div className="chat-pane-container">
        <ChatPane onReset={resetRecipe} />
      </div>
    </div>
  )
}
