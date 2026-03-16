# Report Quality Evaluation Criteria

## 1. Progress Visibility

**Definition:** The report clearly communicates what was accomplished since the last report.

| Rating | Description |
|--------|-------------|
| **Strong** | Lists specific completed tasks with outcomes. Completions match `done` transitions in the audit log. Example: ":white_check_mark: `Implement OAuth callback handler (Est: 2d, Actual with AI: 1.5d)`" |
| **Adequate** | Mentions completed work but lacks specificity or misses some completions visible in the audit log |
| **Weak** | Vague statements like "made progress" or "worked on stuff" with no concrete completions listed |
| **Missing** | No mention of what was accomplished |

**How to verify:** Compare report completion claims against `done` state transitions in `list_user_changes_tool` output for the same period.

## 2. Task Specificity

**Definition:** The report references actual Tudla tasks by name rather than using vague descriptions.

| Rating | Description |
|--------|-------------|
| **Strong** | Uses exact Tudla task names (verifiable via `list_tasks_tool`). Tasks are in backticks. Example: "`Build search index for tasks (Est: 3d)`" |
| **Adequate** | Most tasks are identifiable and match Tudla records, though names may be paraphrased |
| **Weak** | Generic descriptions like "the auth thing" or "that bug" that cannot be matched to specific tasks |
| **Missing** | No task-level detail at all; only project-level or abstract statements |

**How to verify:** Match task names mentioned in the report against tasks returned by `list_tasks_tool` for relevant projects.

## 3. Estimate Tracking

**Definition:** The report includes estimate vs actual figures for completed work.

| Rating | Description |
|--------|-------------|
| **Strong** | Completed tasks include both Est and Actual figures. Example: "(Est: 2d, Actual with AI: 1.5d)". Figures match `ai_assisted_estimate` and `actual_manhours` in Tudla |
| **Adequate** | Estimates are shown for some tasks but not all, or only estimates without actuals |
| **Weak** | Estimates mentioned rarely or inconsistently |
| **Missing** | No estimate or actual duration data anywhere in reports |

**How to verify:** Compare reported figures against `ai_assisted_estimate` and `actual_manhours` fields from `get_project_tool` task data.

## 4. Blocker Identification

**Definition:** The report calls out blocked work with enough context for others to help unblock.

| Rating | Description |
|--------|-------------|
| **Strong** | Blockers are listed with: what is blocked, why, and who can help. Uses @mentions. Example: ":construction: DB optimization blocked on DBA review - @sarah can you take a look at PR #234?" |
| **Adequate** | Blockers are mentioned but missing context or @mentions |
| **Weak** | Blockers exist in the audit log (`blocked` transitions) but are not mentioned, or mentioned without any context |
| **Missing** | Tasks were transitioned to `blocked` state but the report has no blockers section |

**How to verify:** Check `list_user_changes_tool` for `blocked` state transitions. Every blocked task should appear in the report's blockers section. If no tasks are blocked, this criterion is rated N/A (do not penalize).

## 5. Project Alignment

**Definition:** The report accurately reflects what happened in the projects, without significant omissions or fabrications.

| Rating | Description |
|--------|-------------|
| **Strong** | All significant activity from the audit log is reflected in the report. Projects and tasks mentioned all exist in Tudla. No major omissions |
| **Adequate** | Most activity is covered. Minor omissions (e.g., small updates or administrative changes not mentioned) |
| **Weak** | Significant audit log activity is missing from the report (e.g., large tasks completed but not mentioned), or report mentions work that cannot be found in Tudla |
| **Missing** | Report content bears little resemblance to actual recorded activity |

**How to verify:** Compare the full set of changes from `list_user_changes_tool` against report content. Flag any `done` transitions, task creations, or scope changes not mentioned. Also flag any report claims that have no corresponding audit log entry.

## 6. Consistency

**Definition:** Reports are submitted regularly, matching expected cadence for the period.

| Rating | Description |
|--------|-------------|
| **Strong** | One report per business day in the period. No gaps |
| **Adequate** | Minor gaps (1 missing day) or a report covers multiple days adequately |
| **Weak** | Multiple days missing. Less than 60% coverage of business days |
| **Missing** | 0-1 reports for a multi-day period |

**How to verify:** Count submitted reports and compare against business days (Mon-Fri) in the date range. Use `as_of_at` timestamps to identify which days have coverage.

## 7. Forward-Looking

**Definition:** The report communicates what the author plans to work on next.

| Rating | Description |
|--------|-------------|
| **Strong** | Lists specific upcoming tasks with estimates. Tasks exist in Tudla in `new` or `in_progress` state. Grouped by project with health indicators. Example: ":soon: `Add filter UI components (Est: 2d)`" |
| **Adequate** | Mentions next steps but without specific task names or estimates |
| **Weak** | Vague forward-looking statements like "continue working on the project" |
| **Missing** | No mention of upcoming work |

**How to verify:** Match mentioned upcoming tasks against `list_tasks_tool` results filtered to `new` or `in_progress` states. Verify tasks exist and are assigned to the user.
