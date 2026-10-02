#!/usr/bin/env python3
"""Extract rustybuzz's shaping tests (HarfBuzz's test suite, generated into
`tests/shaping/*.rs` by rustybuzz's gen-shaping-tests.py) into flat files for
the runner's `shape-hb` stage.

Usage: shape_hb_tests.py <rustybuzz checkout> <out dir>

Writes `<out>/<module>.tsv`, one test per line:

    name <TAB> font path <TAB> codepoints <TAB> options <TAB> expected

`font path` is relative to the rustybuzz checkout unless absolute (the macOS
tests use system fonts), `codepoints` are comma-separated hex scalars, and
`options` are the hb-shape style options passed to the test's `shape`.
"""

import os
import re
import sys

TEST_RE = re.compile(
    r'#\[test\]\s*fn (\w+)\(\) \{\s*assert_eq!\(\s*shape\(\s*'
    r'"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)",\s*\),\s*'
    r'"((?:[^"\\]|\\.)*)"\s*\);\s*\}',
    re.S,
)


def unescape(s):
    """Unescape a Rust string literal body (including `\\` + newline)."""
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c != '\\':
            out.append(c)
            i += 1
            continue
        n = s[i + 1]
        if n == '\n':
            i += 2
            while i < len(s) and s[i] in ' \t\n\r':
                i += 1
        elif n == 'u':
            end = s.index('}', i)
            out.append(chr(int(s[i + 3:end], 16)))
            i = end + 1
        elif n == 'x':
            out.append(chr(int(s[i + 2:i + 4], 16)))
            i += 4
        else:
            out.append({'n': '\n', 't': '\t', 'r': '\r', '0': '\0',
                        '\\': '\\', '"': '"', "'": "'"}[n])
            i += 2
    return ''.join(out)


def main():
    root, out = sys.argv[1], sys.argv[2]
    shaping = os.path.join(root, 'tests', 'shaping')
    os.makedirs(out, exist_ok=True)
    total = 0
    for name in sorted(os.listdir(shaping)):
        if not name.endswith('.rs') or name in ('main.rs', 'wasm.rs'):
            continue
        src = open(os.path.join(shaping, name), encoding='utf-8').read()
        lines = []
        for m in TEST_RE.finditer(src):
            test, font, text, options, expected = m.groups()
            font = unescape(font)
            cps = ','.join('%X' % ord(c) for c in unescape(text))
            options = unescape(options)
            expected = unescape(expected)
            for field in (test, font, options, expected):
                assert '\t' not in field and '\n' not in field, test
            lines.append('\t'.join([test, font, cps, options, expected]))
        declared = len(re.findall(r'#\[test\]', src))
        assert declared == len(lines), (name, declared, len(lines))
        with open(os.path.join(out, name[:-3] + '.tsv'), 'w', encoding='utf-8') as f:
            f.write(''.join(l + '\n' for l in lines))
        total += len(lines)
    print('extracted %d shaping tests' % total, file=sys.stderr)


if __name__ == '__main__':
    main()
