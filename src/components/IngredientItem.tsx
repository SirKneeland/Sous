import { Ingredient } from '../types/recipe'

interface IngredientItemProps {
  ingredient: Ingredient
  onToggle: (id: string) => void
}

export function IngredientItem({ ingredient, onToggle }: IngredientItemProps) {
  return (
    <label className="ingredient-item">
      <input
        type="checkbox"
        checked={ingredient.checked}
        onChange={() => onToggle(ingredient.id)}
      />
      <span className={ingredient.checked ? 'checked' : ''}>
        {ingredient.text}
      </span>
    </label>
  )
}
