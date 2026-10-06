#!/usr/bin/env bash
# CI: fetch what the tests read besides this repository, without Rust.
#
#   scripts/ci/data.sh
#
# - `.repos/` (scripts/upstream.sh with a shallow upstream checkout): the
#   upstream suite, rustybuzz's and resvg's test suites, the WebAssembly
#   spec tests.
# - The git dependencies of the oracle whose files the runner and the unit
#   tests read, at the revisions of oracle/Cargo.lock: typst-dev-assets,
#   typst-assets and hayro. A development machine has them as cargo
#   checkouts, and the tests look for them there
#   (`~/.cargo/git/checkouts/<name>-*/<rev>`), so they are fetched into that
#   layout (`<name>-ci/<short rev>`).
# - The `target/hayro` and `target/devassets` links of the oracle tests,
#   which are silently skipped without them (see AGENTS.md), and the
#   decompressed CMap bundle of `hayro/cmap/bcmap_test.mbt` (needs the
#   `brotli` command).
#
# Fails if anything the tests would silently skip is missing afterwards.
set -euo pipefail
cd "$(dirname "$0")/../.."

# retry <command ...>: up to three attempts (network hiccups).
retry() {
  local n
  for n in 1 2 3; do
    "$@" && return 0
    echo "data.sh: attempt $n failed: $*" >&2
    sleep $((n * 5))
  done
  return 1
}

export UPSTREAM_SHALLOW=1
retry scripts/upstream.sh

checkouts="$HOME/.cargo/git/checkouts"
# The full revision of a git dependency in oracle/Cargo.lock.
locked_rev() {
  sed -n "s|^source = \"git+https://github.com/$1?rev=[0-9a-f]*#\([0-9a-f]*\)\"\$|\1|p" \
    oracle/Cargo.lock | sort -u
}
# fetch_checkout <name> <owner/repo>: prints the checkout directory.
fetch_checkout() {
  local name=$1 repo=$2 rev dir
  rev=$(locked_rev "$repo")
  [ "$(echo "$rev" | wc -w)" -eq 1 ] || {
    echo "data.sh: expected one locked revision of $repo, got: $rev" >&2
    exit 1
  }
  dir="$checkouts/$name-ci/${rev:0:7}"
  if [ ! -f "$dir/.ci-ok" ]; then
    rm -rf "$dir"
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" remote add origin "https://github.com/$repo.git"
    retry git -C "$dir" fetch -q --depth 1 origin "$rev"
    git -C "$dir" checkout -q FETCH_HEAD
    touch "$dir/.ci-ok"
  fi
  echo "$dir"
}
dev_assets=$(fetch_checkout typst-dev-assets typst/typst-dev-assets)
assets=$(fetch_checkout typst-assets typst/typst-assets)
hayro=$(fetch_checkout hayro LaurenzV/hayro)
echo "typst-dev-assets at $dev_assets"
echo "typst-assets at $assets"
echo "hayro at $hayro"

mkdir -p target
ln -sfn "$hayro" target/hayro
ln -sfn "$dev_assets/files" target/devassets
command -v brotli > /dev/null || {
  echo "data.sh: brotli is not installed (hayro/cmap/bcmap_test.mbt would be skipped)" >&2
  exit 1
}
brotli -d -c target/hayro/hayro-cmap/assets/cmaps.brotli > target/hayro-cmaps.bundle

for f in \
  .repos/typst/tests/suite \
  .repos/typst/tests/ref/render \
  .repos/rustybuzz/tests/fonts \
  .repos/resvg/crates/resvg/tests \
  .repos/wasm-testsuite/proposals/wide-arithmetic/wide-arithmetic.wast \
  target/devassets/images \
  target/devassets/fonts \
  target/devassets/plugins \
  "$assets/files/fonts" \
  target/hayro/hayro-tests/pdfs \
  target/hayro-cmaps.bundle; do
  [ -s "$f" ] || { echo "data.sh: missing $f" >&2; exit 1; }
done
echo "test data ready"
