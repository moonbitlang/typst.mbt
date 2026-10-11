#!/usr/bin/env python3
"""Count allocations and reference-count operations per MoonBit source line
in a native program.

The generated C of a native build has `#line` directives, so every call of
an allocation primitive (`moonbit_malloc`, `moonbit_make_*`) can be charged
to the `.mbt` line it was generated for. This script rewrites such a C file
so that every call site counts itself, and the program writes the counts
when it exits. Calls of `to_owned` (copies of views) are counted the same
way, by their callers' lines, and so are the reference-count operations
that the compiler emits: `moonbit_incref`, `moonbit_decref` (with their
`_cycle_free` and `_value_enum` forms) and the two halves of a release
that the compiler wrote out inline where it knows the type (a count
lowered in place, or `moonbit_free`).

    moon build cli --target native --release
    python3 scripts/alloc_sites.py instrument \\
        _build/native/release/build/cli/cli.c _build/cli-alloc.c \\
        [--calls <regex>] [--in-function <regex>]
    # Compile _build/cli-alloc.c with the command that `moon build cli
    # --target native --release --dry-run` prints for cli.c, adding
    # `-include _build/cli-alloc.c.h -w` and another output name.
    ALLOC_COUNTS=counts.txt _build/cli-alloc.exe compile doc.typ out.svg
    python3 scripts/alloc_sites.py report counts.txt [other.txt] [-n 40] [-k kinds]
    python3 scripts/alloc_sites.py types counts.txt [other.txt] [-n 40]

A line of the counts file is `<count> <kind> <file>:<line>[ <type> <bytes>]`;
the line is that of the statement, which for a multi-line expression is
where it starts. The kinds:

    alloc     an allocation; for an object of a fixed size (a struct, an
              enum constructor, a tuple, a closure) the line names its type
              and its size with the header, arrays have neither
    to_owned  a copy of a view
    incref    a reference taken
    decref    a reference given up
    drop      a `decref` that was the last reference: the object and what
              only it holds are released (a subset of `decref`)
    free      an object released by code the compiler wrote out inline
              where it knows the type (not counted under `decref`)
    call      with `--calls <regex>`: a call of a function whose mangled
              name matches, charged to the caller's line and named by
              the callee (`report -k call`)

Allocations inside core's functions are charged to core's lines
(`.../core/builtin/array.mbt`), not to their callers; `--calls` finds the
callers: generic functions are compiled per type, so the name of an
instance says what it is an instance for (`--calls 'Array4copyGiE'`: who
copies an `Array[Int]`; `--calls 'default__implPB4Hash4hash'`: the keys
that are hashed through a `Hasher` object). A small function is compiled
into its callers, and its allocation keeps its own line; `--in-function
<regex>` names the function that the code is in for the allocation sites
whose `<file>:<line>` matches (`--in-function 'otf/parser.mbt:730'`: who
makes a `Stream`). `report` prints the
sites of the kinds of `-k` (a comma-separated list; `rc` is short for
`incref,decref,drop,free`; default `alloc,to_owned`) and with two files
their differences; `types` adds the allocations up by type.

What the counts mean under the calling convention (see "Reference counts
(native)" in AGENTS.md): an `incref` in a callee at the line that stores or
returns a parameter and a `decref` in its callers after the call are the
pair that `#owned` removes; an `incref` and a `decref` around a call in a
loop over an array are the price of handing an element of a mutable
container to a function.
"""

import os
import re
import sys

LINE = re.compile(r'^\s*#line (\d+) "([^"]*)"')
# An allocation primitive or an instantiation of `to_owned`, called.
CALL = re.compile(
    r'(?<![A-Za-z0-9_$])'
    r'(moonbit_malloc|moonbit_make_[a-z0-9_]+|_M0[A-Za-z0-9_$]*to__owned[A-Za-z0-9_$]*)\('
    r'(sizeof\(struct ([A-Za-z0-9_$]+)\)\))?'
)
# A reference-count operation, called.
RC = re.compile(
    r'(?<![A-Za-z0-9_$])'
    r'(moonbit_incref|moonbit_decref|moonbit_incref_cycle_free|moonbit_decref_cycle_free'
    r'|moonbit_incref_value_enum|moonbit_decref_value_enum|moonbit_free|moonbit_deferred_free'
    r'|Moonbit_set_rc_count)\('
)
RC_KINDS = ('incref', 'decref', 'drop', 'free')


SCALARS = {
    's': 'String', 'i': 'Int', 'l': 'Int64', 'd': 'Double', 'f': 'Float', 'b': 'Bool',
    'c': 'Char', 'y': 'Byte', 'z': 'Bytes', 'u': 'Unit', 'j': 'UInt', 'm': 'UInt64',
}


def unescape(text):
    """`_2f` and its like are the characters of a path; `__` is `_`."""
    text = re.sub(r'_([0-9a-f]{2})', lambda m: chr(int(m.group(1), 16)), text)
    return text.replace('__', '_')


def demangle(name):
    """A readable form of a mangled type name: `library.Value::Content`,
    `Array[(Int, layout.ItemEntry)]`, `closure layout.shape:1346`."""
    s = name[3:] if name.startswith('_M0') else name
    pos = 0

    def ident():
        nonlocal pos
        j = pos
        while j < len(s) and s[j].isdigit():
            j += 1
        n = int(s[pos:j])
        pos = j + n
        return s[j:j + n]

    def types(close):
        nonlocal pos
        items = []
        while s[pos] != close:
            items.append(type_())
        pos += 1
        return items

    def type_():
        nonlocal pos
        c = s[pos]
        pos += 1
        if c == 'R':
            return type_()
        if c == 'O':
            return type_() + '?'
        if c == 'U':
            return '(' + ', '.join(types('E')) + ')'
        if c == 'W':
            params = ', '.join(types('E'))
            # A function type ends with its result (and what it raises).
            result = type_() if pos < len(s) and s[pos] not in 'EQ' else ''
            return 'fn(%s)%s' % (params, ' -> ' + result if result else '')
        if c == 'P':
            package = ''
            if s[pos] == 'B':
                pos += 1
            else:
                if s[pos] == 'C':
                    pos += 1
                k = int(s[pos])
                pos += 1
                for _ in range(k):
                    package = ident()
                package += '.'
            text = package + ident().replace('__', '_')
            if pos < len(s) and s[pos] == 'G':
                pos += 1
                text += '[' + ', '.join(types('E')) + ']'
            return text
        return SCALARS.get(c, c)

    try:
        if s[:1] == 'R' and s[1:2].isdigit():
            # The environment of a closure: `$<package>.<function>.anon_u<n>_l<line>_`.
            pos = 1
            path = unescape(ident()).lstrip('$').rstrip('_')
            return 'closure ' + re.sub(r'\.anon_u\d+_l(\d+)$', r':\1', path.rsplit('/', 1)[-1])
        # `T` a type, `DT` a constructor of an enum.
        while s[pos] in 'DT':
            pos += 1
        text = type_()
        if pos < len(s) and s[pos].isdigit():
            # A constructor; that of an error carries its full path again.
            text += '::' + unescape(ident()).rsplit('.', 1)[-1]
        return text if pos == len(s) else name
    except (ValueError, IndexError):
        return name


def instrument(src, dst, calls=None, in_function=None):
    root = os.getcwd().rstrip('/') + '/'
    within = re.compile(in_function) if in_function else None
    definition = re.compile(r"^[A-Za-z_][^;=]*?(_M0[A-Za-z0-9_$]+)\([^;]*$")
    function = ''
    callee = re.compile(r'(?<![A-Za-z0-9_$])(_M0[A-Za-z0-9_$]*)\(')
    wanted = re.compile(calls) if calls else None
    sites = {}
    order = []
    cur = ('?', 0)

    def site(kind, type_name=''):
        key = (kind,) + cur + (type_name,)
        index = sites.get(key)
        if index is None:
            index = sites[key] = len(order)
            order.append(key)
        return index

    with open(src, errors='replace') as f, open(dst, 'w') as out:
        for line in f:
            m = LINE.match(line)
            if m:
                cur = (m.group(2), int(m.group(1)))
            elif within and line[:1] not in ' \t#}' and definition.match(line):
                function = definition.match(line).group(1)
            # Statements are indented; declarations and definitions start in
            # column 0 and are left alone.
            elif line[:1] in ' \t' and (
                'oonbit_' in line or 'to__owned' in line or wanted and '_M0' in line
            ):

                def count(m):
                    name = m.group(1)
                    kind = 'to_owned' if 'to__owned' in name else 'alloc'
                    type_name = m.group(3) or ''
                    if within and within.search('%s:%d' % cur):
                        type_name += '@' + function
                    index = site(kind, type_name)
                    # `(count, f)(args)`: the comma expression is the callee.
                    return '(alloc_site_counts[%d]++, %s)(%s' % (index, name, m.group(2) or '')

                def count_rc(m):
                    name = m.group(1)
                    if name == 'moonbit_free':
                        return 'ALLOC_SITE_FREE(%d, ' % site('free')
                    if name == 'moonbit_deferred_free':
                        return '(alloc_site_counts[%d]++, %s)(' % (site('free'), name)
                    if name == 'Moonbit_set_rc_count':
                        # A statement: the count of an object that stays is
                        # lowered in place, where the compiler wrote out the
                        # release of an object whose type it knows.
                        return 'alloc_site_counts[%d]++; %s(' % (site('decref'), name)
                    if 'decref' in name and 'value_enum' not in name:
                        # Two counters: the operation, and those that release.
                        index = site('decref')
                        site('drop')
                        return 'ALLOC_SITE_DECREF(%d, %s, ' % (index, name)
                    index = site('incref' if 'incref' in name else 'decref')
                    return '(alloc_site_counts[%d]++, %s)(' % (index, name)

                def count_call(m):
                    name = m.group(1)
                    if 'to__owned' in name or not wanted.search(name):
                        return m.group(0)
                    return '(alloc_site_counts[%d]++, %s)(' % (site('call', name), name)

                if wanted and '_M0' in line:
                    line = callee.sub(count_call, line)
                line = CALL.sub(count, line)
                line = RC.sub(count_rc, line)
            out.write(line)
        out.write('\n#include <stdio.h>\n#include <stdlib.h>\n')
        out.write('static const char *alloc_site_names[%d] = {\n' % max(1, len(order)))
        for kind, path, number, type_name in order:
            if path.startswith(root):
                path = path[len(root):]
            path = path.replace('\\', '/').replace('"', '')
            out.write('  "%s %s:%d",\n' % (kind, path, number))
        out.write('};\n')
        out.write('static const char *alloc_site_types[%d] = {\n' % max(1, len(order)))
        for kind, path, number, type_name in order:
            name, _, where = type_name.partition('@')
            text = demangle(name) if name else ''
            if where:
                text = (text + ' in ' if text else 'in ') + where
            out.write('  "%s",\n' % text.replace('"', '') if text else '  0,\n')
        out.write('};\n')
        # The size of an object of a fixed size, with its header.
        out.write('static const unsigned alloc_site_sizes[%d] = {\n' % max(1, len(order)))
        for kind, path, number, type_name in order:
            type_name = type_name.partition('@')[0]
            out.write(
                '  sizeof(struct %s) + sizeof(struct moonbit_object),\n' % type_name
                if type_name and kind != 'call' else '  0,\n'
            )
        out.write('};\n')
        out.write(
            '__attribute__((destructor)) static void alloc_site_dump(void) {\n'
            '  const char *path = getenv("ALLOC_COUNTS");\n'
            '  if (!path) return;\n'
            '  FILE *f = fopen(path, "w");\n'
            '  if (!f) return;\n'
            '  for (int i = 0; i < %d; i++) {\n'
            '    if (!alloc_site_counts[i]) continue;\n'
            '    if (alloc_site_types[i])\n'
            '      fprintf(f, "%%ld %%s %%s %%u\\n", alloc_site_counts[i], alloc_site_names[i],\n'
            '              alloc_site_types[i], alloc_site_sizes[i]);\n'
            '    else\n'
            '      fprintf(f, "%%ld %%s\\n", alloc_site_counts[i], alloc_site_names[i]);\n'
            '  }\n'
            '  fclose(f);\n'
            '}\n' % len(order)
        )
    # The counters are used before the end of the file: a header to include
    # first (`-include`). Its macros are expanded where they are used, after
    # the runtime's own headers.
    with open(dst + '.h', 'w') as header:
        header.write('static long alloc_site_counts[%d];\n' % max(1, len(order)))
        header.write(
            '/* Whether the reference that is given up is the last one. */\n'
            '#ifndef ALLOC_SITE_UNIQUE\n'
            '#define ALLOC_SITE_UNIQUE(p) (Moonbit_rc_count(Moonbit_object_header(p)) == 1)\n'
            '#endif\n'
            '#define ALLOC_SITE_DECREF(i, f, p) \\\n'
            '  (alloc_site_counts[i]++, alloc_site_counts[(i) + 1] += ALLOC_SITE_UNIQUE(p), f(p))\n'
            '#define ALLOC_SITE_FREE(i, p) (alloc_site_counts[i]++, moonbit_free(p))\n'
        )
    print('%d call sites -> %s (and %s.h)' % (len(order), dst, dst))


def read(path):
    """`{(kind, site): [count, bytes]}`; a site is `file:line` or `file:line type`."""
    counts = {}
    for line in open(path):
        fields = line.rstrip('\n').split(' ')
        number, kind, site = int(fields[0]), fields[1], fields[2]
        size = 0
        if len(fields) > 3:
            size = int(fields[-1])
            site += ' ' + ' '.join(fields[3:-1])
        entry = counts.setdefault((kind, site), [0, 0])
        entry[0] += number
        entry[1] += number * size
    return counts


def megabytes(n):
    return '%7.1f MB' % (n / 1e6) if n else ' ' * 10


def report(paths, top, kinds):
    first = read(paths[0])
    totals = lambda c, kind: sum(v[0] for (k, _), v in c.items() if k == kind)
    all_kinds = ('alloc', 'to_owned') + RC_KINDS
    if len(paths) == 1:
        print(', '.join('%d %s' % (totals(first, k), k) for k in all_kinds if totals(first, k)))
        print('%s in objects of a fixed size' % megabytes(sum(v[1] for v in first.values())).strip())
        rows = [(k, v) for k, v in first.items() if k[0] in kinds]
        for (kind, site), (n, size) in sorted(rows, key=lambda kv: -kv[1][0])[:top]:
            print('%10d %s %-8s %s' % (n, megabytes(size), kind, site))
        return
    second = read(paths[1])
    for kind in all_kinds:
        if totals(first, kind) or totals(second, kind):
            print('%s: %d -> %d' % (kind, totals(first, kind), totals(second, kind)))
    diffs = []
    for key in set(first) | set(second):
        if key[0] not in kinds:
            continue
        a, b = first.get(key, [0, 0])[0], second.get(key, [0, 0])[0]
        if a != b:
            diffs.append((b - a, a, b, key))
    for d, a, b, (kind, site) in sorted(diffs, key=lambda t: -abs(t[0]))[:top]:
        print('%+10d %10d -> %-10d %-8s %s' % (d, a, b, kind, site))


def types(paths, top):
    """Allocations by type: what is allocated most is what is released most."""

    def by_type(path):
        result = {}
        for (kind, site), (n, size) in read(path).items():
            if kind != 'alloc':
                continue
            name = site.split(' ', 1)[1] if ' ' in site else '(array) ' + site.rsplit('/', 1)[-1]
            entry = result.setdefault(name, [0, 0])
            entry[0] += n
            entry[1] += size
        return result

    first = by_type(paths[0])
    if len(paths) == 1:
        for name, (n, size) in sorted(first.items(), key=lambda kv: -kv[1][0])[:top]:
            print('%10d %s %s' % (n, megabytes(size), name))
        return
    second = by_type(paths[1])
    diffs = []
    for name in set(first) | set(second):
        a, b = first.get(name, [0, 0])[0], second.get(name, [0, 0])[0]
        if a != b:
            diffs.append((b - a, a, b, name))
    for d, a, b, name in sorted(diffs, key=lambda t: -abs(t[0]))[:top]:
        print('%+10d %10d -> %-10d %s' % (d, a, b, name))


def main():
    args = sys.argv[1:]
    top = 40
    kinds = ('alloc', 'to_owned')
    if '-n' in args:
        i = args.index('-n')
        top = int(args[i + 1])
        del args[i:i + 2]
    if '-k' in args:
        i = args.index('-k')
        kinds = tuple(
            k for name in args[i + 1].split(',') for k in (RC_KINDS if name == 'rc' else (name,))
        )
        del args[i:i + 2]
    calls = None
    if '--calls' in args:
        i = args.index('--calls')
        calls = args[i + 1]
        del args[i:i + 2]
    in_function = None
    if '--in-function' in args:
        i = args.index('--in-function')
        in_function = args[i + 1]
        del args[i:i + 2]
    if len(args) == 3 and args[0] == 'instrument':
        instrument(args[1], args[2], calls, in_function)
    elif len(args) >= 2 and args[0] == 'report':
        report(args[1:3], top, kinds)
    elif len(args) >= 2 and args[0] == 'types':
        types(args[1:3], top)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
