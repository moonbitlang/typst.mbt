#!/usr/bin/env bash
# CI: regenerate every golden of `tests/golden` with the Rust oracle, from a
# clean checkout.
#
#   scripts/ci/goldens.sh
#
# Needs Rust (the toolchain of oracle/rust-toolchain.toml), moon (the `usvg`
# and `resvg` stages format the oracle tests they regenerate) and python3.
# Fetches the rest: the upstream sources (scripts/upstream.sh), the Unicode
# bidi conformance files of the `break` stage and the pinned wasm-tools of
# the `wasm-spec` stage (into `.repos/`).
#
# Afterwards `tests/golden/.key` holds scripts/ci/goldens_key.sh's key, and
# the oracle tests that the stages regenerate in the tree
# (`usvg/oracle_test.mbt`, `resvg/oracle_test.mbt`) must be the committed
# ones: the goldens are reproducible, or this script fails.
set -euo pipefail
cd "$(dirname "$0")/../.."

UPSTREAM_SHALLOW=${UPSTREAM_SHALLOW:-1} scripts/upstream.sh

# The Unicode bidi conformance files (the version of `bidi/`).
UNICODE_VERSION=16.0.0
bidi=".repos/unicode-$UNICODE_VERSION"
mkdir -p "$bidi"
for f in BidiTest.txt BidiCharacterTest.txt; do
  [ -s "$bidi/$f" ] || curl -fsSL --retry 3 \
    "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/$f" -o "$bidi/$f"
done
export BIDI_TEST_DATA="$PWD/$bidi"

# wasm-tools at the version the wasm goldens are made with.
WASM_TOOLS_VERSION=$(sed -n 's/^WASM_TOOLS_VERSION=//p' scripts/upstream.sh)
if [ "$(wasm-tools --version 2> /dev/null | awk '{print $2}')" != "$WASM_TOOLS_VERSION" ]; then
  case "$(uname -sm)" in
    "Darwin arm64") triple=aarch64-macos ;;
    "Darwin x86_64") triple=x86_64-macos ;;
    "Linux x86_64") triple=x86_64-linux ;;
    "Linux aarch64") triple=aarch64-linux ;;
    *) echo "goldens.sh: no wasm-tools binary for $(uname -sm)" >&2; exit 1 ;;
  esac
  tools=".repos/wasm-tools-$WASM_TOOLS_VERSION-$triple"
  if [ ! -x "$tools/wasm-tools" ]; then
    rm -rf "$tools"
    mkdir -p "$tools"
    curl -fsSL --retry 3 "https://github.com/bytecodealliance/wasm-tools/releases/download/v$WASM_TOOLS_VERSION/wasm-tools-$WASM_TOOLS_VERSION-$triple.tar.gz" \
      | tar xz -C "$tools" --strip-components=1
  fi
  PATH="$PWD/$tools:$PATH"
fi
echo "wasm-tools $(wasm-tools --version)"

rm -rf tests/golden
mkdir -p tests/golden
# The default stages, then the WebAssembly ones (`wasm-validate` reads the
# corpus that `wasm-spec` extracts).
scripts/goldens.sh
scripts/goldens.sh wasm-spec wasm-validate

if ! git diff --exit-code --stat -- usvg/oracle_test.mbt resvg/oracle_test.mbt; then
  echo "goldens.sh: the regenerated oracle tests differ from the committed ones" >&2
  exit 1
fi
{
  scripts/ci/goldens_key.sh
  echo "upstream $(cat UPSTREAM_REV)"
  echo "host $(uname -sm)"
  rustc --version
} > tests/golden/.key
echo "goldens: $(du -sh tests/golden | cut -f1), key $(head -1 tests/golden/.key)"
