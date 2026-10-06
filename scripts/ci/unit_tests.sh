#!/usr/bin/env bash
# CI: run the unit tests and report them.
#
#   scripts/ci/unit_tests.sh [moon test options ...]     (default: --target native)
#
# The full output (with the compiler's warnings) goes to
# `_build/ci/unit/test.log`; the failures and the totals are printed and
# appended to `$GITHUB_STEP_SUMMARY`. Fails if `moon test` fails, or if it
# does not report its totals with `failed: 0`.
set -uo pipefail
cd "$(dirname "$0")/../.."
[ $# -eq 0 ] && set -- --target native
out=_build/ci/unit
mkdir -p "$out"
log="$out/test.log"

start=$(date +%s)
moon test "$@" > "$log" 2>&1
code=$?
seconds=$(($(date +%s) - start))

# A failure is reported as `[module] test file:line ("name") failed` followed
# by its message up to the next blank line.
awk '/^\[.*\] test .* failed/ { show = 1 } show { print } /^$/ { show = 0 }' "$log" \
  > "$out/failures.txt"
totals=$(grep -E '^Total tests: [0-9]+, passed: [0-9]+, failed: [0-9]+' "$log" | tail -1)
head -200 "$out/failures.txt"
echo "${totals:-no totals: moon test did not finish (see the log)}"
echo "moon test $*: exit $code after $seconds s"

ok=1
[ "$code" -eq 0 ] || ok=0
grep -q 'failed: 0\.$' <<< "$totals" || ok=0
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Unit tests (\`moon test $*\`)"
    echo
    if [ "$ok" = 1 ]; then echo "ok: ${totals} ($seconds s)"; else
      echo "**FAILED** (exit $code, $seconds s): ${totals:-no totals}"
      echo
      echo '```'
      head -60 "$out/failures.txt"
      # Without a failing test, the end of the log says why (a build error).
      [ -s "$out/failures.txt" ] || tail -40 "$log"
      echo '```'
    fi
    echo
  } >> "$GITHUB_STEP_SUMMARY"
fi
if [ "$ok" != 1 ]; then
  [ -s "$out/failures.txt" ] || tail -60 "$log"
  echo "::error title=unit tests::moon test $* failed (exit $code): ${totals:-no totals}"
  exit 1
fi
