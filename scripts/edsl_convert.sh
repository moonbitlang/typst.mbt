#!/bin/sh
# Convert the upstream suite to the EDSL (docs/edsl-convert.md, section 8).
#
#   scripts/edsl_convert.sh [--baseline] [filter]
#
# Writes the generated MoonBit into the shard packages tests/edsl_gen/s*
# (gen_cases.mbt, not committed) and tests/edsl_gen/manifest.tsv, makes sure
# the generated code type-checks, and rebuilds the runner, so that
#
#   moon run tests/runner --target native --release -- edsl-suite [filter]
#
# compares the converted cases with the Typst path. The generator must not
# depend on what it generates: the runner is built without generated code
# first and the binary is kept for the generation steps.
#
# Cases whose generated code does not type-check are translator bugs: they
# are listed in tests/edsl_gen/failed.txt with the compiler's message,
# recorded in the manifest (`compile-error: ..`) and regenerated as
# whole-document fragments so that the sweep can run.
set -e
jobs="${JOBS:-8}"
gen=tests/edsl_gen
generator=_build/edsl-convert-runner

rm -f "$gen"/s*/gen_cases.mbt "$gen/failed.txt" "$gen/manifest.tsv"
moon build --target native --release tests/runner -j"$jobs" > _build/edsl-convert-build.log 2>&1 || {
  grep -A12 "^Error" _build/edsl-convert-build.log | head -60
  echo "edsl_convert: the runner does not build without generated code"
  exit 1
}
cp _build/native/release/build/tests/runner/runner.exe "$generator"

"$generator" edsl-convert "$@"
: > "$gen/failed.txt"
attempt=0
while :; do
  attempt=$((attempt + 1))
  moon check --target native -j"$jobs" > _build/edsl-convert-check.log 2>&1 || true
  new=$(python3 scripts/edsl_failed.py _build/edsl-convert-check.log "$gen/manifest.tsv" "$gen/failed.txt")
  echo "edsl_convert: check $attempt: $new new cases with compile errors"
  if [ "$new" = "0" ]; then
    break
  fi
  if [ "$attempt" -ge 8 ]; then
    echo "edsl_convert: the generated code still does not type-check"
    exit 1
  fi
  "$generator" edsl-convert "$@" --failed="$gen/failed.txt"
done
if grep -q "^Error" _build/edsl-convert-check.log; then
  grep -A12 "^Error" _build/edsl-convert-check.log | head -40
  echo "edsl_convert: errors outside the generated cases"
  exit 1
fi
moon build --target native --release tests/runner -j"$jobs" > _build/edsl-convert-build.log 2>&1 || {
  grep -A12 "^Error" _build/edsl-convert-build.log | head -60
  exit 1
}
echo "edsl_convert: done; $(wc -l < "$gen/failed.txt" | tr -d ' ') cases with compile errors"
