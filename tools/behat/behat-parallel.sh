#!/usr/bin/env bash
# Runs each scenario in its own Behat process, BEHAT_JOBS (default: CPU count) at a time.
# Prints the full output of failed scenarios at the end; exits non-zero if any failed.
# Arguments: feature files (default: all of tests/acceptance).
set -euo pipefail
cd "$(dirname "$0")"

jobs="${BEHAT_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}"
if [ "$#" -eq 0 ]; then
    set -- ../../tests/acceptance/*.feature
fi

failures="$(mktemp -d)"
trap 'rm -rf "$failures"' EXIT
export failures

run_scenario() {
    local output
    if output="$(vendor/bin/behat --no-interaction -vvv "$1" 2>&1)"; then
        echo "ok   $1"
    else
        echo "FAIL $1"
        printf '\n===== %s =====\n%s\n' "$1" "$output" > "$failures/$(printf '%s' "$1" | tr '/:.' '___')"
        return 1
    fi
}
export -f run_scenario

scenarios="$(grep -HnE '^[[:space:]]*Scenario( Outline)?:' "$@" | cut -d: -f1,2)"
total="$(printf '%s\n' "$scenarios" | wc -l | tr -d ' ')"
echo "Running $total scenarios, $jobs at a time"

if printf '%s\n' "$scenarios" | xargs -n 1 -P "$jobs" bash -c 'run_scenario "$1"' _; then
    echo "All $total scenarios passed"
    exit 0
fi

cat "$failures"/*
echo "$(find "$failures" -type f | wc -l | tr -d ' ') of $total scenarios failed"
exit 1
