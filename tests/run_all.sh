#!/usr/bin/env bash
# Runs the import, a startup smoke test and every test suite headless.
# Fails if any step exits non-zero OR prints a script/engine error, so errors that
# don't stop a test (e.g. inside a signal handler) still fail the run.
# Usage: tests/run_all.sh [path/to/godot]   (defaults to $GODOT or `godot`)
set -u
GODOT_BIN="${1:-${GODOT:-godot}}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
status=0

run() {
	local name="$1"; shift
	local log
	log="$(mktemp)"
	"$GODOT_BIN" --headless --path "$PROJECT" "$@" >"$log" 2>&1
	local code=$?
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|^ERROR:|Parse Error" "$log"; then
		echo "FAIL  $name (exit $code)"
		grep -E "SCRIPT ERROR|^ERROR:|Parse Error|FAIL" -A2 "$log" | head -40
		status=1
	else
		echo "ok    $name  $(grep -E 'ALL TESTS PASSED' "$log" || true)"
	fi
	rm -f "$log"
}

run "import" --editor --quit
run "smoke (180 frames)" --quit-after 180
for suite in test_pathfinding test_gameplay test_skills test_layout test_stability test_balance; do
	run "$suite" --script "res://tests/$suite.gd"
done
exit $status
