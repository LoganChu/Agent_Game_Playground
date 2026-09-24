#!/usr/bin/env bash
# Full pre-push verification. Exit code 0 only if everything passes.
#   1. Import project (parses every script, imports assets)
#   2. Unit + content-validation tests
#   3. Smoke playthrough of the main scene (talk to all NPCs, pickups, save/load)
#   4. Plain main-scene launch for a few hundred frames
# Any "SCRIPT ERROR", "ERROR:" or "Parse Error" in Godot's output fails the run.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/bin/godot}"
[[ -x "$GODOT" ]] || GODOT="$(command -v godot || true)"
if [[ -z "$GODOT" ]]; then
	echo "godot not found; run tools/setup.sh first" >&2
	exit 2
fi
LOG_DIR="$(mktemp -d)"
FAILED=0

run_step() {
	local name="$1"; shift
	local log="$LOG_DIR/$name.log"
	echo "== $name"
	"$@" >"$log" 2>&1
	local code=$?
	if grep -qE "SCRIPT ERROR|Parse Error|^ERROR:|USER ERROR|Failed to load script" "$log"; then
		echo "   errors in output:"
		grep -nE -A3 "SCRIPT ERROR|Parse Error|^ERROR:|USER ERROR|Failed to load script" "$log" | head -40 | sed 's/^/   /'
		code=1
	fi
	if [[ $code -ne 0 ]]; then
		echo "   FAILED (exit $code) — full log: $log"
		tail -30 "$log" | sed 's/^/   | /'
		FAILED=1
	else
		echo "   ok"
	fi
}

cd "$ROOT"
run_step import timeout 600 "$GODOT" --headless --path . --import
run_step tests timeout 300 "$GODOT" --headless --path . -s res://tests/run_tests.gd
grep -E "^ok|^FAIL|tests," "$LOG_DIR/tests.log" | tail -3 | sed 's/^/   /'
run_step smoke timeout 300 "$GODOT" --headless --path . -- --smoke-test
grep -q "SMOKE TEST PASSED" "$LOG_DIR/smoke.log" || { echo "   smoke test did not report success"; FAILED=1; }
run_step launch timeout 300 "$GODOT" --headless --path . --quit-after 300

if [[ $FAILED -ne 0 ]]; then
	echo "CHECKS FAILED"
	exit 1
fi
echo "ALL CHECKS PASSED"
