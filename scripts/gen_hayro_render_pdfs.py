#!/usr/bin/env python3
"""Write synthetic PDFs that exercise hayro's renderer (`hayro/render`) in
ways hayro's own test corpus does not: all blend modes, transparency groups
with opacity and soft masks (incl. transfer functions and backdrops), images
at various scales/transforms with and without interpolation, soft masks of a
different size, stencil masks with color and pattern paints, gradients with
all extend combinations (axial, concentric/focal/strip radial), dashed and
thin strokes, and even-odd clips.

Usage: python3 scripts/gen_hayro_render_pdfs.py
Writes `hayro/render/testdata/pdfs/*.pdf` (listed in
`hayro/render/testdata/corpus.txt`).
"""

import os
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "hayro/render/testdata/pdfs")


class Pdf:
    def __init__(self):
        self.objects = []

    def add(self, body):
        """Add an object (bytes or str) and return its reference string."""
        if isinstance(body, str):
            body = body.encode("latin-1")
        self.objects.append(body)
        return f"{len(self.objects)} 0 R"

    def reserve(self):
        self.objects.append(None)
        return len(self.objects)

    def set(self, num, body):
        if isinstance(body, str):
            body = body.encode("latin-1")
        self.objects[num - 1] = body

    def stream(self, dict_entries, data, compress=False):
        if isinstance(data, str):
            data = data.encode("latin-1")
        if compress:
            data = zlib.compress(data)
            dict_entries += " /Filter /FlateDecode"
        return self.add(
            f"<< {dict_entries} /Length {len(data)} >>\nstream\n".encode("latin-1")
            + data
            + b"\nendstream"
        )

    def write(self, path, pages):
        """`pages`: list of (width, height, resources, content)."""
        pages_num = self.reserve()
        kids = []
        for (w, h, resources, content) in pages:
            c = self.stream("", content)
            kids.append(
                self.add(
                    f"<< /Type /Page /Parent {pages_num} 0 R /MediaBox [0 0 {w} {h}] "
                    f"/Resources {resources} /Contents {c} >>"
                )
            )
        self.set(
            pages_num,
            f"<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(kids)} >>",
        )
        catalog = self.add(f"<< /Type /Catalog /Pages {pages_num} 0 R >>")
        out = bytearray(b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n")
        offsets = []
        for i, body in enumerate(self.objects):
            offsets.append(len(out))
            out += f"{i + 1} 0 obj\n".encode() + body + b"\nendobj\n"
        xref = len(out)
        out += f"xref\n0 {len(self.objects) + 1}\n0000000000 65535 f \n".encode()
        for o in offsets:
            out += f"{o:010d} 00000 n \n".encode()
        out += (
            f"trailer\n<< /Size {len(self.objects) + 1} /Root {catalog} >>\n"
            f"startxref\n{xref}\n%%EOF\n"
        ).encode()
        with open(path, "wb") as f:
            f.write(out)


BLEND_MODES = [
    "Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten",
    "ColorDodge", "ColorBurn", "HardLight", "SoftLight", "Difference",
    "Exclusion", "Hue", "Saturation", "Color", "Luminosity",
]


def blend_modes():
    pdf = Pdf()
    gs = {}
    for i, bm in enumerate(BLEND_MODES):
        gs[f"B{i}"] = pdf.add(f"<< /Type /ExtGState /BM /{bm} >>")
        gs[f"T{i}"] = pdf.add(f"<< /Type /ExtGState /BM /{bm} /ca 0.6 /CA 0.6 >>")
    gs["H"] = pdf.add("<< /Type /ExtGState /ca 0.5 >>")
    shading = pdf.add(
        "<< /ShadingType 2 /ColorSpace /DeviceRGB /Coords [0 0 400 0] "
        "/Function << /FunctionType 2 /Domain [0 1] /C0 [0.9 0.2 0.1] /C1 [0.1 0.4 0.9] /N 1 >> "
        "/Extend [true true] >>"
    )
    res = (
        "<< /ExtGState << "
        + " ".join(f"/{k} {v}" for k, v in gs.items())
        + f" >> /Shading << /S0 {shading} >> >>"
    )
    content = []
    # A gradient backdrop with some transparent regions.
    content.append("q 0 0 400 200 re W n /S0 sh Q")
    content.append("q /H gs 0.2 0.8 0.3 rg 0 200 400 200 re f Q")
    for i in range(len(BLEND_MODES)):
        x = 10 + (i % 8) * 48
        for row, prefix in enumerate(["B", "T"]):
            y = 20 + (i // 8) * 90 + row * 200
            content.append(
                f"q /{prefix}{i} gs 1 0.85 0.2 rg {x} {y} 40 40 re f "
                f"0.3 0.1 0.6 rg {x + 10} {y + 30} 30 30 re f "
                f"0.9 0.9 0.9 RG 3 w {x} {y} m {x + 40} {y + 60} l S Q"
            )
    pages = [(400, 400, res, "\n".join(content))]
    # Blend modes inside an isolated and a non-isolated transparency group.
    for isolated in ["true", "false"]:
        inner = []
        for i in range(len(BLEND_MODES)):
            x = 10 + (i % 8) * 48
            y = 20 + (i // 8) * 90
            inner.append(
                f"q /T{i} gs 0.1 0.7 0.9 rg {x} {y} 40 40 re f "
                f"1 0.3 0.3 rg {x + 15} {y + 15} 30 30 re f Q"
            )
        form = pdf.stream(
            "/Type /XObject /Subtype /Form /BBox [0 0 400 200] "
            f"/Group << /S /Transparency /I {isolated} /CS /DeviceRGB >> /Resources {res}",
            "\n".join(inner),
        )
        res2 = (
            "<< /ExtGState << "
            + " ".join(f"/{k} {v}" for k, v in gs.items())
            + f" >> /Shading << /S0 {shading} >> /XObject << /F0 {form} >> >>"
        )
        pages.append(
            (
                400,
                200,
                res2,
                "q 0 0 400 200 re W n /S0 sh Q q /H gs /F0 Do Q q 1 0 0 1 5 5 cm /B3 gs /F0 Do Q",
            )
        )
    pdf.write(os.path.join(OUT, "blend_modes.pdf"), pages)


def masks_and_groups():
    pdf = Pdf()
    tr = "<< /FunctionType 2 /Domain [0 1] /C0 [1] /C1 [0] /N 2.2 >>"
    # Luminosity soft mask with a gradient, a backdrop and a transfer function.
    mshading = pdf.add(
        "<< /ShadingType 2 /ColorSpace /DeviceGray /Coords [0 0 300 0] "
        "/Function << /FunctionType 2 /Domain [0 1] /C0 [0] /C1 [1] /N 1 >> /Extend [true true] >>"
    )
    mask_form = pdf.stream(
        "/Type /XObject /Subtype /Form /BBox [0 0 300 300] "
        "/Group << /S /Transparency /CS /DeviceGray >> "
        f"/Resources << /Shading << /M {mshading} >> >>",
        "q 20 20 260 200 re W n /M sh Q 0.5 g 100 230 80 50 re f",
    )
    alpha_form = pdf.stream(
        "/Type /XObject /Subtype /Form /BBox [0 0 300 300] /Group << /S /Transparency >> "
        "/Resources << /ExtGState << /A << /ca 0.4 >> >> >>",
        "0 0 1 rg 50 50 m 250 80 l 150 260 l h f /A gs 20 200 120 80 re f",
    )
    gs = {
        "L": pdf.add(f"<< /Type /ExtGState /SMask << /Type /Mask /S /Luminosity /G {mask_form} >> >>"),
        "LT": pdf.add(
            f"<< /Type /ExtGState /SMask << /Type /Mask /S /Luminosity /G {mask_form} /TR {tr} /BC [0.3] >> >>"
        ),
        "A": pdf.add(f"<< /Type /ExtGState /SMask << /Type /Mask /S /Alpha /G {alpha_form} >> >>"),
        "N": pdf.add("<< /Type /ExtGState /SMask /None >>"),
        "O": pdf.add("<< /Type /ExtGState /ca 0.5 /CA 0.7 >>"),
        "O2": pdf.add("<< /Type /ExtGState /ca 0.3 >>"),
    }
    group = pdf.stream(
        "/Type /XObject /Subtype /Form /BBox [0 0 300 300] /Group << /S /Transparency /I true >> "
        "/Resources << /ExtGState << /O2 " + gs["O2"] + " >> >>",
        "1 0 0 rg 30 30 150 150 re f 0 0.6 0 rg 90 90 150 150 re f /O2 gs 0 0 0 rg 60 150 200 60 re f",
    )
    res = (
        "<< /ExtGState << "
        + " ".join(f"/{k} {v}" for k, v in gs.items())
        + f" >> /XObject << /G {group} >> >>"
    )
    pages = []
    for g in ["L", "LT", "A"]:
        pages.append(
            (
                300,
                300,
                res,
                f"0.95 0.95 0.8 rg 0 0 300 300 re f q /{g} gs 0.8 0.1 0.5 rg 0 0 300 300 re f "
                f"/N gs 0 0 1 rg 10 10 40 40 re f Q q /{g} gs /O gs /G Do Q",
            )
        )
    pages.append((300, 300, res, "q /O gs /G Do Q q 1 0 0 1 40 -20 cm /O gs /G Do Q"))
    pdf.write(os.path.join(OUT, "masks_and_groups.pdf"), pages)


def image_data(w, h, channels, seed):
    out = bytearray()
    for y in range(h):
        for x in range(w):
            for c in range(channels):
                out.append((x * 37 + y * 91 + c * 53 + seed * 17 + (x * y * 7) % 23) % 256)
    return bytes(out)


def images():
    pdf = Pdf()
    xo = {}
    xo["RGB"] = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 7 /Height 5 /ColorSpace /DeviceRGB /BitsPerComponent 8",
        image_data(7, 5, 3, 1),
        compress=True,
    )
    xo["RGBI"] = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 7 /Height 5 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Interpolate true",
        image_data(7, 5, 3, 1),
        compress=True,
    )
    xo["GRAY"] = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 31 /Height 17 /ColorSpace /DeviceGray /BitsPerComponent 8 /Interpolate true",
        image_data(31, 17, 1, 2),
        compress=True,
    )
    big = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 120 /Height 90 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Interpolate true",
        image_data(120, 90, 3, 3),
        compress=True,
    )
    xo["BIG"] = big
    smask_same = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 7 /Height 5 /ColorSpace /DeviceGray /BitsPerComponent 8",
        image_data(7, 5, 1, 4),
    )
    smask_other = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 13 /Height 11 /ColorSpace /DeviceGray /BitsPerComponent 8 /Interpolate true",
        image_data(13, 11, 1, 5),
    )
    xo["SM"] = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 7 /Height 5 /ColorSpace /DeviceRGB /BitsPerComponent 8 "
        f"/SMask {smask_same}",
        image_data(7, 5, 3, 6),
        compress=True,
    )
    xo["SMO"] = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 7 /Height 5 /ColorSpace /DeviceRGB /BitsPerComponent 8 "
        f"/SMask {smask_other}",
        image_data(7, 5, 3, 7),
        compress=True,
    )
    xo["GSM"] = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 31 /Height 17 /ColorSpace /DeviceGray /BitsPerComponent 8 "
        f"/SMask {pdf.stream('/Type /XObject /Subtype /Image /Width 31 /Height 17 /ColorSpace /DeviceGray /BitsPerComponent 8', image_data(31, 17, 1, 8))}",
        image_data(31, 17, 1, 9),
        compress=True,
    )
    # A 1-bit stencil mask.
    stencil_bits = bytearray()
    for y in range(9):
        row = 0
        for x in range(16):
            if (x + y) % 3 == 0 or x == y:
                row |= 1 << (15 - x)
        stencil_bits += row.to_bytes(2, "big")
    xo["ST"] = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 16 /Height 9 /ImageMask true /BitsPerComponent 1",
        bytes(stencil_bits),
    )
    xo["STI"] = pdf.stream(
        "/Type /XObject /Subtype /Image /Width 16 /Height 9 /ImageMask true /BitsPerComponent 1 /Interpolate true /Decode [1 0]",
        bytes(stencil_bits),
    )
    pattern = pdf.stream(
        "/Type /Pattern /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 10 10] /XStep 10 /YStep 10 "
        "/Resources << >>",
        "1 0 0 rg 0 0 5 5 re f 0 0 1 rg 5 5 5 5 re f",
    )
    ext = pdf.add("<< /Type /ExtGState /ca 0.5 >>")
    res = (
        "<< /XObject << "
        + " ".join(f"/{k} {v}" for k, v in xo.items())
        + f" >> /Pattern << /P {pattern} >> /ExtGState << /H {ext} >> >>"
    )
    draws = []
    names = ["RGB", "RGBI", "GRAY", "BIG", "SM", "SMO", "GSM"]
    for i, n in enumerate(names):
        x = 10 + (i % 4) * 100
        y = 10 + (i // 4) * 100
        # Upscaled, downscaled and skewed.
        draws.append(f"q 80 0 0 60 {x} {y} cm /{n} Do Q")
        draws.append(f"q 6 0 0 3 {x} {y + 70} cm /{n} Do Q")
        draws.append(f"q 30 10 -8 25 {x + 40} {y + 65} cm /{n} Do Q")
    draws.append("q 0.2 0.6 0.9 rg 64 0 0 36 10 210 cm /ST Do Q")
    draws.append("q /H gs 0.9 0.3 0.1 rg 64 0 0 36 90 210 cm /STI Do Q")
    draws.append("q /Pattern cs /P scn 64 0 0 36 170 210 cm /ST Do Q")
    draws.append("q 0 0.5 0 rg 7 0 0 4 250 210 cm /ST Do Q")
    draws.append("q 0 0.5 0 rg 40 20 -10 30 300 210 cm /STI Do Q")
    pdf.write(os.path.join(OUT, "images.pdf"), [(420, 260, res, "\n".join(draws))])


def gradients():
    pdf = Pdf()
    fn = "<< /FunctionType 2 /Domain [0 1] /C0 [1 0.8 0] /C1 [0.1 0.2 0.9] /N 1 >>"
    fn3 = (
        "<< /FunctionType 3 /Domain [0 1] /Functions ["
        "<< /FunctionType 2 /Domain [0 1] /C0 [1 0 0] /C1 [0 1 0] /N 1 >> "
        "<< /FunctionType 2 /Domain [0 1] /C0 [0 1 0] /C1 [0 0 1] /N 1 >>] "
        "/Bounds [0.4] /Encode [0 1 0 1] >>"
    )
    shadings = {}
    i = 0
    for ext in ["[false false]", "[true false]", "[false true]", "[true true]"]:
        shadings[f"A{i}"] = pdf.add(
            f"<< /ShadingType 2 /ColorSpace /DeviceRGB /Coords [10 0 70 0] /Function {fn} /Extend {ext} >>"
        )
        shadings[f"C{i}"] = pdf.add(
            f"<< /ShadingType 3 /ColorSpace /DeviceRGB /Coords [40 40 5 40 40 35] /Function {fn3} /Extend {ext} >>"
        )
        shadings[f"F{i}"] = pdf.add(
            f"<< /ShadingType 3 /ColorSpace /DeviceRGB /Coords [30 35 0 45 40 35] /Function {fn} /Extend {ext} >>"
        )
        shadings[f"S{i}"] = pdf.add(
            f"<< /ShadingType 3 /ColorSpace /DeviceRGB /Coords [20 40 12 60 40 12] /Function {fn3} /Extend {ext} >>"
        )
        shadings[f"R{i}"] = pdf.add(
            f"<< /ShadingType 3 /ColorSpace /DeviceRGB /Coords [40 40 30 50 45 5] /Function {fn} /Extend {ext} >>"
        )
        i += 1
    patterns = {}
    patterns["PA"] = pdf.add(f"<< /Type /Pattern /PatternType 2 /Shading {shadings['A3']} /Matrix [1 0.3 -0.2 1 5 5] >>")
    patterns["PF"] = pdf.add(f"<< /Type /Pattern /PatternType 2 /Shading {shadings['F1']} >>")
    gs = pdf.add("<< /Type /ExtGState /ca 0.6 /CA 0.6 >>")
    res = (
        "<< /Shading << "
        + " ".join(f"/{k} {v}" for k, v in shadings.items())
        + " >> /Pattern << "
        + " ".join(f"/{k} {v}" for k, v in patterns.items())
        + f" >> /ExtGState << /H {gs} >> >>"
    )
    content = []
    for col, prefix in enumerate(["A", "C", "F", "S", "R"]):
        for row in range(4):
            content.append(
                f"q 1 0 0 1 {10 + col * 85} {10 + row * 85} cm 0 0 80 80 re W n /{prefix}{row} sh Q"
            )
    content.append("q /Pattern cs /PA scn 440 10 100 150 re f Q")
    content.append("q /H gs /Pattern CS /PF SCN 12 w 1 j 450 200 m 530 260 l 470 330 l S Q")
    content.append("q /Pattern cs /PF scn 1 0 0 1 440 0 cm 10 340 m 90 340 l 50 390 l h f Q")
    pdf.write(os.path.join(OUT, "gradients.pdf"), [(550, 400, res, "\n".join(content))])


def strokes():
    pdf = Pdf()
    content = ["0.1 0.1 0.1 RG"]
    y = 20
    for w in ["0", "0.05", "0.5", "1", "3", "9"]:
        for j in range(3):
            for c in range(3):
                x = 10 + (j * 3 + c) * 60
                content.append(
                    f"q {w} w {j} j {c} J [{'' if c == 0 else '6 3 1 3'}] {c} d "
                    f"{x} {y} m {x + 20} {y + 30} l {x + 40} {y} l {x + 50} {y + 25} {x + 10} {y + 40} {x + 45} {y + 35} c S Q"
                )
        y += 55
    content.append(
        "q 0.5 0 0.2 0.3 300 50 cm 4 w 0.8 0.2 0.2 RG 0 0 m 100 0 l 100 100 l 0 100 l h S Q"
    )
    content.append(
        "q 0 0.4 0.8 rg 400 200 m 500 300 l 400 300 l 500 200 l h 420 220 30 30 re W* n 380 180 140 140 re f Q"
    )
    content.append(
        "q 420 30 100 100 re W n 0.9 0.5 0 rg 470 80 m 560 80 470 170 380 80 c 380 -10 470 -10 470 80 c f Q"
    )
    content.append("q 2 0 0 0.5 0 0 cm 0.6 0 0.6 RG 1 w 200 700 m 280 760 l S Q")
    pdf.write(os.path.join(OUT, "strokes.pdf"), [(560, 400, "<< >>", "\n".join(content))])


def main():
    os.makedirs(OUT, exist_ok=True)
    blend_modes()
    masks_and_groups()
    images()
    gradients()
    strokes()


if __name__ == "__main__":
    main()
