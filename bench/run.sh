#!/usr/bin/env bash
# Benchmarks the typst.mbt CLI against upstream Typst with hyperfine.
#
# Usage: bench/run.sh [--no-build] [--runs N] [workload...]
#   workloads: startup compile pdf svg png showcase longer (default: all but
#   longer)
#
# Environment:
#   TYPST_MBT  the MoonBit CLI binary (default: the native release build)
#   TYPST_RS   the upstream binary (default: .repos/typst/target/release/typst;
#              skipped if missing; build it with
#              `cargo build --release -p typst-cli` in .repos/typst)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
bench="$root/bench"
mbt="${TYPST_MBT:-$root/_build/native/release/build/moonbitlang/typst/cli/cli.exe}"
rs="${TYPST_RS:-$root/.repos/typst/target/release/typst}"
if [ ! -x "$rs" ] && [ -z "${TYPST_RS:-}" ]; then
  # In a git worktree, `.repos` lives in the main checkout.
  common="$(git -C "$root" rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ]; then
    rs="$(cd "$root" && cd "$common/.." && pwd)/.repos/typst/target/release/typst"
  fi
fi
build=1
runs=10
workloads=()
while [ $# -gt 0 ]; do
  case "$1" in
    --no-build) build=0 ;;
    --runs) runs="$2"; shift ;;
    *) workloads+=("$1") ;;
  esac
  shift
done
[ ${#workloads[@]} -eq 0 ] && workloads=(startup compile pdf svg png showcase)

if [ "$build" = 1 ]; then
  (cd "$root" && moon build cli --target native --release)
fi
command -v hyperfine >/dev/null || { echo "hyperfine not found" >&2; exit 1; }

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
common=(--ignore-system-fonts --root "$bench")

# run <name> <args...>: benchmark both binaries with the same arguments
# (`{out}` is replaced by the output directory).
run() {
  local name="$1"; shift
  local args="${*//\{out\}/$out}"
  local cmds=()
  if [ -x "$rs" ]; then
    cmds+=(-n "rust ($name)" "$rs $args --jobs 1")
  fi
  cmds+=(-n "moonbit ($name)" "$mbt $args")
  hyperfine -N --warmup 2 --runs "$runs" "${cmds[@]}"
}

for w in "${workloads[@]}"; do
  case "$w" in
    startup) run startup compile "${common[*]}" "$bench/tiny.typ" "{out}/tiny.pdf" ;;
    compile) run compile query "${common[*]}" "$bench/long.typ" heading ;;
    pdf) run pdf compile "${common[*]}" "$bench/long.typ" "{out}/long.pdf" ;;
    svg) run svg compile "${common[*]}" "$bench/long.typ" "{out}/long-{p}.svg" ;;
    png) run png compile "${common[*]}" "$bench/long.typ" "{out}/long-{p}.png" ;;
    longer) run longer query "${common[*]}" "$bench/longer.typ" heading ;;
    # The showcase uses system fonts (Geeza Pro, PingFang SC on macOS).
    showcase) run showcase compile --root "$bench" "$bench/showcase.typ" "{out}/showcase.pdf" ;;
    *) echo "unknown workload: $w" >&2; exit 1 ;;
  esac
done
