#!/usr/bin/env python3
"""Generates the seeds of the damaged-PNG oracle
(`oracle/src/bin/png_corpus.txt`): small valid PNGs of every colour type and
bit depth, interlaced and not, with stored, fixed-Huffman and
dynamic-Huffman image data, with all five row filters, with the ancillary
chunks the `png` crate parses (`tRNS`, `gAMA`, `cHRM`, `sRGB`, `iCCP`,
`sBIT`, `pHYs`, `bKGD`, `eXIf`, `tEXt`, `zTXt`, `iTXt`, `cICP`, `mDCV`,
`cLLI`) and one it skips (`tIME`), two images whose rows leave the
decompressor's window while it is still running, and an APNG.

The oracle (`gen_png_golden`) damages each seed in the same ways as the
test (`codecs/png_damage_test.mbt`) and records what the `image` crate
makes of every damaged file, decoding like upstream `RasterImage::new`.

Usage: python3 scripts/gen_png_corpus.py
"""
import base64
import os
import random
import struct
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "oracle", "src", "bin", "png_corpus.txt")

SAMPLES = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
PASSES = [(8, 0, 8, 0), (8, 4, 8, 0), (4, 0, 8, 4), (4, 2, 4, 0), (2, 0, 4, 2), (2, 1, 2, 0), (1, 0, 2, 1)]


def chunk(ty, data):
    return struct.pack(">I", len(data)) + ty + data + struct.pack(">I", zlib.crc32(ty + data))


def pack_row(samples, depth):
    """Packs the samples of a row (integers below `1 << depth`)."""
    if depth == 16:
        return b"".join(struct.pack(">H", s) for s in samples)
    if depth == 8:
        return bytes(samples)
    out = bytearray()
    acc = 0
    n = 0
    for s in samples:
        acc = (acc << depth) | s
        n += depth
        if n == 8:
            out.append(acc)
            acc = 0
            n = 0
    if n:
        out.append(acc << (8 - n))
    return bytes(out)


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def filter_row(kind, bpp, prev, row):
    out = bytearray([kind])
    for i, x in enumerate(row):
        a = row[i - bpp] if i >= bpp else 0
        b = prev[i] if prev else 0
        c = prev[i - bpp] if prev and i >= bpp else 0
        pred = [0, a, b, (a + b) // 2, paeth(a, b, c)][kind]
        out.append((x - pred) & 0xFF)
    return bytes(out)


def raw_data(w, h, depth, color, interlace, pixel, filters):
    """The filtered rows of an image whose sample `c` of pixel (x, y) is
    `pixel(x, y, c)`."""
    n = SAMPLES[color]
    bpp = max(1, n * depth // 8)
    out = bytearray()
    count = 0
    passes = PASSES if interlace else [(1, 0, 1, 0)]
    for (xs, xo, ys, yo) in passes:
        prev = None
        for y in range(yo, h, ys):
            xsr = range(xo, w, xs)
            if not xsr:
                break
            row = pack_row([pixel(x, y, c) for x in xsr for c in range(n)], depth)
            out += filter_row(filters[count % len(filters)], bpp, prev, row)
            count += 1
            prev = row
    return bytes(out)


def deflate(raw, mode):
    if mode == "stored":
        return zlib.compress(raw, 0)
    strategy = zlib.Z_FIXED if mode == "fixed" else zlib.Z_DEFAULT_STRATEGY
    c = zlib.compressobj(9, zlib.DEFLATED, 15, 9, strategy)
    return c.compress(raw) + c.flush()


def png(w, h, depth, color, pixel, interlace=False, mode="dynamic", filters=(0, 1, 2, 3, 4),
        before=(), after=(), split=None):
    """`before`: chunks between IHDR and IDAT; `after`: between IDAT and
    IEND; `split`: the size of the IDAT chunks."""
    data = deflate(raw_data(w, h, depth, color, interlace, pixel, filters), mode)
    split = split or len(data)
    idat = b"".join(chunk(b"IDAT", data[i:i + split]) for i in range(0, len(data), split))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, depth, color, 0, 0, int(interlace)))
            + b"".join(chunk(t, d) for (t, d) in before) + idat
            + b"".join(chunk(t, d) for (t, d) in after) + chunk(b"IEND", b""))


def noise(rnd, depth):
    table = [rnd.randrange(1 << depth) for _ in range(4096)]
    return lambda x, y, c: table[(x * 31 + y * 17 + c * 7) % 4096]


def main():
    rnd = random.Random(7)
    cases = []

    def add(name, data):
        cases.append((name, data))

    plte = lambda n: bytes(rnd.randrange(256) for _ in range(3 * n))
    text = (b"tEXt", b"Title\0damaged")
    add("g1", png(13, 9, 1, 0, noise(rnd, 1), mode="stored", before=[(b"tRNS", b"\0\1")]))
    add("g2i", png(11, 10, 2, 0, noise(rnd, 2), interlace=True))
    add("g4", png(9, 7, 4, 0, noise(rnd, 4), mode="fixed",
                  before=[(b"gAMA", struct.pack(">I", 45455)), text]))
    add("g8i", png(7, 9, 8, 0, noise(rnd, 3), interlace=True, mode="stored",
                   before=[(b"tRNS", b"\0\5")]))
    add("g16", png(5, 6, 16, 0, noise(rnd, 9), before=[(b"tRNS", b"\0\7"),
                                                       (b"pHYs", struct.pack(">IIB", 3780, 3780, 1))]))
    icc = b"iccp\0\0" + zlib.compress(bytes(range(48)))
    add("rgb8", png(8, 8, 8, 2, noise(rnd, 2), mode="stored", split=70,
                    before=[(b"gAMA", struct.pack(">I", 45455)), (b"iCCP", icc),
                            (b"eXIf", b"MM\0*\0\0\0\x08\0\0"), text, (b"tRNS", b"\0\1\0\2\0\3")]))
    add("rgb8i", png(10, 6, 8, 2, noise(rnd, 8), interlace=True))
    add("rgb16i", png(4, 5, 16, 2, noise(rnd, 11), interlace=True, mode="fixed",
                      before=[(b"sBIT", b"\x0b\x0b\x0b"),
                              (b"cHRM", struct.pack(">8I", 31270, 32900, 64000, 33000, 30000, 60000, 15000, 6000)),
                              (b"tRNS", b"\0\1\0\2\0\3")]))
    add("p1", png(17, 5, 1, 3, noise(rnd, 1), mode="stored", before=[(b"PLTE", plte(2))]))
    add("p2i", png(9, 9, 2, 3, noise(rnd, 2), interlace=True,
                   before=[(b"PLTE", plte(4)), (b"tRNS", b"\x10\x80\xf0")]))
    add("p4", png(12, 6, 4, 3, noise(rnd, 4), mode="fixed",
                  before=[(b"PLTE", plte(16)), (b"bKGD", b"\3"),
                          (b"zTXt", b"Comment\0\0" + zlib.compress(b"compressed text"))]))
    add("p8i", png(6, 10, 8, 3, noise(rnd, 5), interlace=True, mode="stored",
                   before=[(b"PLTE", plte(20)), (b"tRNS", bytes(range(0, 200, 10))),
                           (b"iTXt", b"Note\0\0\0en\0Notiz\0text \xc3\xa9")]))
    add("ga8", png(6, 6, 8, 4, noise(rnd, 8), before=[(b"sRGB", b"\0")]))
    add("ga16i", png(5, 5, 16, 4, noise(rnd, 16), interlace=True, mode="stored"))
    add("rgba8i", png(9, 7, 8, 6, noise(rnd, 8), interlace=True, mode="fixed",
                      before=[(b"pHYs", struct.pack(">IIB", 2835, 2835, 1)),
                              (b"tIME", struct.pack(">HBBBBB", 2026, 10, 7, 12, 0, 0))]))
    add("rgba16", png(4, 4, 16, 6, noise(rnd, 16),
                      before=[(b"cICP", bytes([1, 13, 0, 1])),
                              (b"mDCV", struct.pack(">8H2I", 35400, 14600, 8500, 39850, 6550, 2300,
                                                    15635, 16450, 10000000, 1)),
                              (b"cLLI", struct.pack(">2I", 10000000, 2500000))]))
    # More rows than the decompressor's window of 32 KiB and than the 128
    # KiB after which the decoder moves its buffer: rows are unfiltered
    # while image data is still read.
    add("big", png(300, 200, 8, 2, lambda x, y, c: ((x // 60) * 40 + (y // 25) * 9 + c * 80) & 0xFF,
                   split=300, filters=(4, 1, 2, 3, 0, 4)))
    add("bigi", png(400, 450, 8, 0, lambda x, y, c: ((x // 80) * 50 + (y // 64) * 30) & 0xFF,
                    interlace=True, split=400))
    # An APNG: the default image is the first frame; a second frame follows.
    rgba = noise(rnd, 8)
    frame = deflate(raw_data(4, 4, 8, 6, False, rgba, (0, 1, 2, 3, 4)), "dynamic")
    fctl = lambda seq: struct.pack(">IIIIIHHBB", seq, 4, 4, 0, 0, 1, 10, 0, 0)
    add("apng", png(4, 4, 8, 6, rgba,
                    before=[(b"acTL", struct.pack(">II", 2, 0)), (b"fcTL", fctl(0))],
                    after=[(b"fcTL", fctl(1)), (b"fdAT", struct.pack(">I", 2) + frame)]))

    with open(OUT, "w") as f:
        for name, data in cases:
            f.write(f"=== {name}\n")
            b64 = base64.b64encode(data).decode()
            for i in range(0, len(b64), 76):
                f.write(b64[i:i + 76] + "\n")
    total = sum(len(d) for _, d in cases)
    print(f"{len(cases)} seeds, {total} bytes -> {OUT}")
    for name, data in cases:
        print(f"  {name}: {len(data)}")


if __name__ == "__main__":
    main()
