#!/usr/bin/env bash
# Regenerate reference outputs from upstream Typst (needs Rust).
# Usage: scripts/goldens.sh [syntax|ast|eval|html|realize|fonts|paged ...]
#
# `fonts` writes the font manifest of the test world (tests/golden/fonts.json);
# `paged` dumps every paged test in the `typst-frame-v1` format (see
# oracle/src/paged.rs).
set -euo pipefail
cd "$(dirname "$0")/.."
# Build from inside oracle/ so that its rust-toolchain.toml applies.
(cd oracle && cargo build --release -q)
ORACLE=oracle/target/release/typst-oracle
SUITE=.repos/typst/tests/suite
stages=("$@")
[ ${#stages[@]} -eq 0 ] && stages=(syntax ast eval html realize fonts paged)
for stage in "${stages[@]}"; do
  if [ "$stage" = fonts ]; then
    "$ORACLE" fonts tests/golden/fonts.json
    continue
  fi
  rm -rf "tests/golden/$stage"
  "$ORACLE" "$stage" "$SUITE" "tests/golden/$stage"
done
