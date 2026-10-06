#!/usr/bin/env bash
# Fetch the pinned upstream Typst checkout into .repos/typst.
#
# UPSTREAM_SHALLOW=1 (CI) fetches only the pinned commit instead of cloning
# the whole history.
set -euo pipefail
cd "$(dirname "$0")/.."
REV=$(cat UPSTREAM_REV)
if [ "${UPSTREAM_SHALLOW:-}" = 1 ]; then
  if [ ! -d .repos/typst/.git ]; then
    mkdir -p .repos/typst
    git -C .repos/typst init -q
    git -C .repos/typst remote add origin https://github.com/typst/typst.git
  fi
  if ! git -C .repos/typst cat-file -e "$REV^{commit}" 2>/dev/null; then
    git -C .repos/typst fetch -q --depth 1 origin "$REV"
  fi
else
  if [ ! -d .repos/typst/.git ]; then
    git clone https://github.com/typst/typst.git .repos/typst
  fi
  git -C .repos/typst fetch -q origin
fi
git -C .repos/typst checkout -q "$REV"
echo "upstream typst at $(git -C .repos/typst rev-parse --short HEAD)"

# rustybuzz sources and its HarfBuzz-derived test suite (fonts + expected
# outputs) at the version locked by the oracle. The `shape` port follows it,
# the oracle's rustybuzz tap (oracle/rustybuzz-tap) compiles it, and the
# `shape-hb` stage runs its tests.
RB_VERSION=$(grep -A1 '^name = "rustybuzz"' oracle/Cargo.lock | sed -n 's/^version = "\(.*\)"/\1/p')
if [ ! -f ".repos/rustybuzz/VERSION-$RB_VERSION" ]; then
  rm -rf .repos/rustybuzz
  mkdir -p .repos/rustybuzz
  curl -fsSL --retry 3 "https://github.com/harfbuzz/rustybuzz/archive/refs/tags/v$RB_VERSION.tar.gz" \
    | tar xz -C .repos/rustybuzz --strip-components=1
  touch ".repos/rustybuzz/VERSION-$RB_VERSION"
fi
echo "rustybuzz at $RB_VERSION"

# resvg sources and its regression suite (SVG files, fonts, resources and
# reference PNGs) at the version locked by the oracle, for the `resvg` stage.
RESVG_VERSION=$(grep -A1 '^name = "resvg"' oracle/Cargo.lock | sed -n 's/^version = "\(.*\)"/\1/p')
if [ ! -f ".repos/resvg/VERSION-$RESVG_VERSION" ]; then
  rm -rf .repos/resvg
  mkdir -p .repos/resvg
  curl -fsSL --retry 3 "https://github.com/linebender/resvg/archive/refs/tags/v$RESVG_VERSION.tar.gz" \
    | tar xz -C .repos/resvg --strip-components=1
  touch ".repos/resvg/VERSION-$RESVG_VERSION"
fi
echo "resvg at $RESVG_VERSION"

# The WebAssembly spec tests for the `wasm-spec` and `wasm-validate` goldens
# (scripts/wasm_spec_extract.sh): `test/core` of the specification (the
# layout with one directory per merged proposal) plus the wide-arithmetic
# proposal from the test suite mirror. The goldens were extracted from them
# with wasm-tools $WASM_TOOLS_VERSION (`wasm-tools json-from-wast`).
WASM_SPEC_REV=98773554ea57bf039ac3c1e32cfa1f6cc2c13424
WASM_TESTSUITE_REV=b464a4cd100d98175ae6e3890db89a2e6c8302f7
WASM_TOOLS_VERSION=1.243.0
WASM_STAMP=".repos/wasm-testsuite/VERSION-$WASM_SPEC_REV-$WASM_TESTSUITE_REV"
if [ ! -f "$WASM_STAMP" ]; then
  rm -rf .repos/wasm-testsuite
  mkdir -p .repos/wasm-testsuite/proposals/wide-arithmetic
  curl -fsSL --retry 3 "https://github.com/WebAssembly/spec/archive/$WASM_SPEC_REV.tar.gz" \
    | tar xz -C .repos/wasm-testsuite --strip-components=3 "spec-$WASM_SPEC_REV/test/core"
  curl -fsSL --retry 3 "https://raw.githubusercontent.com/WebAssembly/testsuite/$WASM_TESTSUITE_REV/proposals/wide-arithmetic/wide-arithmetic.wast" \
    -o .repos/wasm-testsuite/proposals/wide-arithmetic/wide-arithmetic.wast
  touch "$WASM_STAMP"
fi
echo "wasm spec tests at ${WASM_SPEC_REV:0:8} (extract with wasm-tools $WASM_TOOLS_VERSION)"
