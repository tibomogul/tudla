---
name: record-change-evidence
description: >
  Use when the user wants verification evidence for a branch or uncommitted
  changes — screenshots of the actual resulting UI states, captioned with
  what each one demonstrates, plus a markdown evidence report — to attach to
  a PR or bug report. Captured via chrome-devtools MCP; optional combined
  walkthrough GIF assembled with ffmpeg for multi-step flows. Output lives
  under tmp/evidence/<slug>/ (gitignored) and is never committed.
version: 4.0.0
---

# Record Change Evidence

Given a branch or a set of uncommitted changes, drives the UI to exercise
exactly what changed, screenshots each significant resulting state, and
writes a markdown evidence report — the kind of thing you attach to a PR
description or a bug report, not documentation you ship with the app.

This is **not** a docs-tutorial pipeline. The screenshots are the
deliverable — each one gets its own caption in the report stating what it
proves — not disposable raw material for a video. A combined walkthrough
GIF is optional, only for flows where the sequence of steps matters more
than any single state.

Everything this skill produces lives under `tmp/evidence/<slug>/`, which is
fully gitignored (`tmp/*` in `.gitignore`) — nothing here is ever meant to
be committed.

## Prerequisites

- Dev server up: `docker compose up -d` then
  `docker compose exec -d rails bash -lc "bin/dev"`. Verify with
  `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` → `200`.
- Seed data present: `docker compose exec rails bash -lc "bin/rails db:seed"`.
  Seed users (from `db/seeds.rb`) log in with `<name>@example.com` /
  `password`. Pick a seed user whose `UserPartyRole` matches what the
  change actually gates (admin vs member, and at the right org/team/project
  level) — a member-only account will silently miss admin-only controls.
- `chrome-devtools` MCP tools loaded — if deferred, one `ToolSearch` call:
  `select:mcp__chrome-devtools__new_page,mcp__chrome-devtools__navigate_page,mcp__chrome-devtools__click,mcp__chrome-devtools__fill,mcp__chrome-devtools__take_screenshot,mcp__chrome-devtools__take_snapshot,mcp__chrome-devtools__wait_for,mcp__chrome-devtools__list_pages,mcp__chrome-devtools__list_console_messages,mcp__chrome-devtools__list_network_requests,mcp__chrome-devtools__evaluate_script`.
- **`ffmpeg` + `ffprobe` on PATH.** Check with `which ffmpeg ffprobe`. If
  missing, install it yourself first — `brew install ffmpeg` — **this skill
  does not install anything for you.** There is no Python/Pillow dependency
  at all; every image operation below is a single `ffmpeg`/`ffprobe`
  invocation.

## Step 0 — Scope the verification

Figure out what you're actually verifying before touching the browser:

```bash
git status --porcelain
git branch --show-current
git merge-base HEAD origin/main   # if this fails, ask which base to diff against
git diff --stat origin/main...HEAD     # committed branch divergence
git diff --stat                        # uncommitted changes, if any
```

- **If both uncommitted changes and branch divergence exist, ask the user**
  which scope they want evidence for — don't guess.
- **Map changed files to concrete UI states:**
  - View/component/JS-controller/CSS changes (`app/views/**`,
    `app/components/**`, `app/javascript/**`) → the route(s) that render
    them, directly.
  - Controller/route changes → grep the controller for the touched
    action(s) against `config/routes.rb` to find the affected route(s).
  - **Behavioral-only changes with no view diff** — a Pundit policy, a
    state-machine guard/transition, a model validation/callback — still
    need UI verification, found by reasoning rather than by diffing views:
    - Policy change → grep `app/views`/`app/controllers` for the changed
      policy method to find what button/link/section it gates; screenshot
      the boundary it moved (e.g. in both an allowed and a denied role).
    - State-machine change → find the controller action that calls
      `transition_to!` for that machine, then screenshot the effect of
      driving that transition through the actual UI, not the console.
    - Model callback/validation change → find the form/action that would
      trip it, screenshot the resulting error or accepted state.
  - **No user-visible surface at all** (a migration, an internal refactor,
    a backfill task) → say so explicitly in the report's Summary rather
    than forcing a screenshot that doesn't actually demonstrate anything.
- **Slug**: sanitized branch name (`feature/pulse-badges` → `pulse-badges`),
  or derived from the primary changed file/feature if the branch name is
  generic (or you're on `main` with uncommitted changes) — ask the user for
  a one-line slug if neither is obvious.
- **Stale-server risk, specific to after-only evidence:** this skill only
  screenshots current behavior — there's no before/after comparison to
  catch a stale server. Rails autoloads `app/views`/`app/controllers`/
  `app/models` changes in development without a restart, but `config/`,
  initializers, and `config/routes.rb` do **not** reload live. If any
  changed file falls in those paths, restart the app
  (`docker compose restart rails` or equivalent) **before the first
  screenshot** — otherwise the "after" screenshot can silently show old
  behavior with no visible error, and the evidence would just be wrong.

## Step 1 — Get a tab and log in

```
new_page(url: "http://localhost:3000/users/sign_in")
take_snapshot()                          → uids for the email/password/submit fields
fill(uid: <email uid>, value: "<user>@example.com")
fill(uid: <password uid>, value: "password")
evaluate_script(function: "(el) => { el.click(); }", args: [<submit button uid>])
wait_for(text: ["Good Morning", "Notifications"])   // or whatever text marks a successful landing
```

(`fill` is reliable in practice; only the `click` tool isn't — see the
click-reliability note in Step 2, which is why login submit goes through
`evaluate_script` here too.)

Login itself is setup, not evidence — nothing here needs to be captured as
a screenshot.

Note (found in practice): the Devise sign-in page in this repo
(`app/views/devise/sessions/new.html.erb`) is the plain, unstyled Devise
scaffold — no Tailwind/DaisyUI classes at all. This is pre-existing on
`main`, not something broken by your setup; the compiled CSS loads fine
(check with `list_network_requests(resourceTypes: ["stylesheet"])` if a
page ever looks suspiciously unstyled — a `200` there means the CSS
pipeline is fine and the view itself is just plain).

## Step 1.5 — Manufacture backing data, if needed

If Step 0 found the change needs event/activity data seed data doesn't
provide, do it now, before capturing anything, via the app's real API:

```bash
docker compose exec rails bash -lc "bin/rails runner '
record = Task.find(<id>)
actor  = User.find_by(email: \"<actor>@example.com\")
record.update!(unassisted_estimate: 4, ai_assisted_estimate: 3)   # satisfy any transition guard
record.state_machine.transition_to!(:in_progress, user_id: actor.id)
record.state_machine.transition_to!(:in_review, user_id: actor.id)
' 2>&1 | grep -v DEPRECATION"
```

Then verify the effect actually landed (background jobs need a moment):

```bash
sleep 2
docker compose exec rails bash -lc "bin/rails runner 'puts User.find_by(email: \"<recipient>@example.com\").notifications.unread.count' 2>&1 | grep -v DEPRECATION"
```

Prefer this over hand-crafting rows directly: calling the real API
(`transition_to!`, a service object, whatever the controller itself would
call) as the actual actor exercises the same callbacks/broadcasts/jobs a
real user action would, so what you screenshot afterward is exactly what
production behaviour looks like — a bare `Model.create!`/`update!` can skip
all of that.

## Step 2 — Capture evidence screenshots

Directory convention:

```
tmp/evidence/<slug>/
  evidence.md                    # the deliverable, written in Step 4
  01-<state>.png
  01b-<state>-highlight.png      # optional, see Step 2.5
  02-<state>.png
  ...
  <slug>.gif                     # optional, see Step 3
```

Create it first: `mkdir -p tmp/evidence/<slug>`. **The numbered screenshots
are themselves the deliverable** — each gets its own caption in
`evidence.md` — not disposable raw material. Do not delete them once
captured.

`filePath` must resolve **inside the repo** (a configured workspace root)
— an absolute path under a session scratchpad is rejected. Always use a
path relative to the repo root: `tmp/evidence/<slug>/01-<state>.png`.

For each significant state identified in Step 0:

```
take_snapshot()                          → find the uid for the element to act on
evaluate_script(function: "(el) => { el.click(); }", args: [<uid>])   // see below — default, not a fallback
take_screenshot(filePath: "tmp/evidence/<slug>/NN-<state>.png")
```

Number screenshots so they sort in the order they were captured (`01-`,
`02-`, …).

### click reliability (found in practice — use `evaluate_script` by default)

The `click` tool's simulated mouse click is **unreliable in this repo**.
Confirmed failures (no navigation, no state change, no network request —
despite `click` reporting success): a plain GET link, a
`data-turbo-method="patch"` link, and a plain Stimulus-driven button with
no Turbo involvement at all. There's no reliable way to predict in advance
which case you're in, so don't use `click` as the primary mechanism — use
`evaluate_script` to dispatch a real `.click()`:

```
evaluate_script(
  function: "(el) => { el.click(); return { tag: el.tagName }; }",
  args: [<uid>]   // uid from the latest take_snapshot — evaluate_script
                  // resolves it to the actual DOM element, no CSS selector needed
)
```

If you still reach for `click` anyway, **always verify** it actually did
something before screenshotting the result as if it did —
`list_pages()`/`take_snapshot()` — and fall back to the `evaluate_script`
form the moment it doesn't.

For plain same-tab navigation, `navigate_page(type: "url", url: ...)` also
works and is simpler than clicking through the DOM. It doesn't work for
links Turbo converts into a non-GET request (delete buttons, mark-read
links) — that would issue a GET to a route that only accepts PATCH/DELETE
— use the `evaluate_script` click for those.

### Tudla-specific things to know while capturing

- **Turbo Streams replace DOM nodes.** After any action that triggers a
  Turbo Stream update, re-`take_snapshot` for the next target rather than
  reusing an old uid.
- **ActionCable broadcasts arrive asynchronously.** Give a triggering
  action ~1–2s before screenshotting its effect (see Step 1.5's `sleep 2`
  pattern).
- **Destructive-action confirms are safe to click through.** Tudla renders
  delete/confirm dialogs via a custom Turbo confirm (`data-turbo-confirm`,
  see `app/views/layouts/application.html.erb`), not the browser's native
  `confirm()`. Still, don't demo destructive actions against anything
  other than seed/scratch data.
- **Modals/dialogs are in-page `<dialog>` elements** (DaisyUI) — no special
  handling needed beyond waiting for the open animation (~300ms).

## Step 2.5 — Highlight the acting element (optional)

A bare screenshot doesn't always show *what* triggered the state change.
Before performing a click, capture one extra annotated frame that
highlights the target on the state you just screenshotted. Compute the box
browser-side, in already-scaled, already-padded, already-rounded integer
device pixels — no float math in bash:

```
evaluate_script(
  function: "(el) => { const r = el.getBoundingClientRect(); const dpr = window.devicePixelRatio; const pad = 6; return { x: Math.round((r.x - pad) * dpr), y: Math.round((r.y - pad) * dpr), w: Math.round((r.width + pad * 2) * dpr), h: Math.round((r.height + pad * 2) * dpr), t: Math.round(4 * dpr) }; }",
  args: [<uid>]
)
```

```bash
ffmpeg -y -loglevel error -i tmp/evidence/<slug>/NN-<state>.png \
  -vf "drawbox=x=<x>:y=<y>:w=<w>:h=<h>:color=0xFF5A1E@0.9:thickness=<t>" \
  tmp/evidence/<slug>/NNb-<state>-highlight.png
```

`drawbox` clips silently at the frame's edges — a box that overflows or
has negative x/y from padding still renders correctly, no clamping logic
needed. One honest trade-off: `drawbox` draws sharp corners only (no
rounded-rectangle equivalent) — still unambiguous as a highlight.

Name it `NNb-…` (not `(NN+1)-…`) so it sorts immediately after the state
frame it annotates — `"01"` sorts before `"01b"` sorts before `"02"` in a
plain lexicographic glob.

Skip this for states where what's about to happen is already obvious (a
single dominant button) — reserve it for busier screens.

## Step 3 — Optional: assemble a combined walkthrough GIF

**Only when the sequence/motion matters more than any single state** —
most single-change verifications should stop at Step 2 with discrete
captioned screenshots. When a multi-step flow genuinely benefits from a
combined view:

Write `tmp/evidence/<slug>/frames.txt` (the concat demuxer manifest — list
every still in playback order, including any `NNb-…-highlight.png` from
Step 2.5):

```
ffconcat version 1.0
file '01-state.png'
duration 1.8
file '01b-state-highlight.png'
duration 1.0
file '02-state.png'
duration 2.4
file '02-state.png'
```

**The last file must be listed twice** — once with its `duration`, once
bare with no `duration` after it. This is a well-documented ffmpeg
concat-demuxer quirk: `duration` sets how long the *current* entry holds
before advancing to the *next* one, so the final entry's `duration` has
nothing to apply to and is silently dropped unless the file is repeated.

Assembly (single pass — `scale`, `palettegen`, and `paletteuse` chained in
one `-filter_complex` gives two-pass-equivalent GIF quality without a
separate palette file):

```bash
ffmpeg -y -loglevel error -f concat -safe 0 -i tmp/evidence/<slug>/frames.txt \
  -fps_mode vfr \
  -filter_complex "[0:v]scale=1200:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=200[p];[b][p]paletteuse=dither=sierra2_4a[out]" \
  -map "[out]" tmp/evidence/<slug>/<slug>.gif
```

Two things about this command that matter, not just style:

- **`-fps_mode vfr`, not the deprecated `-vsync vfr`.** This is what tells
  ffmpeg to preserve the variable inter-frame gaps from `frames.txt`'s
  `duration` values instead of resampling to a constant rate.
- **Never add an `fps=N` filter anywhere in the chain.** A constant `fps=`
  filter resamples the whole stream to a uniform frame rate, which
  destroys the entire point of per-entry `duration` — every still would
  collapse to the same hold time.

### Verify before trusting it

A clean exit code isn't proof the GIF looks right — check the actual
output:

```bash
ffprobe -hide_banner -loglevel error -f gif -count_frames \
  -i tmp/evidence/<slug>/<slug>.gif \
  -show_entries stream=nb_read_frames,width,height \
  -show_entries frame=pkt_dts_time -of default=noprint_wrappers=1
```

Confirm `nb_read_frames` matches the number of stills listed in
`frames.txt`, `width` is `1200`, and the `pkt_dts_time` deltas roughly
match the intended per-frame hold times. Then extract and `Read` the
first and last frame before calling it done:

```bash
ffmpeg -y -loglevel error -i tmp/evidence/<slug>/<slug>.gif -vf "select=eq(n\,0)" -frames:v 1 tmp/evidence/<slug>/_check_first.png
ffmpeg -y -loglevel error -i tmp/evidence/<slug>/<slug>.gif -vf "select=eq(n\,<last-frame-index>)" -frames:v 1 tmp/evidence/<slug>/_check_last.png
```

Confirm the first frame is a clean opening state (not mid-transition) and
the last frame is the actual final state (not cut off or blank), then
remove the two `_check_*.png` scratch files.

## Step 4 — Write `evidence.md`

```markdown
# Verification Evidence — <short description of the change>

**Branch:** `<branch-name>` (or "uncommitted working-tree changes on `<branch>`")
**Base compared:** `<merge-base-ref-or-sha>` — or "N/A, uncommitted changes only"
**Commit:** `<HEAD short sha>`
**Captured:** <YYYY-MM-DD HH:MM> <org timezone>, against `http://localhost:3000`

<One paragraph: what changed and what this report verifies.>

## Changes Verified

### 1. <Change title — e.g. "Task detail page shows AI-assisted estimate badge">

**What changed:** `<file(s)>`
**How verified:** Logged in as `<user>@example.com` (<role>), navigated to
`<route>`, <action taken>.

![<state description>](01-<state>.png)
*<a claim about what this proves, not a description of what's visible — e.g.
"The AI-assisted estimate badge now renders next to the manual estimate once
both values are present — this did not appear before this change.">*

<repeat one numbered subsection per significant change>

## Combined Walkthrough (optional)

![Walkthrough](<slug>.gif)

<only include this section if Step 3 produced a GIF>

## Summary

<2-4 sentences: does the change behave as intended; explicit note of
anything NOT verified (e.g. "email delivery not exercised — no SMTP
configured in dev"); one-line verdict.>

---
*Evidence for review — not committed to the repo (`tmp/` is gitignored).
See note below on attaching this to a PR/issue.*
```

Each change gets its own numbered subsection with its own screenshot and
its own caption **stating what it demonstrates** — not narrating a tour.
"How verified" names the exact seed user/role/action so another reviewer
could reproduce it. The Summary should explicitly name anything the
evidence does *not* cover, the same way a real test report would.

### The GitHub relative-path gap

GitHub does not render relative image paths (`![...](01-foo.png)`) pasted
into a PR description, issue body, or comment textbox — that only works
for a markdown *file* already committed and viewed on github.com, which
resolves relative links against the repo tree. A local file path pasted
into a comment box is inert text to GitHub's renderer; it will not become
an image. Since `evidence.md` is deliberately **not** committed, actually
attaching this evidence takes one extra manual step: open the PR/issue
comment box and **drag each PNG/GIF file directly into the textarea**
(or use its image-upload control) — GitHub re-hosts each dropped file to
its own `https://github.com/user-attachments/...` URL and inserts a
working image line at the cursor. `evidence.md` is a local staging draft
to write prose around those uploads, not something to paste byte-for-byte
into GitHub.

## Anti-patterns

- **Don't use `click` as the primary interaction mechanism.** It failed
  silently on a plain button and two different kinds of link in testing —
  use `evaluate_script`'s `.click()` by default.
- **Don't screenshot to a path outside the workspace root** — an absolute
  scratchpad path is rejected. Use `tmp/evidence/<slug>/...`.
- **Don't delete the numbered screenshots after Step 3.** They're the
  deliverable, not scratch — the GIF is a supplement, not a replacement.
- **Don't skip the config/routes restart check from Step 0.** After-only
  evidence can't self-catch a stale server the way a before/after
  comparison would — a config or route change that isn't picked up will
  silently produce a screenshot of old behaviour with no visible error.
- **Don't screenshot a behavioral-only change without first finding where
  it's UI-visible.** A policy/state-machine change with no view diff still
  needs a screenshot of the actual boundary it moved — reason about it via
  Step 0's approach rather than skipping it as "no UI to show."
- **Don't use one flat GIF-frame duration for every state.** A highlight
  overlay and a dense list of text need very different hold times.
- **Don't ship a GIF without opening the assembled file itself.** A
  successful `ffmpeg` exit code isn't proof the output looks right —
  extract and `Read` the first and last frame before calling it done.
- **Don't paste `evidence.md`'s relative image links directly into a
  GitHub comment** — see the drag-and-drop note above.
- **Don't record against real/production-shaped data.** Use the seeded
  example org/users so the evidence is reproducible and disposable.

## Output checklist

- [ ] `tmp/evidence/<slug>/evidence.md` — verification report.
- [ ] `tmp/evidence/<slug>/NN-*.png` (+ any `NNb-*-highlight.png`) — kept,
      not deleted.
- [ ] `tmp/evidence/<slug>/<slug>.gif` — only if a multi-step flow
      warranted Step 3, verified via `ffprobe` + reading first/last frame.
- [ ] `git status --short` shows nothing under `tmp/evidence/` staged or
      otherwise at risk of being committed.
