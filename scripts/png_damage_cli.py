#!/usr/bin/env python3
"""Compare the port's CLI with an upstream `typst` binary on documents with
damaged PNG images, end to end.

  scripts/png_damage_cli.py [-j N] [--out DIR] [--tsv FILE] [filter ...]

The oracle of `codecs` (`codecs/png_oracle_test.mbt`, from the `image` and
`png` crates) is the check that CI runs; it compares what the decoder
returns. This script is the same comparison through the two command line
programs, which adds what Typst makes of a decoder's result: the rendered
diagnostic (stderr, byte for byte), the exit status, and the pages. It needs
the upstream binary (`TYPST_UPSTREAM`, default
`.repos/typst/target/release/typst`) and the port's (`TYPST_PORT`, default
`_build/native/release/build/cli/cli.exe`).

The seeds of `oracle/src/bin/png_corpus.txt` are damaged in a selection of
the oracle's ways (`damage` below), and every damaged file is used in three
documents:

- `file`: `#image("p.png")`, compiled to PDF and PNG;
- `bytes`: `#image(read("p.png", encoding: none))`, compiled to PDF;
- `svg`: `#image("p.svg")` of an SVG that holds the PNG as a data URL,
  compiled to PDF, SVG and PNG (the three exporters read the PNG again, each
  with a decoder of its own: krilla, none, resvg).

A document is `identical` if the two programs end with the same exit status
and write the same stderr, the same SVG bytes and the same PNG pixels (a PDF
is only required to be there or not). Where upstream panics (status 101) or
is killed, the port must end with status 1 and a diagnostic; these are
listed. Prints the table; exits with 1 if anything differs.
"""

import argparse
import base64
import concurrent.futures
import os
import shutil
import struct
import subprocess
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from packages_cli import BadPng, same_pixels  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS = os.path.join(ROOT, "oracle", "src", "bin", "png_corpus.txt")
SCRUBBED = ("TYPST_FONT_PATHS", "TYPST_IGNORE_SYSTEM_FONTS", "TYPST_IGNORE_EMBEDDED_FONTS",
            "TYPST_PACKAGE_PATH", "TYPST_PACKAGE_CACHE_PATH", "TYPST_ROOT", "TYPST_FEATURES",
            "SOURCE_DATE_EPOCH")
SIGNATURE = b"\x89PNG\r\n\x1a\n"


def seeds():
    out = []
    for line in open(CORPUS):
        if line.startswith("=== "):
            out.append([line[4:].strip(), ""])
        elif out:
            out[-1][1] += line.strip()
    return [(name, base64.b64decode(b64)) for name, b64 in out]


def parse(seed):
    chunks = []
    pos = 8
    while pos < len(seed):
        (n,) = struct.unpack(">I", seed[pos:pos + 4])
        chunks.append((seed[pos + 4:pos + 8], seed[pos + 8:pos + 8 + n]))
        pos += 12 + n
    return chunks


def chunk_bytes(ty, data, crc_xor=0):
    return (struct.pack(">I", len(data)) + ty + data
            + struct.pack(">I", zlib.crc32(ty + data) ^ crc_xor))


def build(chunks):
    return SIGNATURE + b"".join(chunk_bytes(t, d) for t, d in chunks)


def flip(data, i, b):
    out = bytearray(data)
    out[i] ^= 1 << b
    return bytes(out)


def damage(seed):
    """A selection of the damage of the oracle (`gen_png_golden.rs`), by name."""
    cases = [("valid", seed)]
    n = len(seed)
    # The signature, the length, type, fields and CRC of the header.
    for i in (0, 1, 7, 8, 11, 12, 15, 16, 19, 20, 23, 24, 25, 26, 27, 28, 29, 32):
        for b in (0, 7) if i in (16, 24, 25) else (2,):
            cases.append((f"flip-{i}.{b}", flip(seed, i, b)))
    for i in sorted({40, n // 2, n - 20, n - 13, n - 9, n - 5, n - 1}):
        if 33 <= i < n:
            cases.append((f"flip-{i}.3", flip(seed, i, 3)))
    for cut in sorted({0, 7, 8, 20, 33, n // 2, n - 20, n - 13, n - 12, n - 8, n - 4, n - 1}):
        if 0 <= cut < n:
            cases.append((f"trunc-{cut}", seed[:cut]))
    chunks = parse(seed)
    # The fields of the header, with the right CRC.
    for p in range(13):
        for b in (0, 7) if p in (3, 7, 8, 9) else (0,):
            c = list(chunks)
            c[0] = (c[0][0], flip(c[0][1], p, b))
            cases.append((f"fix-IHDR-{p}.{b}", build(c)))
    for k, (ty, data) in enumerate(chunks):
        name = f"{k}{ty.decode()}"
        cases.append((f"badcrc-{name}", SIGNATURE + b"".join(
            chunk_bytes(t, d, 1 if j == k else 0) for j, (t, d) in enumerate(chunks))))
        cases.append((f"del-{name}", build(chunks[:k] + chunks[k + 1:])))
        cases.append((f"dup-{name}", build(chunks[:k + 1] + chunks[k:])))
        if k + 1 < len(chunks):
            cases.append((f"swap-{name}", build(chunks[:k] + [chunks[k + 1], chunks[k]] + chunks[k + 2:])))
        cases.append((f"empty-{name}", build(chunks[:k] + [(ty, b"")] + chunks[k + 1:])))
        cases.append((f"grow-{name}", build(chunks[:k] + [(ty, data + b"\0")] + chunks[k + 1:])))
        if ty != b"IDAT" and data:
            cases.append((f"fix-{name}-0.0", build(chunks[:k] + [(ty, flip(data, 0, 0))] + chunks[k + 1:])))
    first = min(k for k, c in enumerate(chunks) if c[0] == b"IDAT")
    last = max(k for k, c in enumerate(chunks) if c[0] == b"IDAT")
    idat = b"".join(d for _, d in chunks[first:last + 1])

    def with_idat(parts):
        return build(chunks[:first] + parts + chunks[last + 1:])

    cases.append(("tail8", build(chunks[:-1]) + bytes(8)))
    cases.append(("tail7", build(chunks[:-1]) + bytes(7)))
    cases.append(("garbage", seed + b"\xaa" * 64))
    cases.append(("idat1", with_idat([(b"IDAT", idat[i:i + 1]) for i in range(len(idat))])))
    half = len(idat) // 2
    cases.append(("idatsep", with_idat([(b"IDAT", idat[:half]), (b"tEXt", b"k\0v"), (b"IDAT", idat[half:])])))
    cases.append(("adler", with_idat([(b"IDAT", flip(idat, len(idat) - 1, 0))])))
    cases.append(("adler0", with_idat([(b"IDAT", idat[:-4] + bytes(4))])))
    cases.append(("zcut-5", with_idat([(b"IDAT", idat[:-5])])))
    cases.append(("zextra", with_idat([(b"IDAT", idat + b"\x55" * 16)])))
    for p in sorted({0, 1, 2, 3, 5, len(idat) // 3, half, len(idat) - 6}):
        if 0 <= p < len(idat):
            cases.append((f"z-{p}.4", with_idat([(b"IDAT", flip(idat, p, 4))])))
    # (Names that differ in more than their case: one directory per file.)
    cases.append(("unknown-critical", build(chunks[:1] + [(b"ABCD", b"xy")] + chunks[1:])))
    cases.append(("unknown-ancillary", build(chunks[:1] + [(b"abCd", b"xy")] + chunks[1:])))
    cases.append(("unknown-escaped", build(chunks[:1] + [(b"A\x80\0D", b"xy")] + chunks[1:])))
    # Other dimensions (an interlaced image no wider than 2^24 + 1 pixels:
    # upstream fills a buffer of a row of the full width first).
    width, height = struct.unpack(">II", chunks[0][1][:8])
    interlaced = chunks[0][1][12] != 0
    dims = [(0, height), (width + 1, height), (width, height + 1), (width, height - 1),
            (65536, 65536), ((1 << 24) + 1, height), (width, 0xFFFFFFFF), (0xFFFFFFFF, 0xFFFFFFFF)]
    if not interlaced:
        dims += [(0x7FFFFFFF, height), (0x7FFFFFFF, 0x7FFFFFFF)]
    for w, h in dims:
        ihdr = struct.pack(">II", w, h) + chunks[0][1][8:]
        cases.append((f"dims-{w}x{h}", build([(b"IHDR", ihdr)] + chunks[1:])))
    return cases


SVG = ('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">'
       '<rect width="40" height="40" fill="#ddd"/>'
       '<image x="4" y="4" width="32" height="32" href="data:image/png;base64,{}"/></svg>\n')
DOCS = {
    "file": ('#set page(width: 60pt, height: 60pt, margin: 5pt)\n#image("p.png", width: 40pt)\n', ("pdf", "png")),
    "bytes": ('#set page(width: 60pt, height: 60pt, margin: 5pt)\n'
              '#image(read("p.png", encoding: none), width: 40pt)\n', ("pdf",)),
    "svg": ('#set page(width: 60pt, height: 60pt, margin: 5pt)\n#image("p.svg", width: 40pt)\n',
            ("pdf", "svg", "png")),
}


def run(binary, cwd, doc, fmt, out):
    env = {k: v for k, v in os.environ.items() if k not in SCRUBBED}
    try:
        r = subprocess.run([binary, "compile", "--ignore-system-fonts", "--creation-timestamp", "0",
                            doc + ".typ", out], cwd=cwd, env=env, capture_output=True, timeout=300)
    except subprocess.TimeoutExpired:
        return ("timeout", b"")
    return (r.returncode, r.stderr)


def compare(case, args):
    """Returns `(name, verdict, detail)` rows for one damaged file."""
    seed, name, data = case
    rows = []
    dirs = {}
    for who in ("up", "port"):
        d = os.path.join(args.out, who, seed, name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "p.png"), "wb") as f:
            f.write(data)
        with open(os.path.join(d, "p.svg"), "w") as f:
            f.write(SVG.format(base64.b64encode(data).decode()))
        for doc, (text, _) in DOCS.items():
            with open(os.path.join(d, doc + ".typ"), "w") as f:
                f.write(text)
        dirs[who] = d
    for doc, (_, formats) in DOCS.items():
        for fmt in formats:
            out = f"{doc}.{fmt}"
            up = run(args.upstream, dirs["up"], doc, fmt, out)
            port = run(args.port, dirs["port"], doc, fmt, out)
            label = f"{seed}/{name} {doc}->{fmt}"
            first = (up[1].decode("utf-8", "replace").strip().splitlines() or [""])[0]
            if up[0] not in (0, 1):
                # Upstream panicked (101) or was killed.
                kind = "upstream panics" if up[0] == 101 else f"upstream ends with {up[0]}"
                port_first = (port[1].decode("utf-8", "replace").strip().splitlines() or [""])[0]
                where = [line for line in up[1].decode("utf-8", "replace").splitlines()
                         if "panicked at" in line or "memory allocation" in line]
                rows.append((label, kind, f"port: status {port[0]}, {port_first}; upstream: {' '.join(where)[:200]}"))
                continue
            if up != port:
                rows.append((label, "DIFFERENT", f"upstream {up[0]}: {up[1]!r}; port {port[0]}: {port[1]!r}"))
                continue
            a = os.path.join(dirs["up"], out)
            b = os.path.join(dirs["port"], out)
            if os.path.exists(a) != os.path.exists(b):
                rows.append((label, "DIFFERENT", "output of one only"))
                continue
            if os.path.exists(a):
                if fmt == "svg" and open(a, "rb").read() != open(b, "rb").read():
                    rows.append((label, "DIFFERENT", "SVG bytes"))
                    continue
                if fmt == "png":
                    try:
                        same = same_pixels(a, b)
                    except BadPng as e:
                        same = False
                        first = str(e)
                    if not same:
                        rows.append((label, "DIFFERENT", "PNG pixels"))
                        continue
            rows.append((label, "identical", f"status {up[0]}" + (f", {first}" if first else "")))
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filter", nargs="*", help="only cases whose `seed/name` contains one of these")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--out", default=os.path.join(ROOT, "_build", "png-damage-cli"))
    ap.add_argument("--tsv")
    ap.add_argument("--upstream", default=os.environ.get(
        "TYPST_UPSTREAM", os.path.join(ROOT, ".repos", "typst", "target", "release", "typst")))
    ap.add_argument("--port", default=os.environ.get(
        "TYPST_PORT", os.path.join(ROOT, "_build", "native", "release", "build", "cli", "cli.exe")))
    args = ap.parse_args()
    for binary in (args.upstream, args.port):
        if not os.path.exists(binary):
            sys.exit(f"png_damage_cli.py: no binary {binary}")
    shutil.rmtree(args.out, ignore_errors=True)
    cases = [(seed, name, data) for seed, bytes_ in seeds() for name, data in damage(bytes_)]
    if args.filter:
        cases = [c for c in cases if any(f in f"{c[0]}/{c[1]}" for f in args.filter)]
    rows = []
    with concurrent.futures.ThreadPoolExecutor(args.j) as pool:
        for r in pool.map(lambda c: compare(c, args), cases):
            rows.extend(r)
    counts = {}
    for _, verdict, _ in rows:
        counts[verdict] = counts.get(verdict, 0) + 1
    if args.tsv:
        with open(args.tsv, "w") as f:
            for row in rows:
                f.write("\t".join(row) + "\n")
    for label, verdict, detail in rows:
        if verdict != "identical":
            print(f"{verdict}\t{label}\t{detail}")
    # Diagnostics by their first line, without what varies with the case.
    import re
    classes = {}
    for label, verdict, detail in rows:
        if verdict == "identical":
            d = re.sub(r"0x[0-9a-f]+", "0x#", detail)
            d = re.sub(r"type: [^,]*,", "type: #,", d)
            d = re.sub(r"\b\d+\b", "#", d) if "status 1" in d else d
            key = (label.split(" ")[1], d)
            classes[key] = classes.get(key, 0) + 1
    print(f"\n{len(cases)} damaged files, {len(rows)} compilations by each program")
    for verdict in sorted(counts):
        print(f"  {counts[verdict]:>6}  {verdict}")
    print("\nidentical, by document and diagnostic:")
    for (doc, d), n in sorted(classes.items(), key=lambda kv: (kv[0][0], -kv[1])):
        print(f"  {n:>6}  {doc}  {d}")
    sys.exit(1 if counts.get("DIFFERENT") else 0)


if __name__ == "__main__":
    main()
