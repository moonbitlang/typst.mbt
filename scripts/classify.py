#!/usr/bin/env python3
"""Classify differential failures by the first differing golden line."""
import os, re, sys, collections
stage = sys.argv[1] if len(sys.argv) > 1 else "eval"
gold_root = f"tests/golden/{stage}"
act_root = f"_build/actual/{stage}"
def split(path):
    out = {}
    if not os.path.exists(path): return out
    name = None; buf = []
    for line in open(path).read().split("\n"):
        if line.startswith("=== "):
            if name is not None: out[name] = buf
            name = line[4:]; buf = []
        else:
            buf.append(line)
    if name is not None: out[name] = buf
    return out
cats = collections.Counter()
examples = {}
for dp, _, files in os.walk(gold_root):
    for f in files:
        g = split(os.path.join(dp, f))
        a = split(os.path.join(act_root, os.path.relpath(os.path.join(dp, f), gold_root)))
        for name, gl in g.items():
            al = a.get(name)
            if al is None or al == gl: continue
            # Prefer a message about an unknown variable / method in our output.
            key = None
            for line in al:
                m = re.search(r'"(unknown variable `[^`]*`|type [a-z ]+ has no method `[^`]*`|[^"]*not ported yet[^"]*|cannot access fields on type [a-z ]+)"', line)
                if m: key = m.group(1); break
            if key is None:
                for x, y in zip(gl, al):
                    if x != y:
                        key = "golden: " + re.sub(r'\d+\.\.\d+', 'N..N', x[:90]); break
                else:
                    key = "length differs"
            cats[key] += 1
            examples.setdefault(key, name)
for k, n in cats.most_common(int(sys.argv[2]) if len(sys.argv) > 2 else 60):
    print(f"{n:5} {k}   [{examples[k]}]")
