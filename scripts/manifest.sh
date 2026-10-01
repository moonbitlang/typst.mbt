#!/usr/bin/env bash
# Regenerate gen/manifest.json (elements, functions, types, scopes, casts)
# from the pinned upstream sources. Diff it after upstream re-syncs to detect
# schema drift.
set -euo pipefail
cd "$(dirname "$0")/.."
cargo build --release -q --manifest-path oracle/Cargo.toml --bin extract
mkdir -p gen
oracle/target/release/extract .repos/typst/crates > gen/manifest.json
