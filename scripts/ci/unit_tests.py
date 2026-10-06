#!/usr/bin/env python3
"""Run the unit tests (`moon test --target native`) and give a verdict.

    scripts/ci/unit_tests.py [--shard I/N] [--jobs J]
    scripts/ci/unit_tests.py --sum DIR --shards N

Every test executable is a whole program, so building the tests of the 106
packages costs far more than running them: CI splits the packages into N
shards (`--shard`), balanced by an estimate of that cost, and one job per
shard builds (`moon test --build-only`) and runs its packages. Without
`--shard` all packages are tested by one `moon test`.

The verdict of a run: `moon test` reports its totals, and exactly the tests
listed in `known_failures/unit.<system>-<machine>.txt` fail (tests that are
bit-exact only on the platform their expectations were made on; none on
aarch64 macOS). A listed test that passes must be removed from the list.

The full output goes to `_build/ci/unit/test.log`, the failures to
`failures.txt`, the totals to `totals.json`; a summary is appended to
`$GITHUB_STEP_SUMMARY`. `--sum` adds up the `totals.json` files of all
shards (downloaded into DIR) and fails if a shard is missing or fewer than
`--min-tests` tests ran in total.
"""

import argparse
import glob
import json
import os
import platform
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MODULE = "moonbitlang/typst"
HOST = f"{platform.system().lower()}-{platform.machine().lower()}"
FAIL_RE = re.compile(r'^\[[^\]]*\] test (\S+?):\d+ \("(.*?)"\) failed')
TOTALS_RE = re.compile(r"^Total tests: (\d+), passed: (\d+), failed: (\d+)\.")
SKIP_DIRS = {"_build", "target", "node_modules"}
# Packages whose tests run long (debug build): seconds on the machine the
# build estimate was calibrated on. Only for balancing the shards.
SLOW = {"hayro/render": 300, "doc/examples/review": 145, "hayro/svg": 106}
# Build seconds per megabyte of whole-program source (same calibration).
BUILD_SECONDS_PER_MB = 0.5


def packages():
    """Package path -> (source bytes, dependencies in this module, test kinds)."""
    out = {}
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = sorted(
            d for d in dirnames if not d.startswith(".") and d not in SKIP_DIRS
        )
        if "moon.pkg" not in filenames and "moon.pkg.json" not in filenames:
            continue
        rel = os.path.relpath(dirpath, ROOT).replace(os.sep, "/")
        if rel == ".":
            continue
        size = 0
        kinds = 1
        blackbox = whitebox = False
        for name in filenames:
            if not name.endswith(".mbt"):
                continue
            if name.endswith("_wbtest.mbt"):
                whitebox = True
            elif name.endswith("_test.mbt"):
                blackbox = True
            else:
                size += os.path.getsize(os.path.join(dirpath, name))
        kinds += blackbox + whitebox
        manifest = "moon.pkg" if "moon.pkg" in filenames else "moon.pkg.json"
        with open(os.path.join(dirpath, manifest), encoding="utf-8") as f:
            deps = set(re.findall(r'"%s/([^"]+)"' % re.escape(MODULE), f.read()))
        out[rel] = (size, deps, kinds)
    return out


def weights(pkgs):
    """An estimate of the seconds a package's tests take to build and run."""
    closures = {}

    def closure(name, stack=()):
        if name in closures:
            return closures[name]
        seen = {name}
        for dep in pkgs[name][1]:
            if dep in pkgs and dep not in stack:
                seen |= closure(dep, stack + (name,))
        closures[name] = seen
        return seen

    out = {}
    for name, (_, _, kinds) in pkgs.items():
        program = sum(pkgs[p][0] for p in closure(name))
        out[name] = program / 1e6 * BUILD_SECONDS_PER_MB * kinds + SLOW.get(name, 0)
    return out


def shard(index, count):
    """The packages of shard `index` (1-based) of `count`: the heaviest
    first, each into the lightest shard so far."""
    pkgs = packages()
    cost = weights(pkgs)
    bins = [[0.0, []] for _ in range(count)]
    for name in sorted(pkgs, key=lambda n: (-cost[n], n)):
        target = min(bins, key=lambda b: b[0])
        target[0] += cost[name]
        target[1].append(name)
    return sorted(bins[index - 1][1]), bins[index - 1][0], sum(cost.values())


def known_failures():
    path = os.path.join(HERE, "known_failures", f"unit.{HOST}.txt")
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as f:
        return {
            line.rstrip("\n")
            for line in f
            if line.strip() and not line.startswith("#")
        }


def moon_test(args, log):
    start = time.time()
    with open(log, "ab") as f:
        code = subprocess.call(
            ["moon", "test"] + args, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT
        )
    return code, time.time() - start


def run(args):
    out_dir = os.path.join(ROOT, "_build/ci/unit")
    os.makedirs(out_dir, exist_ok=True)
    log = os.path.join(out_dir, "test.log")
    open(log, "w").close()
    moon = ["--target", "native"]
    if args.jobs:
        moon += ["-j", str(args.jobs)]
    selected = None
    label = "all packages"
    if args.shard:
        index, count = (int(x) for x in args.shard.split("/"))
        selected, cost, total = shard(index, count)
        label = f"shard {index}/{count}"
        print(
            f"{label}: {len(selected)} packages, estimated {cost:.0f} of {total:.0f}"
            " cost units"
        )
        print(" ".join(selected))
        for name in selected:
            moon += ["-p", f"{MODULE}/{name}"]

    build_code, build_seconds = moon_test(moon + ["--build-only"], log)
    print(f"build: exit {build_code} after {build_seconds:.0f} s", flush=True)
    code, run_seconds = moon_test(moon, log)
    print(f"run: exit {code} after {run_seconds:.0f} s", flush=True)

    failed_tests = []
    failures = []
    totals = None
    show = False
    with open(log, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = FAIL_RE.match(line)
            if m:
                failed_tests.append(f'{m[1]} ("{m[2]}")')
                failures.append(line.rstrip("\n")[:2000])
                show = 12
                continue
            t = TOTALS_RE.match(line)
            if t:
                totals = tuple(int(x) for x in t.groups())
                show = 0
            elif show:
                failures.append("    " + line.rstrip("\n")[:400])
                show -= 1
    with open(os.path.join(out_dir, "failures.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(failures) + ("\n" if failures else ""))

    known = known_failures()
    if selected is not None:
        # Only the listed tests whose package is in this shard.
        dirs = set(selected)
        known = {k for k in known if os.path.dirname(k.split(" ")[0]) in dirs}
    unexpected = [t for t in failed_tests if t not in known]
    fixed = sorted(known - set(failed_tests))
    problems = []
    if totals is None:
        problems.append("moon test did not report its totals (a build error?)")
    else:
        if totals[2] != len(failed_tests):
            problems.append(
                f"{totals[2]} tests failed, but {len(failed_tests)} failures were"
                " recognized in the output"
            )
        if totals[0] == 0:
            problems.append("no test ran")
    if code != 0 and not failed_tests:
        problems.append(f"moon test exited with {code}")
    if code == 0 and failed_tests:
        problems.append("moon test exited with 0 although tests failed")
    if unexpected:
        problems.append(f"{len(unexpected)} failing tests")
    if fixed:
        problems.append(
            f"{len(fixed)} known failures pass now: remove them from"
            f" scripts/ci/known_failures/unit.{HOST}.txt ({'; '.join(fixed[:5])})"
        )

    result = {
        "host": HOST,
        "shard": args.shard or "1/1",
        "total": totals[0] if totals else 0,
        "passed": totals[1] if totals else 0,
        "failed": totals[2] if totals else 0,
        "known_failures": len(failed_tests) - len(unexpected),
        "build_seconds": round(build_seconds),
        "run_seconds": round(run_seconds),
        "ok": not problems,
    }
    with open(os.path.join(out_dir, "totals.json"), "w", encoding="utf-8") as f:
        json.dump(result, f)

    totals_text = (
        f"{result['total']} tests, {result['passed']} passed, {result['failed']} failed"
        if totals
        else "no totals"
    )
    if result["known_failures"]:
        totals_text += f" ({result['known_failures']} known for {HOST})"
    timing = f"build {build_seconds:.0f} s, run {run_seconds:.0f} s"
    print(f"{label} on {HOST}: {totals_text}; {timing}")
    md = [f"### Unit tests, {label} on {HOST}", ""]
    if problems:
        md += [f"**FAILED**: {totals_text}; {timing}", ""]
        md += [f"- {p}" for p in problems]
        shown = [f for f in failures if not f.startswith("    ")]
        detail = failures[:80] if unexpected else []
        if not failed_tests:
            with open(log, encoding="utf-8", errors="replace") as f:
                detail = [line.rstrip("\n")[:300] for line in f.readlines()[-40:]]
        if detail:
            md += ["", "```"] + detail + ["```"]
        for p in problems:
            print(f"::error title=unit tests ({label})::{p}")
        for line in (shown if unexpected else detail)[:40]:
            print(line[:600])
    else:
        md += [f"ok: {totals_text}; {timing}"]
    md.append("")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("\n".join(md))
    sys.exit(1 if problems else 0)


def total(args):
    """Add up the shards' totals per host."""
    hosts = {}
    for path in sorted(glob.glob(os.path.join(args.sum, "**/totals.json"), recursive=True)):
        with open(path, encoding="utf-8") as f:
            r = json.load(f)
        hosts.setdefault(r["host"], []).append(r)
    md = ["### Unit tests", "", "| Platform | Shards | Tests | Passed | Failed | Known failures | Result |", "|---|---:|---:|---:|---:|---:|---|"]
    bad = []
    if not hosts:
        bad.append("no totals found")
    for host, rs in sorted(hosts.items()):
        shards = sorted(r["shard"] for r in rs)
        tests = sum(r["total"] for r in rs)
        problems = []
        if shards != [f"{i}/{args.shards}" for i in range(1, args.shards + 1)]:
            problems.append(f"shards {', '.join(shards)} of {args.shards}")
        if tests < args.min_tests:
            problems.append(f"{tests} tests ran, expected at least {args.min_tests}")
        if not all(r["ok"] for r in rs):
            problems.append("a shard failed")
        md.append(
            f"| {host} | {len(rs)}/{args.shards} | {tests} | {sum(r['passed'] for r in rs)}"
            f" | {sum(r['failed'] for r in rs)} | {sum(r['known_failures'] for r in rs)}"
            f" | {'ok' if not problems else '**FAILED**: ' + '; '.join(problems)} |"
        )
        print(f"{host}: {tests} tests in {len(rs)} shards" + (": " + "; ".join(problems) if problems else ""))
        bad += [f"{host}: {p}" for p in problems]
    md.append("")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("\n".join(md))
    for b in bad:
        print(f"::error title=unit tests::{b}")
    sys.exit(1 if bad else 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--shard", help="I/N: test the packages of shard I of N")
    ap.add_argument("--jobs", type=int, help="moon's -j")
    ap.add_argument("--list", action="store_true", help="print the shard and stop")
    ap.add_argument("--sum", metavar="DIR", help="add up totals.json files below DIR")
    ap.add_argument("--shards", type=int, default=1, help="with --sum: the number of shards")
    ap.add_argument(
        "--min-tests",
        type=int,
        default=5600,
        help="with --sum: the least number of tests that must have run (the"
        " suite has 5631; raise it when it falls far behind)",
    )
    args = ap.parse_args()
    if args.sum:
        total(args)
    elif args.list:
        index, count = (int(x) for x in (args.shard or "1/1").split("/"))
        for i in range(1, count + 1) if not args.shard else [index]:
            names, cost, _ = shard(i, count)
            print(f"shard {i}/{count}: {cost:.0f} cost units, {len(names)} packages: {' '.join(names)}")
    else:
        run(args)


if __name__ == "__main__":
    main()
