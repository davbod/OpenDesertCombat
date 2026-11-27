#!/usr/bin/env bash
# Runs the headless import once, then every test suite (godot/tests/*_test.gd) in
# alphabetical order, prints each suite's output and a summary table.
#
# A suite fails if it exits non-zero, prints a "SCRIPT ERROR" or "Parse Error" line,
# never prints its "N failure(s)" summary, or runs longer than SUITE_TIMEOUT.
# Exit code: 0 = everything passed, 1 = something failed, 2 = usage error.
#
# Works with bash 3.2 (macOS) and newer, from any working directory.

usage() {
	cat <<'EOF'
Usage: GODOT=/path/to/godot godot/tests/run_all.sh [suite ...]

Runs the headless import, then every godot/tests/*_test.gd suite (or only the named
suites, e.g. "match_test") and prints a summary. Exits non-zero if anything failed.

Environment:
  GODOT          Godot 4.4.1 binary (required)
  SUITE_TIMEOUT  seconds before a hung import or suite is killed (default 180)
EOF
}

case "${1:-}" in
	-h | --help)
		usage
		exit 0
		;;
esac

if [ -z "${GODOT:-}" ]; then
	echo "run_all.sh: GODOT is not set" >&2
	echo >&2
	usage >&2
	exit 2
fi

# Accept a quoted "~/..." path as well as an expanded one
# shellcheck disable=SC2088 # matching a literal tilde is the point
case "$GODOT" in
	"~/"*) GODOT="$HOME/${GODOT#"~/"}" ;;
esac
case "$GODOT" in
	*/*)
		if [ ! -f "$GODOT" ] || [ ! -x "$GODOT" ]; then
			echo "run_all.sh: GODOT is not an executable file: $GODOT" >&2
			exit 2
		fi
		;;
	*)
		if ! command -v "$GODOT" >/dev/null 2>&1; then
			echo "run_all.sh: GODOT not found in PATH: $GODOT" >&2
			exit 2
		fi
		;;
esac

SUITE_TIMEOUT="${SUITE_TIMEOUT:-180}"
case "$SUITE_TIMEOUT" in
	'' | *[!0-9]*)
		echo "run_all.sh: SUITE_TIMEOUT must be a whole number of seconds: $SUITE_TIMEOUT" >&2
		exit 2
		;;
esac

TESTS_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname -- "$TESTS_DIR")"

# --- Which suites ---

SUITES=()
if [ $# -gt 0 ]; then
	for arg in "$@"; do
		name="$(basename -- "$arg" .gd)"
		if [ ! -f "$TESTS_DIR/$name.gd" ]; then
			echo "run_all.sh: no such suite: $TESTS_DIR/$name.gd" >&2
			exit 2
		fi
		SUITES+=("$name")
	done
else
	# Sort with the C locale so the order is the same on every machine
	while IFS= read -r name; do
		SUITES+=("$name")
	done < <(cd "$TESTS_DIR" && for f in *_test.gd; do [ -f "$f" ] && echo "${f%.gd}"; done | LC_ALL=C sort)
fi
if [ ${#SUITES[@]} -eq 0 ]; then
	echo "run_all.sh: no *_test.gd suites found in $TESTS_DIR" >&2
	exit 1
fi

# --- Plumbing: temp logs, Ctrl-C, timeouts ---

LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/odc-tests.XXXXXX")" || exit 1
GODOT_PID=""
WATCHDOG_PID=""

cleanup() {
	[ -n "$WATCHDOG_PID" ] && kill "$WATCHDOG_PID" 2>/dev/null
	[ -n "$GODOT_PID" ] && kill "$GODOT_PID" 2>/dev/null
	rm -rf "$LOG_DIR"
}
trap cleanup EXIT
trap 'echo "run_all.sh: interrupted" >&2; exit 130' INT TERM

IN_GITHUB=""
[ "${GITHUB_ACTIONS:-}" = "true" ] && IN_GITHUB=1

# run_godot LOG ARGS... — runs Godot with output in LOG, killing it after SUITE_TIMEOUT
# seconds (macOS has no `timeout`). Returns Godot's exit code; writes LOG.timeout if killed.
run_godot() {
	local log="$1"
	shift
	"$GODOT" "$@" >"$log" 2>&1 &
	GODOT_PID=$!
	(
		trap 'kill "$sleeper" 2>/dev/null; exit 0' TERM
		sleep "$SUITE_TIMEOUT" &
		sleeper=$!
		wait "$sleeper"
		: >"$log.timeout"
		kill -TERM "$GODOT_PID" 2>/dev/null
		sleep 5 &
		sleeper=$!
		wait "$sleeper"
		kill -KILL "$GODOT_PID" 2>/dev/null
	) &
	WATCHDOG_PID=$!
	wait "$GODOT_PID"
	local status=$?
	kill -TERM "$WATCHDOG_PID" 2>/dev/null
	wait "$WATCHDOG_PID" 2>/dev/null
	GODOT_PID=""
	WATCHDOG_PID=""
	return $status
}

SCRIPT_ERROR_RESULT="FAILED (script error)"

# classify LOG STATUS — prints "ok" or why a Godot run failed (all but the summary check).
# A runtime script error usually stops the suite's coroutine, so it then hangs until the
# timeout: the result says both.
classify() {
	local reasons=""
	if [ -e "$1.timeout" ]; then
		reasons="timed out after ${SUITE_TIMEOUT}s"
	elif [ "$2" -ne 0 ]; then
		reasons="exit $2"
	fi
	if grep -Eq 'SCRIPT ERROR|Parse Error' "$1"; then
		reasons="${reasons:+$reasons, }script error"
	fi
	if [ -z "$reasons" ]; then
		echo "ok"
	else
		echo "FAILED ($reasons)"
	fi
}

count_lines() { # PATTERN FILE
	grep -c -- "$1" "$2" 2>/dev/null || true
}

group_start() {
	if [ -n "$IN_GITHUB" ]; then echo "::group::$1"; else echo "=== $1"; fi
}

group_end() {
	if [ -n "$IN_GITHUB" ]; then echo "::endgroup::"; else echo; fi
}

echo "Godot:   $("$GODOT" --version 2>/dev/null | tail -n 1)"
echo "Project: $PROJECT_DIR"
echo

# --- Import (fresh checkouts have no .godot/ cache yet) ---

echo "Running import ..."
started=$SECONDS
import_log="$LOG_DIR/import.log"
run_godot "$import_log" --headless --path "$PROJECT_DIR" --import --quit
import_status=$?
import_secs=$((SECONDS - started))
import_result=$(classify "$import_log" $import_status)
if [ "$import_result" = "ok" ]; then
	echo "Import ok (${import_secs}s)"
	echo
else
	group_start "import: $import_result"
	cat "$import_log"
	group_end
	[ -n "$IN_GITHUB" ] && echo "::error title=Godot import failed::$import_result"
	# A script error (e.g. a parse error) still leaves a usable import: run the suites
	# so the log shows what else breaks. Anything else means there is nothing to test.
	if [ "$import_result" != "$SCRIPT_ERROR_RESULT" ]; then
		echo "run_all.sh: the import did not finish; no suites were run." >&2
		exit 1
	fi
fi

# --- Suites ---

# One entry per suite, same index in each array (bash 3.2 has no associative arrays)
R_PASS=()
R_FAIL=()
R_SECS=()
R_RESULT=()
total_pass=0
total_fail=0
failed_suites=0
run_started=$SECONDS

for suite in "${SUITES[@]}"; do
	echo "Running $suite ..."
	log="$LOG_DIR/$suite.log"
	started=$SECONDS
	run_godot "$log" --headless --path "$PROJECT_DIR" --script "res://tests/$suite.gd"
	status=$?
	secs=$((SECONDS - started))

	passes=$(count_lines '^  PASS  ' "$log")
	fails=$(count_lines '^  FAIL  ' "$log")
	result=$(classify "$log" $status)
	if [ "$result" = "ok" ] && ! grep -Eq '^[0-9]+ failure\(s\)$' "$log"; then
		result="FAILED (no summary line)"
	fi

	group_start "$suite: $result"
	cat "$log"
	group_end
	if [ "$result" != "ok" ]; then
		failed_suites=$((failed_suites + 1))
		if [ -n "$IN_GITHUB" ]; then
			echo "::error title=$suite failed::$result, $fails failing check(s)"
			# One annotation per failing check (the first 10), so they show on the PR
			grep '^  FAIL  ' "$log" | head -n 10 | while IFS= read -r line; do
				msg="${line#  FAIL  }"
				echo "::error title=$suite::${msg//\%/%25}"
			done
		fi
	fi

	total_pass=$((total_pass + passes))
	total_fail=$((total_fail + fails))
	R_PASS+=("$passes")
	R_FAIL+=("$fails")
	R_SECS+=("$secs")
	R_RESULT+=("$result")
done

# --- Summary ---

total_secs=$((SECONDS - run_started))
if [ $failed_suites -eq 0 ]; then
	overall="all ${#SUITES[@]} suites passed"
else
	overall="$failed_suites of ${#SUITES[@]} suites FAILED"
fi
if [ "$import_result" != "ok" ]; then
	overall="import FAILED; $overall"
fi

row() { # SUITE PASS FAIL SECONDS RESULT
	printf '%-24s %6s %6s %7s  %s\n' "$1" "$2" "$3" "$4" "$5"
}

echo "Summary"
row "suite" "pass" "fail" "time" "result"
row "(import)" "-" "-" "${import_secs}s" "$import_result"
i=0
while [ $i -lt ${#SUITES[@]} ]; do
	row "${SUITES[$i]}" "${R_PASS[$i]}" "${R_FAIL[$i]}" "${R_SECS[$i]}s" "${R_RESULT[$i]}"
	i=$((i + 1))
done
row "total" "$total_pass" "$total_fail" "${total_secs}s" "$overall"

if [ -n "$IN_GITHUB" ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "### Godot test suites: $overall"
		echo
		echo "| suite | pass | fail | time | result |"
		echo "|---|---:|---:|---:|---|"
		echo "| (import) | - | - | ${import_secs}s | $import_result |"
		i=0
		while [ $i -lt ${#SUITES[@]} ]; do
			echo "| ${SUITES[$i]} | ${R_PASS[$i]} | ${R_FAIL[$i]} | ${R_SECS[$i]}s | ${R_RESULT[$i]} |"
			i=$((i + 1))
		done
		echo "| **total** | **$total_pass** | **$total_fail** | ${total_secs}s | |"
	} >>"$GITHUB_STEP_SUMMARY"
fi

[ $failed_suites -eq 0 ] && [ "$import_result" = "ok" ]
