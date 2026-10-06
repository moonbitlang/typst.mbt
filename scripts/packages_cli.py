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
  `scripts/packages.sh`; the default directory is verified against the
  manifest first with `scripts/packages.sh --check`).

Every document is compiled twice by each program (SVG, then PNG) like the
stage compiles it: `--ignore-system-fonts`, `--creation-timestamp 43200`
(the date of the test world), `docs` as the project root, and the package
directory as both `--package-path` and `--package-cache-path`; the
environment variables that add fonts or packages (`TYPST_FONT_PATHS`,
`TYPST_IGNORE_EMBEDDED_FONTS`, `TYPST_PACKAGE_*`) are removed. With the
packages of the manifest in place nothing is downloaded (an upstream binary
would try to download a package that is missing).

A document is `identical` if, for both formats, the two programs end with
the same exit status (1 for `error-*.typ`, which fail on purpose, else 0;
never a signal), write the same stderr and the same set of page files with
the same bytes (SVG) or the same pixels (PNG, decoded), and a document that
compiles has at least one page and as many PNG as SVG pages. Outputs go to
`_build/packages-cli`. Prints the table (`--tsv FILE` also writes it); exits
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
DEFAULT_PACKAGES = os.path.join(ROOT, ".repos", "typst-packages")
# Variables of typst-cli that change the fonts or the packages a run sees.
SCRUBBED = ("TYPST_FONT_PATHS", "TYPST_IGNORE_SYSTEM_FONTS", "TYPST_IGNORE_EMBEDDED_FONTS",
            "TYPST_PACKAGE_PATH", "TYPST_PACKAGE_CACHE_PATH", "TYPST_ROOT", "TYPST_FEATURES",
            "SOURCE_DATE_EPOCH")


class BadPng(Exception):
    pass


def decode_png(path):
    """Width, height and the RGBA pixels of an 8-bit, non-interlaced PNG
    (grey, grey+alpha, RGB or RGBA; no palette, no `tRNS`). Raises BadPng on
    anything else or on malformed data."""
    d = open(path, "rb").read()
    if d[:8] != b"\x89PNG\r\n\x1a\n":
        raise BadPng(f"{path}: not a PNG")
    i = 8
    idat = b""
    header = None
    ended = False
    while i + 12 <= len(d):
        (n,) = struct.unpack(">I", d[i : i + 4])
        kind = d[i + 4 : i + 8]
        body = d[i + 8 : i + 8 + n]
        crc = d[i + 8 + n : i + 12 + n]
        if len(body) != n or len(crc) != 4 or struct.pack(">I", zlib.crc32(kind + body)) != crc:
            raise BadPng(f"{path}: bad chunk {kind!r}")
        i += 12 + n
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        elif kind in (b"PLTE", b"tRNS"):
            raise BadPng(f"{path}: {kind.decode()} chunks are not supported")
        elif kind == b"IEND":
            ended = True
            break
    if header is None or not ended:
        raise BadPng(f"{path}: truncated")
    w, h, depth, ct, compression, filtering, interlace = header
    if depth != 8 or ct not in (0, 2, 4, 6) or compression or filtering or interlace:
        raise BadPng(f"{path}: unsupported format {header}")
    bpp = {0: 1, 2: 3, 4: 2, 6: 4}[ct]
    try:
        raw = zlib.decompress(idat)
    except zlib.error as e:
        raise BadPng(f"{path}: {e}")
    stride = w * bpp
    if len(raw) != h * (stride + 1):
        raise BadPng(f"{path}: {len(raw)} bytes of image data, expected {h * (stride + 1)}")
    rows = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]
        line = bytearray(raw[p + 1 : p + 1 + stride])
        p += 1 + stride
        if f == 0:
            pass
        elif f == 1:
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
        else:
            raise BadPng(f"{path}: filter type {f}")
        rows += line
        prev = line
    if ct == 6:
        rgba = bytes(rows)
    else:
        out = bytearray(w * h * 4)
        for k in range(w * h):
            px = rows[k * bpp : (k + 1) * bpp]
            if ct == 0:
                out[4 * k : 4 * k + 4] = bytes((px[0], px[0], px[0], 255))
            elif ct == 4:
                out[4 * k : 4 * k + 4] = bytes((px[0], px[0], px[0], px[1]))
            else:
                out[4 * k : 4 * k + 4] = bytes((px[0], px[1], px[2], 255))
        rgba = bytes(out)
    return w, h, rgba


def same_pixels(a, b):
    """Whether the port's PNG `b` has the pixels of upstream's `a`. Equal
    files need no decoding (upstream's file is the reference); otherwise
    both must decode."""
    with open(a, "rb") as fa, open(b, "rb") as fb:
        if fa.read() == fb.read():
            return True
    return decode_png(a) == decode_png(b)


def run(binary, packages, doc, out_dir, fmt, repeat=1):
    """Compile once per repetition, each into an empty directory: the exit
    status, stderr, the pages `{name: bytes}` and the best time. Raises if
    the repetitions disagree."""
    cmd = [
        binary,
        "compile",
        "--ignore-system-fonts",
        "--package-path",
        packages,
        "--package-cache-path",
        packages,
        "--creation-timestamp",
        "43200",
    ]
    if fmt == "png":
        cmd += ["--ppi", "72"]
    # Like the stage: `docs` is the project root (and the working directory,
    # so that the paths in diagnostics do not depend on where the repository
    # is), the document is `<package>/<name>.typ`.
    cmd += ["--root", ".", os.path.relpath(doc, DOCS), os.path.join(out_dir, "p-{0p}." + fmt)]
    env = {k: v for k, v in os.environ.items() if k not in SCRUBBED}
    best = None
    first = None
    for _ in range(repeat):
        if os.path.exists(out_dir):
            shutil.rmtree(out_dir)
        os.makedirs(out_dir)
        start = time.time()
        proc = subprocess.run(cmd, cwd=DOCS, env=env, capture_output=True)
        elapsed = time.time() - start
        best = elapsed if best is None else min(best, elapsed)
        pages = {}
        for name in sorted(os.listdir(out_dir)):
            with open(os.path.join(out_dir, name), "rb") as f:
                pages[name] = f.read()
        result = (proc.returncode, proc.stderr, pages)
        if first is None:
            first = result
        elif result != first:
            raise RuntimeError(f"{binary} is not deterministic on {doc} ({fmt})")
    return first + (best,)


def compare(case, args):
    pkg, name, doc = case
    out = os.path.join(args.out, pkg, name)
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(out)
    res = {"case": f"{pkg}/{name}", "problems": []}
    problems = res["problems"]
    expected = 1 if name.startswith("error-") else 0
    formats = ["svg"] if args.no_png else ["svg", "png"]
    runs = {}
    for fmt in formats:
        for side, binary in (("rs", args.upstream), ("mbt", args.port)):
            try:
                runs[fmt, side] = run(
                    binary, args.packages, doc, os.path.join(out, side, fmt), fmt, args.repeat if fmt == "svg" else 1
                )
            except RuntimeError as e:
                problems.append(str(e))
                runs[fmt, side] = (None, b"", {}, 0.0)
            with open(os.path.join(out, f"{side}.{fmt}.stderr"), "wb") as f:
                f.write(runs[fmt, side][1])
    rc, rerr, rpages, rsecs = runs["svg", "rs"]
    mc, merr, mpages, msecs = runs["svg", "mbt"]
    res["rs_secs"], res["mbt_secs"] = rsecs, msecs
    res["status"] = rc
    res["pages"] = len(rpages)
    res["warnings"] = rerr.count(b"warning: ")
    res["errors"] = rerr.count(b"error: ")
    for fmt in formats:
        rc, rerr, rpages, _ = runs[fmt, "rs"]
        mc, merr, mpages, _ = runs[fmt, "mbt"]
        for side, code in (("upstream", rc), ("port", mc)):
            if code != expected:
                problems.append(f"{fmt}: {side} exit status {code}, expected {expected}")
        if rerr != merr:
            problems.append(f"{fmt}: diagnostics differ")
        if sorted(rpages) != sorted(mpages):
            problems.append(f"{fmt}: pages {len(rpages)} vs {len(mpages)} ({sorted(set(rpages) ^ set(mpages))[:3]})")
        if expected == 0 and not rpages:
            problems.append(f"{fmt}: no pages")
        if expected == 1 and (rpages or mpages):
            problems.append(f"{fmt}: pages of a document that fails")
        differ = []
        for page in sorted(set(rpages) & set(mpages)):
            if fmt == "svg":
                same = rpages[page] == mpages[page]
            else:
                try:
                    same = same_pixels(os.path.join(out, "rs", fmt, page), os.path.join(out, "mbt", fmt, page))
                except BadPng as e:
                    problems.append(str(e))
                    same = True
            if not same:
                differ.append(page)
        if differ:
            what = "bytes" if fmt == "svg" else "pixels"
            problems.append(f"{fmt}: {what} differ on {len(differ)} page(s): {differ[0]}")
    if not args.no_png and len(runs["png", "rs"][2]) != len(runs["svg", "rs"][2]):
        problems.append(f"{len(runs['svg', 'rs'][2])} svg pages but {len(runs['png', 'rs'][2])} png pages")
    return res


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filters", nargs="*", help="substrings of <package>/<document>")
    ap.add_argument("-j", type=int, default=1, help="documents compiled at once (times are only meaningful with 1)")
    ap.add_argument("--repeat", type=int, default=1, help="time the best of N SVG runs")
    ap.add_argument("--no-png", action="store_true")
    ap.add_argument("--out", default=os.path.join(ROOT, "_build", "packages-cli"))
    ap.add_argument("--tsv", help="write the table to this file")
    ap.add_argument("--upstream", default=os.environ.get("TYPST_UPSTREAM", os.path.join(ROOT, ".repos/typst/target/release/typst")))
    ap.add_argument("--port", default=os.environ.get("TYPST_PORT", os.path.join(ROOT, "_build/native/release/build/cli/cli.exe")))
    ap.add_argument("--packages", default=os.environ.get("TYPST_PACKAGES", DEFAULT_PACKAGES))
    args = ap.parse_args()
    # The programs run in `docs`: no path may depend on the directory this
    # script is called from.
    for attr in ("upstream", "port", "packages", "out"):
        setattr(args, attr, os.path.abspath(getattr(args, attr)))
    for what, path in (("upstream binary", args.upstream), ("port binary", args.port), ("packages", args.packages)):
        if not os.path.exists(path):
            sys.exit(f"packages_cli.py: {what} not found: {path}")
    if os.path.realpath(args.packages) == os.path.realpath(DEFAULT_PACKAGES):
        # Exactly the pinned packages (so nothing is missing, and upstream
        # downloads nothing).
        check = subprocess.run([os.path.join(ROOT, "scripts", "packages.sh"), "--check"], capture_output=True, text=True)
        if check.returncode != 0:
            sys.exit("packages_cli.py: " + check.stderr.strip())

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
    if not cases:
        sys.exit("packages_cli.py: no document matches")

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.j)) as pool:
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
        with open(args.tsv, "w") as f:
            f.write("\n".join(rows) + "\n")
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
