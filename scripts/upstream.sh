#!/usr/bin/env bash
# Fetch the pinned upstream Typst checkout into .repos/typst.
set -euo pipefail
cd "$(dirname "$0")/.."
REV=$(cat UPSTREAM_REV)
if [ ! -d .repos/typst/.git ]; then
  git clone https://github.com/typst/typst.git .repos/typst
fi
git -C .repos/typst fetch -q origin
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
  curl -sL "https://github.com/harfbuzz/rustybuzz/archive/refs/tags/v$RB_VERSION.tar.gz" \
    | tar xz -C .repos/rustybuzz --strip-components=1
  touch ".repos/rustybuzz/VERSION-$RB_VERSION"
fi
echo "rustybuzz at $RB_VERSION"
