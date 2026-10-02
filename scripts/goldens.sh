#!/usr/bin/env bash
# Regenerate reference outputs from upstream Typst (needs Rust).
# Usage: scripts/goldens.sh [syntax|ast|eval|html|realize|break ...]
#
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
[ ${#stages[@]} -eq 0 ] && stages=(syntax ast eval html realize break)
for stage in "${stages[@]}"; do
  rm -rf "tests/golden/$stage"
  "$ORACLE" "$stage" "$SUITE" "tests/golden/$stage"
done
