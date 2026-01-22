# User Stories

### US-00: Explore What to Cook (No Canvas Yet)
- Given the user has no active recipe canvas
- When the user asks a vague or preference-based question (e.g. “what’s something with a lot of garlic?”)
- Then the assistant asks 1–2 clarifying questions (max)
- And proposes 3–5 concrete dish options with short blurbs
- And does not create a recipe canvas yet

### US-00b: Commit to an Option (Create Canvas)
- Given the user has no active recipe canvas
- When the user explicitly commits to a specific option (e.g. “Option 2”, “Make the French one”, “Generate that one”)
- Then a full recipe appears in the canvas
- And chat does not contain the recipe body

### US-01: Generate Recipe
- Given a prompt or selected option
- When the user submits it as an explicit commit to generate
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