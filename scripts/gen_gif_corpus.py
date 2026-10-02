#!/usr/bin/env python3
"""Generates the GIF decoder test corpus (`oracle/src/bin/gif_corpus.txt`):
synthetic GIFs with a real LZW encoder (table growth up to 4096 entries,
with and without clear codes when the table is full, KwKwK codes), local
and global palettes, transparency, interlacing, frame offsets, several
frames, extension blocks, and broken files. The oracle (`gen_webp_golden`)
decodes their first frame with the `gif` crate like resvg.

Usage: python3 scripts/gen_gif_corpus.py
"""
import base64
import os
import random
import struct

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "oracle", "src", "bin", "gif_corpus.txt")


def lzw(indices, min_code, clear_when_full=True, end_code=True, initial_clear=True):
    clear = 1 << min_code
    end = clear + 1
    codes = []
    if initial_clear:
        codes.append((clear, min_code + 1))
    table = {(i,): i for i in range(clear)}
    next_code = end + 1
    size = min_code + 1
    w = ()
    for k in indices:
        wk = w + (k,)
        if wk in table:
            w = wk
            continue
        codes.append((table[w], size))
        if next_code < 4096:
            table[wk] = next_code
            next_code += 1
            if next_code > (1 << size) and size < 12:
                size += 1
        elif clear_when_full:
            codes.append((clear, size))
            table = {(i,): i for i in range(clear)}
            next_code = end + 1
            size = min_code + 1
        w = (k,)
    if w:
        codes.append((table[w], size))
        if next_code < 4096:
            next_code += 1
            if next_code > (1 << size) and size < 12:
                size += 1
    if end_code:
        codes.append((end, size))
    acc = 0
    nb = 0
    data = bytearray()
    for c, s in codes:
        acc |= c << nb
        nb += s
        while nb >= 8:
            data.append(acc & 0xFF)
            acc >>= 8
            nb -= 8
    if nb:
        data.append(acc & 0xFF)
    return bytes(data)


def sub_blocks(data, block=255):
    out = bytearray()
    for i in range(0, len(data), block):
        blk = data[i:i + block]
        out.append(len(blk))
        out += blk
    out.append(0)
    return bytes(out)


def palette(n, rnd):
    return bytes(rnd.randrange(256) for _ in range(3 * n))


def image(w, h, n, rnd, kind):
    if kind == "noise":
        return [rnd.randrange(n) for _ in range(w * h)]
    if kind == "runs":
        return [((x // 7) + (y // 3)) % n for y in range(h) for x in range(w)]
    return [(x * y + x // 2) % n for y in range(h) for x in range(w)]


def gif(w, h, frames, gpal_bits=None, ver=b"GIF89a", ext=b"", trailer=True, bg=0):
    out = bytearray(ver + struct.pack("<HH", w, h))
    if gpal_bits is not None:
        rnd = random.Random(w * 31 + h)
        out += bytes([0x80 | 0x70 | (gpal_bits - 1), bg, 0]) + palette(1 << gpal_bits, rnd)
    else:
        out += bytes([0x70, bg, 0])
    out += ext
    for f in frames:
        out += f
    if trailer:
        out.append(0x3B)
    return bytes(out)


def frame(x, y, w, h, indices, min_code, lpal_bits=None, interlace=False,
          transparent=None, control=True, rnd=None, **lzw_args):
    out = bytearray()
    if control:
        flags = (2 << 2) | (1 if transparent is not None else 0)
        out += b"\x21\xf9\x04" + bytes([flags]) + struct.pack("<H", 5)
        out += bytes([transparent or 0, 0])
    flags = (0x40 if interlace else 0)
    if lpal_bits is not None:
        flags |= 0x80 | (lpal_bits - 1)
    out += b"\x2c" + struct.pack("<HHHH", x, y, w, h) + bytes([flags])
    if lpal_bits is not None:
        out += palette(1 << lpal_bits, rnd)
    out.append(min_code)
    out += sub_blocks(lzw(indices, min_code, **lzw_args))
    return bytes(out)


def main():
    cases = []
    rnd = random.Random(42)
    # Basic sizes, palettes and code sizes.
    for (w, h, bits, kind) in [(1, 1, 1, "noise"), (5, 3, 2, "noise"), (19, 12, 4, "runs"),
                               (64, 64, 8, "noise"), (100, 80, 8, "runs"), (33, 7, 3, "mod"),
                               (90, 50, 8, "mod")]:
        n = 1 << bits
        idx = image(w, h, n, rnd, kind)
        min_code = max(2, bits)
        cases.append((f"basic-{w}x{h}-{bits}bit-{kind}",
                      gif(w, h, [frame(0, 0, w, h, idx, min_code)], gpal_bits=bits)))
    # Table full without clear (deferred clear), no end code, no initial clear.
    idx = image(80, 80, 256, rnd, "noise")
    cases.append(("deferred-clear", gif(80, 80, [frame(0, 0, 80, 80, idx, 8, clear_when_full=False)], gpal_bits=8)))
    idx = image(40, 30, 16, rnd, "runs")
    cases.append(("no-end-code", gif(40, 30, [frame(0, 0, 40, 30, idx, 4, end_code=False)], gpal_bits=4)))
    cases.append(("no-initial-clear", gif(40, 30, [frame(0, 0, 40, 30, idx, 4, initial_clear=False)], gpal_bits=4)))
    # Transparency, local palette, interlace, offsets.
    idx = image(23, 17, 8, rnd, "mod")
    cases.append(("transparent", gif(23, 17, [frame(0, 0, 23, 17, idx, 3, transparent=3)], gpal_bits=3)))
    cases.append(("local-palette", gif(23, 17, [frame(0, 0, 23, 17, idx, 3, lpal_bits=3, rnd=rnd)])))
    cases.append(("local-small-palette", gif(23, 17, [frame(0, 0, 23, 17, idx, 3, lpal_bits=2, rnd=rnd)], gpal_bits=3)))
    cases.append(("interlaced", gif(23, 17, [frame(0, 0, 23, 17, idx, 3, interlace=True)], gpal_bits=3)))
    idx2 = image(10, 9, 8, rnd, "noise")
    cases.append(("offset-frame", gif(23, 17, [frame(4, 5, 10, 9, idx2, 3)], gpal_bits=3)))
    cases.append(("frame-outside-screen", gif(10, 10, [frame(6, 6, 10, 9, idx2, 3)], gpal_bits=3)))
    cases.append(("no-control", gif(23, 17, [frame(0, 0, 23, 17, idx, 3, control=False)], gpal_bits=3)))
    cases.append(("multi-frame", gif(23, 17, [frame(0, 0, 23, 17, idx, 3), frame(2, 2, 10, 9, idx2, 3, transparent=0)], gpal_bits=3)))
    cases.append(("gif87a", gif(23, 17, [frame(0, 0, 23, 17, idx, 3, control=False)], gpal_bits=3, ver=b"GIF87a")))
    # Extension blocks.
    app = b"\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00"
    comment = b"\x21\xfe" + sub_blocks(b"hello world" * 30, block=100)
    text = b"\x21\x01\x0c" + bytes(12) + sub_blocks(b"plain")
    cases.append(("extensions", gif(23, 17, [frame(0, 0, 23, 17, idx, 3)], gpal_bits=3, ext=app + comment + text)))
    cases.append(("unknown-extension", gif(23, 17, [frame(0, 0, 23, 17, idx, 3)], gpal_bits=3, ext=b"\x21\x77\x01\x00\x00")))
    cases.append(("bad-control-length", gif(23, 17, [b"\x21\xf9\x03\x00\x00\x00\x00" + frame(0, 0, 23, 17, idx, 3, control=False)], gpal_bits=3)))
    # Broken files.
    good = gif(64, 64, [frame(0, 0, 64, 64, image(64, 64, 256, rnd, "noise"), 8)], gpal_bits=8)
    cases.append(("truncated-data", good[: len(good) * 2 // 3]))
    cases.append(("truncated-header", good[:20]))
    cases.append(("no-palette", gif(23, 17, [frame(0, 0, 23, 17, idx, 3)])))
    cases.append(("no-image", gif(23, 17, [], gpal_bits=3)))
    cases.append(("no-trailer", gif(23, 17, [frame(0, 0, 23, 17, idx, 3)], gpal_bits=3, trailer=False)))
    short = image(23, 17, 8, rnd, "mod")[:200]
    cases.append(("short-data", gif(23, 17, [frame(0, 0, 23, 17, short, 3)], gpal_bits=3)))
    cases.append(("long-data", gif(10, 10, [frame(0, 0, 10, 10, idx, 3)], gpal_bits=3)))
    cases.append(("bad-min-code-size", gif(23, 17, [frame(0, 0, 23, 17, idx, 12)], gpal_bits=3)))
    cases.append(("zero-size-frame", gif(23, 17, [frame(0, 0, 0, 0, [], 3)], gpal_bits=3)))
    bad = bytearray(gif(23, 17, [frame(0, 0, 23, 17, idx, 3)], gpal_bits=3))
    bad[50] ^= 0xFF
    cases.append(("bad-code", bytes(bad)))
    cases.append(("bad-magic", b"GIF88a" + good[6:]))
    with open(OUT, "w") as f:
        for name, data in cases:
            f.write(f"=== {name}\n")
            b = base64.b64encode(data).decode()
            for i in range(0, len(b), 76):
                f.write(b[i:i + 76] + "\n")
    print(f"{len(cases)} cases -> {OUT}")


main()
