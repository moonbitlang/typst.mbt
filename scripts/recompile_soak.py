#!/usr/bin/env python3
"""Soak run of the `recompile` stage (tests/recompile/README.md).

    scripts/recompile_soak.py [--minutes M] [--jobs N] [--seed S] [--all]
                              [--sequences K] [--steps T] [--only NAME]
                              [--match TEXT] [--runner PATH]

Runs the stage document by document (all of them, those named with `--only`
or those whose names contain TEXT; `--all` as for the stage) with the seeds
S, S+1, ... until M minutes have passed (the runs in flight are finished), N
at a time. Each run
is one process (`recompile --only=<document> --seed=<seed> ...`), because an
edit can make the compiler abort where upstream panics, and the runner with
it; such a run is repeated with `--fresh`, which compiles every step in a
fresh world and compares nothing:

- it aborts again: the abort is not about compiling again (the files that
  cause it are a document like any other; whether upstream panics on it too
  is checked by hand),
- it does not: the compiler aborted only because it had compiled before,
  which is a failure.

The clock only decides when to stop: what a seed does is a function of the
seed. The report says which seeds were run completely, so that a failure is
reproduced with

    moon run tests/runner --target native --release -- recompile \\
        --only=<document> --seed=<seed> --sequences=K --steps=T -v

Logs of the runs that failed or aborted are in `_build/recompile/soak/`.
"""

import argparse
import concurrent.futures
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATS = re.compile(
    r"^recompile: (\d+) documents, (\d+) sequences, (\d+) steps, (\d+) compilations"
)
SUMMARY = re.compile(r"^recompile(?: packages)?: (\d+) passed, (\d+) failed")


def run(runner, document, seed, extra, fresh=False):
    """One run: (kind, output). `kind` is pass, fail or abort."""
    command = [runner, "recompile", f"--only={document}", f"--seed={seed}", "-v", "--trace"]
    command += extra
    if fresh:
        command.append("--fresh")
    proc = subprocess.run(
        command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    out = proc.stdout.decode("utf-8", "replace")
    lines = out.split("\n")
    done = any(STATS.match(line) for line in lines)
    if proc.returncode != 0 or not done:
        return "abort", out
    if any(line.startswith("FAIL ") for line in lines):
        return "fail", out
    return "pass", out


def task(runner, document, seed, extra):
    kind, out = run(runner, document, seed, extra)
    fresh = None
    if kind == "abort":
        fresh, fresh_out = run(runner, document, seed, extra, fresh=True)
        out += "\n--- with --fresh ---\n" + fresh_out
    return document, seed, kind, fresh, out


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--minutes", type=float, default=60.0)
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) // 2))
    parser.add_argument("--seed", type=int, default=1000)
    parser.add_argument("--sequences", type=int, default=4)
    parser.add_argument("--steps", type=int, default=12)
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--only", action="append", default=[])
    parser.add_argument("--match", default="")
    parser.add_argument(
        "--runner",
        default=os.path.join(
            ROOT, "_build/native/release/build/tests/runner/runner.exe"
        ),
    )
    args = parser.parse_args()
    if not os.path.exists(args.runner):
        sys.exit(
            f"{args.runner} is missing: moon build --target native --release tests/runner"
        )
    extra = [f"--sequences={args.sequences}", f"--steps={args.steps}"]
    if args.all:
        extra.append("--all")
    names = subprocess.run(
        [args.runner, "recompile", "--names"] + (["--all"] if args.all else []),
        cwd=ROOT,
        stdout=subprocess.PIPE,
        check=True,
    ).stdout.decode().split("\n")
    documents = [n for n in names if n and not n.startswith("recompile:")]
    if args.only:
        documents = [d for d in documents if d in args.only]
    documents = [d for d in documents if args.match in d]
    if not documents:
        sys.exit("no documents")
    out_dir = os.path.join(ROOT, "_build/recompile/soak")
    os.makedirs(out_dir, exist_ok=True)

    start = time.monotonic()
    deadline = start + args.minutes * 60.0
    totals = {"runs": 0, "sequences": 0, "steps": 0, "compilations": 0}
    failures = []
    aborts = []
    seeds_done = 0
    seed = args.seed
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        while time.monotonic() < deadline:
            futures = [
                pool.submit(task, args.runner, document, seed, extra)
                for document in documents
            ]
            for future in concurrent.futures.as_completed(futures):
                document, s, kind, fresh, out = future.result()
                totals["runs"] += 1
                primary = out.split("\n--- with --fresh ---")[0]
                for line in primary.split("\n"):
                    m = STATS.match(line)
                    if m:
                        totals["sequences"] += int(m.group(2))
                        totals["steps"] += int(m.group(3))
                        totals["compilations"] += int(m.group(4))
                if kind == "pass":
                    continue
                log = os.path.join(
                    out_dir, f"seed{s}-{document.replace('/', '_')}.log"
                )
                with open(log, "w", encoding="utf-8") as f:
                    f.write(out)
                if kind == "fail":
                    for line in out.split("\n"):
                        if line.startswith("FAIL "):
                            failures.append(line)
                            print(line, flush=True)
                else:
                    last = [l for l in primary.split("\n") if l.startswith("TRACE")]
                    where = " / ".join(l[6:].strip() for l in last[-2:])
                    verdict = (
                        "aborts in a fresh world too"
                        if fresh == "abort"
                        else "ABORTS ONLY WHEN COMPILED AGAIN"
                    )
                    message = f"ABORT {document} seed={s}: {verdict} ({where})"
                    aborts.append((fresh, message))
                    print(message, flush=True)
            seeds_done += 1
            seed += 1
            elapsed = (time.monotonic() - start) / 60.0
            print(
                f"seed {seed - 1} done after {elapsed:.1f} min: "
                f"{totals['steps']} steps, {len(failures)} failures, {len(aborts)} aborts",
                flush=True,
            )
    elapsed = (time.monotonic() - start) / 60.0
    print()
    print(
        f"soak: {len(documents)} documents, seeds {args.seed}..{seed - 1} "
        f"({seeds_done} complete), {args.sequences} random sequences of "
        f"{args.steps} edits and the sweep each, {elapsed:.1f} minutes with {args.jobs} jobs"
    )
    print(
        f"soak: {totals['runs']} runs, {totals['sequences']} sequences, "
        f"{totals['steps']} steps, {totals['compilations']} compilations"
    )
    recompilation = [m for fresh, m in aborts if fresh != "abort"]
    print(
        f"soak: {len(failures)} failures, {len(aborts)} aborts "
        f"({len(recompilation)} only when compiled again)"
    )
    sys.exit(1 if failures or recompilation else 0)


if __name__ == "__main__":
    main()
