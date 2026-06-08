---
name: rspec-test-reviewer
description: >
  Review RSpec tests for meaningfulness, correctness, and assertion quality.
  Use this skill after writing or generating RSpec tests for the Tudla Rails
  application. Trigger whenever the user asks to review tests, audit test
  quality, check if tests are meaningful, validate rspec coverage, or mentions
  concerns about "weak assertions", "dubious tests", "fake coverage",
  "tautological specs", or "tests just to pass". Also trigger when the user says
  things like "review the tests you just wrote", "are these tests actually
  good", "check test quality", or "make sure the specs are real". This skill is
  specifically about evaluating whether tests verify real application behavior —
  not about writing tests from scratch.
---

# RSpec Test Reviewer

You are reviewing RSpec tests for the Tudla Rails application. Your job is to
determine whether each test meaningfully verifies application behavior, or whether
it exists just to satisfy a coverage metric. This is a quality gate, not a
rubber stamp.

## Why this matters

The test suite is Tudla's safety net for the cross-cutting concerns that are
easy to break silently — soft delete (`.active`), estimate-rollup caching,
Statesman lifecycle propagation, and Pundit authorization. A test that asserts
nothing real is worse than no test — it creates false confidence. The goal is
that every spec, if the production code broke, would actually fail.

## Review process

For each test file under review:

1. **Read the production code being tested** — understand what the class/method
   actually does, what side effects it has, what it returns, and what edge cases
   exist. You cannot review a test without understanding what it's testing.

2. **Read the test file** — evaluate each example group and individual example
   against the criteria below.

3. **Produce a structured review** — for each issue found, identify the specific
   test, the problem category, why it's a problem, and what a meaningful
   replacement would look like.

## What to flag

### Critical issues (the test provides no real safety)

**Tautological assertions** — the test asserts something that is guaranteed to
be true regardless of whether the production code works correctly.

```ruby
# BAD: This will always pass, it tests Ruby's Hash, not your code
it "returns a hash" do
  result = subject.call
  expect(result).to be_a(Hash)
end

# BAD: Asserts the mock's return value, not real behavior
it "gets the user" do
  allow(User).to receive(:find).and_return(user)
  expect(subject.find_user(1)).to eq(user)
end
```

**Mocking the system under test** — when the test mocks or stubs the very
method/class it's supposed to be testing, it's testing the mock framework.

```ruby
# BAD: You're testing that the stub works, not that the method works
it "transitions the task" do
  allow(task).to receive(:current_state).and_return("done")
  expect(task.current_state).to eq("done")
end
```

**Direct state assignment instead of the machine** — Tudla-specific. A spec that
sets `task.state = "done"` (or `update_column(:state, ...)`) and then asserts it
is testing the column, not the Statesman machine. State must be exercised
through `state_machine.transition_to!`; flag any spec that bypasses it.

**Querying without `.active`** — Tudla-specific. A spec for a scope/policy/tool
that builds soft-deletable records but never proves deleted ones are excluded
gives false confidence in the exact place soft delete tends to break. Flag the
missing "excludes soft-deleted" case.

**Testing framework internals** — asserting that ActiveRecord associations exist
via `.reflect_on_association`, or that a column exists. These test Rails, not
your application logic.

**Empty or trivially true expectations** — `expect(true).to be true`,
`expect(subject).to be_truthy` when subject is just an instantiated object, or
`expect { subject }.not_to raise_error` as the sole assertion with no setup that
could actually cause an error.

### Significant issues (the test has value but is misleading or fragile)

**Incomplete verification** — the test exercises the code path but only checks a
superficial property of the result (e.g. `be_present` on a return value when the
test should verify the actual content or structure).

```ruby
# WEAK: proves it returned something, not that it returned the right thing
expect(scope.cached_unassisted_estimate).to be_present

# BETTER: proves the rollup math
expect(scope.cached_unassisted_estimate).to eq(30)
```

**Over-mocking** — so much of the dependency graph is stubbed that the test no
longer exercises any real integration. A unit test can use targeted mocks
(stub the LLM client, the mailer, ActionCable); the issue is when mocking makes
the test tautological, not when mocking exists.

**Testing private methods directly** — using `send(:private_method)`. Tudla's
MCP-tool specs do legitimately reach `send(:filter_by_team, ...)` because that
method encodes the security-critical scoping logic; that's a deliberate contract
test. Outside such cases, prefer testing through the public interface.

**Clock-dependent assertions** — using `Date.today`, `Time.now`, `Time.current`
directly inside an assertion (or in the exercised production path) without
freezing time. If the clock advances between running the code and evaluating the
assertion, the test can fail spuriously, and a bug that hard-codes the wrong date
would still pass. Freeze with `travel_to`. Also check timezone correctness: Tudla
formats times in the **organization** timezone — an assertion against a UTC/
browser-clock value is wrong even when frozen.

```ruby
# GOOD: deterministic and meaningful
travel_to(Time.zone.local(2026, 1, 15, 9)) do
  expect(record.reload.done_at).to be_within(1.second).of(Time.zone.local(2026, 1, 15, 9))
end
```

`travel_to` is available everywhere (`ActiveSupport::Testing::TimeHelpers` is
included in `spec/rails_helper.rb`). Flag any clock call without a surrounding
`travel_to` as a **Significant** issue.

**Brittle string matching** — asserting on an exact error message or log string
that could change without affecting behavior.

### Minor issues (style or missed opportunity)

**Missing edge cases** — the happy path is tested but obvious failure modes are
not (nil inputs, empty collections, forbidden state transitions, authorization
boundaries, soft-deleted records, boundary values).

**Redundant examples** — multiple `it` blocks testing the same code path with
trivially different inputs and no additional coverage.

**Context without meaning** — `context "when valid"` containing the same setup as
the outer scope, adding nesting without clarity.

## Review output format

> When this skill is invoked by the `spec-reviewer` sub-agent, the agent's
> frontmatter prescribes an exact Markdown block (verdict + issues + good tests +
> notes) that orchestration appends to a checklist verbatim. Follow the agent's
> block in that context. The format below describes the general shape for
> direct/interactive use of this skill on a single file.

For each file reviewed, state the file path and provide:

1. **Summary verdict** — one of:
   - **PASS** — all tests are meaningful; minor suggestions only
   - **NEEDS WORK** — some tests are weak but the file has real value
   - **FAIL** — the file has critical issues; tests provide false confidence

2. **Issues found** — for each issue:
   - The `it`/`describe`/`context` block (quote the description string)
   - The category (from the lists above)
   - A brief explanation of why it's a problem, specific to this test
   - A concrete suggestion for what a meaningful test would look like

3. **What's good** — briefly note tests that are well-written. Positive
   reinforcement helps calibrate what "good" looks like for future generation.

## Important principles

- **Be specific.** "This test is weak" is useless feedback. Say exactly what the
  assertion proves and what it fails to prove.

- **Understand intent before criticizing.** A test for `respond_to(:method)`
  might seem trivial in isolation but could be a deliberate interface contract.
  Check the context.

- **Don't demand integration tests everywhere.** Unit tests with targeted mocks
  are fine. The issue is when mocking makes the test tautological.

- **Weigh the Tudla-sensitive behaviours heavily.** Tests that verify soft-delete
  exclusion, estimate-cache rollups, Statesman guards/propagation/atomicity, and
  Pundit role/state boundaries are the most valuable. Call out when they are
  missing for code that touches those concerns.

- **Suggest, don't just reject.** Every flagged issue should include a concrete
  alternative — show what the improved test would look like.

- **A test that exercises real code and makes a real assertion is fine** even if
  it's not comprehensive. Perfection is not the bar — meaningfulness is.
