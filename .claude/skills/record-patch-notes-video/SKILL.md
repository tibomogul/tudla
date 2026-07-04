---
name: record-patch-notes-video
description: >
  Use when the user wants to ship release notes for the work on the current
  branch with an accompanying demo GIF. Audits the branch's changes vs its
  base, records a short walkthrough of the new behaviour via the
  record-change-evidence capture pipeline, and writes a dated markdown
  release notes doc under docs/release_notes/. Tudla has no in-app changelog
  UI, so the deliverable is a docs artefact, not a wired-up modal.
version: 1.0.0
---

# Record Tudla Patch Notes

Produces the artefacts for a release: a short GIF demo of the new behaviour
on the current branch, and a `docs/release_notes/<YYYY-MM-DD>.md` entry
written in Keep-a-Changelog style. This is the patch-notes counterpart to
`record-change-evidence` — reuse that skill's capture/highlight/GIF-assembly
steps; this one focuses on the audit and the release-notes copy.

Unlike the source of this skill (adapted from a project with an in-app
"What's New" modal), Tudla has no changelog UI to wire into. The release
notes doc *is* the deliverable — it lives in `docs/` alongside the app's
other implementation/operational guides.

## Prerequisites

- Branch contains the changes you want to publish — i.e. you're not on
  `main`.
- `git merge-base HEAD origin/main` resolves. If the branch was cut from
  somewhere else, ask the user which base to diff against before starting.
- The `record-change-evidence` pipeline is available (dev server up, seed
  data loaded, `chrome-devtools` tools loaded, `ffmpeg`/`ffprobe` on PATH)
  and the changes are actually running on `http://localhost:3000` —
  otherwise the recording demos the old behaviour.

## Step 0 — Audit the branch

```bash
git log --oneline origin/main..HEAD
git diff --stat origin/main...HEAD
git diff --name-only origin/main...HEAD | grep -E "^app/|^db/migrate/" | head -30
```

For each commit, decide which release-notes section it belongs in:

- **Added** — new user-visible feature, page, action, or capability.
- **Changed** — modification to existing behaviour the user will notice.
- **Fixed** — a bug fix.
- **Deprecated** — feature scheduled for removal.
- **Removed** — feature gone.

Skip commits that are pure refactors, test-only, infra, or migrations with no
user-visible effect (e.g. a `cached_*_estimate` backfill, an index add). Show
the user the proposed mapping before writing any copy — they sign off on it.

## Step 1 — Decide the release date + file

```
docs/release_notes/<YYYY-MM-DD>.md
```

Default to today's date in the organization's configured timezone (see
`AGENTS.md` — org-level timezone, default `Australia/Brisbane`), not UTC or
the host machine's local time. If a file for today already exists (a
same-day release was already published), ask the user whether to append a
suffix (`2026-05-19-2.md`) or merge into the existing file.

## Step 2 — Record the demo GIF

Follow `record-change-evidence`'s Steps 1–3 (login, manufacture backing
data if needed, capture screenshots, optionally highlight the acting
element, then assemble a GIF) — **not** its Step 0 (this skill already did
its own audit above) and **not** its Step 4 (that writes an `evidence.md`
verification report; this skill writes its own release-notes prose in
Step 3 below instead). Conventions specific to this skill:

- **Length:** shorter than a full evidence capture — 6–10 beats, one per
  headline `Added`/`Changed` item. Skip minor `Fixed` items in the
  recording; describe those in prose only.
- **Slug:** use the release date — `patch-<YYYY-MM-DD>` — so the file
  doesn't collide with an unrelated evidence capture of the same feature.
- **Output location:** save to `docs/release_notes/<YYYY-MM-DD>/patch-<YYYY-MM-DD>.gif`
  (a same-named subfolder next to the `.md` file), **not**
  `tmp/evidence/` — this GIF ships with the release notes doc and is meant
  to be committed, unlike `record-change-evidence`'s default gitignored
  output. Point its Step 3 assembly command at this path directly instead
  of `tmp/evidence/<slug>/`.
- **Raw screenshots:** unlike `record-change-evidence`'s Step 2 (where they're
  the deliverable and must be kept), delete them after the GIF is assembled —
  only the `.gif` ships here, per this skill's own Output checklist.

## Step 3 — Write the release notes

```markdown
# Release Notes — <YYYY-MM-DD>

![Demo](<YYYY-MM-DD>/patch-<YYYY-MM-DD>.gif)

## Added

- **<Feature title>** — <1-2 sentences, user-facing language, past tense>.

## Changed

- **<Title>** — <description>.

## Fixed

- <One-line bug-fix description.>
```

Rules:

- Omit any section with no entries — don't include empty headers.
- Attach the GIF once, near the top, under whichever section has the
  headline change (usually `Added`). Don't repeat it per bullet.
- Tone: user-facing, past tense, plain English — not commit-message
  phrasing (`fix: null check on X` → "Fixed an issue where X could show a
  blank screen"). Run the copy past the user before finalizing.
- `Fixed`/`Deprecated`/`Removed` are flat one-line bullets; `Added`/`Changed`
  get a bolded title plus a short description, matching the pattern above.

## Step 4 — Update the release notes index

If `docs/release_notes/README.md` doesn't exist, create it with a table:
date, one-line summary, link to the dated file. Otherwise prepend a new row
(newest first). This is the only "registration" step in this repo — there's
no `changelog/index.json` or app-side manifest to keep in sync with it.

## Step 5 — Verify

```bash
ls docs/release_notes/<YYYY-MM-DD>/
```

- Confirm the GIF renders when previewing the markdown (GitHub/editor
  preview, or `open docs/release_notes/<YYYY-MM-DD>.md` if you have a
  markdown viewer configured).
- Confirm every bullet maps back to a real commit from Step 0 — no invented
  features, no commit dropped without a deliberate "skip, no user-visible
  effect" decision.

## Anti-patterns

- **Don't write release-note copy from commit messages verbatim.** Commits
  describe what was done; release notes describe what the user will see.
- **Don't bundle multiple unrelated features into one bullet.** Each
  `Added`/`Changed` entry is one capability or screen change. Split them.
- **Don't invent a changelog UI feature to wire into.** Tudla doesn't have
  one; if the user wants an in-app "What's New" surface, that's a separate,
  larger feature request — flag it rather than fabricating JSON files an app
  won't read.
- **Don't skip the GIF.** Without it the entry is a wall of text and the
  point of this skill (showing, not just telling) is lost.
- **Don't date the file in the future** — sort order and reader expectations
  both assume `releaseDate <= today` in the org's timezone.

## Output checklist

- [ ] `docs/release_notes/<YYYY-MM-DD>.md` — release notes, Keep-a-Changelog style.
- [ ] `docs/release_notes/<YYYY-MM-DD>/patch-<YYYY-MM-DD>.gif` — demo GIF.
- [ ] `docs/release_notes/README.md` — new date indexed (newest first).
- [ ] Copy reviewed and approved by the user before finalizing.

## Reference

- `.claude/skills/record-change-evidence/SKILL.md` — the capture/highlight/
  GIF-assembly pipeline this skill leans on.
- `docs/betting_table_user_guide.md` — tone reference for user-facing prose.
