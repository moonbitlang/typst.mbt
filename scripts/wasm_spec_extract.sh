#!/usr/bin/env bash
# Extract the WebAssembly spec test suite into JSON command files and binary
# modules (`wasm-tools json-from-wast`), for the `wasm-spec` goldens.
#
# Usage: scripts/wasm_spec_extract.sh [TESTSUITE_DIR] [OUT_DIR]
#
# TESTSUITE_DIR defaults to $WASM_TESTSUITE or `.repos/wasm-testsuite` (a
# checkout of https://github.com/WebAssembly/testsuite, see upstream.sh). The
# top-level `*.wast` files and the proposal directories that wasmi's feature
# set covers (or rejects) are extracted into OUT_DIR/<dir>/<name>.json plus
# OUT_DIR/<dir>/<name>/*.wasm. Files that wasm-tools cannot parse are skipped
# (listed in OUT_DIR/skipped.txt).
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=${1:-${WASM_TESTSUITE:-.repos/wasm-testsuite}}
OUT=${2:-tests/golden/wasm-spec/corpus}
rm -rf "$OUT"
mkdir -p "$OUT"
: > "$OUT/skipped.txt"
extract() {
  local dir=$1 wast=$2
  local name
  name=$(basename "$wast" .wast)
  mkdir -p "$OUT/$dir/$name"
  if ! wasm-tools json-from-wast "$wast" -o "$OUT/$dir/$name.json" \
      --wasm-dir "$OUT/$dir/$name/" 2>/dev/null; then
    echo "$dir/$name" >> "$OUT/skipped.txt"
    rm -rf "$OUT/$dir/$name" "$OUT/$dir/$name.json"
  fi
}
for wast in "$SRC"/*.wast; do
  extract core "$wast"
done
for dir in simd relaxed-simd bulk-memory multi-memory memory64 exceptions gc \
    proposals/wide-arithmetic; do
  [ -d "$SRC/$dir" ] || continue
  for wast in "$SRC/$dir"/*.wast; do
    extract "${dir//\//-}" "$wast"
  done
done
# Our own additions (tests/wasm/*.wast).
for wast in tests/wasm/*.wast; do
  extract extra "$wast"
done
echo "extracted $(find "$OUT" -name '*.json' | wc -l) files," \
  "skipped $(wc -l < "$OUT/skipped.txt")"
