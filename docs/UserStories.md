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
  bottom 15% of the screen
- Then the ThumbDrop gesture fires with a slingshot haptic sequence
- And Chat Mode opens

### US-42: ThumbDrop to Close Chat
- Given the user is in Chat Mode
- When the user swipes down on the input bar or anywhere in the bottom 15%
  of the screen
- Then the ThumbDrop gesture fires with a slingshot haptic sequence
- And the chat sheet dismisses returning to Cook Mode

--- 
## Voice Mode

- As a user cooking with messy hands, I can activate voice mode from Cook Mode so I can interact with Sous without touching my phone.
- As a user in voice mode, I can see a persistent visual indicator at the bottom of the screen showing whether the system is ready, listening, thinking, or speaking.
- As a user in voice mode, I can speak naturally to Sous and receive a spoken response, so the interaction feels conversational rather than transactional.
- As a user in voice mode, I can interrupt Sous while it is speaking by saying "stop" or "wait", so I am not forced to listen to a response I already know is wrong.
- As a user in voice mode, when a patch is proposed I can say "accept" or "reject" to action it, as an alternative to tapping the buttons.
- As a user in voice mode, I can exit by saying "done" or "exit", tapping the X button in the bar, or using a ThumbDrop gesture.
- As a user, the recipe canvas remains visible and readable while voice mode is active, so I can glance at my current step without switching modes.

---

### US-43: Set Unit System Preference
- Given the user opens Settings → Preferences
- When they select Imperial or Metric under Unit System
- Then the preference is saved and applied to all future recipe generation

### US-44: Unit Preference Applied to Generated Recipes
- Given the user has a unit system preference set
- When a new recipe canvas is created
- Then all measurements and temperatures use the preferred unit system
- And the assistant does not explicitly mention applying the preference

### US-45: Post-Import Unit Conversion Modal
- Given the user has just imported a recipe
- And the recipe's detected units differ from the user's preferred unit system
- When the import completes
- Then a modal appears asking if they would like to convert the recipe
- And the "Convert" button is the primary (blue) action
- And "Keep Original" is the secondary action

### US-46: Convert Imported Recipe Units
- Given the post-import conversion modal is visible
- When the user taps Convert
- Then a loading screen appears showing "Converting to [imperial/metric]…"
- And the recipe is silently converted and applied to the canvas directly
- And no patch review screen appears
- And no conversion message appears in the chat transcript
- And the converted recipe becomes the baseline for restore-to-original

### US-47: Keep Original Units After Import
- Given the post-import conversion modal is visible
- When the user taps Keep Original
- Then the modal dismisses
- And the recipe remains in its original units
- And the chat transcript is unchanged

### US-48: No Modal for Unit-Ambiguous Recipes
- Given the user has just imported a recipe with no detectable units
  (e.g. "3 eggs, salt to taste, 1 clove garlic")
- When the import completes
- Then no conversion modal appears
---

## Accounts & Sync (Project 2)

### US-49: Sign-In Gate on First Launch
- Given the user has never signed in
- When they open the app
- Then a full-screen Sign in with Apple screen appears before any recipe content
- And the Sous wordmark and a one-line value proposition are shown
- And a neutral loading state (not the sign-in screen) is shown briefly while the
  app checks for an existing session

### US-50: Sign in with Apple Creates an Account
- Given the sign-in screen is visible
- When the user completes Sign in with Apple
- Then a Sous account is created (or matched) on the backend
- And a session token is stored in the device Keychain
- And the app proceeds to the main recipe experience
- And on a failed or canceled attempt, an inline error appears and the user stays
  on the sign-in screen

### US-51: Silent Session Restore on Relaunch
- Given the user signed in previously and the session is still valid
- When they relaunch the app
- Then they are taken straight to the main experience without signing in again
- And if the stored session is rejected, they are returned to the sign-in screen

### US-52: Account Section in Settings
- Given the user is signed in
- When they open Settings
- Then an Account section appears above Preferences showing their name (editable),
  email (read-only), and plan in plain English
- And BYOK users see an "OG" badge and "Using your own API key"
- And rows for Manage Subscription, Share Sous (with referral code), Sign Out, and
  Delete Account are present

### US-53: Edit Display Name
- Given the user is in the Account section
- When they edit their name and submit
- Then the new name is shown immediately and synced to the backend in the background

### US-54: Sign Out
- Given the user taps Sign Out
- Then a confirmation appears ("You'll need to sign in again to use Sous.")
- And on confirm, the session is cleared and the app returns to the sign-in screen
- And local recipes and data are NOT wiped

### US-55: Delete Account
- Given the user taps Delete Account
- Then a confirmation modal warns that account, recipes, memories, and preferences
  will be permanently deleted and this cannot be undone
- And on confirm, the account is deleted on the backend, all local data
  (session token, preferences, memories, recipe sessions) is wiped, and the app
  returns to the sign-in screen
- And on cancel, nothing changes

### US-56: Preferences and Memories Sync
- Given the user is signed in
- When they change a preference or add/edit/delete a memory
- Then the change persists locally immediately
- And the full current state is synced to the backend in the background
- And a sync failure never blocks or disrupts the current session

### US-57: Server-Wins Hydrate on Sign-In
- Given the user signs in on a device
- When sign-in completes
- Then preferences and memories are fetched from the backend and merged with local
  state, with the server winning on conflicts
- And device-only settings (voice, unit system) and any local-only items created
  before sign-in are preserved

### US-58: BYOK Routing Unchanged
- Given a BYOK-eligible (OG) user is signed in
- When they make any recipe request
- Then their OpenAI calls still go directly from the device using their own key,
  exactly as before accounts existed

### US-59: Non-BYOK Requests Are Proxied (Project 3)
- Given a non-BYOK user (trialing / subscriber / grace) is signed in
- When they chat, generate, import, convert, rescale, or send a photo
- Then the AI call is routed through the Sous backend proxy instead of OpenAI
  directly, and the experience is identical — same responses, same streaming
- And the user never sees or needs an OpenAI API key

### US-60: Usage Shown in Settings (Project 3)
- Given a signed-in user opens Settings → Account
- When the screen appears
- Then a non-BYOK user sees their recipe usage for the period:
  - Trial: "X of 14 recipes used · N days left in trial"
  - Subscriber: "X of 100 recipes this month · Resets in N days"
- And a BYOK user sees "Using your own API key · No limits apply"
- And while loading the line shows "Loading usage…", and on a failed fetch it shows "--"

### US-61: Recipe Cap Reached (Project 3)
- Given a non-BYOK user has reached their recipe limit for the period
- When they try to create a new recipe (commit "Make this recipe", or import)
- Then the request is declined before any AI call is made (no tokens spent)
- And the user is told the limit was reached
  - (Full paywall / upgrade UX is Project 4; Project 3 returns the cap-reached signal)

### US-62: Off-Topic Request Declined (Project 3)
- Given a non-BYOK user sends a clearly non-cooking message (e.g. "write me a
  Python function", "who is the president")
- When the message is sent
- Then the backend declines it with a friendly "let's keep it in the kitchen" message
  and does not spend AI tokens on it
- And borderline or cooking-adjacent messages are always allowed (the detector is
  intentionally conservative)
