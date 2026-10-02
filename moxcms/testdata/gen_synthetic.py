#!/usr/bin/env python3
"""Generates synthetic ICC profiles exercising moxcms code paths that the
real-world fixtures do not cover (differing RGB curves, CICP transfer
characteristics, parametric curve types, lutAtoBType CMYK pipelines).

Usage: python3 moxcms/testdata/gen_synthetic.py [out_dir]
(writes synth_*.icc next to this script by default)
"""

import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def s15(v):
    return struct.pack(">i", int(round(v * 65536)))


def xyz_tag(x, y, z):
    return b"XYZ " + b"\0" * 4 + s15(x) + s15(y) + s15(z)


def curv(entries):
    return b"curv" + b"\0" * 4 + struct.pack(">I", len(entries)) + b"".join(
        struct.pack(">H", e) for e in entries
    )


def para(kind, params):
    return (
        b"para"
        + b"\0" * 4
        + struct.pack(">HH", kind, 0)
        + b"".join(s15(p) for p in params)
    )


def pad4(b):
    return b + b"\0" * ((4 - len(b) % 4) % 4)


def profile(cls, space, pcs, version, tags):
    """tags: list of (sig, data)."""
    n = len(tags)
    offset = 132 + 12 * n
    table = b""
    body = b""
    for sig, data in tags:
        data = pad4(data)
        table += sig.encode() + struct.pack(">II", offset + len(body), len(data))
        body += data
    size = 132 + 12 * n + len(body)
    header = struct.pack(">I", size)
    header += b"\0" * 4
    header += struct.pack(">I", version)
    header += cls.encode() + space.encode() + pcs.encode()
    header += b"\0" * 12  # date
    header += b"acsp"
    header += b"\0" * 24  # platform, flags, manufacturer, model, attributes
    header += struct.pack(">I", 0)  # intent
    header += s15(0.9642) + s15(1.0) + s15(0.8249)
    header += b"\0" * 48
    assert len(header) == 128
    return header + struct.pack(">I", n) + table + body


SRGB_COLORANTS = [
    (0.4360747, 0.2225045, 0.0139322),
    (0.3850649, 0.7168786, 0.0971045),
    (0.1430804, 0.0606169, 0.7141733),
]


def rgb_profile(r, g, b, version=0x04300000, extra=()):
    tags = [
        ("rXYZ", xyz_tag(*SRGB_COLORANTS[0])),
        ("gXYZ", xyz_tag(*SRGB_COLORANTS[1])),
        ("bXYZ", xyz_tag(*SRGB_COLORANTS[2])),
        ("wtpt", xyz_tag(0.9642, 1.0, 0.8249)),
        ("rTRC", r),
        ("gTRC", g),
        ("bTRC", b),
    ]
    tags += list(extra)
    return profile("mntr", "RGB ", "XYZ ", version, tags)


def table_curve(n, f):
    return [min(65535, max(0, int(round(f(i / (n - 1)) * 65535)))) for i in range(n)]


def curve_mab(c):
    """A curve inside mAB/mBA: same encoding as a TRC."""
    return pad4(c)


def lut_ab(in_ch, out_ch, a_curves, clut, grid, m_curves, matrix, b_curves):
    """lutAtoBType ('mAB ')."""
    head_len = 32
    parts = []
    offsets = {}
    cur = head_len

    def add(name, data):
        nonlocal cur
        offsets[name] = cur
        parts.append(data)
        cur += len(data)

    if b_curves is not None:
        add("b", b"".join(curve_mab(c) for c in b_curves))
    if matrix is not None:
        m, bias = matrix
        add("matrix", b"".join(s15(v) for v in m) + b"".join(s15(v) for v in bias))
    if m_curves is not None:
        add("m", b"".join(curve_mab(c) for c in m_curves))
    if clut is not None:
        gp = bytes(grid + [0] * (16 - len(grid)))
        data = gp + bytes([2, 0, 0, 0]) + b"".join(struct.pack(">H", v) for v in clut)
        add("clut", pad4(data))
    if a_curves is not None:
        add("a", b"".join(curve_mab(c) for c in a_curves))
    head = b"mAB " + b"\0" * 4 + bytes([in_ch, out_ch, 0, 0])
    head += struct.pack(
        ">IIIII",
        offsets.get("b", 0),
        offsets.get("matrix", 0),
        offsets.get("m", 0),
        offsets.get("clut", 0),
        offsets.get("a", 0),
    )
    assert len(head) == head_len
    return head + b"".join(parts)


def cmyk_clut(grid, out_lab):
    vals = []
    for c in range(grid):
        for m in range(grid):
            for y in range(grid):
                for k in range(grid):
                    cf, mf, yf, kf = (v / (grid - 1) for v in (c, m, y, k))
                    r = (1 - cf) * (1 - kf)
                    g = (1 - mf) * (1 - kf)
                    b = (1 - yf) * (1 - kf)
                    if out_lab:
                        l = 0.2 * r + 0.7 * g + 0.1 * b
                        a = 0.5 + 0.3 * (r - g)
                        bb = 0.5 + 0.3 * (g - b)
                        out = (l, a, bb)
                    else:
                        out = (0.4 * r + 0.35 * g + 0.15 * b, 0.2 * r + 0.7 * g + 0.1 * b, 0.02 * r + 0.1 * g + 0.7 * b)
                    vals += [min(65535, max(0, int(round(v * 65535)))) for v in out]
    return vals


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    files = {}
    srgb_para = para(3, [2.4, 1 / 1.055, 0.055 / 1.055, 1 / 12.92, 0.04045])
    # Differing curves -> TransformShaperRgbNeon (float) executor.
    files["synth_rgb_mixed_trc.icc"] = rgb_profile(
        srgb_para,
        curv([0x0233]),
        curv(table_curve(256, lambda x: x ** 1.8)),
    )
    # All parametric curve types (same on all channels).
    for kind, params in [
        (0, [2.2]),
        (1, [2.4, 1.1, -0.1]),
        (2, [2.4, 1.1, -0.1, 0.05]),
        (3, [2.4, 1 / 1.055, 0.055 / 1.055, 1 / 12.92, 0.04045]),
        (4, [2.6, 0.95, 0.05, 1 / 10.0, 0.08, 0.01, 0.02]),
    ]:
        c = para(kind, params)
        files[f"synth_rgb_para{kind}.icc"] = rgb_profile(c, c, c)
        files[f"synth_gray_para{kind}.icc"] = profile(
            "mntr", "GRAY", "XYZ ", 0x04300000, [("kTRC", c), ("wtpt", xyz_tag(0.9642, 1.0, 0.8249))]
        )
    # Identity and gamma curv
    files["synth_rgb_curv_empty.icc"] = rgb_profile(curv([]), curv([]), curv([]))
    files["synth_gray_gamma18.icc"] = profile(
        "mntr", "GRAY", "XYZ ", 0x02100000, [("kTRC", curv([0x01CD])), ("wtpt", xyz_tag(0.9642, 1.0, 0.8249))]
    )
    files["synth_gray_table.icc"] = profile(
        "mntr", "GRAY", "XYZ ", 0x02100000,
        [("kTRC", curv(table_curve(1024, lambda x: x ** 2.2 if x > 0.04 else x / 12.0))), ("wtpt", xyz_tag(0.9642, 1.0, 0.8249))],
    )
    # CICP transfer characteristics on a matrix shaper.
    for tc in [1, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 16, 17, 18]:
        cicp = b"cicp" + b"\0" * 4 + bytes([1, tc, 0, 1])
        files[f"synth_rgb_cicp{tc}.icc"] = rgb_profile(
            srgb_para, srgb_para, srgb_para, version=0x04400000, extra=[("cicp", cicp)]
        )
    # CMYK lutAtoBType pipelines (Lab and XYZ PCS, linear and non-linear A curves).
    grid = 5
    lin = curv([])
    a_nl = [curv(table_curve(64, lambda x, e=e: x ** e)) for e in (1.2, 0.9, 1.1, 1.3)]
    m_nl = [para(0, [1.1]), para(0, [0.9]), para(0, [1.05])]
    b_nl = [para(0, [1.0 / 1.1]), curv([]), para(1, [1.2, 1.0, 0.0])]
    mat = ([1.0, 0.02, 0.0, 0.01, 0.98, 0.0, 0.0, 0.03, 1.0], [0.0, 0.01, 0.0])
    for name, pcs, a, m, b, matrix in [
        ("synth_cmyk_mab_lab_linear.icc", "Lab ", [lin] * 4, None, [lin] * 3, None),
        ("synth_cmyk_mab_lab_curves.icc", "Lab ", a_nl, m_nl, b_nl, mat),
        ("synth_cmyk_mab_xyz_curves.icc", "XYZ ", a_nl, m_nl, b_nl, mat),
    ]:
        clut = cmyk_clut(grid, pcs == "Lab ")
        tag = lut_ab(4, 3, a, clut, [grid] * 4, m, matrix, b)
        files[name] = profile("prtr", "CMYK", pcs, 0x04300000, [("A2B0", tag), ("wtpt", xyz_tag(0.9642, 1.0, 0.8249))])
    for name, data in files.items():
        with open(os.path.join(out, name), "wb") as f:
            f.write(data)
    print(len(files), "profiles")


if __name__ == "__main__":
    main()
