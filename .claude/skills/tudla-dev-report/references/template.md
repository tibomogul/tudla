# Dev Team Daily Report — Template & Reference

## Report Template Structure

```
*My Vibe:* [vibe_emoji] [short description]

*_Yesterday's Wins (Completed Tasks):_*
* :white_check_mark: `[task name] (Est: Xd, Actual with AI: Yd)` — [optional brief context]
* :white_check_mark: `[task name]`

*_Today's Focus & Status:_*
[epic_health_emoji] *_[Project Name]_* ([duration in weeks])
* :hammer: `[task name] (Est: Xd)` — currently working on
* :soon: `[task name] (Est: Xd)` — up next
* :construction: `[task name] (Est: Xd)` — blocked

:clipboard: *_Non-Epic Work:_*
* :gear: `[task description]`

*_Blockers / @Mentions:_*
* :construction: [blocker description]
* :link: [dependency description] @[person]

*_Notes:_*
* [any additional context, observations, or heads-up items]
```

## Emoji Cheat Sheet

### Vibe Emojis
| Emoji | Shortcode | When to use |
|-------|-----------|-------------|
| :rocket: | `:rocket:` | Shipping fast, lots of completions |
| :sunglasses: | `:sunglasses:` | Smooth day, good progress |
| :headphones: | `:headphones:` | Deep focus / heads-down coding |
| :thinking_face: | `:thinking_face:` | Investigating, debugging, uncertain |
| :hot_face: | `:hot_face:` | Under pressure, lots of blockers |
| :handshake: | `:handshake:` | Collaboration-heavy day |
| :coffee: | `:coffee:` | Slow start, warming up |
| :seedling: | `:seedling:` | Starting something new |
| :broom: | `:broom:` | Cleanup / tech debt day |

### Epic Health (Project Risk State)
| State | Emoji | Shortcode |
|-------|-------|-----------|
| Green | :large_green_circle: | `:large_green_circle:` |
| Yellow | :large_yellow_circle: | `:large_yellow_circle:` |
| Red | :red_circle: | `:red_circle:` |

### Task Status
| Status | Emoji | Shortcode |
|--------|-------|-----------|
| Completed | :white_check_mark: | `:white_check_mark:` |
| In progress | :hammer: | `:hammer:` |
| Up next | :soon: | `:soon:` |
| Blocked | :construction: | `:construction:` |
| In review | :eyes: | `:eyes:` |

### Non-Epic Work
| Emoji | Shortcode | Use for |
|-------|-----------|---------|
| :clipboard: | `:clipboard:` | Section header |
| :gear: | `:gear:` | Misc tasks, ops work |
| :busts_in_silhouette: | `:busts_in_silhouette:` | Meetings, pairing |

## Example Reports

### Example 1 — Monday Report (covering Friday)

```
*My Vibe:* :rocket: Shipping mode — closed out the auth epic on Friday

*_Yesterday's Wins (Completed Tasks):_*
* :white_check_mark: `Implement OAuth callback handler (Est: 2d, Actual with AI: 1.5d)`
* :white_check_mark: `Write integration tests for login flow (Est: 1d, Actual with AI: 0.5d)`
* :white_check_mark: `Update user settings page with connected accounts`

*_Today's Focus & Status:_*
:large_green_circle: *_Search & Filters Epic_* (Week 2 of 6)
* :hammer: `Build search index for tasks (Est: 3d)` — picking this up today
* :soon: `Add filter UI components (Est: 2d)`

:large_yellow_circle: *_Performance Improvements_* (Week 4 of 6)
* :construction: `Database query optimization (Est: 2d)` — waiting on DBA review

:clipboard: *_Non-Epic Work:_*
* :gear: `Review and merge 2 PRs from last week`

*_Blockers / @Mentions:_*
* :construction: DB optimization blocked on DBA review — @sarah can you take a look at PR #234?
* :link: Search index depends on the new schema migration — @mike ETA on that?

*_Notes:_*
* Auth epic wrapped up ahead of schedule — AI pairing cut estimate time significantly
```

### Example 2 — Tuesday Report

```
*My Vibe:* :headphones: Deep focus day — heads down on search

*_Yesterday's Wins (Completed Tasks):_*
* :white_check_mark: `Build search index for tasks (Est: 3d, Actual with AI: 1d)` — Copilot helped massively here
* :white_check_mark: `Review and merge 2 PRs`

*_Today's Focus & Status:_*
:large_green_circle: *_Search & Filters Epic_* (Week 2 of 6)
* :hammer: `Add filter UI components (Est: 2d)` — started late yesterday, continuing today
* :soon: `Search results pagination (Est: 1d)`

:large_yellow_circle: *_Performance Improvements_* (Week 4 of 6)
* :eyes: `Database query optimization (Est: 2d)` — DBA approved, in review now

*_Blockers / @Mentions:_*
* :link: Need design review on filter UI — @lisa can you check Figma comments?
```

## Formatting Rules

1. **Always use Slack shortcodes** — never Unicode emoji characters
2. **Bold** uses `*text*` (Slack bold), **italic** uses `_text_` (Slack italic), **bold italic** uses `*_text_*`
3. **Backticks** around task names: `` `task name (Est: Xd)` ``
4. **One line per task** — keep descriptions brief
5. **Duration format**: Use `Xd` for days (e.g., `2d`, `0.5d`)
6. **Week format**: "Week X of Y" for project duration
7. **Omit empty sections** — if no blockers, skip the Blockers section
8. **Estimate vs Actual**: Only include "Actual with AI: Yd" when actual duration data is available
9. **Group tasks by project** — each project gets its own health emoji header
10. **Non-epic work** goes under the `:clipboard:` section, not under a project
