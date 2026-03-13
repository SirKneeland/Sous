# User Stories

### US-00: Explore What to Cook (No Canvas Yet)
- Given the user has no active recipe canvas
- When the user asks a vague or preference-based question (e.g. "what's something with a lot of garlic?")
- Then the assistant asks 1–2 clarifying questions (max)
- And proposes 3–5 concrete dish options with short blurbs
- And does not create a recipe canvas yet

### US-00b: Commit to an Option (Create Canvas)
- Given the user has no active recipe canvas
- When the user explicitly commits to a specific option (e.g. "Option 2", "Make the French one", "Generate that one")
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
- When user expresses a missing ingredient (e.g. "I forgot onions")
- Then ingredients update
- And future steps adjust
- And no done step is modified

### US-05: Mistake Recovery
- Given the user reports a cooking mistake (e.g. "I burned the garlic")
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

### US-08: Set Preferences
- Given the user has no preferences set
- When the user opens Settings
- Then they can set:
  - Default portion count
  - Hard-avoid ingredients or food categories
  - Kitchen equipment available
  - Free-form custom instructions
- And preferences are persisted immediately on save
- And the user may leave any field blank

### US-09: Apply Preferences on Recipe Creation
- Given the user has preferences set
- When a new recipe canvas is created
- Then the recipe is scaled to the default portion count
- And hard-avoid ingredients do not appear
- And kitchen equipment and custom instructions are applied silently
- And the assistant does not explicitly mention applying preferences

### US-10: Override Preferences for One Recipe
- Given the user has preferences set
- When the user explicitly requests a conflicting change (e.g. "make it for 6", "fish is fine tonight")
- Then the assistant asks for confirmation if required
- And applies the override only to the current recipe
- And does not update the user's stored preferences

### US-11: Update Preferences
- Given the user has preferences set
- When the user edits their preferences in Settings
- Then the stored preferences are updated
- And future recipes use the new preferences
- And the current recipe is not retroactively modified

### US-12: Ask Before Proposing Changes
- Given a recipe canvas exists
- When the user asks an exploratory or ambiguous question (e.g. "should I add more garlic?")
- Then the assistant asks a clarifying question
- And does not propose any recipe patches yet

### US-13: Start New Recipe (No Recipe in Progress)
- Given the user has no active recipe or has completed one
- When the user taps "New"
- Then the app resets immediately to the blank starting state
- And no confirmation dialog is shown

### US-14: Start New Recipe (Recipe in Progress)
- Given the user has an active recipe in progress
- When the user taps "New"
- Then a confirmation dialog appears warning that the current recipe will be cleared
- When the user confirms
- Then the app resets to the blank starting state
- And the previous session is not recoverable via the new recipe flow (but may appear in Recent Recipes)

### US-15: Browse Recent Recipes
- Given the user has previously created one or more recipes
- When the user opens the recent recipes list
- Then they see a list of past recipe sessions, most recent first
- And each entry shows enough information to identify the recipe (e.g. title)

### US-16: Resume a Recent Recipe
- Given the user is viewing the recent recipes list
- When the user taps a previous recipe
- Then the app restores that session
- Including the recipe canvas, step progress, and chat history for that session

### US-17: Memory Proposed
- Given a recipe canvas exists or a conversation is in progress
- When the user says something memorable (e.g. "I hate cilantro")
- Then the AI proposes a memory via a toast at the top of the chat
- And the toast shows the proposed memory text in third person (e.g. "hates cilantro")
- And the toast shows three inline buttons: Save, Edit, Skip
- And haptic feedback fires when the toast appears

### US-18: Memory Saved via Toast
- Given a memory toast is visible
- When the user taps Save
- Then the memory is saved immediately
- And the toast dismisses
- And haptic feedback fires

### US-19: Memory Saved via Timeout
- Given a memory toast is visible and the user has not interacted with it
- When 10 seconds elapse
- Then the memory is saved automatically
- And the toast dismisses

### US-20: Memory Timeout Paused
- Given a memory toast is visible with a timeout in progress
- When the user taps anywhere on the toast
- Then the timeout pauses
- And the user can take their time deciding

### US-21: Memory Edited via Toast
- Given a memory toast is visible
- When the user taps Edit
- Then an edit flow opens pre-populated with the proposed memory text
- When the user saves their edit
- Then the edited memory is saved

### US-22: Memory Skipped via Toast
- Given a memory toast is visible
- When the user taps Skip
- Then the toast dismisses without saving anything

### US-23: View and Manage Memories in Settings
- Given the user has saved memories
- When they navigate to the Memories section in Settings
- Then they see a list of all saved memories
- And a line of explanatory text tells them they can tap to edit and swipe left to delete
- When they tap a memory
- Then an edit flow opens
- When they swipe left on a memory
- Then it is deleted

### US-24: Memories Applied as Context
- Given the user has saved memories
- When a new LLM request is made
- Then the memories are included as silent context
- And the AI uses them to inform its responses without explicitly announcing it
