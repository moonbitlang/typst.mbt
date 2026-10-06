#!/usr/bin/env bash
# CI: compare the converted suite with the Typst path (`edsl-suite`), after
# `scripts/edsl_convert.sh` generated the conversions and rebuilt the runner.
# `edsl-suite` exits with 1 on any failing or unconverted case; this adds
# the log, the totals in the job summary and the conversion's compile errors.
set -uo pipefail
cd "$(dirname "$0")/../.."
mkdir -p _build/ci
log=_build/ci/edsl-suite.log
start=$(date +%s)
_build/native/release/build/tests/runner/runner.exe edsl-suite > "$log" 2>&1
code=$?
seconds=$(($(date +%s) - start))
totals=$(grep -E '^edsl-suite: [0-9]+ passed, [0-9]+ failed' "$log" | tail -1)
errors=$(wc -l < tests/edsl_gen/failed.txt | tr -d ' ')
grep '^FAIL ' "$log" | head -100
echo "${totals:-no totals (see the log)}"
echo "edsl-suite: exit $code after $seconds s; $errors conversions with compile errors"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### EDSL conversion sweep"
    echo
    echo "$([ "$code" -eq 0 ] && echo ok || echo '**FAILED**'): ${totals:-no totals} ($seconds s);" \
      "$errors conversions with compile errors (regenerated as fragments)"
    echo
    if [ "$code" -ne 0 ]; then
      echo '```'
      grep '^FAIL ' "$log" | head -60
      [ -n "$totals" ] || tail -30 "$log"
      echo '```'
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi
[ "$code" -eq 0 ] && [ -n "$totals" ]
