#!/usr/bin/env bash
# Run RSpec inside the Docker dev container and print the SimpleCov %.
#
# Usage:
#   bash .claude/skills/rspec-test-writer/scripts/run-coverage.sh
#   bash .claude/skills/rspec-test-writer/scripts/run-coverage.sh spec/models/task_spec.rb
#   bash .claude/skills/rspec-test-writer/scripts/run-coverage.sh spec/models/task_spec.rb:42
#
# Exits non-zero on RSpec failure. Always prints coverage/.last_run.json afterward
# (when present) so the caller can compare before/after coverage.

set -euo pipefail

# scripts/ -> rspec-test-writer/ -> skills/ -> .claude/ -> repo root (4 levels up)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

SERVICE="rails"
TARGET="${1:-}"

echo "==> Running rspec inside ${SERVICE} container: ${TARGET:-(full suite)}"
echo

# -lc so the login shell init runs and `bundle` is on PATH.
# -T disables pseudo-TTY allocation so output is captured cleanly.
set +e
docker compose exec -T "$SERVICE" bash -lc "bundle exec rspec ${TARGET}"
RSPEC_EXIT=$?
set -e

echo
if [[ -f coverage/.last_run.json ]]; then
  echo "==> coverage/.last_run.json"
  cat coverage/.last_run.json
  echo
fi

echo "==> rspec exit code: ${RSPEC_EXIT}"
echo "==> Open coverage/index.html for a per-file breakdown."

exit "$RSPEC_EXIT"
