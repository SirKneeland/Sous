import { Ingredient } from '../types/recipe'

interface IngredientItemProps {
  ingredient: Ingredient
  onToggle: (id: string) => void
  isHighlighted?: boolean
  highlightType?: 'changed' | 'added' | 'removed'
}

export function IngredientItem({
  ingredient,
  onToggle,
  isHighlighted = false,
  highlightType
}: IngredientItemProps) {
  const highlightClass = isHighlighted
    ? highlightType === 'added'
      ? 'highlight-added'
      : highlightType === 'removed'
        ? 'highlight-removed'
        : 'highlight-changed'
    : ''

  const isRemoved = ingredient.removed === true

  return (
    <label className={`ingredient-item ${highlightClass} ${isRemoved ? 'removed' : ''}`}>
      <input
        type="checkbox"
        checked={ingredient.checked}
        onChange={() => onToggle(ingredient.id)}
        disabled={isRemoved}
      />
      <span className={ingredient.checked || isRemoved ? 'checked' : ''}>
        {ingredient.text}
      </span>
    </label>
  )
}
