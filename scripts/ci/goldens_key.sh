#!/usr/bin/env bash
# Print the key of the goldens this checkout needs: a hash of everything
# that determines what the Rust oracle writes (the upstream revision, the
# oracle with its lock file and toolchain, the scripts that drive it and the
# extra WebAssembly tests). CI caches `tests/golden` under this key and
# `scripts/ci/goldens.sh` stamps it into `tests/golden/.key`.
set -euo pipefail
cd "$(dirname "$0")/../.."
{
  cat UPSTREAM_REV
  git ls-files -z -- oracle tests/wasm \
    scripts/goldens.sh scripts/upstream.sh scripts/wasm_spec_extract.sh \
    scripts/shape_hb_tests.py scripts/ci/goldens.sh scripts/ci/goldens_key.sh \
    | LC_ALL=C sort -z | xargs -0 shasum -a 256
} | shasum -a 256 | cut -c1-20
