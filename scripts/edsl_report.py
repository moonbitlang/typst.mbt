#!/usr/bin/env python3
"""Aggregates the conversion of the suite (docs/edsl-convert.md, section 11):
`tests/edsl_gen/manifest.tsv` (written by `edsl-convert`) and
`tests/edsl_gen/results.tsv` (written by `edsl-suite`).

Usage: edsl_report.py [--failures N] [--dir DIR] [--check CHECK]

Prints a table per suite directory (tests, tiers, first-attempt compiles,
equal), the fallback constructs, and the failures grouped by the first
failed check and the first difference.
"""

import collections
import re
import sys


def read_tsv(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        for line in f:
            fields = line.rstrip("\n").split("\t")
            fields += [""] * (len(header) - len(fields))
            rows.append(dict(zip(header, fields)))
    return rows


def unescape(s):
    return s.replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def signature(detail):
    """A coarse key for grouping first differences."""
    detail = unescape(detail)
    lines = [l.strip() for l in detail.split("\n")]
    edsl = next((l for l in lines if l.startswith("edsl:")), "")
    typst = next((l for l in lines if l.startswith("typst:")), "")
    text = (edsl[5:].strip()[:90] + " | " + typst[6:].strip()[:90]) if edsl or typst else lines[0][:120]
    return re.sub(r"\d+", "N", text)


def main():
    args = sys.argv[1:]
    top = 25
    only_dir = None
    only_check = None
    while args:
        a = args.pop(0)
        if a == "--failures":
            top = int(args.pop(0))
        elif a == "--dir":
            only_dir = args.pop(0)
        elif a == "--check":
            only_check = args.pop(0)
    manifest = read_tsv("tests/edsl_gen/manifest.tsv")
    try:
        results = {r["number"]: r for r in read_tsv("tests/edsl_gen/results.tsv")}
    except FileNotFoundError:
        results = {}

    dirs = collections.OrderedDict()
    constructs = collections.Counter()
    construct_bytes = collections.Counter()
    for row in manifest:
        d = row["file"].split("/")[0]
        if only_dir and d != only_dir:
            continue
        s = dirs.setdefault(d, collections.Counter())
        s["tests"] += 1
        tier = row["tier"]
        if tier == "T3" and row["math_only"] == "true":
            tier = "T3m"
        s[tier] += 1
        s["source"] += int(row["source_bytes"])
        s["fallback"] += int(row["fallback_bytes"])
        if row["compile"] == "ok":
            s["compiled"] += 1
        if row["paged"] == "true":
            s["paged"] += 1
        for f in filter(None, row["fallbacks"].split(";")):
            construct, kind, size = f.rsplit(":", 2)
            constructs[(construct, kind)] += 1
            construct_bytes[(construct, kind)] += int(size)
        r = results.get(row["number"])
        if r is not None:
            s["ran"] += 1
            if r["failed"] == "":
                s["equal"] += 1
                s["equal_" + tier] += 1

    cols = ["tests", "paged", "T1", "T2", "T3m", "T3", "T4", "compiled", "ran", "equal"]
    print("| directory | " + " | ".join(cols) + " | fallback bytes |")
    print("|---|" + "---:|" * (len(cols) + 1))
    total = collections.Counter()
    for d, s in dirs.items():
        total.update(s)
        ratio = 100.0 * s["fallback"] / max(1, s["source"])
        print(f"| {d} | " + " | ".join(str(s[c]) for c in cols) + f" | {ratio:.0f}% |")
    ratio = 100.0 * total["fallback"] / max(1, total["source"])
    print("| **total** | " + " | ".join(str(total[c]) for c in cols) + f" | {ratio:.0f}% |")
    print()
    print("equal by tier: " + ", ".join(
        f"{t} {total['equal_' + t]}/{total[t]}" for t in ["T1", "T2", "T3m", "T3", "T4"] if total[t]))
    print()
    print("fallback constructs (fragments, bytes):")
    for (construct, kind), n in constructs.most_common(40):
        print(f"  {n:6d} {construct_bytes[(construct, kind)]:9d}  {construct} ({kind})")
    print()

    groups = collections.defaultdict(list)
    for row in manifest:
        d = row["file"].split("/")[0]
        if only_dir and d != only_dir:
            continue
        r = results.get(row["number"])
        if r is None or r["failed"] == "":
            continue
        first = r["failed"].split(" ")[0]
        if only_check and first != only_check:
            continue
        groups[(first, signature(r["detail"]))].append(f"{row['file']} :: {row['name']}")
    print(f"failures by first failed check and first difference ({sum(len(v) for v in groups.values())}):")
    for (check, sig), names in sorted(groups.items(), key=lambda kv: -len(kv[1]))[:top]:
        print(f"  {len(names):5d}  {check}: {sig}")
        print(f"         e.g. {names[0]}")


if __name__ == "__main__":
    main()
