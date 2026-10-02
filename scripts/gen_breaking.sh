#!/usr/bin/env bash
# Regenerate the data tables of the `bidi`, `linebreak`, `hypher` packages
# and `unicode/word_tables_gen.mbt` from the locked Rust crates (needs Rust
# and the crates in the cargo registry, e.g. after `scripts/goldens.sh`).
set -euo pipefail
cd "$(dirname "$0")/.."
REGISTRY=$(ls -d "${CARGO_HOME:-$HOME/.cargo}"/registry/src/index.crates.io-* | head -1)
(cd oracle && cargo build --release -q --bin gen_breaking)
oracle/target/release/gen_breaking "$REGISTRY" "$PWD"
