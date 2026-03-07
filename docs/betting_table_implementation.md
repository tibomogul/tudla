# Betting Table Implementation

Technical reference for the betting table feature, covering the controller logic, view layer, Stimulus controller, and Turbo Stream updates.

## Overview

The betting table allows organization admins to review pitches in the `ready_for_betting` state and either bet on them (creating a project assigned to a team) or reject them. The UI updates in-place via Turbo Streams without full page reloads.

## Routing

The betting table is a member route on cycles, and bet/transition are member routes on pitches:

```ruby
# config/routes.rb
resources :cycles do
  member do
    get :betting_table
  end
end

resources :pitches do
  member do
    patch :transition
    post :bet
  end
end
```

## Controller Layer

### `CyclesController#betting_table`

**File:** `app/controllers/cycles_controller.rb`

Loads all pitches relevant to the betting table:

- `ready_for_betting` pitches in the same organization (available for betting).
- `bet` and `rejected` pitches that have a project linked to this cycle (shown greyed out).

Sets `@betting_enabled` based on cycle state — `true` only when the cycle is in `shaping` or `betting`.

Groups pitches by appetite into `@big_batch_pitches` (appetite = 6) and `@small_batch_pitches` (appetite = 2).

Loads `@teams` for the team selection dropdown and sidebar.

### `PitchesController#bet`

**File:** `app/controllers/pitches_controller.rb`

1. Validates `team_id` presence — redirects back with alert if blank.
2. In a transaction: creates a `Project` from the pitch and transitions the pitch to `bet` state.
3. Responds to both HTML (redirect to project) and `turbo_stream` (in-place card + sidebar update).

For turbo_stream responses, loads `@cycle`, `@teams`, and `@betting_enabled` to re-render the partials.

### `PitchesController#transition`

**File:** `app/controllers/pitches_controller.rb`

Extended to handle `update_context: "betting_table"`. When this context is set:

- Loads `@cycle` from `params[:cycle_id]`.
- Loads `@teams` and `@betting_enabled`.
- The turbo_stream template replaces the betting card instead of the standard pitch partial.

## View Layer

### `betting_table.html.erb`

**File:** `app/views/cycles/betting_table.html.erb`

Main layout with:

- Cycle state badge next to the heading.
- Warning banner when `@betting_enabled` is false.
- Two-column grid: pitch cards (2/3) and team availability sidebar (1/3).
- Passes `teams` and `betting_enabled` as locals to each card partial.

### `_betting_pitch_card.html.erb`

**File:** `app/views/cycles/_betting_pitch_card.html.erb`

Each card is wrapped with `id="<%= dom_id(pitch, :betting_card) %>"` for Turbo Stream targeting and `data-controller="betting-modal"` for Stimulus.

**Card states:**

| Pitch State | Appearance | Actions |
|---|---|---|
| `ready_for_betting` + betting enabled | Normal card | Preview, Place Bet, Reject |
| `bet` | Greyed out (opacity-60), "Bet — TeamName" badge | None |
| `rejected` | Greyed out (opacity-60), "Rejected" badge | None |
| Any state + betting disabled | Normal/greyed | None (read-only) |

**Key elements:**

- Header: title link, appetite badge, ingredients count, state badge, author/date.
- Problem excerpt: truncated to 200 chars.
- Action row: Preview toggle, Place Bet button, Reject button (with `turbo_confirm`).
- Expandable details: hidden by default, toggled by Stimulus. Renders all 4 markdown ingredients using `render_markdown()`.
- Bet dialog: DaisyUI `<dialog>` with team `<select>` dropdown. Form posts to `bet_pitch_path` with `data-turbo-stream: true`.

**Locals required:** `pitch`, `cycle`, `teams`, `betting_enabled`.

### `_team_availability.html.erb`

**File:** `app/views/cycles/_team_availability.html.erb`

Wrapped with `id="team_availability"` for Turbo Stream targeting. Shows each team's member count and how many projects are committed to the cycle.

**Locals required:** `teams`, `cycle`.

## Turbo Stream Templates

### `bet.turbo_stream.erb`

**File:** `app/views/pitches/bet.turbo_stream.erb`

Replaces two targets after a successful bet:

1. `dom_id(@pitch, :betting_card)` — re-renders the card (now greyed out with team name).
2. `team_availability` — re-renders the sidebar (updated commitment count).

### `transition.turbo_stream.erb`

**File:** `app/views/pitches/transition.turbo_stream.erb`

Conditionally branches on `@update_context`:

- `"betting_table"` — replaces `dom_id(@pitch, :betting_card)` with the betting card partial.
- Default — replaces `dom_id(@pitch)` with the standard pitch partial (existing behavior).

## Stimulus Controller

### `betting_modal_controller.js`

**File:** `app/javascript/controllers/betting_modal_controller.js`

Thin DOM-toggling controller:

- **Targets:** `betDialog`, `details`, `chevron`.
- **`openBet()`** — calls `betDialogTarget.showModal()` to open the native `<dialog>`.
- **`togglePreview()`** — toggles `hidden` class on `detailsTarget` and `rotate-180` on `chevronTarget`.

Auto-registered via `eagerLoadControllersFrom` in the controllers index.

## Helper

### `pitch_ingredients_count`

**File:** `app/helpers/pitches_helper.rb`

```ruby
def pitch_ingredients_count(pitch)
  [ pitch.problem, pitch.appetite, pitch.solution, pitch.rabbit_holes, pitch.no_gos ]
    .count(&:present?)
end
```

Returns a count (0-5) of how many pitch ingredients are filled in. Used in card headers as "N/5 ingredients".

## Authorization

- **Viewing the betting table:** requires `show?` policy on the cycle (any organization member).
- **Place Bet button:** guarded by `policy(pitch).bet?` (admin only).
- **Reject button:** guarded by `policy(pitch).reject?` (admin only).
- **Betting actions disabled:** when cycle state is `active` or `completed`, `betting_enabled` is false and no action buttons render.

## Test Coverage

### Request Specs

**`spec/requests/cycles_spec.rb`:**

- Betting table renders successfully.
- Pitches grouped by appetite.
- `betting_enabled` true for shaping, false for active.
- Bet pitches shown greyed out.

**`spec/requests/pitches_spec.rb`:**

- Bet with `team_id` creates project.
- Bet without `team_id` redirects with error.
- Bet with turbo_stream format returns turbo_stream response.
- Transition to rejected with `update_context=betting_table` returns turbo_stream with betting card.

### Helper Specs

**`spec/helpers/pitches_helper_spec.rb`:**

- `pitch_ingredients_count` returns correct counts for full, empty, partial, and blank-string inputs.
