# User Stories

### US-01: Generate Recipe
- Given a prompt (“cozy chili”)
- When the user submits it
- Then a full recipe appears in the canvas
- And chat does not contain the recipe body

### US-02: Track Progress
- Given a recipe with steps
- When the user taps a step
- Then it becomes `done`
- And is visually locked

### US-03: No Past Edits Rule
- Given step N is `done`
- When a user request would alter step N
- Then the AI must not modify that step
- And must add a note or recovery step after the current step

### US-04: Mid-Cook Change
- Given a recipe in progress
- When user expresses a missing ingredient (e.g. “I forgot onions”)
- Then ingredients update
- And future steps adjust
- And no done step is modified

### US-05: Mistake Recovery
- Given the user reports a cooking mistake (e.g. “I burned the garlic”)
- Then a recovery step is inserted in the future
- And later flavor steps compensate

### US-06: Cooking Mode
- Given a recipe
- When user enters cooking mode
- Then one step is enlarged and focused
- And user can advance steps

### US-07: Undo
- Given a patch is applied
- When user taps undo
- Then the recipe reverts one version