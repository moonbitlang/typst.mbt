#!/usr/bin/env python3
"""Generate JBIG2 test files for `hayro/jbig2/oracle_test.mbt`.

A small deterministic JBIG2 *encoder* (ITU-T T.88): MQ arithmetic coder
(Annex E), integer/IAID coders (Annex A), generic regions (templates 0-3,
TPGDON, custom AT pixels, MMR via the T.6 encoder of
`scripts/gen_ccitt_test_files.py`), generic refinement regions (GRTEMPLATE
0/1, TPGRON, AT pixels), pattern dictionaries and halftone regions (MMR and
arithmetic, HENABLESKIP, HCOMBOP, gray-coded bitplanes, grid vectors),
symbol dictionaries and text regions (arithmetic and Huffman with the
standard tables and user-defined table segments, refinement/aggregation,
REFCORNER/TRANSPOSED, SBDSOFFSET, strips), composition operators, page
default pixels, striped pages with unknown height, intermediate regions,
end-of-page/end-of-file segments, standalone files (sequential and
random-access organization) and embedded streams with globals, plus
truncated and corrupted variants.

Writes the files to `hayro/jbig2/testdata/files/` and the case list to
`hayro/jbig2/testdata/cases.tsv`
(`file<TAB>globals<TAB>kind<TAB>tags<TAB>intended`): `kind` is `file`
(`Image::new`) or `embedded` (`Image::new_embedded` with the `globals` file
or `-`), `tags` names the exercised features and `intended` is the pixel
record (see below) of the page this encoder meant to produce (`-` for
corrupted variants). The decoder never reads `tags`/`intended`; they
document the cases and let `--check <oracle.tsv>` report how many cases the
real decoder decodes as intended.

The expected decodings come from the real hayro-jbig2:
`cargo run --release --offline --bin gen_hayro_codec_tests -- jbig2 ../hayro/jbig2/testdata/cases.tsv > ../hayro/jbig2/testdata/oracle.tsv`
(in `oracle/`).

Pixel record: `push_pixel` appends `1` (black) or `0`, `push_pixel_chunk`
appends `[<1|0><count>]`, `next_line` appends `\\n`; the record is
`<rows> <len>:<fnv1a64>`.
"""

import importlib.util
import os
import random
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "hayro/jbig2/testdata")

_spec = importlib.util.spec_from_file_location(
    "gen_ccitt_test_files", os.path.join(ROOT, "scripts/gen_ccitt_test_files.py"))
ccitt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ccitt)


# ---------------------------------------------------------------------------
# Bitmaps (lists of rows of 0/1, 1 = black)


def blank(w, h, v=0):
    return [[v] * w for _ in range(h)]


def get(img, x, y):
    if img and 0 <= y < len(img) and 0 <= x < len(img[0]):
        return img[y][x]
    return 0


def dims(img):
    return (len(img[0]) if img else 0), len(img)


def combine(dst, src, x0, y0, op):
    """Bitmap::combine (pixels outside `dst` are ignored)."""
    dw, dh = dims(dst)
    sw, sh = dims(src)
    for sy in range(sh):
        y = y0 + sy
        if not 0 <= y < dh:
            continue
        for sx in range(sw):
            x = x0 + sx
            if not 0 <= x < dw:
                continue
            d, s = dst[y][x], src[sy][sx]
            dst[y][x] = {"or": d | s, "and": d & s, "xor": d ^ s,
                         "xnor": 1 - (d ^ s), "replace": s}[op]


COMBOPS = {"or": 0, "and": 1, "xor": 2, "xnor": 3, "replace": 4}


def fnv(data):
    h = 0xcbf29ce484222325
    for b in data:
        h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h


def record(img):
    """The pixel record of `emit_bitmap` (see the module docs)."""
    w, h = dims(img)
    out = bytearray()
    bpr = (w + 7) // 8
    for row in img:
        x = 0
        chunk = None
        cnt = 0

        def flush():
            out.extend(b"[%d%d]" % (1 if chunk == 0xFF else 0, cnt))

        for i in range(bpr):
            byte = 0
            for k in range(8):
                if i * 8 + k < w:
                    byte |= row[i * 8 + k] << (7 - k)
            rem = w - x
            if rem >= 8 and byte in (0, 0xFF):
                if chunk == byte:
                    cnt += 1
                    x += 8
                    continue
                if chunk is not None:
                    flush()
                chunk = byte
                cnt = 1
                x += 8
                continue
            if chunk is not None:
                flush()
                chunk = None
                cnt = 0
            for k in range(min(rem, 8)):
                out.append(ord("1") if (byte >> (7 - k)) & 1 else ord("0"))
            x += min(rem, 8)
        if chunk is not None:
            flush()
        out.extend(b"\n")
    return "%d %d:%016x" % (h, len(out), fnv(out))


# ---------------------------------------------------------------------------
# Bit writer (MSB first)


class BitWriter:
    def __init__(self):
        self.bits = []

    def put(self, n, v):
        for i in range(n - 1, -1, -1):
            self.bits.append((v >> i) & 1)

    def put_code(self, code):
        self.bits.extend(int(c) for c in code)

    def align(self):
        while len(self.bits) % 8:
            self.bits.append(0)

    def extend_bytes(self, data):
        self.align()
        for b in data:
            self.put(8, b)

    def to_bytes(self):
        bits = self.bits + [0] * (-len(self.bits) % 8)
        return bytes(int("".join(map(str, bits[i:i + 8])), 2) for i in range(0, len(bits), 8))


# ---------------------------------------------------------------------------
# MQ arithmetic coder (Annex E), contexts packed as `index | mps << 7`

QE = [
    (0x5601, 1, 1, 1), (0x3401, 2, 6, 0), (0x1801, 3, 9, 0), (0x0AC1, 4, 12, 0),
    (0x0521, 5, 29, 0), (0x0221, 38, 33, 0), (0x5601, 7, 6, 1), (0x5401, 8, 14, 0),
    (0x4801, 9, 14, 0), (0x3801, 10, 14, 0), (0x3001, 11, 17, 0), (0x2401, 12, 18, 0),
    (0x1C01, 13, 20, 0), (0x1601, 29, 21, 0), (0x5601, 15, 14, 1), (0x5401, 16, 14, 0),
    (0x5101, 17, 15, 0), (0x4801, 18, 16, 0), (0x3801, 19, 17, 0), (0x3401, 20, 18, 0),
    (0x3001, 21, 19, 0), (0x2801, 22, 19, 0), (0x2401, 23, 20, 0), (0x2201, 24, 21, 0),
    (0x1C01, 25, 22, 0), (0x1801, 26, 23, 0), (0x1601, 27, 24, 0), (0x1401, 28, 25, 0),
    (0x1201, 29, 26, 0), (0x1101, 30, 27, 0), (0x0AC1, 31, 28, 0), (0x09C1, 32, 29, 0),
    (0x08A1, 33, 30, 0), (0x0521, 34, 31, 0), (0x0441, 35, 32, 0), (0x02A1, 36, 33, 0),
    (0x0221, 37, 34, 0), (0x0141, 38, 35, 0), (0x0111, 39, 36, 0), (0x0085, 40, 37, 0),
    (0x0049, 41, 38, 0), (0x0025, 42, 39, 0), (0x0015, 43, 40, 0), (0x0009, 44, 41, 0),
    (0x0005, 45, 42, 0), (0x0001, 45, 43, 0), (0x5601, 46, 46, 0),
]


class MQEncoder:
    def __init__(self):
        self.a = 0x8000
        self.c = 0
        self.ct = 12
        self.b = 0
        self.bp = -1
        self.out = bytearray()

    def encode(self, ctx, i, d):
        st = ctx[i]
        idx, mps = st & 0x7F, st >> 7
        qe, nmps, nlps, sw = QE[idx]
        self.a -= qe
        if d == mps:
            if self.a & 0x8000 == 0:
                if self.a < qe:
                    self.a = qe
                else:
                    self.c += qe
                ctx[i] = (mps << 7) | nmps
                self.renorme()
            else:
                self.c += qe
        else:
            if self.a < qe:
                self.c += qe
            else:
                self.a = qe
            if sw:
                mps = 1 - mps
            ctx[i] = (mps << 7) | nlps
            self.renorme()

    def renorme(self):
        while True:
            self.a <<= 1
            self.c <<= 1
            self.ct -= 1
            if self.ct == 0:
                self.byteout()
            if self.a & 0x8000:
                break

    def emit(self):
        if self.bp >= 0:
            self.out.append(self.b)
        self.bp += 1

    def byteout(self):
        if self.b == 0xFF:
            rblock = True
        elif self.c < 0x8000000:
            rblock = False
        else:
            self.b += 1
            if self.b == 0xFF:
                self.c &= 0x7FFFFFF
                rblock = True
            else:
                rblock = False
        self.emit()
        if rblock:
            self.b = (self.c >> 20) & 0xFF
            self.c &= 0xFFFFF
            self.ct = 7
        else:
            self.b = (self.c >> 19) & 0xFF
            self.c &= 0x7FFFF
            self.ct = 8

    def flush(self):
        tempc = self.c + self.a
        self.c |= 0xFFFF
        if self.c >= tempc:
            self.c -= 0x8000
        self.c <<= self.ct
        self.byteout()
        self.c <<= self.ct
        self.byteout()
        self.emit()
        self.out.extend(b"\xFF\xAC")
        return bytes(self.out)


class MQDecoder:
    """A transcription of `ArithmeticDecoder` (for the self-test only)."""

    def __init__(self, data):
        self.data = data
        self.bp = 0
        self.c = ((self.byte(0) ^ 0xFF) << 16)
        self.read_byte()
        self.c = (self.c << 7) & 0xFFFFFFFF
        self.ct -= 7
        self.a = 0x8000

    def byte(self, p):
        return self.data[p] if p < len(self.data) else 0xFF

    def read_byte(self):
        if self.byte(self.bp) == 0xFF:
            if self.byte(self.bp + 1) > 0x8F:
                self.ct = 8
            else:
                self.bp += 1
                self.c = (self.c + 0xFE00 - (self.byte(self.bp) << 9)) & 0xFFFFFFFF
                self.ct = 7
        else:
            self.bp += 1
            self.c = (self.c + 0xFF00 - (self.byte(self.bp) << 8)) & 0xFFFFFFFF
            self.ct = 8

    def decode(self, ctx, i):
        st = ctx[i]
        idx, mps = st & 0x7F, st >> 7
        qe, nmps, nlps, sw = QE[idx]
        self.a -= qe
        if (self.c >> 16) < self.a:
            if self.a & 0x8000:
                return mps
            if self.a < qe:
                d = 1 - mps
                if sw:
                    mps = 1 - mps
                ctx[i] = (mps << 7) | nlps
            else:
                d = mps
                ctx[i] = (mps << 7) | nmps
        else:
            self.c = (self.c - (self.a << 16)) & 0xFFFFFFFF
            if self.a < qe:
                self.a = qe
                d = mps
                ctx[i] = (mps << 7) | nmps
            else:
                self.a = qe
                d = 1 - mps
                if sw:
                    mps = 1 - mps
                ctx[i] = (mps << 7) | nlps
        while not self.a & 0x8000:
            if self.ct == 0:
                self.read_byte()
            self.a <<= 1
            self.c = (self.c << 1) & 0xFFFFFFFF
            self.ct -= 1
        return d


def mq_self_test():
    rng = random.Random(7)
    for n in [1, 5, 100, 5000]:
        for p in [0.01, 0.3, 0.5, 0.97]:
            ctxs = [0] * 64
            seq = [(rng.randrange(64), 1 if rng.random() < p else 0) for _ in range(n)]
            enc = MQEncoder()
            for i, d in seq:
                enc.encode(ctxs, i, d)
            data = enc.flush()
            dctx = [0] * 64
            dec = MQDecoder(data)
            for i, d in seq:
                assert dec.decode(dctx, i) == d, (n, p)


class IntCoder:
    """The integer arithmetic coding procedure (A.2), one context set."""

    def __init__(self):
        self.ctx = [0] * 512

    def encode(self, enc, v):
        prev = [1]

        def bit(d):
            enc.encode(self.ctx, prev[0] & 0x1FF, d)
            if prev[0] < 256:
                prev[0] = (prev[0] << 1) | d
            else:
                prev[0] = (((prev[0] << 1) | d) & 511) | 256

        def bits(v, n):
            for i in range(n - 1, -1, -1):
                bit((v >> i) & 1)

        if v is None:
            bit(1)
            bit(0)
            bits(0, 2)
            return
        bit(1 if v < 0 else 0)
        m = abs(v)
        for prefix, n, base in [(0, 2, 0), (1, 4, 4), (2, 6, 20), (3, 8, 84), (4, 12, 340)]:
            if m < base + (1 << n):
                for _ in range(prefix):
                    bit(1)
                bit(0)
                bits(m - base, n)
                return
        for _ in range(5):
            bit(1)
        bits(m - 4436, 32)


class IdCoder:
    """The IAID procedure (A.3)."""

    def __init__(self, codelen):
        self.codelen = codelen
        self.ctx = [0] * (1 << codelen)

    def encode(self, enc, v):
        prev = 1
        for i in range(self.codelen - 1, -1, -1):
            d = (v >> i) & 1
            enc.encode(self.ctx, prev, d)
            prev = (prev << 1) | d


def symcodelen(n):
    """`32 - (n - 1).leading_zeros()` (n >= 1)."""
    return (n - 1).bit_length()


# ---------------------------------------------------------------------------
# Generic regions (6.2)

DEFAULT_AT = {0: [(3, -1), (-3, -1), (2, -2), (-2, -2)], 1: [(3, -1)], 2: [(2, -1)], 3: [(2, -1)]}
SLTP = {0: 0x9B25, 1: 0x0795, 2: 0x00E5, 3: 0x0195}
CTX_BITS = {0: 16, 1: 13, 2: 10, 3: 10}


def generic_context(img, x, y, t, at):
    g = lambda dx, dy: get(img, x + dx, y + dy)
    if t == 0:
        return (g(-1, 0) | g(-2, 0) << 1 | g(-3, 0) << 2 | g(-4, 0) << 3
                | g(*at[0]) << 4 | g(2, -1) << 5 | g(1, -1) << 6 | g(0, -1) << 7
                | g(-1, -1) << 8 | g(-2, -1) << 9 | g(*at[1]) << 10 | g(*at[2]) << 11
                | g(1, -2) << 12 | g(0, -2) << 13 | g(-1, -2) << 14 | g(*at[3]) << 15)
    if t == 1:
        return (g(-1, 0) | g(-2, 0) << 1 | g(-3, 0) << 2 | g(*at[0]) << 3
                | g(2, -1) << 4 | g(1, -1) << 5 | g(0, -1) << 6 | g(-1, -1) << 7
                | g(-2, -1) << 8 | g(2, -2) << 9 | g(1, -2) << 10 | g(0, -2) << 11
                | g(-1, -2) << 12)
    if t == 2:
        return (g(-1, 0) | g(-2, 0) << 1 | g(*at[0]) << 2 | g(1, -1) << 3
                | g(0, -1) << 4 | g(-1, -1) << 5 | g(-2, -1) << 6 | g(1, -2) << 7
                | g(0, -2) << 8 | g(-1, -2) << 9)
    return (g(-1, 0) | g(-2, 0) << 1 | g(-3, 0) << 2 | g(-4, 0) << 3
            | g(*at[0]) << 4 | g(1, -1) << 5 | g(0, -1) << 6 | g(-1, -1) << 7
            | g(-2, -1) << 8 | g(-3, -1) << 9)


def encode_generic(enc, ctx, img, t, at, tpgdon=False, skip=None):
    """Encode `img` with the generic region procedure (6.2.5). `skip(x, y)`
    marks the pixels that are not coded (USESKIP)."""
    w, h = dims(img)
    ltp = 0
    # Pixels not coded because of `skip` are 0 for the decoder.
    cur = [row[:] for row in img]
    if skip:
        for y in range(h):
            for x in range(w):
                if skip(x, y):
                    cur[y][x] = 0
    for y in range(h):
        if tpgdon:
            prev = cur[y - 1] if y > 0 else [0] * w
            typical = 1 if cur[y] == prev else 0
            enc.encode(ctx, SLTP[t], typical ^ ltp)
            ltp = typical
            if typical:
                continue
        for x in range(w):
            if skip and skip(x, y):
                continue
            enc.encode(ctx, generic_context(cur, x, y, t, at), cur[y][x])


def at_bytes(t, at):
    out = b""
    for (x, y) in at[: 4 if t == 0 else 1]:
        out += struct.pack(">bb", x, y)
    return out


def mmr(img, eofb=False):
    return ccitt.encode(img, -1, False, False, eofb)


# ---------------------------------------------------------------------------
# Generic refinement regions (6.3), context layout as hayro-jbig2's


def ref_views(ref, w, y, dx, dy, pad=0):
    """The reference pixels hayro-jbig2's `RefinementContextGatherer` sees for
    each `x` of row `y` (a function `(ax, ay) -> pixel` per x, ax/ay in
    -1..1). It keeps 32-pixel windows of the three reference rows; when
    `x - dx < 0` the windows are zeroed and its reload test leaves them
    zeroed until `x - dx + 1 >= 32`, so with GRREFERENCEDX > 0 the first
    reference columns read as 0 (T.88 reads the real pixels there). The
    encoder models this so that such regions still decode as intended.
    The windows also include the padding bits of the reference's last word,
    which are `pad` (1 for bitmaps created with default pixel 1, e.g. a page
    or halftone/text region with default pixel 1) instead of 0."""
    rw = dims(ref)[0]
    padded = (rw + 31) // 32 * 32
    views = []
    cur_x = 0
    zero = False
    for x in range(w):
        rx = x - dx
        if rx < 0:
            zero = True
            cur_x = 0
        elif rx + 1 >= cur_x + 32 or rx < cur_x:
            cur_x = max(rx - 1, 0)
            zero = False

        def view(ax, ay, rx=rx, cur_x=cur_x, zero=zero):
            c = rx + ax
            if zero or not 0 <= c - cur_x < 32:
                return 0
            ry = y - dy + ay
            if rw <= c < padded and 0 <= ry < len(ref):
                return pad
            return get(ref, c, ry)

        views.append(view)
    return views


def refine_context(img, f, x, y, t, at, at2):
    """`f` is the buffered reference view of `x`; `at2(ax, ay)` reads the
    reference directly (template 0's second AT pixel)."""
    r = lambda ax, ay: get(img, x + ax, y + ay)
    if t == 0:
        return (r(*at[0]) << 12 | r(0, -1) << 11 | r(1, -1) << 10 | r(-1, 0) << 9
                | at2(*at[1]) << 8 | f(0, -1) << 7 | f(1, -1) << 6
                | f(-1, 0) << 5 | f(0, 0) << 4 | f(1, 0) << 3
                | f(-1, 1) << 2 | f(0, 1) << 1 | f(1, 1))
    return (r(-1, -1) << 9 | r(0, -1) << 8 | r(1, -1) << 7 | r(-1, 0) << 6
            | f(0, -1) << 5 | f(-1, 0) << 4 | f(0, 0) << 3 | f(1, 0) << 2
            | f(0, 1) << 1 | f(1, 1))


def encode_refinement(enc, ctx, img, ref, dx, dy, t, at, tpgron=False, pad=0):
    w, h = dims(img)
    ltp = 0
    sltp = 0x10 if t == 0 else 0x8
    default_at = t == 0 and list(at[0]) == [-1, -1] and list(at[1]) == [-1, -1]
    for y in range(h):
        views = ref_views(ref, w, y, dx, dy, pad)

        def uniform(x):
            vals = {views[x](i, j) for i in (-1, 0, 1) for j in (-1, 0, 1)}
            return len(vals) == 1

        if tpgron:
            typical = 1
            for x in range(w):
                if uniform(x) and img[y][x] != views[x](0, 0):
                    typical = 0
                    break
            enc.encode(ctx, sltp, typical ^ ltp)
            ltp = typical
        for x in range(w):
            if ltp and uniform(x):
                continue
            f = views[x]
            # (The default AT pixel (-1, -1) is read through the window too.)
            at2 = f if default_at else (lambda ax, ay, x=x: get(ref, x - dx + ax, y - dy + ay))
            enc.encode(ctx, refine_context(img, f, x, y, t, at, at2), img[y][x])


def rat_bytes(at):
    return struct.pack(">bbbb", at[0][0], at[0][1], at[1][0], at[1][1])


# ---------------------------------------------------------------------------
# Huffman tables (Annex B)


def standard_tables():
    src = open(os.path.join(ROOT, "target/hayro/hayro-jbig2/src/huffman_tables_generated.rs")).read()
    out = {}
    for name, body in re.findall(r"const TABLE_(\w): \[N; INLINE_TABLE_SIZE\] = \[\n(.*?)\n\];", src, re.S):
        nodes = []
        for line in body.split("\n"):
            line = line.strip()
            m = re.match(r"N::Intermediate \{ zero: (?:Some\(nz\((\d+)\)\)|None), one: (?:Some\(nz\((\d+)\)\)|None) \},", line)
            if m:
                nodes.append(("I", int(m.group(1) or 0), int(m.group(2) or 0)))
                continue
            m = re.match(r"N::Leaf\(L \{ range_low: (-?\d+), range_length: (\d+), is_lower: (\w+), is_out_of_band: (\w+) \}\),", line)
            if m:
                nodes.append(("L", int(m.group(1)), int(m.group(2)), m.group(3) == "true", m.group(4) == "true"))
                continue
            nodes.append(("E",))
        leaves = []

        def walk(i, code):
            n = nodes[i]
            if n[0] == "I":
                if n[1]:
                    walk(n[1], code + "0")
                if n[2]:
                    walk(n[2], code + "1")
            elif n[0] == "L":
                leaves.append((code,) + n[1:])

        walk(0, "")
        out["B%d" % (ord(name) - ord("A") + 1)] = leaves
    return out


STD = standard_tables()


def assign_codes(lines):
    """B.3: `lines` are (range_low, preflen, rangelen, is_lower, is_oob)."""
    lenmax = max((l[1] for l in lines), default=0)
    count = [0] * (lenmax + 1)
    for l in lines:
        count[l[1]] += 1
    count[0] = 0
    first = [0] * (lenmax + 1)
    codes = [None] * len(lines)
    for cur in range(1, lenmax + 1):
        first[cur] = (first[cur - 1] + count[cur - 1]) * 2
        code = first[cur]
        for i, l in enumerate(lines):
            if l[1] == cur:
                codes[i] = format(code, "0%db" % cur)
                code += 1
    return [(codes[i], l[0], l[2], l[3], l[4]) for i, l in enumerate(lines) if l[1] > 0]


def huff_encode(bw, table, v):
    """Write `v` (`None` = OOB) with `table` (leaves of (code, low, rangelen,
    is_lower, is_oob))."""
    for code, low, rl, lower, oob in table:
        if v is None:
            if oob:
                bw.put_code(code)
                return
            continue
        if oob:
            continue
        if lower:
            if v <= low and low - v < (1 << rl):
                bw.put_code(code)
                bw.put(rl, low - v)
                return
        elif low <= v < low + (1 << rl):
            bw.put_code(code)
            bw.put(rl, v - low)
            return
    raise ValueError("value %r not in table" % (v,))


def custom_table(htoob, htps, htrs, low, high, prefs, rangelens, lowpref, highpref, oobpref):
    """A user-defined table: (segment data, leaves)."""
    bw = BitWriter()
    bw.put(8, (1 if htoob else 0) | ((htps - 1) << 1) | ((htrs - 1) << 4))
    for v in (low, high):
        bw.put(32, v & 0xFFFFFFFF)
    lines = []
    cur = low
    i = 0
    while cur < high:
        bw.put(htps, prefs[i])
        bw.put(htrs, rangelens[i])
        lines.append((cur, prefs[i], rangelens[i], False, False))
        cur += 1 << rangelens[i]
        i += 1
    bw.put(htps, lowpref)
    lines.append((low - 1, lowpref, 32, True, False))
    bw.put(htps, highpref)
    lines.append((cur, highpref, 32, False, False))
    if htoob:
        bw.put(htps, oobpref)
        lines.append((0, oobpref, 0, False, True))
    return bw.to_bytes(), assign_codes(lines)


# ---------------------------------------------------------------------------
# Segments and files


def u32(v):
    return struct.pack(">I", v & 0xFFFFFFFF)


def region_info(w, h, x, y, op="or", extra=0):
    return u32(w) + u32(h) + u32(x) + u32(y) + bytes([COMBOPS[op] | extra])


class Seg:
    def __init__(self, num, typ, data, referred=(), page=1, unknown_len=False, retain=True):
        self.num, self.typ, self.data = num, typ, data
        self.referred = list(referred)
        self.page = page
        self.unknown_len = unknown_len
        self.retain = retain

    def header(self):
        out = u32(self.num)
        out += bytes([self.typ | (0x40 if self.page > 255 else 0) | (0 if self.retain else 0x80)])
        n = len(self.referred)
        if n <= 4:
            out += bytes([n << 5])
        else:
            out += u32(0xE0000000 | n) + bytes((n + 8) // 8)
        for r in self.referred:
            if self.num <= 256:
                out += bytes([r])
            elif self.num <= 65536:
                out += struct.pack(">H", r)
            else:
                out += u32(r)
        out += u32(self.page) if self.page > 255 else bytes([self.page])
        out += u32(0xFFFFFFFF if self.unknown_len else len(self.data))
        return out

    def bytes(self):
        return self.header() + self.data


FILE_ID = b"\x97\x4A\x42\x32\x0D\x0A\x1A\x0A"


def embedded(segs):
    return b"".join(s.bytes() for s in segs)


def standalone(segs, random_access=False, pages=1):
    flags = 0 if random_access else 1
    if pages is None:
        flags |= 2
    out = FILE_ID + bytes([flags]) + (u32(pages) if pages is not None else b"")
    if random_access:
        return out + b"".join(s.header() for s in segs) + b"".join(s.data for s in segs)
    return out + embedded(segs)


def page_info(w, h, default=0, striped=False, stripe=0):
    flags = (default << 2) | 1
    return Seg(0, 48, u32(w) + u32(h) + u32(0) + u32(0) + bytes([flags])
               + struct.pack(">H", (0x8000 if striped else 0) | stripe))


# ---------------------------------------------------------------------------
# Region encoders (segment data)


def generic_segment(img, t=0, at=None, tpgdon=False, mmr_=False, eofb=False, x=0, y=0, op="or",
                    unknown_len=False, row_count=None):
    w, h = dims(img)
    at = at or DEFAULT_AT[t]
    flags = (1 if mmr_ else 0) | (t << 1) | (8 if tpgdon else 0)
    data = region_info(w, h, x, y, op) + bytes([flags])
    if mmr_:
        coded = mmr(img, eofb or unknown_len)
    else:
        data += at_bytes(t, at)
        enc = MQEncoder()
        encode_generic(enc, [0] * (1 << CTX_BITS[t]), img, t, at, tpgdon)
        coded = enc.flush()
    data += coded
    if unknown_len:
        if mmr_:
            data += b"\x00\x00"
        data += u32(h if row_count is None else row_count)
    return data


def refinement_segment(img, ref, dx, dy, t=0, at=((-1, -1), (-1, -1)), tpgron=False, x=0, y=0, op="or",
                       pad=0):
    w, h = dims(img)
    data = region_info(w, h, x, y, op) + bytes([t | (2 if tpgron else 0)])
    if t == 0:
        data += rat_bytes(at)
    enc = MQEncoder()
    encode_refinement(enc, [0] * (1 << (13 if t == 0 else 10)), img, ref, dx, dy, t, at, tpgron, pad)
    return data + enc.flush()


def gray_planes(gi, bpp):
    planes = []
    for j in range(bpp - 1, -1, -1):
        p = []
        for row in gi:
            r = []
            for v in row:
                b = (v >> j) & 1
                if j < bpp - 1:
                    b ^= (v >> (j + 1)) & 1
                r.append(b)
            p.append(r)
        planes.append(p)
    return planes


def pattern_dict_segment(patterns, t=0, mmr_=False):
    pw, ph = dims(patterns[0])
    coll = [sum((p[y] for p in patterns), []) for y in range(ph)]
    data = bytes([(1 if mmr_ else 0) | (t << 1), pw, ph]) + u32(len(patterns) - 1)
    if mmr_:
        return data + mmr(coll, True)
    at = [(-pw, 0), (-3, -1), (2, -2), (-2, -2)] if t == 0 else [(-pw, 0)]
    enc = MQEncoder()
    encode_generic(enc, [0] * (1 << CTX_BITS[t]), coll, t, at)
    return data + enc.flush()


def grid_cells(hgx, hgy, hrx, hry, gw, gh):
    for m in range(gh):
        for n in range(gw):
            yield m, n, (hgx + m * hry + n * hrx) >> 8, (hgy + m * hrx - n * hry) >> 8


def halftone(region_w, region_h, patterns, gi, hgx, hgy, hrx, hry, t=0, mmr_=False, skip=False,
             hop="or", defpix=0, x=0, y=0, op="or"):
    """Halftone region segment data and the region bitmap it should decode to."""
    gh, gw = len(gi), len(gi[0])
    pw, ph = dims(patterns[0])
    n = len(patterns)
    bpp = (n - 1).bit_length() if n > 1 else 1
    skipped = set()
    if skip:
        for m, k, px, py in grid_cells(hgx, hgy, hrx, hry, gw, gh):
            if px + pw <= 0 or px >= region_w or py + ph <= 0 or py >= region_h:
                skipped.add((k, m))
        gi = [[0 if (k, m) in skipped else gi[m][k] for k in range(gw)] for m in range(gh)]
    flags = (1 if mmr_ else 0) | (t << 1) | (8 if skip else 0) | (COMBOPS[hop] << 4) | (0x80 if defpix else 0)
    data = region_info(region_w, region_h, x, y, op) + bytes([flags])
    data += u32(gw) + u32(gh) + struct.pack(">iiHH", hgx, hgy, hrx, hry)
    planes = gray_planes(gi, bpp)
    if mmr_:
        for p in planes:
            data += mmr(p, False)
    else:
        enc = MQEncoder()
        ctx = [0] * (1 << CTX_BITS[t])
        sk = (lambda xx, yy: (xx, yy) in skipped) if skip else None
        for p in planes:
            encode_generic(enc, ctx, p, t, DEFAULT_AT[t], False, sk)
        data += enc.flush()
    region = blank(region_w, region_h, defpix)
    for m, k, px, py in grid_cells(hgx, hgy, hrx, hry, gw, gh):
        combine(region, patterns[gi[m][k]], px, py, hop)
    return data, region


# ---------------------------------------------------------------------------
# Text regions (6.4) and symbol dictionaries (6.5)

CORNERS = {"bl": 0, "tl": 1, "br": 2, "tr": 3}


class ArithText:
    """Arithmetic text region coding with (possibly shared) contexts."""

    def __init__(self, enc, codelen, gr_ctx, ints=None):
        self.enc = enc
        self.ints = ints if ints is not None else {}
        for k in ["dt", "fs", "ds", "it", "ri", "rdw", "rdh", "rdx", "rdy"]:
            self.ints.setdefault(k, IntCoder())
        self.ints.setdefault("id", IdCoder(codelen))
        self.gr_ctx = gr_ctx

    def int(self, k, v):
        self.ints[k].encode(self.enc, v)

    def sym(self, v):
        self.ints["id"].encode(self.enc, v)

    def t(self, v, logss):
        self.int("it", v)

    def ri(self, v):
        self.int("ri", v)

    def refine(self, target, ref, dx, dy, rt, rat):
        encode_refinement(self.enc, self.gr_ctx, target, ref, dx, dy, rt, rat)


class HuffText:
    """Huffman text region coding; `tables` maps dt/fs/ds/rdw/rdh/rdx/rdy/rsize
    to leaves, symbol IDs use `codelen`-bit codes (code = index)."""

    def __init__(self, bw, tables, codelen):
        self.bw = bw
        self.tables = tables
        self.codelen = codelen

    def int(self, k, v):
        huff_encode(self.bw, self.tables[k], v)

    def sym(self, v):
        self.bw.put(self.codelen, v)

    def t(self, v, logss):
        self.bw.put(logss, v)

    def ri(self, v):
        self.bw.put(1, v)

    def refine(self, target, ref, dx, dy, rt, rat):
        enc = MQEncoder()
        encode_refinement(enc, [0] * (1 << (13 if rt == 0 else 10)), target, ref, dx, dy, rt, rat)
        data = enc.flush()
        huff_encode(self.bw, self.tables["rsize"], len(data))
        self.bw.extend_bytes(data)


def text_encode(coder, symbols, insts, logss=0, corner="tl", transposed=False, dsoffset=0,
                refine=False, rt=0, rat=((-1, -1), (-1, -1)), region=None, op="or"):
    """Encode the instances `(sym, s, t, refinement)` (strip order;
    refinement = None or (rdw, rdh, rdx, rdy, target)) and draw them into
    `region` like the decoder."""
    ss = 1 << logss
    strips = []
    # (Strips must come in increasing order; `sorted` is stable.)
    for inst in sorted(insts, key=lambda i: i[2] // ss):
        base = inst[2] // ss * ss
        if strips and strips[-1][0] == base:
            strips[-1][1].append(inst)
        else:
            strips.append((base, [inst]))
    # STRIPT starts at -SBSTRIPS (DT = 1, the Huffman DT tables start at 1).
    strip_t = -ss
    coder.int("dt", 1)
    first_s = 0
    for base, sis in strips:
        coder.int("dt", (base - strip_t) // ss)
        strip_t = base
        cur_s = None
        for sym, s, t, rf in sis:
            ref = symbols[sym]
            bm = rf[4] if rf else ref
            w, h = dims(bm)
            pre = (w - 1 if not transposed and corner in ("tr", "br")
                   else h - 1 if transposed and corner in ("bl", "br") else 0)
            target = s - pre
            if cur_s is None:
                coder.int("fs", target - first_s)
                first_s = target
            else:
                coder.int("ds", target - (cur_s + dsoffset))
            if ss != 1:
                coder.t(t - base, logss)
            coder.sym(sym)
            if refine:
                coder.ri(1 if rf else 0)
                if rf:
                    rdw, rdh, rdx, rdy, tgt = rf
                    for k, v in (("rdw", rdw), ("rdh", rdh), ("rdx", rdx), ("rdy", rdy)):
                        coder.int(k, v)
                    coder.refine(tgt, ref, (rdw >> 1) + rdx, (rdh >> 1) + rdy, rt, rat)
            if region is not None:
                if not transposed:
                    x, y = {"tl": (s, t), "tr": (s - w + 1, t), "bl": (s, t - h + 1),
                            "br": (s - w + 1, t - h + 1)}[corner]
                else:
                    x, y = {"tl": (t, s), "tr": (t - w + 1, s), "bl": (t, s - h + 1),
                            "br": (t - w + 1, s - h + 1)}[corner]
                combine(region, bm, x, y, op)
            post = (w - 1 if not transposed and corner in ("tl", "bl")
                    else h - 1 if transposed and corner in ("tl", "tr") else 0)
            cur_s = s + post
        coder.int("ds", None)


def text_segment(w, h, symbols, insts, huffman=False, logss=0, corner="tl", transposed=False,
                 dsoffset=0, refine=False, rt=0, rat=((-1, -1), (-1, -1)), sbop="or", defpix=0,
                 x=0, y=0, op="or", hflags=None, custom=None, idlen=None):
    """Text region segment data and the region bitmap it should decode to.
    `hflags` = (fs, ds, dt, rdw, rdh, rdy, rdx, rsize) selections for Huffman;
    `custom` = the user tables in reference order (leaves)."""
    region = blank(w, h, defpix)
    flags = ((1 if huffman else 0) | (2 if refine else 0) | (logss << 2) | (CORNERS[corner] << 4)
             | (0x40 if transposed else 0) | (COMBOPS[sbop] << 7) | (0x200 if defpix else 0)
             | ((dsoffset & 0x1F) << 10) | (rt << 15))
    data = region_info(w, h, x, y, op) + struct.pack(">H", flags)
    if huffman:
        hf = hflags or (0, 0, 0, 0, 0, 0, 0, 0)
        data += struct.pack(">H", hf[0] | hf[1] << 2 | hf[2] << 4 | hf[3] << 6 | hf[4] << 8
                            | hf[5] << 10 | hf[6] << 12 | hf[7] << 14)
    if refine and rt == 0:
        data += rat_bytes(rat)
    data += u32(len(insts))
    if huffman:
        customs = list(custom or [])
        tables = {}
        # (The order in which the user tables are consumed, 7.4.3.1.6.)
        for k, sel, std in (("fs", hf[0], ["B6", "B7"]), ("ds", hf[1], ["B8", "B9", "B10"]),
                            ("dt", hf[2], ["B11", "B12", "B13"]), ("rdw", hf[3], ["B14", "B15"]),
                            ("rdh", hf[4], ["B14", "B15"]), ("rdy", hf[5], ["B14", "B15"]),
                            ("rdx", hf[6], ["B14", "B15"]), ("rsize", hf[7], ["B1"])):
            if sel == 3 or (k == "rsize" and sel == 1):
                tables[k] = customs.pop(0)
            else:
                tables[k] = STD[std[sel]]
        bw = BitWriter()
        n = len(symbols)
        L = idlen if idlen is not None else max(1, symcodelen(n))
        # Run codes: L (prefix length 1), 32 (2), 33 (3); remaining 0.
        rl = [0] * 35
        rl[L] = 1
        rl[32] = 2
        rl[33] = 3
        for v in rl:
            bw.put(4, v)
        rcodes = {l[1]: l[0] for l in assign_codes([(i, rl[i], 0, False, False) for i in range(35)])}
        i = 0
        while i < n:
            if i > 0 and n - i >= 3:
                rep = min(6, n - i)
                bw.put_code(rcodes[32])
                bw.put(2, rep - 3)
                i += rep
            else:
                bw.put_code(rcodes[L])
                i += 1
        bw.align()
        coder = HuffText(bw, tables, L)
        text_encode(coder, symbols, insts, logss, corner, transposed, dsoffset, refine, rt, rat, region, sbop)
        data += bw.to_bytes()
    else:
        enc = MQEncoder()
        coder = ArithText(enc, symcodelen(len(symbols)) if symbols else 0,
                          [0] * (1 << (13 if rt == 0 else 10)))
        text_encode(coder, symbols, insts, logss, corner, transposed, dsoffset, refine, rt, rat, region, sbop)
        data += enc.flush()
    return data, region


def symbol_dict(input_syms, classes, exports, huffman=False, refagg=False, t=0, at=None, rt=0,
                rat=((-1, -1), (-1, -1)), dh=0, dw=0, bmsize_custom=False, agg_custom=False,
                ctx_used=None, retain=False, mmr_coll=False, custom=None):
    """Symbol dictionary segment data. `classes` = [(height, [entry])] where
    an entry is a bitmap (generic/collective), or with `refagg` one of
    ("ref", id, rdx, rdy, bitmap) / ("agg", [(sym, s, t, refinement)], bitmap).
    `exports` = flags over input + new symbols. Returns (data, new symbols,
    exported symbols, retained contexts)."""
    at = at or DEFAULT_AT[t]
    new = []
    n_new = sum(len(c[1]) for c in classes)
    total = len(input_syms) + n_new
    flags = ((1 if huffman else 0) | (2 if refagg else 0) | (dh << 2) | (dw << 4)
             | (0x40 if bmsize_custom else 0) | (0x80 if agg_custom else 0)
             | (0x100 if ctx_used else 0) | (0x200 if retain else 0) | (t << 10) | (rt << 12))
    data = struct.pack(">H", flags)
    if not huffman:
        data += at_bytes(t, at)
    if refagg and rt == 0:
        data += rat_bytes(rat)
    data += u32(sum(exports)) + u32(n_new)
    codelen = symcodelen(total)
    customs = list(custom or [])

    def bitmap_of(entry):
        return entry if not isinstance(entry, tuple) else entry[-1]

    if not huffman:
        enc = MQEncoder()
        if ctx_used:
            gctx, rctx = list(ctx_used[0]), list(ctx_used[1])
        else:
            gctx, rctx = [0] * (1 << CTX_BITS[t]), [0] * (1 << (13 if rt == 0 else 10))
        ints = {k: IntCoder() for k in ["dh", "dw", "ex", "ai"]}
        text_ints = {}
        prev_h = 0
        for hgt, entries in classes:
            ints["dh"].encode(enc, hgt - prev_h)
            prev_h = hgt
            sw = 0
            for e in entries:
                bm = bitmap_of(e)
                ints["dw"].encode(enc, dims(bm)[0] - sw)
                sw = dims(bm)[0]
                if not refagg:
                    encode_generic(enc, gctx, bm, t, at)
                elif e[0] == "ref":
                    ints["ai"].encode(enc, 1)
                    coder = ArithText(enc, codelen, rctx, text_ints)
                    coder.sym(e[1])
                    coder.int("rdx", e[2])
                    coder.int("rdy", e[3])
                    encode_refinement(enc, rctx, bm, (input_syms + new)[e[1]], e[2], e[3], rt, rat)
                else:
                    ints["ai"].encode(enc, len(e[1]))
                    coder = ArithText(enc, codelen, rctx, text_ints)
                    bm = blank(*dims(bm))
                    text_encode(coder, input_syms + new, e[1], refine=True, rt=rt, rat=rat, region=bm)
                new.append(bm)
            ints["dw"].encode(enc, None)
        for run in export_runs(exports):
            ints["ex"].encode(enc, run)
        data += enc.flush()
        exported = [s for s, e in zip(input_syms + new, exports) if e]
        return data, new, exported, (gctx, rctx) if retain else None
    bw = BitWriter()
    dh_t = customs.pop(0) if dh == 3 else STD["B4" if dh == 0 else "B5"]
    dw_t = customs.pop(0) if dw == 3 else STD["B2" if dw == 0 else "B3"]
    bm_t = customs.pop(0) if bmsize_custom else STD["B1"]
    agg_t = customs.pop(0) if agg_custom else STD["B1"]
    rctx = [0] * (1 << (13 if rt == 0 else 10))
    prev_h = 0
    for hgt, entries in classes:
        huff_encode(bw, dh_t, hgt - prev_h)
        prev_h = hgt
        sw = 0
        for e in entries:
            bm = bitmap_of(e)
            huff_encode(bw, dw_t, dims(bm)[0] - sw)
            sw = dims(bm)[0]
            if refagg:
                if e[0] == "ref":
                    huff_encode(bw, agg_t, 1)
                    bw.put(max(1, codelen), e[1])
                    huff_encode(bw, STD["B15"], e[2])
                    huff_encode(bw, STD["B15"], e[3])
                    enc = MQEncoder()
                    encode_refinement(enc, rctx, bm, (input_syms + new)[e[1]], e[2], e[3], rt, rat)
                    coded = enc.flush()
                    huff_encode(bw, STD["B1"], len(coded))
                    bw.extend_bytes(coded)
                else:
                    huff_encode(bw, agg_t, len(e[1]))
                    tables = {"fs": STD["B6"], "ds": STD["B8"], "dt": STD["B11"], "rdw": STD["B15"],
                              "rdh": STD["B15"], "rdx": STD["B15"], "rdy": STD["B15"], "rsize": STD["B1"]}
                    coder = HuffText(bw, tables, codelen)
                    bm = blank(*dims(bm))
                    text_encode(coder, input_syms + new, e[1], refine=True, rt=rt, rat=rat, region=bm)
            new.append(bm)
        huff_encode(bw, dw_t, None)
        if not refagg:
            coll = [sum((bitmap_of(e)[y] for e in entries), []) for y in range(hgt)]
            if mmr_coll:
                coded = mmr(coll)
                huff_encode(bw, bm_t, len(coded))
                bw.extend_bytes(coded)
            else:
                huff_encode(bw, bm_t, 0)
                bw.align()
                for row in coll:
                    for x in range(0, len(row), 8):
                        byte = 0
                        for k in range(8):
                            if x + k < len(row):
                                byte |= row[x + k] << (7 - k)
                        bw.put(8, byte)
    for run in export_runs(exports):
        huff_encode(bw, STD["B1"], run)
    exported = [s for s, e in zip(input_syms + new, exports) if e]
    return data + bw.to_bytes(), new, exported, None


def export_runs(flags):
    runs = []
    cur = False
    i = 0
    while i < len(flags):
        n = 0
        while i < len(flags) and flags[i] == cur:
            n += 1
            i += 1
        runs.append(n)
        cur = not cur
    return runs


# ---------------------------------------------------------------------------
# Test images


def text_image(rng, w, h, density=0.5):
    img = blank(w, h)
    for y in range(h):
        if y % 9 < 6:
            x = rng.randrange(0, 5)
            while x < w:
                gw = rng.randrange(2, 7)
                for i in range(x, min(w, x + gw)):
                    if rng.random() < density:
                        img[y][i] = 1
                x += gw + rng.randrange(1, 5)
    for y in range(1, h):
        if rng.random() < 0.4:
            img[y] = img[y - 1][:]
    return img


def glyph(rng, w, h):
    img = blank(w, h)
    for y in range(h):
        for x in range(w):
            if (x in (0, w - 1) or y in (0, h - 1)) and rng.random() < 0.8:
                img[y][x] = 1
            elif rng.random() < 0.25:
                img[y][x] = 1
    return img


def perturb(rng, img, n=3):
    out = [row[:] for row in img]
    w, h = dims(img)
    for _ in range(n):
        x, y = rng.randrange(w), rng.randrange(h)
        out[y][x] ^= 1
    return out


def resized(rng, img, w, h):
    ow, oh = dims(img)
    out = blank(w, h)
    for y in range(h):
        for x in range(w):
            out[y][x] = get(img, x, y)
    return perturb(rng, out, 2)


# ---------------------------------------------------------------------------
# Cases


class Cases:
    def __init__(self):
        self.files_dir = os.path.join(OUT, "files")
        os.makedirs(self.files_dir, exist_ok=True)
        for f in os.listdir(self.files_dir):
            os.remove(os.path.join(self.files_dir, f))
        self.rows = []
        self.n = 0

    def write(self, name, data):
        open(os.path.join(self.files_dir, name), "wb").write(data)

    def add(self, tag, data, page, kind="embedded", globals_=None, rng=None, variants=True):
        name = "j%03d_%s.%s" % (self.n, tag, "jb2" if kind == "file" else "bin")
        self.n += 1
        self.write(name, data)
        gname = "-"
        if globals_ is not None:
            gname = name.rsplit(".", 1)[0] + ".glob"
            self.write(gname, globals_)
        self.rows.append((name, gname, kind, tag, record(page) if page is not None else "-"))
        if variants and rng is not None and len(data) > 30:
            # Truncated and corrupted variants.
            if rng.random() < 0.35:
                cut = rng.randrange(len(data) // 3, len(data))
                tn = name.rsplit(".", 1)[0] + "_trunc." + name.rsplit(".", 1)[1]
                self.write(tn, data[:cut])
                self.rows.append((tn, gname, kind, tag + ",truncated", "-"))
            if rng.random() < 0.35:
                d = bytearray(data)
                for _ in range(rng.randrange(1, 4)):
                    i = rng.randrange(len(d))
                    d[i] ^= 1 << rng.randrange(8)
                cn = name.rsplit(".", 1)[0] + "_corrupt." + name.rsplit(".", 1)[1]
                self.write(cn, bytes(d))
                self.rows.append((cn, gname, kind, tag + ",corrupt", "-"))

    def save(self):
        with open(os.path.join(OUT, "cases.tsv"), "w") as f:
            f.write("# file\tglobals\tkind\ttags\tintended (scripts/gen_jbig2_test_files.py)\n")
            for r in self.rows:
                f.write("\t".join(r) + "\n")


def page_segs(w, h, default=0, **kw):
    return [page_info(w, h, default, **kw)]


def composed(w, h, default, regions):
    page = blank(w, h, default)
    for img, x, y, op in regions:
        combine(page, img, x, y, op)
    return page


def gen_generic(cases, rng):
    # All templates, TPGDON, default/custom AT pixels, several sizes.
    for t in range(4):
        for tpgdon in (False, True):
            for custom_at in (False, True):
                w, h = rng.choice([(67, 23), (32, 17), (101, 31), (8, 5), (300, 12)])
                img = text_image(rng, w, h)
                at = DEFAULT_AT[t]
                if custom_at:
                    at = [(rng.randrange(-8, 9), rng.randrange(-6, 0)) for _ in range(4 if t == 0 else 1)]
                    if t == 0:
                        at[1] = (-rng.randrange(1, 9), 0)
                op = rng.choice(["or", "replace"])
                segs = page_segs(w, h) + [Seg(1, 38, generic_segment(img, t, at, tpgdon, op=op))]
                tag = "generic,t%d%s%s" % (t, ",tpgdon" if tpgdon else "", ",customat" if custom_at else "")
                cases.add(tag, embedded(segs), img, rng=rng)
    # Larger pages, region offsets, lossless type, all-white/all-black rows.
    for i in range(4):
        w, h = rng.choice([(129, 40), (200, 50), (64, 64)])
        img = text_image(rng, w - 10, h - 7, 0.7)
        for y in range(0, len(img), 5):
            img[y] = [y % 2] * len(img[0])
        t = i % 4
        segs = page_segs(w, h) + [Seg(1, 39 if i % 2 else 38,
                                      generic_segment(img, t, None, i >= 2, x=7, y=3))]
        page = composed(w, h, 0, [(img, 7, 3, "or")])
        cases.add("generic,offset,t%d" % t, embedded(segs), page, rng=rng)


def gen_mmr(cases, rng):
    for i, (w, h) in enumerate([(67, 23), (1, 1), (32, 9), (250, 40), (17, 3)]):
        img = text_image(rng, w, h)
        segs = page_segs(w, h) + [Seg(1, 38, generic_segment(img, mmr_=True, eofb=i % 2 == 0))]
        cases.add("generic,mmr%s" % (",eofb" if i % 2 == 0 else ""), embedded(segs), img, rng=rng)


def gen_unknown_length(cases, rng):
    for mmr_ in (False, True):
        for short in (False, True):
            w, h = 60, 20
            img = text_image(rng, w, h)
            rows = 12 if short else h
            segs = page_segs(w, h) + [Seg(1, 38, generic_segment(img, 1, None, False, mmr_, unknown_len=True,
                                                                 row_count=rows), unknown_len=True)]
            page = composed(w, h, 0, [(img[:rows], 0, 0, "or")])
            data = standalone(segs + [Seg(2, 49, b""), Seg(3, 51, b"")])
            cases.add("generic,unknownlength%s%s" % (",mmr" if mmr_ else "", ",rowcount" if short else ""),
                      data, page, kind="file", rng=rng)


def gen_compose(cases, rng):
    ops = ["or", "and", "xor", "xnor", "replace"]
    for default in (0, 1):
        for op in ops:
            w, h = 80, 30
            regions = []
            segs = page_segs(w, h, default)
            num = 1
            for k in range(3):
                rw, rh = rng.randrange(10, 60), rng.randrange(5, 25)
                img = text_image(rng, rw, rh)
                x, y = rng.randrange(0, w - 5), rng.randrange(0, h - 3)
                rop = op if k else rng.choice(ops)
                segs.append(Seg(num, 38, generic_segment(img, k % 4, None, False, k == 2, x=x, y=y, op=rop)))
                regions.append((img, x, y, rop))
                num += 1
            page = composed(w, h, default, regions)
            cases.add("compose,%s,default%d" % (op, default), embedded(segs), page, rng=rng)
    # A full-page region on a pristine page (decoded in place).
    for default in (0, 1):
        for op in ops:
            img = text_image(rng, 40, 12)
            segs = page_segs(40, 12, default) + [Seg(1, 38, generic_segment(img, 2, op=op))]
            cases.add("compose,fullpage,%s,default%d" % (op, default), embedded(segs),
                      composed(40, 12, default, [(img, 0, 0, op)]), rng=rng)


def gen_striped(cases, rng):
    for unknown in (True, False):
        w = 50
        stripes = [(0, 10), (10, 25), (25, 31)]
        segs = [page_info(w, 0xFFFFFFFF if unknown else 31, 0, striped=True, stripe=16)]
        regions = []
        num = 1
        for y0, y1 in stripes:
            img = text_image(rng, w - 4, y1 - y0)
            segs.append(Seg(num, 38, generic_segment(img, 0, x=2, y=y0)))
            regions.append((img, 2, y0, "or"))
            segs.append(Seg(num + 1, 50, u32(y1 - 1)))
            num += 2
        segs += [Seg(num, 49, b""), Seg(num + 1, 51, b"")]
        page = composed(w, 31, 0, regions)
        cases.add("striped%s" % (",unknownheight" if unknown else ""), standalone(segs), page,
                  kind="file", rng=rng)
    # Unknown height without end-of-stripe segments (error).
    segs = [page_info(20, 0xFFFFFFFF, 0, striped=True, stripe=8),
            Seg(1, 38, generic_segment(text_image(rng, 20, 4)))]
    cases.add("striped,unknownheight,noeos", embedded(segs), None)


def gen_refinement(cases, rng):
    for t in (0, 1):
        for tpgron in (False, True):
            for custom_at in (False, True):
                if t == 1 and custom_at:
                    continue
                w, h = 70, 25
                base = text_image(rng, w, h)
                target = perturb(rng, base, 25)
                at = ((-1, -1), (-1, -1))
                if custom_at:
                    at = ((rng.randrange(-3, 0), rng.randrange(-2, 0)), (rng.randrange(-2, 3), rng.randrange(-2, 3)))
                # Immediate refinement of the page (no referred-to segment).
                rx, ry, rw, rh = 5, 3, 50, 18
                page0 = composed(w, h, 0, [(base, 0, 0, "or")])
                ref_region = [row[rx:rx + rw] for row in page0[ry:ry + rh]]
                tgt = perturb(rng, ref_region, 30)
                segs = page_segs(w, h) + [Seg(1, 38, generic_segment(base, 0)),
                                          Seg(2, 42, refinement_segment(tgt, page0, -rx, -ry, t, at, tpgron,
                                                                        x=rx, y=ry, op="replace"))]
                page = composed(w, h, 0, [(base, 0, 0, "or"), (tgt, rx, ry, "replace")])
                tag = "refine,page,gr%d%s%s" % (t, ",tpgron" if tpgron else "", ",customat" if custom_at else "")
                cases.add(tag, embedded(segs), page, rng=rng)
                # Refinement of an intermediate region (decoded into the page directly).
                segs = page_segs(w, h) + [Seg(1, 36, generic_segment(base, 1)),
                                          Seg(2, 43, refinement_segment(target, base, 0, 0, t, at, tpgron), [1])]
                cases.add("refine,intermediate,gr%d%s%s" % (t, ",tpgron" if tpgron else "",
                                                           ",customat" if custom_at else ""),
                          embedded(segs), target, rng=rng)
    # Refinement of a page with default pixel 1 (its padding bits are set).
    for t in (0, 1):
        w, h = 45, 14
        base = text_image(rng, 30, 10)
        page0 = composed(w, h, 1, [(base, 2, 2, "xor")])
        tgt = perturb(rng, [row[20:45] for row in page0[1:13]], 20)
        segs = page_segs(w, h, 1) + [Seg(1, 38, generic_segment(base, 0, x=2, y=2, op="xor")),
                                     Seg(2, 42, refinement_segment(tgt, page0, -20, -1, t, x=20, y=1,
                                                                   op="replace", pad=1))]
        cases.add("refine,page,default1,gr%d" % t, embedded(segs),
                  composed(w, h, 1, [(base, 2, 2, "xor"), (tgt, 20, 1, "replace")]), rng=rng)
    # Chain: intermediate generic -> intermediate refinement -> immediate refinement at an offset.
    w, h = 60, 30
    base = text_image(rng, 40, 20)
    mid = perturb(rng, base, 20)
    final = perturb(rng, mid, 20)
    segs = page_segs(w, h, 1) + [
        Seg(1, 36, generic_segment(base, 3, x=10, y=5)),
        Seg(2, 40, refinement_segment(mid, base, 0, 0, 1, x=10, y=5), [1]),
        Seg(3, 42, refinement_segment(final, mid, 0, 0, 0, ((-2, -1), (1, 1)), True, x=10, y=5, op="xor"), [2]),
    ]
    cases.add("refine,chain,intermediate", embedded(segs), composed(w, h, 1, [(final, 10, 5, "xor")]), rng=rng)


def gen_halftone(cases, rng):
    configs = [
        dict(t=0, mmr_=False, skip=False, hop="or", n=4, pw=4, ph=4),
        dict(t=1, mmr_=False, skip=True, hop="or", n=7, pw=6, ph=5),
        dict(t=2, mmr_=False, skip=False, hop="xor", n=16, pw=3, ph=3),
        dict(t=3, mmr_=False, skip=True, hop="and", n=2, pw=8, ph=8, defpix=1),
        dict(t=0, mmr_=True, skip=False, hop="replace", n=9, pw=5, ph=4),
        dict(t=0, mmr_=True, skip=False, hop="xnor", n=3, pw=40, ph=3),
        dict(t=0, mmr_=False, skip=True, hop="or", n=5, pw=33, ph=6, rotated=True),
        dict(t=1, mmr_=False, skip=False, hop="or", n=1, pw=4, ph=4),
        dict(t=0, mmr_=False, skip=True, hop="replace", n=12, pw=4, ph=4, rotated=True, defpix=1),
    ]
    for i, c in enumerate(configs):
        patterns = [glyph(rng, c["pw"], c["ph"]) for _ in range(c["n"])]
        pdt = rng.choice([0, 1, 2, 3]) if not c["mmr_"] else 0
        rw, rh = 90, 40
        gw, gh = rw // c["pw"] + 2, rh // c["ph"] + 2
        if c.get("rotated"):
            hrx, hry = c["pw"] * 230, c["ph"] * 90
            hgx, hgy = -3 * 256, -10 * 256
        else:
            hrx, hry = c["pw"] * 256, 0
            hgx, hgy = -256 * 2, -256
        # (Grid rows advance by (HRY, HRX), so non-square patterns overlap.)
        gi = [[rng.randrange(c["n"]) for _ in range(gw)] for _ in range(gh)]
        data, region = halftone(rw, rh, patterns, gi, hgx, hgy, hrx, hry, c["t"], c["mmr_"], c["skip"],
                                c["hop"], c.get("defpix", 0), x=4, y=2, op="or")
        immediate = i % 3 != 2
        segs = page_segs(rw + 8, rh + 4) + [Seg(1, 16, pattern_dict_segment(patterns, pdt, c["mmr_"]))]
        if immediate:
            segs.append(Seg(2, 22 if i % 2 else 23, data, [1]))
            page = composed(rw + 8, rh + 4, 0, [(region, 4, 2, "or")])
        else:
            # Intermediate halftone, shown through an immediate refinement.
            target = perturb(rng, region, 15)
            segs.append(Seg(2, 20, data, [1]))
            segs.append(Seg(3, 42, refinement_segment(target, region, 0, 0, 1, x=4, y=2,
                                                      pad=c.get("defpix", 0)), [2]))
            page = composed(rw + 8, rh + 4, 0, [(target, 4, 2, "or")])
        tag = "halftone,ht%d%s%s,%s,pd%d%s%s" % (c["t"], ",mmr" if c["mmr_"] else "", ",skip" if c["skip"] else "",
                                                 c["hop"], pdt, ",rotated" if c.get("rotated") else "",
                                                 "" if immediate else ",intermediate")
        cases.add(tag, embedded(segs), page, rng=rng)
    # A halftone region without a pattern dictionary (error).
    patterns = [glyph(rng, 4, 4) for _ in range(2)]
    data, _ = halftone(20, 20, patterns, [[0, 1], [1, 0]], 0, 0, 1024, 0)
    cases.add("halftone,missingdict", embedded(page_segs(20, 20) + [Seg(1, 22, data)]), None)


def gen_symbols_arith(cases, rng):
    syms = [glyph(rng, rng.randrange(3, 9), h) for h in (5, 5, 6, 6, 6, 9) for _ in range(1)]
    syms.sort(key=lambda s: dims(s)[1])
    classes = []
    for s in syms:
        h = dims(s)[1]
        if classes and classes[-1][0] == h:
            classes[-1][1].append(s)
        else:
            classes.append((h, [s]))
    order = [s for _, cs in classes for s in cs]
    variants = []
    for corner in ("tl", "tr", "bl", "br"):
        for transposed in (False, True):
            variants.append(dict(corner=corner, transposed=transposed))
    for i, v in enumerate(variants):
        t = i % 4
        at = DEFAULT_AT[t] if i % 3 else [(rng.randrange(-4, 5), rng.randrange(-4, 0))] * (4 if t == 0 else 1)
        if t == 0 and not i % 3:
            at = [(-2, -1), (1, -1), (-1, -2), (2, -2)]
        sd, new, exported, _ = symbol_dict([], classes, [True] * len(order), t=t, at=at)
        w, h = 100, 40
        logss = i % 4
        dsoffset = [0, 3, -2, 15, -16][i % 5]
        insts = []
        for strip in range(3):
            base = 6 + strip * 12
            s = rng.randrange(0, 10)
            for _ in range(rng.randrange(2, 6)):
                sym = rng.randrange(len(exported))
                insts.append((sym, s, base + rng.randrange(1 << logss), None))
                s += rng.randrange(-3, 12)
        sbop = rng.choice(["or", "xor"])
        data, region = text_segment(w, h, exported, insts, logss=logss, dsoffset=dsoffset, sbop=sbop,
                                    defpix=i % 2, op="or", **v)
        segs = page_segs(w, h) + [Seg(1, 0, sd), Seg(2, 6 if i % 2 else 7, data, [1])]
        tag = "symbol,text,arith,sd%d,%s%s,strips%d,dsoff%d,%s" % (
            t, v["corner"], ",transposed" if v["transposed"] else "", 1 << logss, dsoffset, sbop)
        cases.add(tag, embedded(segs), composed(w, h, 0, [(region, 0, 0, "or")]), rng=rng)
    # Globals + export subsets + two dictionaries + text refinement.
    for rt in (0, 1):
        g1 = [glyph(rng, rng.randrange(4, 8), 7) for _ in range(5)]
        sd1, _, ex1, _ = symbol_dict([], [(7, g1)], [True, False, True, True, False], t=1)
        g2 = [glyph(rng, rng.randrange(4, 8), 8) for _ in range(3)]
        sd2, _, ex2, _ = symbol_dict(ex1, [(8, g2)], [False, True, True, False, True, True], t=2)
        symbols = ex1 + ex2
        insts = []
        s = 2
        for k in range(7):
            sym = rng.randrange(len(symbols))
            rf = None
            if k % 2:
                rdw, rdh = rng.randrange(-2, 3), rng.randrange(-2, 3)
                sw, sh = dims(symbols[sym])
                rf = (rdw, rdh, rng.randrange(-1, 2), rng.randrange(-1, 2),
                      resized(rng, symbols[sym], sw + rdw, sh + rdh))
            insts.append((sym, s, 10, rf))
            s += 10
        rat = ((-1, -1), (-1, -1)) if rt else ((-2, -1), (0, 1))
        data, region = text_segment(90, 20, symbols, insts, refine=True, rt=rt, rat=rat)
        globals_ = embedded([Seg(0, 0, sd1, page=0)])
        segs = [Seg(1, 48, page_info(90, 20).data), Seg(2, 0, sd2, [0]), Seg(3, 6, data, [0, 2])]
        cases.add("symbol,text,arith,globals,export,refine,gr%d" % rt, embedded(segs), region,
                  globals_=globals_, rng=rng)
    # Refinement/aggregation symbol dictionary, retained contexts.
    for rt in (0, 1):
        base = [glyph(rng, 6, 7) for _ in range(3)]
        sd1, new1, ex1, retained = symbol_dict([], [(7, base)], [True] * 3, t=0, retain=True)
        sym_ref = perturb(rng, base[1], 4)
        agg_w, agg_h = 20, 9
        agg_target = blank(agg_w, agg_h)
        insts = [(0, 0, 0, None), (2, 7, 1, (1, 0, 0, 0, resized(rng, base[2], 7, 7)))]
        tmp = blank(agg_w, agg_h)
        combine(tmp, base[0], 0, 0, "or")
        combine(tmp, insts[1][3][4], 7 + 0, 1, "or")
        agg_target = tmp
        classes = [(7, [("ref", 1, 0, 0, sym_ref)]), (9, [("agg", insts, agg_target),
                                                         ("ref", 3, 1, -1, resized(rng, sym_ref, 8, 9))])]
        rat = ((-1, -1), (-1, -1)) if rt == 1 else ((-1, -2), (1, 0))
        sd2, new2, ex2, _ = symbol_dict(ex1, classes, [False, True, False, True, True, True], refagg=True,
                                        rt=rt, rat=rat)
        # (Referring to the first dictionary for its contexts also makes its
        # exported symbols input symbols.)
        sd3, new3, ex3, _ = symbol_dict(ex1, [(7, [perturb(rng, b, 3) for b in base])],
                                        [False, True, False, True, True, False], t=0,
                                        ctx_used=retained)
        symbols = ex2 + ex3
        insts = [(k, 3 + 12 * k, 12, None) for k in range(len(symbols))]
        data, region = text_segment(90, 24, symbols, insts)
        segs = page_segs(90, 24) + [Seg(1, 0, sd1, retain=True), Seg(2, 0, sd2, [1]), Seg(3, 0, sd3, [1]),
                                    Seg(4, 6, data, [2, 3])]
        cases.add("symbol,refagg,arith,retained,gr%d" % rt, embedded(segs), region, rng=rng)


def gen_symbols_huffman(cases, rng):
    std_sel = [  # (fs, ds, dt, rdw, rdh, rdy, rdx, rsize)
        (0, 0, 0, 0, 0, 0, 0, 0), (1, 1, 1, 1, 1, 1, 1, 0), (0, 2, 2, 0, 1, 0, 1, 0), (1, 0, 1, 1, 0, 1, 0, 0)]
    for i, sel in enumerate(std_sel):
        dh, dw = i % 2, (i // 2) % 2
        heights = [5, 6, 8] if dh == 0 else [8, 5, 6]
        classes = [(h, [glyph(rng, rng.randrange(3, 9), h) for _ in range(rng.randrange(1, 4))]) for h in heights]
        if dw == 0:
            # (B.2 has no negative values.)
            classes = [(h, sorted(c, key=lambda b: dims(b)[0])) for h, c in classes]
        n = sum(len(c) for _, c in classes)
        exports = [True] * n
        if i == 3:
            exports[1] = False
        sd, new, exported, _ = symbol_dict([], classes, exports, huffman=True, dh=dh, dw=dw, mmr_coll=i % 2 == 1)
        insts = []
        logss = i
        for strip in range(3):
            base = 8 + 10 * strip
            s = rng.randrange(0, 6)
            for _ in range(rng.randrange(1, 5)):
                sym = rng.randrange(len(exported))
                rf = None
                if i >= 2 and rng.random() < 0.4:
                    sw, sh = dims(exported[sym])
                    rdw, rdh = rng.randrange(-2, 3), rng.randrange(-2, 3)
                    rf = (rdw, rdh, rng.randrange(-1, 2), rng.randrange(-2, 2),
                          resized(rng, exported[sym], sw + rdw, sh + rdh))
                insts.append((sym, s, base + rng.randrange(1 << logss), rf))
                s += rng.randrange(0, 12)
        corner = ["tl", "bl", "tr", "br"][i]
        data, region = text_segment(100, 45, exported, insts, huffman=True, logss=logss, corner=corner,
                                    transposed=i == 1, dsoffset=[0, 2, -1, 0][i], refine=i >= 2,
                                    rt=i % 2, rat=((-1, -1), (-1, -1)), hflags=sel)
        segs = page_segs(100, 45) + [Seg(1, 0, sd), Seg(2, 6, data, [1])]
        cases.add("symbol,text,huffman,dh%d,dw%d,%s,sel%d%s%s" % (
            dh, dw, "mmrcoll" if i % 2 else "rawcoll", i, ",refine" if i >= 2 else "",
            ",transposed" if i == 1 else ""), embedded(segs), region, rng=rng)
    # User-defined tables (table segments): text DS/FS and symbol DH/DW/BMSIZE.
    ds_data, ds_t = custom_table(True, 3, 3, -4, 20, [3, 3, 3, 4, 4], [2, 3, 3, 1, 2], 5, 5, 2)
    fs_data, fs_t = custom_table(False, 3, 4, 0, 64, [1, 2, 3], [4, 5, 5], 4, 4, 0)
    dh_data, dh_t = custom_table(False, 2, 2, 1, 9, [1, 2], [2, 2], 3, 3, 0)
    dw_data, dw_t = custom_table(True, 3, 3, 0, 16, [1, 2], [3, 3], 4, 4, 3)
    bm_data, bm_t = custom_table(False, 2, 5, 0, 32, [1], [5], 2, 2, 0)
    classes = [(6, [glyph(rng, 5, 6), glyph(rng, 7, 6)]), (8, [glyph(rng, 4, 8)])]
    sd, new, exported, _ = symbol_dict([], classes, [True] * 3, huffman=True, dh=3, dw=3, bmsize_custom=True,
                                       custom=[dh_t, dw_t, bm_t])
    insts = [(0, 2, 10, None), (1, 4, 10, None), (2, 3, 10, None), (1, 2, 20, None), (0, 30, 20, None)]
    data, region = text_segment(70, 30, exported, insts, huffman=True, hflags=(3, 3, 0, 0, 0, 0, 0, 0),
                                custom=[fs_t, ds_t])
    segs = page_segs(70, 30) + [Seg(1, 53, dh_data), Seg(2, 53, dw_data), Seg(3, 53, bm_data),
                                Seg(4, 0, sd, [1, 2, 3]), Seg(5, 53, fs_data), Seg(6, 53, ds_data),
                                Seg(7, 6, data, [4, 5, 6])]
    cases.add("symbol,text,huffman,customtables", embedded(segs), region, rng=rng)
    # Huffman refinement/aggregation symbol dictionary.
    base = [glyph(rng, 6, 7) for _ in range(3)]
    sd1, _, ex1, _ = symbol_dict([], [(7, base)], [True] * 3, huffman=True)
    insts = [(0, 0, 0, None), (1, 7, 1, (0, -1, 0, 0, resized(rng, base[1], 6, 6)))]
    agg = blank(14, 8)
    combine(agg, base[0], 0, 0, "or")
    combine(agg, insts[1][3][4], 7, 1, "or")
    classes = [(7, [("ref", 2, 0, 0, perturb(rng, base[2], 3))]), (8, [("agg", insts, agg)])]
    sd2, _, ex2, _ = symbol_dict(ex1, classes, [False, False, True, True, True], huffman=True, refagg=True)
    insts = [(k, 2 + 16 * k, 10, None) for k in range(len(ex2))]
    data, region = text_segment(60, 20, ex2, insts, huffman=True)
    segs = page_segs(60, 20) + [Seg(1, 0, sd1), Seg(2, 0, sd2, [1]), Seg(3, 6, data, [2])]
    cases.add("symbol,refagg,huffman", embedded(segs), region, rng=rng)


def gen_files(cases, rng):
    # Standalone files: sequential and random access, multiple segments,
    # long referred-to lists, large segment numbers, end of page/file.
    img = text_image(rng, 50, 20)
    img2 = text_image(rng, 30, 10)
    for ra in (False, True):
        segs = page_segs(60, 25) + [Seg(1, 38, generic_segment(img, 0, x=0, y=0)),
                                    Seg(2, 38, generic_segment(img2, 2, x=20, y=12, op="xor")),
                                    Seg(3, 49, b""), Seg(4, 51, b"")]
        page = composed(60, 25, 0, [(img, 0, 0, "or"), (img2, 20, 12, "xor")])
        cases.add("file,%s,eop,eof" % ("randomaccess" if ra else "sequential"),
                  standalone(segs, ra, pages=None if ra else 1), page, kind="file", rng=rng)
    # Many referred-to segments (long form) and 2/4-byte segment numbers.
    gl = [glyph(rng, 5, 6) for _ in range(6)]
    segs = [Seg(300, 48, page_info(40, 12).data)]
    sds = []
    for k in range(6):
        sd, _, ex, _ = symbol_dict([], [(6, [gl[k]])], [True], t=3)
        sds.append(Seg(301 + k, 0, sd))
    insts = [(k, 1 + 6 * k, 3, None) for k in range(6)]
    data, region = text_segment(40, 12, gl, insts)
    segs += sds + [Seg(70000, 6, data, [s.num for s in sds], page=300)]
    cases.add("file,longreferred,segnum", standalone(segs), region, kind="file", rng=rng)
    # An intermediate text region with default pixel 1, refined into the page.
    gl = [glyph(rng, 6, 6) for _ in range(3)]
    sd, _, ex, _ = symbol_dict([], [(6, gl)], [True] * 3, t=1)
    insts = [(k % 3, 2 + 7 * k, 3, None) for k in range(5)]
    data, region = text_segment(40, 12, ex, insts, defpix=1, sbop="xor", x=3, y=2)
    target = perturb(rng, region, 25)
    segs = page_segs(48, 16) + [Seg(1, 0, sd), Seg(2, 4, data, [1]),
                                Seg(3, 42, refinement_segment(target, region, 0, 0, 0, x=3, y=2, pad=1), [2])]
    cases.add("text,intermediate,default1,refine", embedded(segs), composed(48, 16, 0, [(target, 3, 2, "or")]),
              rng=rng)
    # Ignored segment types (profiles, colour palette, extension), the
    # EXTTEMPLATE flag, a second page information segment and segments after
    # the end of the page.
    img = text_image(rng, 30, 9)
    img2 = text_image(rng, 30, 9)
    gen = bytearray(generic_segment(img, 0))
    gen[17] |= 0x10
    segs = page_segs(30, 9) + [Seg(1, 52, b"\x00\x01"), Seg(2, 54, b"\x01\x02\x03"), Seg(3, 62, b"\x00" * 6),
                               Seg(4, 38, bytes(gen)), Seg(5, 48, page_info(10, 10).data), Seg(6, 49, b""),
                               Seg(7, 38, generic_segment(img2, 1, op="xor"))]
    cases.add("ignoredsegments,exttemplate,eop", embedded(segs), img, rng=rng)
    # Error cases.
    good = standalone(page_segs(10, 10) + [Seg(1, 38, generic_segment(text_image(rng, 10, 10)))])
    cases.add("error,badheader", b"\x97\x4A\x42\x32\x0D\x0A\x1A\x0B" + good[8:], None, kind="file", variants=False)
    cases.add("error,reservedbits", good[:8] + bytes([good[8] | 0x10]) + good[9:], None, kind="file", variants=False)
    cases.add("error,nopageinfo", embedded([Seg(1, 38, generic_segment(text_image(rng, 10, 10)))]), None)
    cases.add("error,emptypage", embedded(page_segs(0, 10)), None)
    cases.add("error,unknowntype", embedded(page_segs(10, 10) + [Seg(1, 9, b"")]), None)
    bad = Seg(1, 38, b"", [5])
    cases.add("error,forwardref", embedded(page_segs(10, 10)) + bad.header(), None)
    cases.add("error,toolarge", embedded(page_segs(70000, 10)), None)
    cases.add("error,empty", b"", None)
    img = text_image(rng, 20, 8)
    cases.add("generic,emptydata", embedded(page_segs(20, 8) + [Seg(1, 38, generic_segment(img)[:18 + 8])]),
              None)
    cases.add("pageonly,default1", embedded(page_segs(13, 3, 1)), blank(13, 3, 1))


def main():
    mq_self_test()
    rng = random.Random(4242)
    cases = Cases()
    gen_generic(cases, rng)
    gen_mmr(cases, rng)
    gen_unknown_length(cases, rng)
    gen_compose(cases, rng)
    gen_striped(cases, rng)
    gen_refinement(cases, rng)
    gen_halftone(cases, rng)
    gen_symbols_arith(cases, rng)
    gen_symbols_huffman(cases, rng)
    gen_files(cases, rng)
    cases.save()
    total = sum(os.path.getsize(os.path.join(cases.files_dir, f)) for f in os.listdir(cases.files_dir))
    print(len(cases.rows), "cases,", len(os.listdir(cases.files_dir)), "files,", total, "bytes")
    if len(sys.argv) > 2 and sys.argv[1] == "--check":
        check(sys.argv[2])


def check(oracle):
    """Compare the intended records with an oracle output."""
    lines = [l for l in open(oracle).read().split("\n") if l and not l.startswith("#")]
    rows = [r for r in open(os.path.join(OUT, "cases.tsv")).read().split("\n") if r and not r.startswith("#")]
    good = bad = 0
    for row, line in zip(rows, lines):
        f = row.split("\t")
        o = line.split("\t")
        if f[4] == "-":
            continue
        if o[3] == f[4] and o[2].endswith(" ok"):
            good += 1
        else:
            bad += 1
            print("not as intended:", f[0], f[3], "|", o[2], o[3], "| intended", f[4])
    print(good, "as intended,", bad, "not")


if __name__ == "__main__":
    main()
