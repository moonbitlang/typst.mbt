#!/usr/bin/env python3
"""Compare the port's CLI with an upstream `typst` binary on the package
documents (tests/packages/docs), end to end.

  scripts/packages_cli.py [-j N] [--no-png] [--out DIR] [filter ...]

The `packages` stage of the runner (tests/runner/packages_stage.mbt) is the
check that CI runs; it compares frames and SVG with goldens of the oracle.
This script is the same comparison through the two command line programs,
which additionally covers what the stage does not: the rendered diagnostics
(stderr, byte for byte), the exit status, the PNG pixels at 72 ppi and the
time both need. It needs

- the upstream binary (`TYPST_UPSTREAM`, default
  `.repos/typst/target/release/typst`: `cargo build --release -p typst-cli`
  in `.repos/typst`),
- the port's (`TYPST_PORT`, default `_build/native/release/build/cli/cli.exe`:
  `moon build cli --target native --release`) and
- the packages (`TYPST_PACKAGES`, default `.repos/typst-packages`:
  `scripts/packages.sh`).

Every document is compiled twice by each program (SVG, then PNG) with
`--ignore-system-fonts --creation-timestamp 0` and the package directory as
both `--package-path` and `--package-cache-path`, so nothing is read from the
network or from the machine's fonts. Outputs go to `_build/packages-cli`.
Prints one line per document and a table (`--tsv FILE` writes it); exits
with 1 if anything differs.
"""

import argparse
import concurrent.futures
import os
import shutil
import struct
import subprocess
import sys
import time
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "tests", "packages", "docs")


def decode_png(path):
    """Size, colour type and the unfiltered bytes of an 8-bit PNG."""
    d = open(path, "rb").read()
    assert d[:8] == b"\x89PNG\r\n\x1a\n"
    i = 8
    idat = b""
    w = h = ct = None
    while i < len(d):
        (n,) = struct.unpack(">I", d[i : i + 4])
        t = d[i + 4 : i + 8]
        body = d[i + 8 : i + 8 + n]
        i += 12 + n
        if t == b"IHDR":
            w, h, bd, ct, _, _, il = struct.unpack(">IIBBBBB", body)
            assert il == 0 and bd == 8
        elif t == b"IDAT":
            idat += body
    bpp = {2: 3, 6: 4, 0: 1, 4: 2}[ct]
    raw = zlib.decompress(idat)
    stride = w * bpp
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]
        line = bytearray(raw[p + 1 : p + 1 + stride])
        p += 1 + stride
        if f == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out += line
        prev = line
    return w, h, ct, bytes(out)


def same_pixels(a, b):
    if open(a, "rb").read() == open(b, "rb").read():
        return True
    return decode_png(a) == decode_png(b)


def run(binary, packages, doc, out_dir, fmt, repeat=1):
    os.makedirs(out_dir, exist_ok=True)
    cmd = [
        binary,
        "compile",
        "--ignore-system-fonts",
        "--package-path",
        packages,
        "--package-cache-path",
        packages,
        "--creation-timestamp",
        "0",
    ]
    if fmt == "png":
        cmd += ["--ppi", "72"]
    # Like the stage: `docs` is the project root (and the working directory,
    # so that the paths in diagnostics do not depend on where the repository
    # is), the document is `<package>/<name>.typ`.
    cmd += ["--root", ".", os.path.relpath(doc, DOCS), os.path.join(out_dir, "p-{0p}." + fmt)]
    best = None
    for _ in range(repeat):
        start = time.time()
        proc = subprocess.run(cmd, cwd=DOCS, capture_output=True)
        elapsed = time.time() - start
        best = elapsed if best is None else min(best, elapsed)
    return proc.returncode, proc.stderr, best


def compare(case, args):
    pkg, name, doc = case
    out = os.path.join(args.out, pkg, name)
    shutil.rmtree(out, ignore_errors=True)
    res = {"case": f"{pkg}/{name}", "problems": []}
    sides = {}
    for side, binary in (("rs", args.upstream), ("mbt", args.port)):
        code, err, secs = run(binary, args.packages, doc, os.path.join(out, side, "svg"), "svg", args.repeat)
        open(os.path.join(out, side + ".stderr"), "wb").write(err)
        sides[side] = (code, err, secs)
        if not args.no_png and code == 0:
            run(binary, args.packages, doc, os.path.join(out, side, "png"), "png")
    (rc, rerr, rsecs), (mc, merr, msecs) = sides["rs"], sides["mbt"]
    res["rs_secs"], res["mbt_secs"] = rsecs, msecs
    res["status"] = rc
    if rc != mc:
        res["problems"].append(f"exit status {rc} vs {mc}")
    if rerr != merr:
        res["problems"].append("diagnostics differ")
    res["warnings"] = rerr.count(b"warning: ")
    res["errors"] = rerr.count(b"error: ")

    def pages(side, fmt):
        d = os.path.join(out, side, fmt)
        return sorted(os.listdir(d)) if os.path.isdir(d) else []

    rp, mp = pages("rs", "svg"), pages("mbt", "svg")
    res["pages"] = len(rp)
    if len(rp) != len(mp):
        res["problems"].append(f"pages {len(rp)} vs {len(mp)}")
    svg_diff = [
        p
        for p in rp
        if p in mp
        and open(os.path.join(out, "rs", "svg", p), "rb").read() != open(os.path.join(out, "mbt", "svg", p), "rb").read()
    ]
    if svg_diff:
        res["problems"].append(f"svg differs on {len(svg_diff)} page(s): {svg_diff[0]}")
    if not args.no_png:
        rq, mq = pages("rs", "png"), pages("mbt", "png")
        if len(rq) != len(mq):
            res["problems"].append(f"png pages {len(rq)} vs {len(mq)}")
        png_diff = [
            p
            for p in rq
            if p in mq and not same_pixels(os.path.join(out, "rs", "png", p), os.path.join(out, "mbt", "png", p))
        ]
        if png_diff:
            res["problems"].append(f"png pixels differ on {len(png_diff)} page(s): {png_diff[0]}")
    return res


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filters", nargs="*", help="substrings of <package>/<document>")
    ap.add_argument("-j", type=int, default=1, help="documents compiled at once (times are only meaningful with 1)")
    ap.add_argument("--repeat", type=int, default=1, help="time the best of N runs")
    ap.add_argument("--no-png", action="store_true")
    ap.add_argument("--out", default=os.path.join(ROOT, "_build", "packages-cli"))
    ap.add_argument("--tsv", help="write the table to this file")
    ap.add_argument("--upstream", default=os.environ.get("TYPST_UPSTREAM", os.path.join(ROOT, ".repos/typst/target/release/typst")))
    ap.add_argument("--port", default=os.environ.get("TYPST_PORT", os.path.join(ROOT, "_build/native/release/build/cli/cli.exe")))
    ap.add_argument("--packages", default=os.environ.get("TYPST_PACKAGES", os.path.join(ROOT, ".repos/typst-packages")))
    args = ap.parse_args()
    # The programs run in the documents' directories.
    args.packages = os.path.abspath(args.packages)
    args.out = os.path.abspath(args.out)
    for what, path in (("upstream binary", args.upstream), ("port binary", args.port), ("packages", args.packages)):
        if not os.path.exists(path):
            sys.exit(f"packages_cli.py: {what} not found: {path}")

    cases = []
    for pkg in sorted(os.listdir(DOCS)):
        d = os.path.join(DOCS, pkg)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".typ"):
                name = f[: -len(".typ")]
                if not args.filters or any(x in f"{pkg}/{name}" for x in args.filters):
                    cases.append((pkg, name, os.path.join(d, f)))

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.j) as pool:
        results = list(pool.map(lambda c: compare(c, args), cases))

    rows = ["case\tpages\tstatus\twarnings\terrors\tupstream_s\tport_s\tratio\tresult"]
    bad = 0
    for r in results:
        ratio = r["mbt_secs"] / r["rs_secs"] if r["rs_secs"] > 0 else 0
        verdict = "identical" if not r["problems"] else "; ".join(r["problems"])
        bad += bool(r["problems"])
        rows.append(
            f"{r['case']}\t{r['pages']}\t{r['status']}\t{r['warnings']}\t{r['errors']}\t{r['rs_secs']:.2f}\t{r['mbt_secs']:.2f}\t{ratio:.2f}\t{verdict}"
        )
    print("\n".join(rows))
    if args.tsv:
        open(args.tsv, "w").write("\n".join(rows) + "\n")
    pages = sum(r["pages"] for r in results)
    rs = sum(r["rs_secs"] for r in results)
    mbt = sum(r["mbt_secs"] for r in results)
    print(
        f"packages-cli: {len(results)} documents, {pages} pages, {len(results) - bad} identical, {bad} differ; "
        f"upstream {rs:.1f} s, port {mbt:.1f} s ({mbt / rs if rs else 0:.2f}x)"
    )
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
