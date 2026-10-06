#!/usr/bin/env python3
"""Count allocations per MoonBit source line in a native program.

The generated C of a native build has `#line` directives, so every call of
an allocation primitive (`moonbit_malloc`, `moonbit_make_*`) can be charged
to the `.mbt` line it was generated for. This script rewrites such a C file
so that every call site counts itself, and the program writes the counts
when it exits. Calls of `to_owned` (copies of views) are counted the same
way, by their callers' lines.

    moon build cli --target native --release
    python3 scripts/alloc_sites.py instrument \\
        _build/native/release/build/cli/cli.c _build/cli-alloc.c
    # Compile _build/cli-alloc.c with the command that `moon build cli
    # --target native --release --dry-run` prints for cli.c, adding
    # `-include _build/cli-alloc.c.h -w` and another output name.
    ALLOC_COUNTS=counts.txt _build/cli-alloc.exe compile doc.typ out.svg
    python3 scripts/alloc_sites.py report counts.txt [other.txt] [-n 40]

A line of the counts file is `<count> <alloc|to_owned> <file>:<line>`; the
line is that of the statement, which for a multi-line expression is where
it starts. Allocations inside core's functions are charged to core's lines
(`.../core/builtin/array.mbt`), not to their callers. `report` with two
files prints the differences.
"""

import os
import re
import sys

LINE = re.compile(r'^\s*#line (\d+) "([^"]*)"')
# An allocation primitive or an instantiation of `to_owned`, called.
CALL = re.compile(
    r'(?<![A-Za-z0-9_$])'
    r'(moonbit_malloc|moonbit_make_[a-z0-9_]+|_M0[A-Za-z0-9_$]*to__owned[A-Za-z0-9_$]*)\('
)


def instrument(src, dst):
    root = os.getcwd().rstrip('/') + '/'
    sites = {}
    order = []
    cur = ('?', 0)
    with open(src, errors='replace') as f, open(dst, 'w') as out:
        for line in f:
            m = LINE.match(line)
            if m:
                cur = (m.group(2), int(m.group(1)))
            # Statements are indented; declarations and definitions start in
            # column 0 and are left alone.
            elif line[:1] in ' \t' and ('moonbit_ma' in line or 'to__owned' in line):

                def count(m):
                    name = m.group(1)
                    key = ('to_owned' if 'to__owned' in name else 'alloc',) + cur
                    index = sites.get(key)
                    if index is None:
                        index = sites[key] = len(order)
                        order.append(key)
                    # `(count, f)(args)`: the comma expression is the callee.
                    return '(alloc_site_counts[%d]++, %s)(' % (index, name)

                line = CALL.sub(count, line)
            out.write(line)
        out.write('\n#include <stdio.h>\n#include <stdlib.h>\n')
        out.write('static const char *alloc_site_names[%d] = {\n' % max(1, len(order)))
        for kind, path, number in order:
            if path.startswith(root):
                path = path[len(root):]
            out.write('  "%s %s:%d",\n' % (kind, path.replace('\\', '/').replace('"', ''), number))
        out.write('};\n')
        out.write(
            '__attribute__((destructor)) static void alloc_site_dump(void) {\n'
            '  const char *path = getenv("ALLOC_COUNTS");\n'
            '  if (!path) return;\n'
            '  FILE *f = fopen(path, "w");\n'
            '  if (!f) return;\n'
            '  for (int i = 0; i < %d; i++) {\n'
            '    if (alloc_site_counts[i])\n'
            '      fprintf(f, "%%ld %%s\\n", alloc_site_counts[i], alloc_site_names[i]);\n'
            '  }\n'
            '  fclose(f);\n'
            '}\n' % len(order)
        )
    # The counters are used before the end of the file: a header to include
    # first (`-include`).
    with open(dst + '.h', 'w') as header:
        header.write('static long alloc_site_counts[%d];\n' % max(1, len(order)))
    print('%d call sites -> %s (and %s.h)' % (len(order), dst, dst))


def read(path):
    counts = {}
    for line in open(path):
        number, kind, site = line.rstrip('\n').split(' ', 2)
        counts[(kind, site)] = counts.get((kind, site), 0) + int(number)
    return counts


def report(paths, top):
    first = read(paths[0])
    totals = lambda c, kind: sum(v for (k, _), v in c.items() if k == kind)
    if len(paths) == 1:
        print('%d allocations, %d to_owned calls' % (totals(first, 'alloc'), totals(first, 'to_owned')))
        for (kind, site), n in sorted(first.items(), key=lambda kv: -kv[1])[:top]:
            print('%10d %-8s %s' % (n, kind, site))
        return
    second = read(paths[1])
    for kind in ('alloc', 'to_owned'):
        print('%s: %d -> %d' % (kind, totals(first, kind), totals(second, kind)))
    diffs = []
    for key in set(first) | set(second):
        a, b = first.get(key, 0), second.get(key, 0)
        if a != b:
            diffs.append((b - a, a, b, key))
    for d, a, b, (kind, site) in sorted(diffs, key=lambda t: -abs(t[0]))[:top]:
        print('%+10d %10d -> %-10d %-8s %s' % (d, a, b, kind, site))


def main():
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == 'instrument':
        instrument(args[1], args[2])
    elif len(args) >= 2 and args[0] == 'report':
        top = 40
        if '-n' in args:
            i = args.index('-n')
            top = int(args[i + 1])
            del args[i:i + 2]
        report(args[1:3], top)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
