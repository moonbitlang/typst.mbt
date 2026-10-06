#!/usr/bin/env bash
# TEMP (platform probe on the draft PR, not for main): what the original
# Rust crates produce on this platform for everything that
# scripts/ci/known_failures/*.linux-x86_64.txt lists, and whether the port
# agrees with them here.
#
# Expects the macOS-made goldens unpacked in `golden-macos/tests/golden` and
# the test data of scripts/ci/data.sh. Results go to `_build/ci/probe/`.
# Never fails; read the output.
set -uo pipefail
cd "$(dirname "$0")/../.."
out="$PWD/_build/ci/probe"
mkdir -p "$out"
section() { echo; echo "=================== $* ==================="; }

section "1. Rust oracle: stage goldens made on $(uname -sm)"
# Like scripts/ci/goldens.sh, without its final checks.
scripts/ci/goldens.sh > "$out/goldens.log" 2>&1
echo "goldens.sh: exit $? (non-zero if the oracle tests it regenerates differ)"
tail -5 "$out/goldens.log"
git status --short | head -20
git diff --stat -- usvg/oracle_test.mbt resvg/oracle_test.mbt
git diff -- resvg/oracle_test.mbt usvg/oracle_test.mbt > "$out/oracle_tests_in_tree.diff"
head -60 "$out/oracle_tests_in_tree.diff" | cut -c1-300
diff -rq golden-macos/tests/golden tests/golden 2>&1 | grep -v '\.key\|\.generated' > "$out/goldens-differing.txt"
echo "golden files that differ between aarch64 macOS and this platform: $(wc -l < "$out/goldens-differing.txt")"
head -40 "$out/goldens-differing.txt" | cut -c1-300
for f in paged/model/link.txt resvg/cases.jsonl; do
  echo "--- $f"
  diff "golden-macos/tests/golden/$f" "tests/golden/$f" > "$out/$(echo "$f" | tr / _).diff"
  head -8 "$out/$(echo "$f" | tr / _).diff" | cut -c1-600
done
# Keep every differing file pair small enough to read.
while read -r _ a _ b _; do
  [ -f "$a" ] && [ -f "$b" ] && diff "$a" "$b" | head -200 | cut -c1-2000 > "$out/golden_$(echo "$b" | tr / _).diff"
done < <(grep '^Files ' "$out/goldens-differing.txt" | head -50)

section "2. The port against the goldens made here (paged link-show, resvg)"
git checkout -q -- usvg/oracle_test.mbt resvg/oracle_test.mbt
moon build --target native tests/runner > "$out/runner-build.log" 2>&1 || tail -30 "$out/runner-build.log"
runner=_build/native/debug/build/tests/runner/runner.exe
"$runner" paged link-show --verbose 2>&1 | tail -6 | cut -c1-400
"$runner" resvg no-width-and-height --verbose 2>&1 | grep -v '^PASS' | tail -8 | cut -c1-400
"$runner" resvg 2>&1 | tail -3

section "3. Rust generators of the unit oracles on this platform vs. the committed expectations"
(
  cd oracle || exit 1
  cargo run --release -q --bin gen_kurbo_stroke_tests > "$out/kurbo_stroke_oracle.tsv" 2> "$out/kurbo.err"
  echo "kurbo stroke oracle: $(diff ../kurbo/testdata/stroke_oracle.tsv "$out/kurbo_stroke_oracle.tsv" | grep -c '^>') of $(wc -l < "$out/kurbo_stroke_oracle.tsv") lines differ from the committed file"
  diff ../kurbo/testdata/stroke_oracle.tsv "$out/kurbo_stroke_oracle.tsv" | head -6 | cut -c1-300
  cargo run --release -q --bin gen_hayro_render_tests -- ../hayro/render/testdata/corpus.txt 1 0.37 > "$out/hayro_render_expected.tsv" 2> "$out/render.err"
  echo "hayro render oracle: lines that differ from the committed file:"
  diff ../hayro/render/testdata/expected.tsv "$out/hayro_render_expected.tsv" | cut -c1-300 | head -20
  cargo run --release -q --bin gen_svgtypes_tests > "$out/svgtypes_oracle_test.mbt" 2> "$out/svgtypes.err"
  cargo run --release -q --bin gen_tiny_skia_path_tests > "$out/tiny_skia_path_oracle_wbtest.mbt" 2> "$out/tsp.err"
)
cp "$out/svgtypes_oracle_test.mbt" svgtypes/oracle_test.mbt
cp "$out/tiny_skia_path_oracle_wbtest.mbt" tiny_skia_path/oracle_wbtest.mbt
cp "$out/kurbo_stroke_oracle.tsv" kurbo/testdata/stroke_oracle.tsv
cp "$out/hayro_render_expected.tsv" hayro/render/testdata/expected.tsv
moon fmt > /dev/null 2>&1
git diff --stat -- svgtypes tiny_skia_path kurbo hayro/render
git diff -- svgtypes/oracle_test.mbt | grep '^[-+] ' | head -12 | cut -c1-400
git diff -- tiny_skia_path/oracle_wbtest.mbt | grep '^[-+] ' | head -6 | cut -c1-400

section "4. Upstream typst on this platform vs. typst/oracle_wbtest.mbt"
(
  cd .repos/typst || exit 1
  cargo +1.97.1 build --release -q -p typst-cli > "$out/typst-cli-build.log" 2>&1 || tail -20 "$out/typst-cli-build.log"
)
python3 scripts/gen_typst_oracle.py .repos/typst/target/release/typst > "$out/gen_typst_oracle.log" 2>&1 || tail -20 "$out/gen_typst_oracle.log"
moon fmt > /dev/null 2>&1
git diff --stat -- typst/oracle_wbtest.mbt
git diff -- typst/oracle_wbtest.mbt > "$out/typst_oracle_wbtest.diff"
grep '^[-+] ' "$out/typst_oracle_wbtest.diff" | head -40 | cut -c1-400

section "5. The port's unit tests against the expectations made here"
git status --short | head
moon test --target native -p moonbitlang/typst/kurbo -p moonbitlang/typst/svgtypes \
  -p moonbitlang/typst/tiny_skia_path -p moonbitlang/typst/hayro/render \
  -p moonbitlang/typst/typst > "$out/unit.log" 2>&1
echo "moon test: exit $?"
grep -E '^\[.*\] test .* failed|^Total tests' "$out/unit.log" | cut -c1-400
git diff > "$out/tree.diff"
echo "probe done"
