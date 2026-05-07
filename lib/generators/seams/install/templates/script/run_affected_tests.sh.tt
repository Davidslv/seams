#!/usr/bin/env bash
# Detects which engines changed vs the merge base with `main` and runs
# only those engines' specs. Falls back to running every engine when
# the diff is empty (a noop branch) or when invoked with --all.
#
# Usage:
#
#   script/run_affected_tests.sh            # diff against main
#   script/run_affected_tests.sh --all      # run every engine
#   BASE_BRANCH=develop script/run_affected_tests.sh
#
# Exit code is the OR of every engine spec run — first failure aborts.

set -euo pipefail

BASE_BRANCH="${BASE_BRANCH:-main}"
RUN_ALL=0

if [[ "${1:-}" == "--all" ]]; then
  RUN_ALL=1
fi

# Resolve the merge base so we ignore commits already on main.
merge_base="$(git merge-base "$BASE_BRANCH" HEAD 2>/dev/null || echo "")"
if [[ -z "$merge_base" ]]; then
  echo "Could not resolve merge base with $BASE_BRANCH — running all engines."
  RUN_ALL=1
fi

if [[ "$RUN_ALL" == "1" ]]; then
  changed_engines=$(ls -1 engines/ 2>/dev/null || true)
else
  changed_engines=$(git diff --name-only "$merge_base" HEAD -- 'engines/*' \
                      | awk -F/ '{print $2}' | sort -u)
fi

if [[ -z "$changed_engines" ]]; then
  echo "No engines changed since $BASE_BRANCH. Nothing to test."
  exit 0
fi

echo "Engines to test:"
echo "$changed_engines" | sed 's/^/  - /'
echo

failed=()
for engine in $changed_engines; do
  if [[ ! -d "engines/$engine" ]]; then
    continue
  fi
  echo "=== running engines/$engine specs ==="
  if ! bundle exec rspec "engines/$engine/spec"; then
    failed+=("$engine")
  fi
done

if (( ${#failed[@]} > 0 )); then
  echo
  echo "Failed engines: ${failed[*]}"
  exit 1
fi

echo
echo "All affected engine specs passed."
