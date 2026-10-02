#!/usr/bin/env python3
"""Generates the WebP decoder test corpus (`oracle/src/bin/webp_corpus.txt`):
synthetic PNG/GIF images encoded with libwebp's `cwebp`, `img2webp` and
`gif2webp` (Homebrew `webp`) with many encoder settings, so that the lossy
(VP8: segments, loop filters, intra modes), lossless (VP8L: transforms,
color cache, meta Huffman codes), alpha (ALPH: filters, compression) and
animation (ANMF) paths of the decoder are exercised. The oracle
(`gen_webp_golden`) decodes them with image-webp.

Usage: python3 scripts/gen_webp_corpus.py
"""
import base64
import os
import random
import struct
import subprocess
import tempfile
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "oracle", "src", "bin", "webp_corpus.txt")


def png(path, w, h, pixels, alpha):
    """Writes an 8-bit RGB(A) PNG; `pixels` yields (r, g, b, a) row-major."""
    raw = bytearray()
    it = iter(pixels)
    for _ in range(h):
        raw.append(0)
        for _ in range(w):
            r, g, b, a = next(it)
            raw += bytes([r, g, b] + ([a] if alpha else []))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6 if alpha else 2, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
    data += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(data)


def gradient(w, h, seed, alpha=False, noise=0):
    rnd = random.Random(seed)
    for y in range(h):
        for x in range(w):
            r = (x * 255 // max(w - 1, 1) + rnd.randint(-noise, noise)) % 256
            g = (y * 255 // max(h - 1, 1) + rnd.randint(-noise, noise)) % 256
            b = ((x + y) * 7 + rnd.randint(-noise, noise)) % 256
            a = 255
            if alpha:
                a = max(0, min(255, 128 + int(127 * ((x - w / 2) / (w / 2 + 1)))))
                if (x // 5 + y // 5) % 3 == 0:
                    a = 0
            yield (r, g, b, a)


def shapes(w, h, seed, alpha=False):
    rnd = random.Random(seed)
    circles = [(rnd.randrange(w), rnd.randrange(h), rnd.randrange(3, max(4, w // 3)),
                (rnd.randrange(256), rnd.randrange(256), rnd.randrange(256)))
               for _ in range(6)]
    for y in range(h):
        for x in range(w):
            col = (240, 240, 230)
            a = 255 if not alpha else 0
            for cx, cy, r, c in circles:
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    col = c
                    a = 255 if not alpha else 90 + (r * 37) % 166
            yield col + (a,)


def palette(w, h, n, seed, alpha=False):
    rnd = random.Random(seed)
    colors = [(rnd.randrange(256), rnd.randrange(256), rnd.randrange(256),
               rnd.choice([0, 128, 255]) if alpha else 255) for _ in range(n)]
    for y in range(h):
        for x in range(w):
            yield colors[(x // 3 + y // 2 * 5 + (x * y) % 3) % n]


def noise(w, h, seed, alpha=False):
    rnd = random.Random(seed)
    for _ in range(w * h):
        yield (rnd.randrange(256), rnd.randrange(256), rnd.randrange(256),
               rnd.randrange(256) if alpha else 255)


def gif(path, w, h, n_colors, seed, transparent=None, frames=1):
    """A GIF with uncompressed-style LZW (clear code every 2^k - 3 pixels)."""
    rnd = random.Random(seed)
    bits = max(2, (n_colors - 1).bit_length())
    pal = bytearray()
    for i in range(1 << bits):
        pal += bytes([rnd.randrange(256), rnd.randrange(256), rnd.randrange(256)])
    out = bytearray(b"GIF89a" + struct.pack("<HH", w, h) + bytes([0x80 | (bits - 1), 0, 0]))
    out += pal
    out += b"\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00"
    for f in range(frames):
        flags = 0x08 | (1 if transparent is not None else 0)
        out += b"\x21\xf9\x04" + bytes([flags]) + struct.pack("<H", 10) + bytes([transparent or 0, 0])
        out += b"\x2c" + struct.pack("<HHHH", 0, 0, w, h) + b"\x00"
        idx = [((x + y + f * 3) // 2 + rnd.randrange(2)) % n_colors for y in range(h) for x in range(w)]
        min_code = bits
        clear = 1 << min_code
        code_size = min_code + 1
        codes = []
        run = 0
        codes.append(clear)
        for i in idx:
            codes.append(i)
            run += 1
            if run == (1 << code_size) - clear - 3:
                codes.append(clear)
                run = 0
        codes.append(clear + 1)
        acc = 0
        nb = 0
        data = bytearray()
        for c in codes:
            acc |= c << nb
            nb += code_size
            while nb >= 8:
                data.append(acc & 0xFF)
                acc >>= 8
                nb -= 8
        if nb:
            data.append(acc & 0xFF)
        out.append(min_code)
        for i in range(0, len(data), 255):
            blk = data[i:i + 255]
            out.append(len(blk))
            out += blk
        out.append(0)
    out.append(0x3B)
    open(path, "wb").write(out)


def main():
    tmp = tempfile.mkdtemp()
    cases = []

    def p(name):
        return os.path.join(tmp, name)

    srcs = {
        "grad37x23": (37, 23, gradient(37, 23, 1, noise=20), False),
        "grad64x48a": (64, 48, gradient(64, 48, 2, alpha=True, noise=8), True),
        "shapes150x100": (150, 100, shapes(150, 100, 3), False),
        "shapes97x61a": (97, 61, shapes(97, 61, 4, alpha=True), True),
        "noise33x17": (33, 17, noise(33, 17, 5), False),
        "noise20x20a": (20, 20, noise(20, 20, 6, alpha=True), True),
        "px1x1": (1, 1, gradient(1, 1, 7), False),
        "px2x2a": (2, 2, gradient(2, 2, 8, alpha=True), True),
        "line17x1": (17, 1, gradient(17, 1, 9, noise=50), False),
        "line1x17": (1, 17, gradient(1, 17, 10, noise=50), False),
        "pal2": (41, 19, palette(41, 19, 2, 11), False),
        "pal4": (41, 19, palette(41, 19, 4, 12), False),
        "pal13a": (41, 19, palette(41, 19, 13, 13, alpha=True), True),
        "pal200": (64, 40, palette(64, 40, 200, 14), False),
    }
    for name, (w, h, px, alpha) in srcs.items():
        png(p(name + ".png"), w, h, list(px), alpha)

    def cwebp(src, name, *args):
        out = p(name + ".webp")
        subprocess.run(["cwebp", "-quiet", *args, p(src + ".png"), "-o", out], check=True)
        cases.append((name, out))

    lossy_opts = [
        ("q75", []),
        ("q5", ["-q", "5"]),
        ("q100", ["-q", "100"]),
        ("m0", ["-m", "0"]),
        ("m6seg1", ["-m", "6", "-segments", "1"]),
        ("nofilter", ["-sns", "0", "-f", "0"]),
        ("f100sharp7", ["-f", "100", "-sharpness", "7"]),
        ("simple", ["-nostrong", "-f", "80"]),
        ("strong", ["-strong", "-f", "40", "-sharpness", "3"]),
        ("sharpyuv", ["-sharp_yuv"]),
    ]
    for src in ["grad37x23", "shapes150x100", "noise33x17", "px1x1", "line17x1", "line1x17"]:
        for opt, args in lossy_opts:
            cwebp(src, f"lossy-{src}-{opt}", *args)
    for src in ["grad64x48a", "shapes97x61a", "noise20x20a", "px2x2a", "pal13a"]:
        for opt, args in [
            ("q75", []),
            ("afnone", ["-alpha_filter", "none"]),
            ("afbest", ["-alpha_filter", "best"]),
            ("am0", ["-alpha_method", "0"]),
            ("aq30", ["-alpha_q", "30"]),
            ("exact", ["-exact", "-q", "50"]),
        ]:
            cwebp(src, f"alpha-{src}-{opt}", *args)
    for src in srcs:
        for opt, args in [
            ("z0", ["-lossless", "-z", "0"]),
            ("z6", ["-lossless", "-z", "6"]),
            ("z9", ["-lossless", "-z", "9"]),
            ("exact", ["-lossless", "-exact"]),
            ("near60", ["-lossless", "-near_lossless", "60"]),
        ]:
            cwebp(src, f"lossless-{src}-{opt}", *args)

    # Animations.
    frames = [p(f"anim{i}.png") for i in range(3)]
    for i, f in enumerate(frames):
        png(f, 40, 30, list(shapes(40, 30, 20 + i, alpha=i == 1)), True)
    for name, args in [
        ("anim-lossy", ["-lossy"]),
        ("anim-lossless", ["-lossless"]),
        ("anim-mixed", ["-mixed"]),
    ]:
        out = p(name + ".webp")
        subprocess.run(["img2webp", "-q", "70", *args, *frames, "-o", out], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        cases.append((name, out))
    gif(p("anim.gif"), 23, 17, 6, 30, transparent=2, frames=3)
    for name, args in [("gif-lossless", []), ("gif-lossy", ["-lossy"])]:
        out = p(name + ".webp")
        subprocess.run(["gif2webp", "-quiet", *args, p("anim.gif"), "-o", out], check=True)
        cases.append((name, out))

    # Truncated and corrupted files.
    for name, src in [("trunc-lossy", "lossy-shapes150x100-q75"),
                      ("trunc-lossless", "lossless-shapes150x100-z6")]:
        data = open(p(src + ".webp"), "rb").read()
        out = p(name + ".webp")
        open(out, "wb").write(data[: len(data) * 2 // 3])
        cases.append((name, out))
    data = bytearray(open(p("lossless-noise33x17-z6.webp"), "rb").read())
    for i in range(40, len(data), 37):
        data[i] ^= 0x5A
    open(p("corrupt-lossless.webp"), "wb").write(data)
    cases.append(("corrupt-lossless", p("corrupt-lossless.webp")))

    with open(OUT, "w") as f:
        for name, path in cases:
            f.write(f"=== {name}\n")
            b = base64.b64encode(open(path, "rb").read()).decode()
            for i in range(0, len(b), 76):
                f.write(b[i:i + 76] + "\n")
    print(f"{len(cases)} cases -> {OUT}")


main()
