#!/usr/bin/env python3
"""Classify `paged` stage failures (typst-frame-v1 dumps).

Usage: python3 scripts/classify_paged.py [N] [--examples K] [--text-free] [--list]

`--text-free` only considers tests whose golden is a successful layout
without text (which do not depend on inline layout); `--list` prints every
failing test with its bucket instead of the bucket counts.

Run `moon run tests/runner --target native -- paged --dump` first. Each
failing test is put into one bucket:

- `ours err: <msg>`: we fail with an error while upstream succeeds,
- `diag: <first differing line>`: the diagnostics differ otherwise,
- `<record>: <field>`: the first differing record of a successful layout,
  named by its kind (`frame`, `shape`, `text`, ...) and, if the kinds agree,
  the first differing field (`size`, `position`, `geometry`, ...).
"""
import json
import os
import re
import sys
import collections

GOLD_ROOT = "tests/golden/paged"
ACT_ROOT = "_build/actual/paged"

# Field names of the records (see `oracle/src/paged.rs`).
FIELDS = {
    "header": ["kind", "version", "revision", "fonts", "name"],
    "diagnostics": ["kind", "status", "lines"],
    "document": ["kind", "info", "options", "page_count"],
    "font": ["kind", "F", "sha", "index", "variations", "family", "postscript", "upem"],
    "image-resource": ["kind", "I", "kind", "sha", "page", "size", "dpi", "exif", "icc", "deps"],
    "content": ["kind", "C", "content"],
    "page": ["kind", "P", "number", "bleed", "fill", "numbering", "supplement"],
    "frame": ["kind", "R", "size", "baseline", "hardness", "item_count"],
    "group": ["kind", "R", "index", "position", "child", "transform", "clip", "label", "parent"],
    "text": ["kind", "R", "index", "position", "font", "size", "fill", "stroke", "lang", "region", "text", "glyphs"],
    "shape": ["kind", "R", "index", "position", "geometry", "fill", "fill_rule", "stroke", "span"],
    "image": ["kind", "R", "index", "position", "image", "size", "alt", "scaling", "span"],
    "link": ["kind", "R", "index", "position", "size", "destination"],
    "tag-start": ["kind", "R", "index", "position", "L", "C", "introspectable", "tagged"],
    "tag-end": ["kind", "R", "index", "position", "L", "K", "introspectable", "tagged"],
    "end": ["kind"],
}


def split(path):
    out = {}
    if not os.path.exists(path):
        return out
    name = None
    buf = []
    for line in open(path).read().split("\n"):
        if line.startswith("=== "):
            if name is not None:
                out[name] = buf
            name = line[4:]
            buf = []
        elif line:
            buf.append(line)
    if name is not None:
        out[name] = buf
    return out


def norm(s):
    s = re.sub(r"\d+\.\.\d+", "N..N", s)
    s = re.sub(r"\b\d+\b", "N", s)
    return s[:110]


def parse(line):
    try:
        return json.loads(line)
    except Exception:
        return None


def classify(gl, al):
    gd = next((parse(l) for l in gl if l.startswith('["diagnostics"')), None)
    ad = next((parse(l) for l in al if l.startswith('["diagnostics"')), None)
    if gd and ad:
        if gd[1] == "ok" and ad[1] == "err":
            msg = ad[2][0] if ad[2] else ""
            m = re.search(r'"(.*)"', msg)
            return "ours err: " + norm(m.group(1) if m else msg)
        if gd != ad:
            for x, y in zip(gd[2], ad[2]):
                if x != y:
                    return "diag: golden " + norm(x)
            if len(gd[2]) != len(ad[2]):
                extra = (ad[2] if len(ad[2]) > len(gd[2]) else gd[2])[min(len(gd[2]), len(ad[2]))]
                who = "ours extra" if len(ad[2]) > len(gd[2]) else "golden extra"
                return f"diag: {who} " + norm(extra)
            return "diag: status " + gd[1] + " vs " + ad[1]
    for x, y in zip(gl, al):
        if x == y:
            continue
        gx, ay = parse(x), parse(y)
        if not gx or not ay:
            return "unparsable line"
        if gx[0] != ay[0]:
            return f"record: golden {gx[0]} vs ours {ay[0]}"
        names = FIELDS.get(gx[0], [])
        for i, (u, v) in enumerate(zip(gx, ay)):
            if u != v:
                field = names[i] if i < len(names) else str(i)
                if gx[0] == "content" and field == "content":
                    m = re.match(r"([a-z.]+)\(", str(u))
                    return f"content: {m.group(1) if m else '?'}"
                return f"{gx[0]}: {field}"
        return f"{gx[0]}: length"
    return "length differs"


def main():
    n = 40
    examples = 1
    args = sys.argv[1:]
    if "--examples" in args:
        i = args.index("--examples")
        examples = int(args[i + 1])
        del args[i : i + 2]
    text_free = "--text-free" in args
    listing = "--list" in args
    args = [a for a in args if a not in ("--text-free", "--list")]
    if args:
        n = int(args[0])
    cats = collections.Counter()
    ex = collections.defaultdict(list)
    for dp, _, files in os.walk(GOLD_ROOT):
        for f in files:
            gpath = os.path.join(dp, f)
            g = split(gpath)
            a = split(os.path.join(ACT_ROOT, os.path.relpath(gpath, GOLD_ROOT)))
            for name, gl in g.items():
                al = a.get(name)
                if al is None or al == gl:
                    continue
                if text_free and (
                    len(gl) < 2
                    or '"ok"' not in gl[1]
                    or any(l.startswith('["text"') for l in gl)
                ):
                    continue
                key = classify(gl, al)
                if listing:
                    print(f"{name} | {key}")
                cats[key] += 1
                if len(ex[key]) < examples:
                    ex[key].append(name)
    for k, c in cats.most_common(n):
        print(f"{c:5} {k}   [{', '.join(ex[k])}]")


main()
