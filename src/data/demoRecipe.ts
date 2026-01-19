import { Recipe } from '../types/recipe'

export const demoRecipe: Recipe = {
  id: 'demo-cozy-chili',
  title: 'Cozy Weeknight Chili',
  ingredients: [
    { id: 'ing-1', text: '1 lb ground beef', checked: false },
    { id: 'ing-2', text: '1 medium onion, diced', checked: false },
    { id: 'ing-3', text: '3 cloves garlic, minced', checked: false },
    { id: 'ing-4', text: '1 can (14 oz) diced tomatoes', checked: false },
    { id: 'ing-5', text: '1 can (15 oz) kidney beans, drained', checked: false },
    { id: 'ing-6', text: '2 tbsp chili powder', checked: false },
    { id: 'ing-7', text: '1 tsp cumin', checked: false },
    { id: 'ing-8', text: '1 tsp smoked paprika', checked: false },
    { id: 'ing-9', text: 'Salt and pepper to taste', checked: false },
    { id: 'ing-10', text: '1 cup beef broth', checked: false },
  ],
  steps: [
    {
      id: 'step-1',
      text: 'Heat a large pot or Dutch oven over medium-high heat. Add ground beef and cook, breaking it up, until browned (5-7 minutes). Drain excess fat.',
      status: 'todo'
    },
    {
      id: 'step-2',
      text: 'Add diced onion to the pot. Cook until softened and translucent (3-4 minutes).',
      status: 'todo'
    },
    {
      id: 'step-3',
      text: 'Add minced garlic and cook until fragrant (about 30 seconds). Don\'t let it burn!',
      status: 'todo'
    },
    {
      id: 'step-4',
      text: 'Stir in chili powder, cumin, and smoked paprika. Toast the spices for 1 minute.',
      status: 'todo'
    },
    {
      id: 'step-5',
      text: 'Pour in diced tomatoes, kidney beans, and beef broth. Stir to combine.',
      status: 'todo'
    },
    {
      id: 'step-6',
      text: 'Bring to a boil, then reduce heat to low. Simmer uncovered for 20-25 minutes, stirring occasionally.',
      status: 'todo'
    },
    {
      id: 'step-7',
      text: 'Season with salt and pepper to taste. Serve hot with your favorite toppings!',
      status: 'todo'
    },
  ],
  notes: [
    'Great with shredded cheese, sour cream, or fresh cilantro on top.',
    'Leftovers taste even better the next day!'
  ],
  currentStepId: 'step-1',
  version: 1
}
