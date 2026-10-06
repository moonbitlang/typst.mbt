#!/usr/bin/env python3
"""Run differential stages of tests/runner and fail on any regression.

    scripts/ci/stages.py [options] [stage ...]

The runner prints `<label>: N passed, M failed` and always exits with 0, and
a stage whose inputs are missing reports `0 passed, 0 failed`. This script
turns that into a verdict. A stage is good if

- the runner exits with 0 and prints the summary lines of the stage, each
  once, and no other,
- passed + failed + skipped is the number of cases in `stages.tsv` and
  skipped is the number given there (so a suite that silently shrinks, and
  goldens or inputs that are missing, fail),
- exactly the cases listed in `known_failures/<stage>.txt` fail (the replay
  stages are not at parity; a listed case that passes must be removed, so
  that it cannot regress unnoticed later), and
- at least as many outputs as `stages.tsv` says are byte-identical before
  canonicalization (raw hash parity), where the stage reports that.

Without stage arguments every stage of `stages.tsv` is run. Per stage the
output goes to `<out>/<stage>.log` (with `--verbose`, i.e. the first
difference of every failing case); failing stages are run again with
`--dump` and the failing cases' sections are diffed against the goldens
into `<out>/diffs/`. A Markdown table is appended to `$GITHUB_STEP_SUMMARY`
(or `--summary`).

`--check-key` also requires the goldens to be the ones generated for this
checkout (`scripts/ci/goldens_verify.sh`).
"""

import argparse
import concurrent.futures
import difflib
import os
import platform
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SUMMARY_RE = re.compile(
    r"^(?P<label>[A-Za-z][A-Za-z -]*): (?P<passed>\d+) passed, (?P<failed>\d+) failed"
    r"(?:, (?P<skipped>\d+) skipped)?"
)
IDENTICAL_RE = re.compile(
    r"^(?P<label>[A-Za-z][A-Za-z -]*): (?P<n>\d+) byte-identical before canonicalization"
)
# Where a stage's goldens and `--dump` output live if not under its own name.
GOLDEN_DIR = {"svg-replay": "svg", "pdf-semantic-replay": "pdf-semantic"}
MAX_DIFF_LINES = 400
MAX_DIFF_CASES = 200


def read_table():
    """stage -> [(label, cases, skipped, least byte-identical or None)]."""
    system = platform.system().lower()
    table = {}
    with open(os.path.join(HERE, "stages.tsv"), encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            stage, label, total, skips, identical = line.split("\t")
            # `<number>` or `<number> <system>=<number> ...`.
            skips = skips.split()
            skipped = int(skips[0])
            for alt in skips[1:]:
                name, _, n = alt.partition("=")
                if name == system:
                    skipped = int(n)
            identical = None if identical == "-" else int(identical)
            table.setdefault(stage, []).append((label, int(total), skipped, identical))
    return table


def known_failures(stage):
    """The `FAIL` lines a stage may print, for this platform."""
    host = f"{platform.system().lower()}-{platform.machine().lower()}"
    known = set()
    for name in (f"{stage}.txt", f"{stage}.{host}.txt"):
        path = os.path.join(HERE, "known_failures", name)
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                known.update(
                    line.rstrip("\n")
                    for line in f
                    if line.strip() and not line.startswith("#")
                )
    return known


class Result:
    def __init__(self, stage):
        self.stage = stage
        self.rows = []  # (label, passed, failed, skipped, total)
        self.problems = []
        self.fails = []  # unexpected `FAIL` lines
        self.known = 0  # known failures that failed
        self.fixed = []  # known failures that passed
        self.seconds = 0.0
        self.notes = []

    @property
    def ok(self):
        return not self.problems


def run_stage(runner, stage, expect, out_dir):
    res = Result(stage)
    log = os.path.join(out_dir, f"{stage}.log")
    start = time.time()
    with open(log, "wb") as f:
        code = subprocess.call(
            [runner, stage, "--verbose"], cwd=ROOT, stdout=f, stderr=subprocess.STDOUT
        )
    res.seconds = time.time() - start
    with open(log, encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    if code != 0:
        res.problems.append(f"the runner exited with {code}")
    seen = {}
    identical = {}
    fail_lines = []
    labels = {label for label, _, _, _ in expect}
    for line in lines:
        if line.startswith("FAIL "):
            fail_lines.append(line)
            continue
        m = SUMMARY_RE.match(line)
        if m:
            seen.setdefault(m["label"], []).append(m)
            continue
        # Notes of the stage, or of one of its labels (`packages svg: ...`).
        m = IDENTICAL_RE.match(line)
        if m and m["label"] in labels:
            identical[m["label"]] = int(m["n"])
        if line.startswith(stage + ": "):
            res.notes.append(line[len(stage) + 2 :])
        elif m and m["label"] in labels:
            res.notes.append(line[len(stage) + 1 :])
    for label in seen:
        if label not in labels:
            res.problems.append(f"unexpected summary line `{label}: ...`")
    for label, total, skips, least in expect:
        if least is not None and identical.get(label, -1) < least:
            res.problems.append(
                f"{label}: {identical.get(label, 'no')} byte-identical before"
                f" canonicalization, expected at least {least}"
            )
        found = seen.get(label, [])
        if len(found) != 1:
            res.problems.append(
                f"expected one `{label}: N passed, M failed` line, got {len(found)}"
            )
            continue
        m = found[0]
        passed, failed = int(m["passed"]), int(m["failed"])
        skipped = int(m["skipped"] or 0)
        res.rows.append((label, passed, failed, skipped, total))
        if passed + failed + skipped != total:
            res.problems.append(
                f"{label}: {passed + failed + skipped} cases, expected {total}"
                " (missing inputs or goldens? if the suite changed, update"
                " scripts/ci/stages.tsv)"
            )
        if skipped != skips:
            res.problems.append(
                f"{label}: {skipped} cases skipped, expected {skips} (missing inputs?)"
            )
    known = known_failures(stage)
    res.fails = [line for line in fail_lines if line not in known]
    res.known = len(fail_lines) - len(res.fails)
    res.fixed = sorted(known - set(fail_lines))
    failed_total = sum(row[2] for row in res.rows)
    if res.fixed:
        # Keep the allowance tight: a case that passes again must not be
        # allowed to regress unnoticed later.
        res.problems.append(
            f"{len(res.fixed)} known failures pass now: remove them from"
            f" scripts/ci/known_failures/ ({', '.join(x[5:] for x in res.fixed[:5])}"
            + (", ..." if len(res.fixed) > 5 else "")
            + ")"
        )
    if res.fails:
        res.problems.append(f"{len(res.fails)} failing cases")
    elif failed_total != res.known:
        # Failures are counted, but not all of them are listed (or the
        # reverse): never accept a count that the `FAIL` lines do not explain.
        res.problems.append(
            f"{failed_total} failed cases, but {res.known} known `FAIL` lines"
        )
    return res


def sections(path):
    """`=== name` sections of a golden or dump file."""
    out = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return out
    name = None
    buf = []
    for line in text.split("\n"):
        if line.startswith("=== "):
            if name is not None:
                out[name] = buf
            name, buf = line[4:], []
        else:
            buf.append(line)
    if name is not None:
        out[name] = buf
    return out


def write_diffs(runner, res, out_dir):
    """Rerun a failing stage with `--dump` and diff its failing cases."""
    stage = res.stage
    with open(os.devnull, "wb") as null:
        subprocess.call(
            [runner, stage, "--dump"], cwd=ROOT, stdout=null, stderr=subprocess.STDOUT
        )
    golden = os.path.join(ROOT, "tests/golden", GOLDEN_DIR.get(stage, stage))
    actual = os.path.join(ROOT, "_build/actual", stage)
    written = 0
    for line in res.fails[:MAX_DIFF_CASES]:
        m = re.match(r"^FAIL (\S+) :: (.*)$", line)
        if m:
            rel, name = m[1], m[2]
            base = rel[:-4] if rel.endswith(".typ") else rel[: -len(".txt")]
            want = sections(os.path.join(golden, base + ".txt")).get(name)
            got = sections(os.path.join(actual, base + ".txt")).get(name)
        else:
            m = re.match(r"^FAIL font (\S+)", line)
            if not m:
                continue
            base = name = m[1]

            def whole(path):
                try:
                    with open(path, encoding="utf-8", errors="replace") as f:
                        return f.read().split("\n")
                except OSError:
                    return None

            want = whole(os.path.join(golden, base + ".txt"))
            got = whole(os.path.join(actual, base + ".txt"))
        if got is None:
            continue
        diff = list(
            difflib.unified_diff(
                want or ["<missing golden>"],
                got,
                "golden/" + base + " :: " + name,
                "actual/" + base + " :: " + name,
                lineterm="",
                n=3,
            )
        )
        if len(diff) > MAX_DIFF_LINES:
            more = len(diff) - MAX_DIFF_LINES
            diff = diff[:MAX_DIFF_LINES] + [f"... ({more} more lines)"]
        safe = re.sub(r"[^A-Za-z0-9._-]+", "_", name)[:120]
        path = os.path.join(out_dir, "diffs", stage, base, safe + ".diff")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(diff) + "\n")
        written += 1
    return written


def check_goldens():
    """The goldens must be the ones generated for this checkout."""
    proc = subprocess.run(
        [os.path.join(HERE, "goldens_verify.sh")],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if proc.returncode == 0:
        return None
    lines = proc.stdout.strip().split("\n")
    return lines[-1] if lines else "goldens_verify.sh failed"


def main():
    table = read_table()
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument(
        "--runner",
        default="_build/native/release/build/tests/runner/runner.exe",
        help="the built runner (default: the native release build)",
    )
    ap.add_argument("--out", default="_build/ci/stages")
    ap.add_argument("--summary", default=os.environ.get("GITHUB_STEP_SUMMARY"))
    ap.add_argument("--title", default="Differential stages")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    ap.add_argument("--check-key", action="store_true")
    ap.add_argument("stages", nargs="*")
    args = ap.parse_args()
    stages = args.stages or list(table)
    for stage in stages:
        if stage not in table:
            sys.exit(f"stages.py: no expectations for the stage `{stage}` in stages.tsv")
    runner = os.path.join(ROOT, args.runner)
    if not os.path.exists(runner):
        sys.exit(f"stages.py: {args.runner} does not exist; build the runner first")
    out_dir = os.path.join(ROOT, args.out)
    os.makedirs(out_dir, exist_ok=True)

    key_problem = check_goldens() if args.check_key else None
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        futures = [
            pool.submit(run_stage, runner, stage, table[stage], out_dir)
            for stage in stages
        ]
        results = [f.result() for f in futures]

    md = [f"### {args.title}", ""]
    if key_problem:
        md += [f"**{key_problem}**", ""]
    md += [
        "| Stage | Passed | Failed | Skipped | Cases | Time | Result |",
        "|---|---:|---:|---:|---:|---:|---|",
    ]
    details = []
    notes = []
    for res in results:
        verdict = "ok" if res.ok else "**FAILED**"
        if res.known:
            verdict += f" ({res.known} known failures)"
        rows = res.rows or [(res.stage, "?", "?", "?", "?")]
        for i, (label, passed, failed, skipped, total) in enumerate(rows):
            md.append(
                f"| {label} | {passed} | {failed} | {skipped} | {total} | "
                + (f"{res.seconds:.1f} s | {verdict} |" if i == 0 else "| |")
            )
        line = f"{res.stage}: " + ", ".join(
            f"{label}: {passed} passed, {failed} failed"
            + (f", {skipped} skipped" if skipped else "")
            for label, passed, failed, skipped, _ in res.rows
        )
        print(f"{'ok  ' if res.ok else 'FAIL'} {line} ({res.seconds:.1f} s)")
        for note in res.notes:
            print(f"       {note}")
            notes.append(f"- `{res.stage}`: {note}")
        if res.ok:
            continue
        diffs = write_diffs(runner, res, out_dir) if res.fails else 0
        for problem in res.problems:
            print(f"::error title=stage {res.stage}::{problem}")
            details.append(f"- `{res.stage}`: {problem}")
        for fail in res.fails[:20]:
            print(f"       {fail}")
            details.append(f"  - `{fail}`")
        if len(res.fails) > 20:
            details.append(f"  - ... and {len(res.fails) - 20} more")
        if diffs:
            details.append(
                f"  - {diffs} diffs in the artifact (`diffs/{res.stage}/`);"
                f" first differences in `{res.stage}.log`"
            )
    if details:
        md += [""] + details
    if notes:
        md += ["", "<details><summary>Notes</summary>", ""] + notes + ["", "</details>"]
    md.append("")
    text = "\n".join(md)
    with open(os.path.join(out_dir, "summary.md"), "w", encoding="utf-8") as f:
        f.write(text)
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as f:
            f.write(text)
    if key_problem:
        print(f"::error title=goldens::{key_problem}")
    bad = [res.stage for res in results if not res.ok]
    if bad or key_problem:
        print(f"stages.py: FAILED: {' '.join(bad) or 'goldens'}")
        sys.exit(1)
    print(f"stages.py: {len(results)} stages ok")


if __name__ == "__main__":
    main()
