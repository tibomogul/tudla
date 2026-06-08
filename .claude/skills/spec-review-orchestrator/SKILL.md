---
name: spec-review-orchestrator
description: >
  Orchestrates a full RSpec spec-quality audit across the project. Triggers
  when the user asks to "review all specs", "audit test quality", "run the
  spec review checklist", "continue spec review", or "resume spec review".
  Builds and maintains a resumable checklist at `spec_review_checklist.md`,
  then spawns the `spec-reviewer` sub-agent once per spec file (sequentially,
  one at a time) and appends each verdict to the checklist. Designed to
  survive interruptions — rate limits, context exhaustion, or the user just
  closing the terminal.
---

# Spec Review Orchestrator

Coordinates a multi-file RSpec audit. The goal is a resumable checklist in
`spec_review_checklist.md` that survives interruptions.

The substantive review criteria live in the `rspec-test-reviewer` skill. The
per-file output contract lives in the `spec-reviewer` sub-agent's frontmatter.
This skill owns only the workflow.

## Workflow

### Step 1: Build or load the checklist

Check if `spec_review_checklist.md` already exists in the project root.

**If it does not exist:**

1. Find all `_spec.rb` files under `spec/`.
2. Create `spec_review_checklist.md` with this structure:

```markdown
# Spec Review Checklist

> Generated: <date>
> Last updated: <date and time>

## Summary

| Verdict | Count |
|---------|-------|
| PASS | 0 |
| NEEDS WORK | 0 |
| FAIL | 0 |
| PENDING | <total> |

## Reviews

- [ ] `spec/models/task_spec.rb` — PENDING
- [ ] `spec/policies/pitch_policy_spec.rb` — PENDING
- ...
```

List every spec file, one per line, as an unchecked Markdown checkbox with status PENDING.

**If it already exists:**

Read it. Find the first line that still shows `- [ ]` and `PENDING`. That is where you resume.
Tell the user how many are done and how many remain.

### Step 2: Review one file at a time

For each PENDING file, **in order**:

1. Spawn a single sub-agent using the `spec-reviewer` agent. Pass it the spec file path.
2. Wait for the sub-agent to return its review.
3. Append the sub-agent's full output block verbatim to the `## Detailed Reviews`
   section at the bottom of `spec_review_checklist.md`. (The shape of that block
   is defined by the `spec-reviewer` agent's frontmatter — do not reformat it.)
4. Update the checklist line for that file:
   - Change `- [ ]` to `- [x]`
   - Replace `PENDING` with the verdict: `PASS`, `NEEDS WORK`, or `FAIL`
5. Update the Summary counts.
6. Update the "Last updated" timestamp.
7. **Write the file to disk after every single review.** This is what makes it resumable.

Process files **one at a time**, not in parallel. This keeps context usage predictable and
avoids rate limit bursts. The checklist is the resumption mechanism — parallelism is not
needed.

### Step 3: After all reviews (or if interrupted)

When all files are reviewed or if you're about to hit a context limit:

1. Ensure `spec_review_checklist.md` is saved with the latest state.
2. Print a summary: how many PASS / NEEDS WORK / FAIL, and how many PENDING remain.
3. If there are remaining PENDING files, tell the user:
   "Run this again to continue from where we left off."

## Important rules

- **One sub-agent at a time.** Sequential, not parallel.
- **Save after every review.** The file on disk is the source of truth.
- **Never re-review a completed file** unless the user explicitly asks.
- **If the user says "continue" or "resume"**, load the checklist and pick up from the
  first PENDING entry.
