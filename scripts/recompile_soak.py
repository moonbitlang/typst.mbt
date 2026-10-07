#!/usr/bin/env python3
"""Soak run of the `recompile` stage (tests/recompile/README.md).

    scripts/recompile_soak.py [--minutes M] [--jobs N] [--seed S] [--all]
                              [--sequences K] [--steps T] [--cold C]
                              [--timeout MIN] [--only NAME] [--match TEXT]
                              [--runner PATH]

Runs the stage document by document (all of them, those named with `--only`
or those whose names contain TEXT; `--all` as for the stage) with the seeds
S, S+1, ... until M minutes have passed (the runs in flight are finished), N
at a time. A run is one process,

    recompile --only=<document> --seed=<seed> --sequences=K --steps=T
              --snapshots=<dir> -v --trace

which writes the files of every step before it compiles it and a digest of
what the compilation gave after. With them this script does what the stage
cannot do in its own process:

- Cold references. C steps of every run that passed (chosen by the seed) are
  compiled again from their snapshots, each as the first compilation of a
  new process (`recompile --replay=<snapshot>`), and must give the digest
  that the watch loop gave. The references of the stage share their process
  with the loop, so a cache that neither `set_layout_memo_enabled(false)`
  turns off nor `evict(1)` drops could make all of them wrong together; a
  new process has no cache.
- Aborts. An edit can make the compiler abort where upstream panics, and
  the runner with it. The snapshot without a digest is the one that was
  being compiled; it is compiled again in a new process. If that aborts
  too, the abort is not about compiling again (whether upstream panics on
  those files is checked by hand; they stay in the output directory).
  If it does not, or if the runner died somewhere else (in a reference),
  the abort is a failure.
- Runs that do not end within `--timeout` minutes are killed and are
  failures.

The clock only decides when to stop: what a seed does is a function of the
seed. A failure is reproduced with

    moon run tests/runner --target native --release -- recompile \\
        --only=<document> --seed=<seed> --sequences=K --steps=T -v

Logs and snapshots of the runs that failed or aborted are kept in
`_build/recompile/soak/`; the exit status is 1 if anything failed.
"""

import argparse
import concurrent.futures
import os
import random
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "_build/recompile/soak")
STATS = re.compile(
    r"^recompile: (\d+) documents, (\d+) sequences, (\d+) steps, (\d+) compilations"
)
SUMMARY = re.compile(r"^recompile(?: packages)?: (\d+) passed, (\d+) failed")


def call(command, timeout):
    """(exit status or None after a timeout, output)."""
    try:
        proc = subprocess.run(
            command,
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as e:
        return None, (e.stdout or b"").decode("utf-8", "replace")
    return proc.returncode, proc.stdout.decode("utf-8", "replace")


def replay(args, step_dir):
    """The digest of a snapshot compiled in a new process, or None."""
    command = [args.runner, "recompile", f"--replay={step_dir}"]
    if args.all:
        command.append("--all")
    code, out = call(command, args.timeout * 60)
    if code != 0:
        return None, out
    for line in out.split("\n"):
        if line.startswith("DIGEST "):
            return line[7:].strip(), out
    return None, out


def steps_of(snap):
    """The step directories of a run's snapshots, in the order they ran."""
    found = []
    for base, dirs, files in os.walk(snap):
        if "meta.txt" in files:
            found.append(base)
    found.sort(key=lambda d: os.path.getmtime(os.path.join(d, "meta.txt")))
    return found


def task(args, document, seed):
    """One run. Returns (document, seed, kind, lines, stats, keep)."""
    tag = f"seed{seed}-{document.replace('/', '_')}"
    snap = os.path.join(OUT, "snapshots", tag)
    shutil.rmtree(snap, ignore_errors=True)
    command = [
        args.runner,
        "recompile",
        f"--only={document}",
        f"--seed={seed}",
        f"--sequences={args.sequences}",
        f"--steps={args.steps}",
        # (Relative: the runner makes the directories from where it runs.)
        f"--snapshots={os.path.relpath(snap, ROOT)}",
        "-v",
        "--trace",
    ]
    if args.all:
        command.append("--all")
    code, out = call(command, args.timeout * 60)
    lines = out.split("\n")
    stats = [0, 0, 0]
    for line in lines:
        m = STATS.match(line)
        if m:
            stats = [int(m.group(2)), int(m.group(3)), int(m.group(4))]
    summaries = [SUMMARY.match(line) for line in lines]
    summaries = [m for m in summaries if m]
    passed = sum(int(m.group(1)) for m in summaries)
    failed = sum(int(m.group(2)) for m in summaries)
    messages = []
    kind = "pass"
    if code is None:
        kind = "fail"
        messages.append(f"TIMEOUT {document} seed={seed}: killed after {args.timeout} min")
    elif code != 0 or not summaries:
        # The runner died. Where?
        steps = steps_of(snap)
        open_steps = [d for d in steps if not os.path.exists(os.path.join(d, "digest.txt"))]
        where = os.path.relpath(open_steps[-1], snap) if open_steps else "a reference"
        if open_steps:
            digest, replay_out = replay(args, open_steps[-1])
            out += "\n--- replay of " + open_steps[-1] + " ---\n" + replay_out
            if digest is None:
                kind = "abort"
                messages.append(
                    f"ABORT {document} seed={seed} at {where}: aborts in a new process too"
                )
            else:
                kind = "fail"
                messages.append(
                    f"ABORT {document} seed={seed} at {where}: ONLY WHEN COMPILED AGAIN"
                )
        else:
            kind = "fail"
            messages.append(
                f"ABORT {document} seed={seed} in a reference, not in the watch loop"
            )
    elif failed or any(line.startswith("FAIL ") for line in lines):
        kind = "fail"
        messages += [line for line in lines if line.startswith("FAIL ")]
    elif passed == 0 or stats[1] == 0:
        kind = "fail"
        messages.append(f"EMPTY {document} seed={seed}: nothing was compared")
    else:
        # Cold references.
        # (Not the steps whose sources were reparsed into a tree that a
        # parse does not give: a new process parses.)
        steps = [
            d
            for d in steps_of(snap)
            if not os.path.exists(os.path.join(d, "reparsed.txt"))
        ]
        rng = random.Random(f"{seed}/{document}")
        for step_dir in rng.sample(steps, min(args.cold, len(steps))):
            with open(os.path.join(step_dir, "digest.txt"), encoding="utf-8") as f:
                want = f.read().strip()
            got, replay_out = replay(args, step_dir)
            stats.append(1)
            if got != want:
                kind = "fail"
                where = os.path.relpath(step_dir, snap)
                messages.append(
                    f"COLD {document} seed={seed} at {where}: a new process gives "
                    f"{'an abort' if got is None else 'another result'}"
                )
                out += "\n--- replay of " + step_dir + " ---\n" + replay_out
    cold = len(stats) - 3
    if kind == "pass":
        shutil.rmtree(snap, ignore_errors=True)
    else:
        with open(os.path.join(OUT, tag + ".log"), "w", encoding="utf-8") as f:
            f.write(out)
    return document, seed, kind, messages, stats[:3] + [cold]


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--minutes", type=float, default=60.0)
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) // 2))
    parser.add_argument("--seed", type=int, default=1000)
    parser.add_argument("--sequences", type=int, default=4)
    parser.add_argument("--steps", type=int, default=12)
    parser.add_argument("--cold", type=int, default=3)
    parser.add_argument("--timeout", type=float, default=30.0)
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
    args.runner = os.path.abspath(args.runner)
    if not os.path.exists(args.runner):
        sys.exit(
            f"{args.runner} is missing: moon build --target native --release tests/runner"
        )
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
    os.makedirs(OUT, exist_ok=True)

    start = time.monotonic()
    deadline = start + args.minutes * 60.0
    totals = [0, 0, 0, 0]
    runs = 0
    failures = []
    aborts = []
    seeds_done = 0
    seed = args.seed
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        while seeds_done == 0 or time.monotonic() < deadline:
            futures = [pool.submit(task, args, document, seed) for document in documents]
            for future in concurrent.futures.as_completed(futures):
                document, s, kind, messages, stats = future.result()
                runs += 1
                for i, n in enumerate(stats):
                    totals[i] += n
                for message in messages:
                    print(message, flush=True)
                if kind == "fail":
                    failures += messages
                elif kind == "abort":
                    aborts += messages
            seeds_done += 1
            seed += 1
            elapsed = (time.monotonic() - start) / 60.0
            print(
                f"seed {seed - 1} done after {elapsed:.1f} min: {totals[1]} steps, "
                f"{totals[3]} cold references, {len(failures)} failures, "
                f"{len(aborts)} aborts that a new process repeats",
                flush=True,
            )
    elapsed = (time.monotonic() - start) / 60.0
    print()
    print(
        f"soak: {len(documents)} documents, seeds {args.seed}..{seed - 1}, "
        f"{args.sequences} random sequences of {args.steps} edits and the sweep "
        f"each, {elapsed:.1f} minutes with {args.jobs} jobs"
    )
    print(
        f"soak: {runs} runs, {totals[0]} sequences, {totals[1]} steps, "
        f"{totals[2]} compilations, {totals[3]} cold references"
    )
    print(
        f"soak: {len(failures)} failures, {len(aborts)} aborts that a new process repeats"
    )
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
