---
name: tudla-dev-report
description: >
  Use when the user asks for a "daily report", "standup update", "dev daily",
  "yesterday's changes", or "daily update". Generates a formatted Dev Team Daily
  report from Tudla data.
version: 1.0.0
---

# Dev Team Daily Report

Generate a Slack-ready standup report by fetching data from Tudla MCP tools and formatting it with the template in `references/template.md`.

## Workflow

### Phase 1: Fetch Data

1. **Determine the previous business day** relative to today's date:
   - Monday → use Friday
   - Tuesday–Friday → use the day before
   - Use `Australia/Brisbane` (AEST/AEST) timezone for all datetime boundaries
2. Call `mcp__tudla__list_user_changes` with:
   - `start_time`: Previous business day `00:00:00+10:00`
   - `end_time`: Previous business day `23:59:59+10:00`
   - `limit`: 200
3. Call `mcp__tudla__list_projects` to get all accessible projects
4. For each project referenced in changes, call `mcp__tudla__get_project` to get full details (scopes, tasks, risk state, duration)

### Phase 2: Analyze Changes

Parse the changes output and classify into:

| Category | How to identify |
|----------|----------------|
| **Completed tasks** | Task state changed to `done` → goes in "Yesterday's Wins" |
| **In-progress tasks** | Task state changed to `in_progress` or `in_review` |
| **Blocked tasks** | Task state changed to `blocked` → goes in "Blockers" |
| **New tasks** | Task was created (event: `create`, item_type: `Task`) |
| **Updated scopes/projects** | Risk state changes, estimate changes |

For completed tasks, include estimate vs actual duration if both are available.

### Phase 3: Vibe Suggestion + User Input

Suggest a vibe emoji based on patterns in the data:

| Pattern | Suggested vibe |
|---------|---------------|
| Many completions | `:rocket:` or `:sunglasses:` |
| Blocked items present | `:thinking_face:` or `:hot_face:` |
| Collaboration-heavy changes | `:handshake:` |
| Deep code/task work | `:headphones:` |
| Starting new epic/project | `:rocket:` |

**Ask the user** to confirm or change the vibe before proceeding.

### Phase 4: Today's Focus Refinement

Pre-populate "Today's Focus" from current Tudla state:

1. Group tasks by project/epic
2. Show project risk state as epic health emoji:
   - `green` → `:large_green_circle:`
   - `yellow` → `:large_yellow_circle:`
   - `red` → `:red_circle:`
3. Show project duration in weeks
4. Mark tasks with status emoji:
   - `in_progress` → `:hammer:`
   - `new` (upcoming) → `:soon:`
   - `blocked` → `:construction:`
5. Include estimate for each task

**Present the draft to the user** and ask them to confirm or adjust.

### Phase 5: Generate Report

Assemble the final report following the template in `references/template.md`. Key rules:

- Use **Slack shortcodes** for emojis (`:white_check_mark:` not checkmark unicode)
- Use Slack bold (`*bold*`) and italic (`_italic_`) formatting
- Group tasks under their project with epic health indicator
- Include estimate/actual data where available
- Keep it concise — one line per task

### Phase 6: Output

1. Output the formatted report inside a **code block** for easy copy-paste to Slack
2. Ask if any adjustments are needed

## MCP Tools Used

- `mcp__tudla__list_user_changes` — PaperTrail audit log for previous business day
- `mcp__tudla__list_projects` — All accessible projects
- `mcp__tudla__get_project` — Project details with scopes/tasks
- `mcp__tudla__list_tasks` — Tasks filtered by project/state (for Today's Focus)
