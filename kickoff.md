You are building a phone-first “Chat + Living Recipe Canvas” app.

Non-negotiable core: the recipe is a persistent canvas; chat never reprints full recipes.
The AI must return structured PATCHES that update the recipe state. Completed steps are immutable.

Read these docs first:
- docs/PRD.md
- docs/UserStories.md
- docs/StateModel.md
- docs/PatchingRules.md
- docs/Milestones.md

Implementation constraints:
- Mobile-first layout with dual-pane (canvas above, chat below).
- Recipe state stored as structured JSON.
- Steps have status todo|done; done steps cannot be edited.
- Provide a demo route that demonstrates the North Star flow.
- Build Milestone 1 first without any LLM calls.

Output requirements:
- Before coding, list the exact files you will create/modify.
- After coding, provide a manual test checklist proving the acceptance criteria.