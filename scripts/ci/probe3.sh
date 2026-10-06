#!/usr/bin/env bash
# TEMP (platform probe on the draft PR): the C library's math functions as a
# C program sees them, next to what Rust's std returns in a Rust program.
set -uo pipefail
cd "$(dirname "$0")"
out=${TMPDIR:-/tmp}/probe3
mkdir -p "$out"
cc -O2 -ffp-contract=off probe3.c -o "$out/c" -lm && "$out/c" > "$out/c.txt"
rustc -O probe3.rs -o "$out/rust" && "$out/rust" > "$out/rust.txt"
echo "function, C library (cc), Rust std $(rustc --version):"
paste "$out/c.txt" "$out/rust.txt" | awk '{print "  " $1, $2, $4, ($2 == $4 ? "same" : "DIFFERENT")}'
if [ -d ../../oracle ]; then
  (cd ../../oracle && rustc -O ../scripts/ci/probe3.rs -o "$out/rust-pinned" && "$out/rust-pinned" > "$out/rust-pinned.txt" && echo "pinned $(rustc --version):" \
    && paste "$out/c.txt" "$out/rust-pinned.txt" | awk '{print "  " $1, $2, $4, ($2 == $4 ? "same" : "DIFFERENT")}')
fi
# Which `cbrt` the Rust binary links.
(nm -D "$out/rust" 2> /dev/null | grep -i " cbrt\| fma\| sin$" ; nm "$out/rust" 2> /dev/null | grep -i " cbrt$\| fma$" ) | head
true
