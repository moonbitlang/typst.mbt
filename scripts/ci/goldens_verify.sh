#!/usr/bin/env bash
# CI: check that `tests/golden` is what scripts/ci/goldens.sh generates for
# this checkout:
#
# - its key (`tests/golden/.key`) is the one of scripts/ci/goldens_key.sh
#   (stale goldens fail loudly), and
# - the oracle tests that the oracle regenerates in the tree
#   (`usvg/oracle_test.mbt`, `resvg/oracle_test.mbt`) are the committed
#   ones, by the checksums recorded when the goldens were generated (this
#   also holds a change of those files to the oracle when the goldens come
#   from a cache).
#
# The last line of output is the verdict.
set -uo pipefail
cd "$(dirname "$0")/../.."
want=$(scripts/ci/goldens_key.sh) || exit 1
have=$(head -1 tests/golden/.key 2> /dev/null)
if [ -z "$have" ]; then
  echo "tests/golden/.key is missing (this checkout needs the goldens with key $want)"
  exit 1
fi
if [ "$have" != "$want" ]; then
  echo "stale goldens: their key is $have, this checkout needs $want"
  exit 1
fi
if ! shasum -a 256 -c tests/golden/.generated.sha256; then
  echo "usvg/oracle_test.mbt or resvg/oracle_test.mbt is not what the oracle generates (scripts/goldens.sh usvg resvg)"
  exit 1
fi
echo "goldens ok: key $have"
