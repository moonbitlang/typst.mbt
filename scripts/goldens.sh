#!/usr/bin/env bash
# Regenerate reference outputs from upstream Typst (needs Rust).
# Usage: scripts/goldens.sh [syntax|ast|eval|html ...]
set -euo pipefail
cd "$(dirname "$0")/.."
# Build from inside oracle/ so that its rust-toolchain.toml applies.
(cd oracle && cargo build --release -q)
ORACLE=oracle/target/release/typst-oracle
SUITE=.repos/typst/tests/suite
stages=("$@")
[ ${#stages[@]} -eq 0 ] && stages=(syntax ast eval html)
for stage in "${stages[@]}"; do
  rm -rf "tests/golden/$stage"
  "$ORACLE" "$stage" "$SUITE" "tests/golden/$stage"
done
