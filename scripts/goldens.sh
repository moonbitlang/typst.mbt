#!/usr/bin/env bash
# Regenerate reference outputs from upstream Typst (needs Rust).
# Usage: scripts/goldens.sh [syntax|ast|reparse|eval|html|realize|fonts|font|paged|svg|shape|shape-hb|break ...]
#
# `reparse` applies seeded pseudo-random edits to every test body through
# `Source::edit`/`Source::replace` and dumps the reparsed ranges and trees
# (oracle/src/reparse.rs).
# `fonts` writes the font manifest of the test world (tests/golden/fonts.json);
# `font` dumps what ttf-parser reports for every face (oracle/src/font.rs);
# `paged` dumps every paged test in the `typst-frame-v1` format (see
# oracle/src/paged.rs); `svg` dumps the raw upstream SVG of every paged test
# (pretty, merged pages, 1pt gap; see oracle/src/svg.rs).
# `shape` dumps every text run Typst shapes while
# compiling the paged tests, with rustybuzz's output (oracle/src/shape.rs);
# `shape-hb` extracts rustybuzz's own shaping test suite.
# The `break` stage additionally dumps the Unicode bidi conformance files
# (BidiTest.txt, BidiCharacterTest.txt, Unicode 16.0) if BIDI_TEST_DATA
# names a directory containing them.
set -euo pipefail
cd "$(dirname "$0")/.."
# Build from inside oracle/ so that its rust-toolchain.toml applies.
(cd oracle && cargo build --release -q)
ORACLE=oracle/target/release/typst-oracle
SUITE=.repos/typst/tests/suite
stages=("$@")
[ ${#stages[@]} -eq 0 ] && stages=(syntax ast reparse eval html realize fonts font paged svg shape shape-hb break)
for stage in "${stages[@]}"; do
  if [ "$stage" = shape-hb ]; then
    # rustybuzz's own shaping tests (needs .repos/rustybuzz, see upstream.sh).
    rm -rf tests/golden/shape-hb
    python3 scripts/shape_hb_tests.py .repos/rustybuzz tests/golden/shape-hb
    continue
  fi
  if [ "$stage" = fonts ]; then
    "$ORACLE" fonts tests/golden/fonts.json
    continue
  fi
  rm -rf "tests/golden/$stage"
  "$ORACLE" "$stage" "$SUITE" "tests/golden/$stage"
done
