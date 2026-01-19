
# Patching Rules

The AI never rewrites the full recipe.

It emits:

1. `assistant_message` — short chat reply
2. `patches` — machine-readable operations

Allowed operations:

- add_step(after_step_id, text)
- update_step(step_id, text)  // only if status === todo
- update_ingredient(id, text)
- add_ingredient(text)
- remove_ingredient(id)
- add_note(text)

Hard rules:

- AI may not modify any step with status `done`.
- If a change requires altering a done step:
  - Add a recovery step after the current step OR
  - Add a note explaining what to do.

Example output:

```json
{
  "assistant_message": "No worries — we can make this work without onions.",
  "patches": [
    {"op":"remove_ingredient","id":"onion"},
    {"op":"add_ingredient","text":"1 bell pepper, diced"},
    {"op":"update_step","step_id":"step-1","text":"Sauté bell pepper and garlic in olive oil."}
  ]
}