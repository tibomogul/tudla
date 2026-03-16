---
name: tudla-report-analyzer
description: >
  Use when the user asks to "analyze report", "critique report", "review report",
  "report quality", or "report analysis". Analyzes a user's Tudla reports against
  quality criteria and cross-references with actual project/task data.
version: 1.0.0
---

# Report Analyzer

Analyze a user's Tudla reports against quality criteria and cross-reference with actual project/task activity data. Produces a structured evaluation with ratings, verified/unverified claims, and actionable recommendations.

## Workflow

### Phase 1: Resolve User and Time Range

1. Parse the user's request to extract: **target person name**, **time range** (e.g., "past week", "last month"), and optional **team/project filters**
2. Compute `start_time` and `end_time` in ISO8601 with `+10:00` (Australia/Brisbane). Default: past 7 calendar days from today
3. Call `mcp__tudla__fetch_reports_tool` with `team_id: 1` (R&D default) and the computed date range
4. Scan returned "Author: username" fields for a **case-insensitive** match on the requested name
5. Extract report IDs belonging to that author. If no match or ambiguous, ask the user to clarify

### Phase 2: Fetch Full Report Content

1. For each report ID from Phase 1, call `mcp__tudla__get_report_tool` to get full content
2. Collect: `{id, content, as_of_at, reportable_type, reportable_name, status}`
3. If no submitted reports found, inform the user and suggest broadening the date range

### Phase 3: Fetch Actual Activity Data (Cross-Reference)

1. Call `mcp__tudla__list_user_changes_tool` with `team_id: 1` and the same date range, `limit: 200`. Filter output for changes by the target user
2. Call `mcp__tudla__list_projects_tool` to get all projects
3. For each project referenced in reports or changes, call `mcp__tudla__get_project_tool` for scope/task/risk details
4. This produces two datasets: **what the user claimed** (reports) vs. **what actually happened** (audit log)

### Phase 4: Analyze and Score

Evaluate each report against the 7 criteria defined in `references/criteria.md`:

| # | Criterion | What to check |
|---|-----------|---------------|
| 1 | Progress visibility | Are completions clearly stated? Match against `done` transitions in audit log |
| 2 | Task specificity | Are exact Tudla task names used, or vague descriptions? |
| 3 | Estimate tracking | Are Est vs Actual figures included? Match against task `ai_assisted_estimate` / `actual_manhours` |
| 4 | Blocker identification | Are blockers called out with context? Match against `blocked` state transitions |
| 5 | Project alignment | Do mentioned projects/tasks exist in Tudla? Any significant audit log activity omitted? |
| 6 | Consistency | Count reports vs expected business days in range. Note gaps |
| 7 | Forward-looking | Does report mention upcoming tasks? Verify they exist in `new`/`in_progress` state |

Rate each criterion: **Strong / Adequate / Weak / Missing**

Cross-reference findings:
- **Verified claims** — completions/activity confirmed by audit log
- **Unreported activity** — significant changes not mentioned in reports
- **Unverified claims** — report mentions not found in audit data

### Phase 5: Output Structured Analysis

Format the output as follows:

```
## Report Analysis: [User Name]
**Period:** [start] to [end]
**Reports reviewed:** X of Y expected

### Overall Rating: [Strong / Adequate / Needs Improvement / Poor]

### Criteria Breakdown
| Criteria | Rating | Notes |
|----------|--------|-------|
| Progress visibility | ... | ... |
| Task specificity | ... | ... |
| Estimate tracking | ... | ... |
| Blocker identification | ... | ... |
| Project alignment | ... | ... |
| Consistency | ... | ... |
| Forward-looking | ... | ... |

### Cross-Reference Findings
**Verified claims:** [list]
**Unreported activity:** [list]
**Unverified claims:** [list]

### Recommendations
1. [Specific, actionable recommendation]
2. ...
```

After outputting the analysis, ask the user if they want to drill into any specific report or criterion.

## Overall Rating Logic

| Condition | Rating |
|-----------|--------|
| 5+ criteria Strong, none Weak/Missing | **Strong** |
| 3+ criteria Strong or Adequate, at most 1 Missing | **Adequate** |
| 2+ criteria Weak or 1+ Missing | **Needs Improvement** |
| 3+ criteria Weak/Missing | **Poor** |

## MCP Tools Used

- `mcp__tudla__fetch_reports_tool` — Fetch reports by date range, team, and user
- `mcp__tudla__get_report_tool` — Get full report content by ID
- `mcp__tudla__list_user_changes_tool` — PaperTrail audit log for cross-referencing
- `mcp__tudla__list_projects_tool` — All accessible projects
- `mcp__tudla__get_project_tool` — Project details with scopes, tasks, risk state
- `mcp__tudla__list_tasks_tool` — Tasks filtered by project/state
