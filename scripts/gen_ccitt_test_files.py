#!/usr/bin/env python3
"""Generate CCITT fax test streams for `hayro/ccitt/oracle_test.mbt`.

Writes deterministic bi-level images encoded with a small T.4/T.6 encoder
(Group 3 1D (MH), Group 3 2D (MR) and Group 4 (MMR), with and without EOLs,
byte alignment, RTC/EOFB, black-is-1, plus truncated and corrupted variants)
to `hayro/ccitt/testdata/files/` and the decode settings of every case to
`hayro/ccitt/testdata/cases.tsv`
(`file<TAB>columns<TAB>rows<TAB>k<TAB>end_of_line<TAB>byte_align<TAB>end_of_block<TAB>black_is_1`).

The expected decodings come from the real hayro-ccitt:
`cargo run --release --offline --bin gen_hayro_codec_tests -- ccitt ../hayro/ccitt/testdata/cases.tsv > ../hayro/ccitt/testdata/oracle.tsv`
(in `oracle/`). The code tables are read from
`hayro/ccitt/state_machine.mbt`.
"""

import os
import random
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "hayro/ccitt/testdata")


def tables():
    src = open(os.path.join(ROOT, "hayro/ccitt/state_machine.mbt")).read()
    out = {}
    for name in ["white_terminating", "white_makeup", "black_terminating",
                 "black_makeup", "common_makeup"]:
        body = re.search(r"let " + name + r" : FixedArray\[\(Int, Int, Int\)\] = \[(.*?)\]", src, re.S).group(1)
        out[name] = {int(r): (int(l), int(c, 2)) for r, l, c in
                     re.findall(r"\((\d+), (\d+), 0b([01]+)\)", body)}
    return out


T = tables()


class Bits:
    def __init__(self):
        self.bits = []

    def put(self, length, code):
        for i in range(length - 1, -1, -1):
            self.bits.append((code >> i) & 1)

    def put_str(self, s):
        for ch in s:
            self.bits.append(int(ch))

    def align(self):
        while len(self.bits) % 8:
            self.bits.append(0)

    def to_bytes(self):
        bits = self.bits + [0] * (-len(self.bits) % 8)
        return bytes(int("".join(map(str, bits[i:i + 8])), 2) for i in range(0, len(bits), 8))


def put_run(bits, run, white):
    term = T["white_terminating" if white else "black_terminating"]
    makeup = dict(T["white_makeup" if white else "black_makeup"])
    makeup.update(T["common_makeup"])
    while run >= 64:
        m = min(run - run % 64, 2560)
        bits.put(*makeup[m])
        run -= m
    bits.put(*term[run])


def changes(line):
    """Changing elements: positions where the color differs from the previous
    pixel (an imaginary white pixel precedes the line); 1 = black."""
    prev = 0
    out = []
    for i, p in enumerate(line):
        if p != prev:
            out.append(i)
        prev = p
    return out


def encode_1d(bits, line):
    w = len(line)
    pos = 0
    white = True
    while pos < w:
        end = pos
        color = 0 if white else 1
        while end < w and line[end] == color:
            end += 1
        put_run(bits, end - pos, white)
        pos = end
        white = not white
    # A line that ends with a white run still needs nothing more; if the
    # coding ended with a black run, the decoder stops at the line width.


def encode_2d(bits, line, ref):
    w = len(line)
    cl = changes(line)
    rl = changes(ref)

    def color_at(l, i):
        return l[i] if 0 <= i < w else 0

    def next_change(chs, after):
        for c in chs:
            if c > after:
                return c
        return w

    a0 = -1
    color = 0
    while True:
        a1 = next_change(cl, a0)
        # b1: first change on the reference line right of a0 with the
        # opposite color of a0's color.
        b1 = w
        for c in rl:
            if c > a0 and color_at(ref, c) != color:
                b1 = c
                break
        b2 = next_change(rl, b1)
        if b2 < a1:
            bits.put_str("0001")
            a0 = b2
        elif abs(a1 - b1) <= 3:
            d = a1 - b1
            bits.put_str({0: "1", 1: "011", 2: "000011", 3: "0000011",
                          -1: "010", -2: "000010", -3: "0000010"}[d])
            a0 = a1
            color = 1 - color
        else:
            a2 = next_change(cl, a1)
            bits.put_str("001")
            put_run(bits, a1 - max(a0, 0), color == 0)
            put_run(bits, a2 - a1, color != 0)
            a0 = a2
        if a0 >= w:
            break


EOL = "000000000001"


def encode(image, k, eol, byte_align, eob):
    bits = Bits()
    ref = [0] * len(image[0])
    for y, line in enumerate(image):
        if k < 0:
            encode_2d(bits, line, ref)
        else:
            if eol:
                bits.put_str(EOL)
            if k > 0:
                one_d = y % k == 0
                bits.put(1, 1 if one_d else 0)
                if one_d:
                    encode_1d(bits, line)
                else:
                    encode_2d(bits, line, ref)
            else:
                encode_1d(bits, line)
        if byte_align:
            bits.align()
        ref = line
    if eob:
        if k < 0:
            bits.put_str(EOL + EOL)
        else:
            for _ in range(6):
                bits.put_str(EOL)
                if k > 0:
                    bits.put(1, 1)
    return bits.to_bytes()


def image(rng, w, h, kind):
    img = []
    for y in range(h):
        if kind == "noise":
            line = [1 if rng.random() < 0.3 else 0 for _ in range(w)]
        elif kind == "text":
            # Blocky glyph-like structures with some vertical coherence.
            line = [0] * w
            if y % 12 < 9:
                x = rng.randrange(0, 8)
                while x < w:
                    gw = rng.randrange(2, 9)
                    for i in range(x, min(w, x + gw)):
                        line[i] = 1 if ((i * 7 + y * 3) % 11) < 6 else 0
                    x += gw + rng.randrange(1, 6)
        elif kind == "stripes":
            line = [1 if ((x + y // 3) // 5) % 2 else 0 for x in range(w)]
        elif kind == "long":
            # Long runs (make-up codes, > 2560).
            split = (y * 997) % w
            line = [0] * split + [1] * (w - split)
        elif kind == "white":
            line = [0] * w
        else:
            line = [1] * w
        img.append(line)
    # Vertical coherence for 2D coding: copy some lines with small shifts.
    if kind == "text":
        for y in range(1, h):
            if rng.random() < 0.5:
                s = rng.randrange(-2, 3)
                img[y] = [img[y - 1][min(max(x - s, 0), w - 1)] for x in range(w)]
    return img


def main():
    rng = random.Random(1234)
    files_dir = os.path.join(OUT, "files")
    os.makedirs(files_dir, exist_ok=True)
    for f in os.listdir(files_dir):
        os.remove(os.path.join(files_dir, f))
    cases = []
    sizes = [(1, 1), (7, 3), (8, 4), (9, 5), (31, 17), (64, 8), (100, 30), (1728, 6), (3000, 4)]
    kinds = ["text", "noise", "stripes", "long", "white", "black"]
    modes = [(-1, False, False, True), (-1, False, False, False), (-1, False, True, False),
             (0, False, False, False), (0, True, False, True), (0, True, True, True),
             (0, False, True, False), (2, True, False, True), (4, True, False, False),
             (2, False, False, False), (3, True, True, True)]
    n = 0
    for (w, h) in sizes:
        for kind in kinds:
            if kind == "long" and w < 100:
                continue
            img = image(rng, w, h, kind)
            for (k, eol, align, eob) in modes:
                if rng.random() < 0.45 and not (kind == "text" and w == 100):
                    continue
                data = encode(img, k, eol, align, eob)
                black1 = rng.random() < 0.2
                name = f"c{n:03d}_{kind}_{w}x{h}_k{k}.bin"
                n += 1
                open(os.path.join(files_dir, name), "wb").write(data)
                rows = h if rng.random() < 0.8 else 0
                cases.append((name, w, rows, k, eol, align, eob, black1))
                # Variants decoded with mismatched settings, truncated and
                # corrupted data.
                if rng.random() < 0.3:
                    cases.append((name, w, h + 3, k, not eol, align, not eob, black1))
                if rng.random() < 0.3 and len(data) > 4:
                    tname = name.replace(".bin", "_trunc.bin")
                    open(os.path.join(files_dir, tname), "wb").write(data[: len(data) * 2 // 3])
                    cases.append((tname, w, h, k, eol, align, eob, black1))
                if rng.random() < 0.3 and len(data) > 4:
                    cname = name.replace(".bin", "_corrupt.bin")
                    d = bytearray(data)
                    for _ in range(3):
                        i = rng.randrange(len(d))
                        d[i] ^= 1 << rng.randrange(8)
                    open(os.path.join(files_dir, cname), "wb").write(bytes(d))
                    cases.append((cname, w, h, k, eol, align, eob, black1))
                if rng.random() < 0.15:
                    cases.append((name, w + 1, h, k, eol, align, eob, black1))
    with open(os.path.join(OUT, "cases.tsv"), "w") as f:
        f.write("# file\tcolumns\trows\tk\tend_of_line\tbyte_align\tend_of_block\tblack_is_1 (scripts/gen_ccitt_test_files.py)\n")
        for c in cases:
            f.write("\t".join(str(int(v)) if isinstance(v, bool) else str(v) for v in c) + "\n")
    print(len(cases), "cases,", n, "files")


if __name__ == "__main__":
    main()
