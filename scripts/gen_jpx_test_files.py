#!/usr/bin/env python3
"""Generate the JPEG 2000 test files of `hayro/jpeg2000/testdata/files/`.

Small deterministic synthetic images are encoded with OpenJPEG's
`opj_compress` (checked with v2.5.4), covering the codestream features the
decoder supports (wavelets, MCT, progression orders, layers, resolutions,
code-block/precinct sizes, tiles with odd origins, SOP/EPH, tile parts, mode
switches, precisions, subsampling, component counts). JP2 box variants that
`opj_compress` cannot write (palettes, channel definitions, ICC/enumerated
colour specifications, extended box lengths) and a few damaged files are
assembled here from generated codestreams.

Usage: python3 scripts/gen_jpx_test_files.py
Then regenerate the oracle (in `oracle/`):
  cargo build --release --offline --bin gen_hayro_codec_tests &&
  ./target/release/gen_hayro_codec_tests jpx ../hayro/jpeg2000/testdata/files/* \
    > ../hayro/jpeg2000/testdata/oracle.tsv
"""

import os
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "hayro", "jpeg2000", "testdata", "files")
OPJ = shutil.which("opj_compress")


class Rng:
    """xorshift32, so that the images don't depend on Python's `random`."""

    def __init__(self, seed):
        self.s = (seed * 2654435761 + 1) & 0xFFFFFFFF or 1

    def next(self):
        s = self.s
        s ^= (s << 13) & 0xFFFFFFFF
        s ^= s >> 17
        s ^= (s << 5) & 0xFFFFFFFF
        self.s = s
        return s


def samples(w, h, prec, signed, comp, seed, noise=8):
    """A smooth pattern with some texture and noise for one component."""
    rng = Rng(seed * 131 + comp * 7 + 1)
    top = (1 << prec) - 1
    out = []
    for y in range(h):
        for x in range(w):
            v = (x * (17 + comp * 5) + y * (11 + comp * 3)) * top // max(1, (w + h) * 16)
            v += ((x // 4 + y // 4 + comp) % 3) * top // 8
            if (x * x + y * y + comp * 13) % 23 < 3:
                v += top // 3
            v += rng.next() % (noise + 1) * top // 255
            v %= top + 1
            if signed:
                v -= 1 << (prec - 1)
            out.append(v)
    return out


def raw_bytes(comps, prec):
    """Planar big-endian (`.raw`) samples."""
    data = bytearray()
    for vals in comps:
        for v in vals:
            if prec <= 8:
                data += struct.pack(">B", v & 0xFF)
            else:
                data += struct.pack(">H", v & 0xFFFF)
    return bytes(data)


def encode(name, w, h, ncomp=1, prec=8, signed=False, sub=None, opts=(), seed=0,
           noise=8, ext=None):
    """Encode a synthetic image with `opj_compress`, return the output path."""
    sub = sub or [(1, 1)] * ncomp
    comps = []
    for c in range(ncomp):
        dx, dy = sub[c]
        cw, ch = -(-w // dx), -(-h // dy)
        comps.append(samples(cw, ch, prec, signed, c, seed, noise))
    ext = ext or os.path.splitext(name)[1]
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "out" + ext)
        if prec % 2 == 1:
            # opj_compress's raw reader rejects odd precisions, its PGM
            # reader derives the precision from the maximum value.
            assert ncomp == 1 and not signed
            src = os.path.join(tmp, "in.pgm")
            with open(src, "wb") as f:
                f.write(b"P5\n%d %d\n%d\n" % (w, h, (1 << prec) - 1) + raw_bytes(comps, prec))
            cmd = [OPJ, "-i", src, "-o", out] + list(opts)
        else:
            src = os.path.join(tmp, "in.raw")
            with open(src, "wb") as f:
                f.write(raw_bytes(comps, prec))
            fmt = "%d,%d,%d,%d,%s@%s" % (
                w, h, ncomp, prec, "s" if signed else "u",
                ":".join("%dx%d" % s for s in sub))
            cmd = [OPJ, "-i", src, "-o", out, "-F", fmt] + list(opts)
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0 or not os.path.exists(out):
            sys.exit("opj_compress failed for %s: %s\n%s" % (name, " ".join(cmd), res.stdout + res.stderr))
        with open(out, "rb") as f:
            data = f.read()
    return data


def write(name, data):
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(data)


# ---- JP2 boxes ----


def box(tag, payload):
    return struct.pack(">I", 8 + len(payload)) + tag + payload


def xl_box(tag, payload):
    return struct.pack(">I", 1) + tag + struct.pack(">Q", 16 + len(payload)) + payload


def ihdr(w, h, nc, bpc=7):
    return box(b"ihdr", struct.pack(">IIHBBBB", h, w, nc, bpc, 7, 0, 0))


def colr_enum(cs, extra=b""):
    return box(b"colr", struct.pack(">BBBI", 1, 0, 0, cs) + extra)


def colr_icc(profile):
    return box(b"colr", struct.pack(">BBB", 2, 0, 0) + profile)


def icc_profile(cs_tag):
    """A minimal ICC header (only the colour space signature is read)."""
    header = bytearray(128)
    struct.pack_into(">I", header, 0, 128)
    header[16:20] = cs_tag
    header[36:40] = b"acsp"
    return bytes(header) + struct.pack(">I", 0)


def pclr(entries, depths):
    out = struct.pack(">HB", len(entries), len(depths))
    out += bytes(d - 1 for d in depths)
    for row in entries:
        for v, d in zip(row, depths):
            n = max(1, (d + 7) // 8)
            out += v.to_bytes(n, "big")
    return box(b"pclr", out)


def cmap(entries):
    return box(b"cmap", b"".join(struct.pack(">HBB", c, t, p) for c, t, p in entries))


def cdef(defs):
    return box(b"cdef", struct.pack(">H", len(defs)) +
               b"".join(struct.pack(">HHH", *d) for d in defs))


def jp2(codestream, header_boxes, w, h, nc, codestream_box=None):
    sig = box(b"jP  ", b"\r\n\x87\n")
    ftyp = box(b"ftyp", b"jp2 " + struct.pack(">I", 0) + b"jp2 ")
    jp2h = box(b"jp2h", ihdr(w, h, nc) + b"".join(header_boxes))
    jp2c = (codestream_box or box)(b"jp2c", codestream)
    return sig + ftyp + jp2h + jp2c


def main():
    if OPJ is None:
        sys.exit("opj_compress not found")
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        os.remove(os.path.join(OUT, f))

    # Wavelets, quality, MCT.
    write("gray8_53.j2k", encode("x.j2k", 33, 29, opts=["-n", "3"]))
    write("gray8_97.j2k", encode("x.j2k", 40, 40, opts=["-I", "-r", "8"]))
    write("gray8_97_lossless_r.j2k", encode("x.j2k", 24, 21, opts=["-I", "-n", "3"]))
    write("rgb8_mct1.j2k", encode("x.j2k", 37, 23, 3, opts=["-mct", "1", "-n", "3"]))
    write("rgb8_mct0.j2k", encode("x.j2k", 37, 23, 3, opts=["-mct", "0", "-n", "3"]))
    write("rgb8_97_mct.j2k", encode("x.j2k", 45, 38, 3, opts=["-I", "-mct", "1", "-r", "20,5"]))
    write("rgb8_97_nomct.j2k", encode("x.j2k", 45, 38, 3, opts=["-I", "-mct", "0", "-q", "35"]))

    # Progression orders with layers and precincts.
    for p in ["LRCP", "RLCP", "RPCL", "PCRL", "CPRL"]:
        write("prog_%s.j2k" % p.lower(), encode(
            "x.j2k", 50, 45, 3, opts=["-p", p, "-r", "30,10,1", "-n", "4",
                                      "-c", "[16,16],[8,8]", "-b", "8,8"], seed=3))
        write("prog_%s_tiles.j2k" % p.lower(), encode(
            "x.j2k", 41, 35, 3, opts=["-p", p, "-r", "15,1", "-n", "3", "-t", "16,16",
                                      "-d", "3,2", "-T", "1,1"], seed=4))
        write("prog_%s_sub.j2k" % p.lower(), encode(
            "x.j2k", 34, 30, 3, sub=[(1, 1), (2, 2), (2, 2)],
            opts=["-p", p, "-r", "10,1", "-n", "3", "-c", "[16,16]"], seed=5))

    # Quality layers.
    write("layers_q.j2k", encode("x.j2k", 48, 40, opts=["-q", "30,40,50", "-I"], seed=6))
    write("layers_r.j2k", encode("x.j2k", 48, 40, 3, opts=["-r", "40,20,10,1"], seed=7))
    write("layers_many.j2k", encode("x.j2k", 32, 32, opts=["-r", "80,60,40,30,20,10,5,2,1"], seed=8))

    # Resolutions.
    for n in [1, 2, 4, 6]:
        write("res_n%d.j2k" % n, encode("x.j2k", 64, 64, opts=["-n", str(n)], seed=9 + n))
    write("res_n6_97.j2k", encode("x.j2k", 70, 66, 3, opts=["-n", "6", "-I", "-r", "12"], seed=15))

    # Code-block sizes.
    for b in ["4,4", "16,64", "64,16", "32,32", "4,64"]:
        write("cblk_%s.j2k" % b.replace(",", "x"), encode(
            "x.j2k", 50, 50, opts=["-b", b, "-n", "4"], seed=16))
    write("cblk_8x4_97.j2k", encode("x.j2k", 39, 27, opts=["-b", "8,4", "-I", "-n", "3"], seed=17))

    # Precincts.
    write("prec_32_16_8.j2k", encode("x.j2k", 60, 52, 3, opts=["-c", "[32,32],[16,16],[8,8]", "-n", "5"], seed=18))
    write("prec_64x16.j2k", encode("x.j2k", 60, 52, opts=["-c", "[64,16]", "-n", "4", "-b", "16,8"], seed=19))

    # Tiles with odd image and tile origins.
    write("tiles_16.j2k", encode("x.j2k", 50, 37, opts=["-t", "16,16", "-n", "3"], seed=20))
    write("tiles_17x13_off.j2k", encode("x.j2k", 50, 37, 3, opts=["-t", "17,13", "-d", "3,5", "-T", "1,2", "-n", "2"], seed=21))
    write("tiles_off_97.j2k", encode("x.j2k", 45, 41, 3, opts=["-t", "20,24", "-d", "7,3", "-T", "5,1", "-I", "-n", "3"], seed=22))
    write("tiles_odd_origin.j2k", encode("x.j2k", 33, 33, opts=["-d", "5,9", "-n", "4"], seed=23))
    # (No tiles with subsampled components: upstream panics (index out of
    # bounds in `store`) when decoding those at a reduced resolution, and the
    # oracle decodes every file at reduced resolutions too.)

    # SOP/EPH and tile parts.
    write("sop_eph.j2k", encode("x.j2k", 40, 30, 3, opts=["-SOP", "-EPH", "-r", "10,1", "-n", "3"], seed=25))
    write("sop.j2k", encode("x.j2k", 40, 30, opts=["-SOP", "-n", "3"], seed=26))
    write("eph.j2k", encode("x.j2k", 40, 30, opts=["-EPH", "-n", "3"], seed=27))
    for tp in ["R", "L", "C"]:
        write("tp_%s.j2k" % tp.lower(), encode(
            "x.j2k", 40, 34, 3, opts=["-TP", tp, "-t", "20,20", "-r", "10,1", "-n", "3"], seed=28))
    write("plt_tlm.j2k", encode("x.j2k", 40, 34, opts=["-PLT", "-TLM", "-t", "20,20", "-n", "3"], seed=29))

    # Mode switches.
    for m in [1, 2, 4, 8, 16, 32, 63, 5, 42, 9, 36]:
        write("mode_%d.j2k" % m, encode("x.j2k", 40, 38, opts=["-M", str(m), "-n", "3"], seed=30 + m, noise=60))
        write("mode_%d_97.j2k" % m, encode("x.j2k", 40, 38, 3, opts=["-M", str(m), "-I", "-r", "6", "-n", "3"], seed=40 + m, noise=60))
    write("mode_1_layers.j2k", encode("x.j2k", 64, 64, opts=["-M", "1", "-r", "20,5,1", "-n", "4"], seed=60, noise=120))
    write("mode_5_layers.j2k", encode("x.j2k", 64, 64, opts=["-M", "5", "-r", "20,5,1", "-n", "4"], seed=61, noise=120))
    write("mode_8_odd.j2k", encode("x.j2k", 37, 31, opts=["-M", "8", "-n", "3", "-b", "8,8"], seed=62, noise=60))

    # Precisions.
    for p in [1, 2, 3, 4, 5, 7, 9, 10, 12, 15, 16]:
        write("prec%d_u.j2k" % p, encode("x.j2k", 23, 19, prec=p, opts=["-n", "3"], seed=70 + p, noise=40))
    # (Signed raw input only works with even precisions.)
    for p in [2, 4, 6, 8, 10, 12, 14, 16]:
        write("prec%d_s.j2k" % p, encode("x.j2k", 23, 19, prec=p, signed=True, opts=["-n", "3"], seed=80 + p, noise=40))
    write("prec12_97.j2k", encode("x.j2k", 30, 26, prec=12, opts=["-I", "-r", "5", "-n", "3"], seed=90))
    write("prec16_rgb.j2k", encode("x.j2k", 21, 17, 3, prec=16, opts=["-n", "2"], seed=91))
    write("prec10_rgb_97.j2k", encode("x.j2k", 21, 17, 3, prec=10, signed=True, opts=["-I", "-n", "2", "-q", "45"], seed=92))

    # Subsampling.
    write("sub_420.j2k", encode("x.j2k", 35, 27, 3, sub=[(1, 1), (2, 2), (2, 2)], opts=["-mct", "0", "-n", "3"], seed=93))
    write("sub_422.j2k", encode("x.j2k", 35, 27, 3, sub=[(1, 1), (2, 1), (2, 1)], opts=["-mct", "0", "-n", "3"], seed=94))
    write("sub_all2x2.j2k", encode("x.j2k", 35, 27, 3, sub=[(2, 2)] * 3, opts=["-n", "3"], seed=95))
    write("sub_gray3x2.j2k", encode("x.j2k", 31, 20, 1, sub=[(3, 2)], opts=["-n", "2"], seed=96))
    write("sub_420_97.j2k", encode("x.j2k", 35, 27, 3, sub=[(1, 1), (2, 2), (2, 2)], opts=["-mct", "0", "-I", "-r", "8", "-n", "3"], seed=97))

    # Component counts.
    write("comp2.j2k", encode("x.j2k", 30, 22, 2, opts=["-n", "3"], seed=98))
    write("comp4.j2k", encode("x.j2k", 30, 22, 4, opts=["-n", "3"], seed=99))
    write("comp4_mct.j2k", encode("x.j2k", 30, 22, 4, opts=["-n", "3", "-mct", "1"], seed=100))
    write("comp5.j2k", encode("x.j2k", 20, 18, 5, opts=["-n", "2"], seed=101))
    write("comp2_mct_strict.j2k", encode("x.j2k", 20, 18, 2, opts=["-n", "2"], seed=102))

    # Odd sizes around 8/16/32/64 boundaries.
    for (w, h) in [(1, 1), (1, 9), (9, 1), (7, 9), (8, 8), (15, 17), (16, 16), (31, 33),
                   (32, 32), (63, 65), (64, 64), (65, 63), (3, 70)]:
        n = 1
        while n < 5 and (min(w, h) >> n) >= 1:
            n += 1
        write("size_%dx%d.j2k" % (w, h), encode("x.j2k", w, h, opts=["-n", str(n)], seed=w * 100 + h))
        write("size_%dx%d_97.j2k" % (w, h), encode("x.j2k", w, h, 3, opts=["-n", str(n), "-I", "-r", "4"], seed=w * 100 + h + 1))

    # JP2 files written by opj_compress.
    write("jp2_gray.jp2", encode("x.jp2", 30, 25, 1, opts=["-n", "3"], seed=110))
    write("jp2_rgb.jp2", encode("x.jp2", 30, 25, 3, opts=["-n", "3", "-I", "-r", "10"], seed=111))
    write("jp2_rgba.jp2", encode("x.jp2", 30, 25, 4, opts=["-n", "3"], seed=112))
    write("jp2_gray12.jp2", encode("x.jp2", 30, 25, 1, prec=12, opts=["-n", "3"], seed=113))

    # Hand-assembled JP2 box variants.
    w, h = 28, 21
    gray = encode("x.j2k", w, h, 1, opts=["-n", "3"], seed=120)
    rgb = encode("x.j2k", w, h, 3, opts=["-n", "3"], seed=121)
    rgba = encode("x.j2k", w, h, 4, opts=["-n", "3"], seed=122)
    ga = encode("x.j2k", w, h, 2, opts=["-n", "3"], seed=123)
    rgb12 = encode("x.j2k", w, h, 3, prec=12, opts=["-n", "3"], seed=124)
    rgb_sub = encode("x.j2k", w, h, 3, sub=[(1, 1), (2, 2), (2, 2)], opts=["-n", "3", "-mct", "0"], seed=125)
    idx4 = encode("x.j2k", w, h, 1, prec=4, opts=["-n", "3"], seed=126, noise=255)
    idx8 = encode("x.j2k", w, h, 1, prec=8, opts=["-n", "3"], seed=127, noise=255)
    cmyk = encode("x.j2k", w, h, 4, opts=["-n", "3", "-mct", "0"], seed=128)

    pal16 = [[(i * 16) & 0xFF, (255 - i * 16) & 0xFF, (i * 37) & 0xFF] for i in range(16)]
    pal256 = [[i, (i * 7) & 0xFF, 255 - i] for i in range(256)]
    write("box_pclr_rgb.jp2", jp2(idx4, [colr_enum(16), pclr(pal16, [8, 8, 8]),
                                          cmap([(0, 1, 0), (0, 1, 1), (0, 1, 2)])], w, h, 1))
    write("box_pclr_nocmap.jp2", jp2(idx8, [colr_enum(16), pclr(pal256, [8, 8, 8])], w, h, 1))
    write("box_pclr_gray12.jp2", jp2(idx4, [colr_enum(17), pclr([[i * 273] for i in range(16)], [12]),
                                            cmap([(0, 1, 0)])], w, h, 1))
    write("box_pclr_short.jp2", jp2(idx8, [colr_enum(16), pclr(pal16, [8, 8, 8]),
                                           cmap([(0, 1, 0), (0, 1, 1), (0, 1, 2)])], w, h, 1))
    write("box_pclr_direct.jp2", jp2(ga, [colr_enum(16), pclr(pal16, [8, 8]),
                                          cmap([(0, 1, 0), (0, 1, 1), (1, 0, 0)])], w, h, 2))
    write("box_pclr_bad_cmap.jp2", jp2(idx4, [colr_enum(16), pclr(pal16, [8, 8, 8]),
                                              cmap([(0, 1, 0), (0, 1, 5), (3, 0, 0)])], w, h, 1))
    write("box_pclr_5bit.jp2", jp2(idx4, [colr_enum(16), pclr([[i * 2, 31 - i, i] for i in range(16)], [5, 5, 5]),
                                          cmap([(0, 1, 0), (0, 1, 1), (0, 1, 2)])], w, h, 1))

    write("box_cdef_ga.jp2", jp2(ga, [colr_enum(17), cdef([(0, 0, 1), (1, 1, 0)])], w, h, 2))
    write("box_cdef_rgba.jp2", jp2(rgba, [colr_enum(16), cdef([(0, 0, 1), (1, 0, 2), (2, 0, 3), (3, 1, 0)])], w, h, 4))
    write("box_cdef_bgra.jp2", jp2(rgba, [colr_enum(16), cdef([(3, 1, 0), (2, 0, 1), (1, 0, 2), (0, 0, 3)])], w, h, 4))
    write("box_cdef_reorder.jp2", jp2(rgb, [colr_enum(16), cdef([(0, 0, 3), (1, 0, 1), (2, 0, 2)])], w, h, 3))
    write("box_cdef_short.jp2", jp2(rgba, [colr_enum(16), cdef([(0, 0, 1), (1, 0, 2), (2, 0, 3)])], w, h, 4))
    write("box_cdef_bad_type.jp2", jp2(rgba, [colr_enum(16), cdef([(0, 0, 1), (1, 0, 2), (2, 0, 3), (3, 2, 0)])], w, h, 4))
    write("box_cdef_gap.jp2", jp2(rgba, [colr_enum(16), cdef([(0, 0, 1), (1, 0, 2), (3, 0, 3), (4, 1, 0)])], w, h, 4))

    write("box_icc_rgb.jp2", jp2(rgb, [colr_icc(icc_profile(b"RGB "))], w, h, 3))
    write("box_icc_gray.jp2", jp2(gray, [colr_icc(icc_profile(b"GRAY"))], w, h, 1))
    write("box_icc_cmyk.jp2", jp2(cmyk, [colr_icc(icc_profile(b"CMYK"))], w, h, 4))
    write("box_icc_lab.jp2", jp2(rgb, [colr_icc(icc_profile(b"Lab "))], w, h, 3))
    write("box_icc_bogus.jp2", jp2(rgba, [colr_icc(icc_profile(b"XXXX"))], w, h, 4))
    write("box_icc_short.jp2", jp2(rgb, [colr_icc(b"abc")], w, h, 3))
    write("box_icc_2clr.jp2", jp2(ga, [colr_icc(icc_profile(b"2CLR"))], w, h, 2))

    write("box_sycc.jp2", jp2(rgb, [colr_enum(18)], w, h, 3))
    write("box_sycc_sub.jp2", jp2(rgb_sub, [colr_enum(18)], w, h, 3))
    write("box_sycc_12.jp2", jp2(rgb12, [colr_enum(18)], w, h, 3))
    write("box_sycc_gray.jp2", jp2(gray, [colr_enum(18)], w, h, 1))
    write("box_cielab_default.jp2", jp2(rgb, [colr_enum(14)], w, h, 3))
    write("box_cielab_params.jp2", jp2(rgb12, [colr_enum(14, struct.pack(">7I", 100, 0, 170, 2048, 200, 1536, 0x00443530))], w, h, 3))
    write("box_cielab_prec2.jp2", jp2(encode("x.j2k", w, h, 3, prec=2, opts=["-n", "3"], seed=129), [colr_enum(14)], w, h, 3))
    write("box_romm.jp2", jp2(rgb, [colr_enum(21)], w, h, 3))
    write("box_esrgb.jp2", jp2(rgb, [colr_enum(20)], w, h, 3))
    write("box_cmyk.jp2", jp2(cmyk, [colr_enum(12)], w, h, 4))
    write("box_cmyk_ycc.jp2", jp2(cmyk, [colr_enum(12)], w, h, 4))
    write("box_unsupported_enum.jp2", jp2(rgb, [colr_enum(19)], w, h, 3))
    write("box_bad_enum.jp2", jp2(rgb, [colr_enum(99)], w, h, 3))
    write("box_colr_method3.jp2", jp2(rgb, [box(b"colr", b"\x03\x00\x00")], w, h, 3))
    write("box_colr_method3_5c.jp2", jp2(encode("x.j2k", 12, 10, 5, opts=["-n", "2"], seed=130),
                                         [box(b"colr", b"\x03\x00\x00")], 12, 10, 5))
    write("box_no_colr.jp2", jp2(rgba, [], w, h, 4))
    write("box_two_colr.jp2", jp2(gray, [colr_enum(17), colr_enum(16)], w, h, 1))
    write("box_gray_as_rgb.jp2", jp2(gray, [colr_enum(16)], w, h, 1))
    write("box_rgb_as_gray.jp2", jp2(rgb, [colr_enum(17)], w, h, 3))
    write("box_xl_codestream.jp2", jp2(rgb, [colr_enum(16)], w, h, 3, codestream_box=xl_box))
    write("box_zero_len_codestream.jp2", jp2(rgb, [colr_enum(16)], w, h, 3,
                                             codestream_box=lambda t, p: struct.pack(">I", 0) + t + p))
    write("box_extra_boxes.jp2", jp2(gray, [colr_enum(17), box(b"res ", b"\x00" * 10)], w, h, 1)
          + box(b"xml ", b"<x/>"))
    write("box_no_jp2h.jp2", box(b"jP  ", b"\r\n\x87\n") + box(b"ftyp", b"jp2 \x00\x00\x00\x00jp2 ")
          + box(b"jp2c", gray))
    write("box_no_codestream.jp2", jp2(gray, [colr_enum(17)], w, h, 1)[: -(len(gray) + 8)])
    write("box_bad_ftyp.jp2", box(b"jP  ", b"\r\n\x87\n") + box(b"ftyX", b"jp2 ") + box(b"jp2c", gray))
    write("box_trailing_garbage.jp2", jp2(gray, [colr_enum(17)], w, h, 1) + b"\x00\x00\x00\x40abcd")

    # Damaged codestreams.
    full = encode("x.j2k", 40, 36, 3, opts=["-n", "3", "-r", "10,3,1"], seed=131, noise=80)
    write("damaged_trunc_half.j2k", full[: len(full) // 2])
    write("damaged_trunc_90.j2k", full[: len(full) * 9 // 10])
    write("damaged_no_eoc.j2k", full[:-2])
    noisy = bytearray(full)
    for i in range(len(full) // 2, len(full) - 2, 97):
        noisy[i] ^= 0x5A
    write("damaged_bitflips.j2k", bytes(noisy))
    write("damaged_bad_magic.j2k", b"\xff\x4f\xff\x52" + full[4:])
    write("damaged_header_only.j2k", full[: full.index(b"\xff\x90")])
    lossy = encode("x.j2k", 40, 36, 1, opts=["-n", "3", "-I", "-r", "5"], seed=132, noise=80)
    write("damaged_trunc_97.j2k", lossy[: len(lossy) * 2 // 3])
    bypass = encode("x.j2k", 40, 36, 1, opts=["-n", "3", "-M", "1"], seed=133, noise=200)
    write("damaged_trunc_bypass.j2k", bypass[: len(bypass) * 2 // 3])
    write("damaged_trunc_jp2.jp2", jp2(full, [colr_enum(16)], 40, 36, 3)[:-200])

    total = 0
    for f in sorted(os.listdir(OUT)):
        total += os.path.getsize(os.path.join(OUT, f))
    print("%d files, %d bytes" % (len(os.listdir(OUT)), total))


if __name__ == "__main__":
    main()
