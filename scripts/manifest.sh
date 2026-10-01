#!/usr/bin/env bash
# Regenerate gen/manifest.json (elements, functions, types, scopes, casts)
# from the pinned upstream sources. Diff it after upstream re-syncs to detect
# schema drift.
set -euo pipefail
cd "$(dirname "$0")/.."
# Build from inside oracle/ so that its rust-toolchain.toml applies.
(cd oracle && cargo build --release -q --bin extract)
mkdir -p gen
oracle/target/release/extract .repos/typst/crates > gen/manifest.json
