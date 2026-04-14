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

### US-06: Mark a Step Done
- Given a recipe with steps in Cook Mode
- When the user right-swipes a step row
- Then the step is marked `done`
- And is visually locked with strikethrough styling
- And cannot be modified by the AI

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

### US-25: Import a Recipe (Zero State Entry Point)
- Given the user has no active recipe canvas
- When the user taps "Talk to a recipe" on the zero state screen
- Then an import sheet appears offering three input methods: Camera, Photo Library, and Paste Text

### US-26: Import via Photo or Screenshot
- Given the import sheet is open
- When the user captures a photo or selects one from their library
- Then the AI extracts the recipe from the image
- And generates a recipe canvas immediately
- And any line where confidence is low is flagged with `[??]`

### US-27: Import via Pasted Text
- Given the import sheet is open
- When the user pastes raw recipe text
- Then the AI extracts the recipe from the text
- And generates a recipe canvas immediately
- And any line where confidence is low is flagged with `[??]`

### US-28: Post-Import First Message
- Given a recipe canvas has just been created via import
- When the canvas appears
- Then the AI sends a first chat message acknowledging the loaded recipe
- And invites the user to make any adaptations (serving size, substitutions, dietary changes, etc.)

### US-29: Import Skips Exploration Phase
- Given the user initiates a recipe import
- When the canvas is generated
- Then no clarifying questions are asked and no option cards are shown
- And the app routes directly into cooking/edit mode

### US-30: Faithful Extraction
- Given a recipe is being imported
- Then the AI must not alter, substitute, or editorialize during extraction
- And all subsequent changes must go through the normal patch flow

### US-31: Swipe to Mark Done
- Given a recipe canvas with steps or ingredients
- When the user right-swipes a row
- Then the item is marked done
- And ingredients check without strikethrough; steps check with strikethrough

### US-32: Swipe to Ask Sous
- Given a recipe canvas with steps or ingredients
- When the user left-swipes a row
- Then the chat sheet opens
- And the swiped row is quoted as context in the chat input
- And the user can type a question about that specific item

### US-33: Start a Step Timer
- Given a recipe step contains a time reference
- When the user taps the inline timer affordance
- Then a timer starts for that duration (or a picker appears for ambiguous ranges)
- And a banner appears above the Talk to Sous button showing the label and live
  countdown

### US-34: Pause and Resume a Timer
- Given a timer is running
- When the user opens the timer sheet and taps Pause
- Then the timer pauses and the button label changes to Resume
- When the user taps Resume
- Then the timer continues from where it stopped

### US-35: Delete a Timer
- Given a timer sheet is open
- When the user taps Delete Timer
- Then the timer is removed from the step and the sheet dismisses
- And the step can now be marked done

### US-36: Timer Completion Notification
- Given a timer is running and the app is backgrounded
- When the timer reaches zero
- Then a local notification fires
- And the notification is cleared if the app relaunches or a new recipe is started

### US-37: Request Mise en Place
- Given a recipe canvas exists and no Mise en Place section has been generated
- When the user taps the Mise en Place trigger
- Then on first use a confirmation modal explains the feature
- Then the AI extracts prep steps into a MISE EN PLACE section between
  Ingredients and Procedure
- And extracted steps are removed from the Procedure
- And the trigger is hidden

### US-38: Check a Mise en Place Component
- Given a Mise en Place section exists with vessel groups
- When the user taps a component within a vessel group
- Then that component is checked independently
- When all components in a group are checked
- Then the group header auto-completes

### US-39: Collapse and Expand Ingredients
- Given a recipe canvas with an Ingredients section
- When the user taps the collapse toggle
- Then the Ingredients section collapses and the state persists for the session
- When an accepted patch modifies ingredients
- Then the Ingredients section auto-expands

### US-40: Delete Active Recipe from History
- Given the user is viewing the History sheet
- And the currently active recipe is in the list
- When the user deletes that recipe
- Then a confirmation modal warns them they are deleting the recipe currently
  on the canvas
- When they confirm
- Then the recipe is removed from History and the app navigates to zero state

### US-41: ThumbDrop to Open Chat
- Given the user is in Cook Mode
- When the user swipes down on the Talk to Sous button or anywhere in the
  bottom 30% of the screen
- Then the ThumbDrop gesture fires with a slingshot haptic sequence
- And Chat Mode opens

### US-42: ThumbDrop to Close Chat
- Given the user is in Chat Mode
- When the user swipes down on the input bar or anywhere in the bottom 30%
  of the screen
- Then the ThumbDrop gesture fires with a slingshot haptic sequence
- And the chat sheet dismisses returning to Cook Mode
