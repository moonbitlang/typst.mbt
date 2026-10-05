#!/usr/bin/env python3
"""Maps the errors of `moon check` in the generated shard files to cases
(docs/edsl-convert.md, section 8).

Usage: edsl_failed.py <check log> <manifest.tsv> <failed.txt>

Appends `number<TAB>message` to failed.txt for every case with an error
that is not listed there yet, and prints the number of cases added.
"""

import re
import sys


def main():
    log, manifest, failed_path = sys.argv[1:4]
    # (shard, first line, last line, number)
    ranges = []
    with open(manifest, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        col = {name: i for i, name in enumerate(header)}
        for line in f:
            row = line.rstrip("\n").split("\t")
            ranges.append((
                int(row[col["shard"]]),
                int(row[col["first_line"]]),
                int(row[col["last_line"]]),
                int(row[col["number"]]),
            ))
    known = set()
    try:
        with open(failed_path, encoding="utf-8") as f:
            for line in f:
                if "\t" in line:
                    known.add(int(line.split("\t")[0]))
    except FileNotFoundError:
        pass

    location = re.compile(r"tests/edsl_gen/s(\d+)/gen_cases\.mbt:(\d+):\d+")
    found = {}
    in_error = False
    place = None
    for line in open(log, encoding="utf-8", errors="replace"):
        if line.startswith("Error:"):
            in_error = True
            place = None
            continue
        if line.startswith("Warning:"):
            in_error = False
            continue
        if not in_error:
            continue
        m = location.search(line)
        if m and place is None:
            place = (int(m.group(1)), int(m.group(2)))
            continue
        if place is not None and "╰" in line:
            message = line.split("╰", 1)[1].lstrip("─ ").strip()
            shard, at = place
            for s, first, last, number in ranges:
                if s == shard and first <= at <= last:
                    found.setdefault(number, message)
                    break
            in_error = False
    new = {n: m for n, m in found.items() if n not in known}
    with open(failed_path, "a", encoding="utf-8") as f:
        for number in sorted(new):
            f.write(f"{number}\t{new[number]}\n")
    print(len(new))


if __name__ == "__main__":
    main()
