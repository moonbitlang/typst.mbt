#!/usr/bin/env python3
"""Generates extra cases for the `image`-crate-level decoding tests
(`oracle/src/bin/image_corpus.txt`, read by `gen_image_golden`): GIF and
WebP files with ICC profiles, frames that do or do not span the logical
screen, and broken headers. They are derived from cases of
`gif_corpus.txt` and `webp_corpus.txt`. Case names are `<format>/<name>`.

Usage: python3 scripts/gen_image_corpus.py
"""
import base64
import os
import struct

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BIN = os.path.join(ROOT, "oracle", "src", "bin")
OUT = os.path.join(BIN, "image_corpus.txt")


def corpus(name):
    cases = {}
    cur = None
    for line in open(os.path.join(BIN, name)):
        if line.startswith("=== "):
            cur = line[4:].strip()
            cases[cur] = ""
        elif cur is not None:
            cases[cur] += line.strip()
    return {k: base64.b64decode(v) for k, v in cases.items()}


GIFS = corpus("gif_corpus.txt")
WEBPS = corpus("webp_corpus.txt")


def gif_split(data):
    """Splits a GIF with a global palette into (header incl. palette, rest)."""
    flags = data[10]
    pos = 13
    if flags & 0x80:
        pos += 3 * (1 << ((flags & 7) + 1))
    return data[:pos], data[pos:]


def app_ext(name, blocks):
    out = bytearray(b"\x21\xff")
    out.append(len(name))
    out += name
    for b in blocks:
        out.append(len(b))
        out += b
    out.append(0)
    return bytes(out)


def gif_with_screen(data, width, height):
    return data[:6] + struct.pack("<HH", width, height) + data[10:]


def gif_with_frame(data, left, top):
    """Moves the first image descriptor of a GIF."""
    head, rest = gif_split(data)
    i = rest.index(b"\x2c")
    rest = rest[: i + 1] + struct.pack("<HH", left, top) + rest[i + 5 :]
    return head + rest


def riff(chunks):
    body = b"WEBP" + b"".join(chunks)
    return b"RIFF" + struct.pack("<I", len(body)) + body


def chunk(fourcc, data):
    pad = b"\x00" if len(data) % 2 else b""
    return fourcc + struct.pack("<I", len(data)) + data + pad


def webp_chunks(data):
    pos = 12
    out = []
    while pos + 8 <= len(data):
        fourcc = data[pos : pos + 4]
        size = struct.unpack("<I", data[pos + 4 : pos + 8])[0]
        out.append((fourcc, data[pos + 8 : pos + 8 + size]))
        pos += 8 + size + (size & 1)
    return out


def vp8x(flags, width, height):
    return chunk(
        b"VP8X",
        bytes([flags, 0, 0, 0])
        + struct.pack("<I", width - 1)[:3]
        + struct.pack("<I", height - 1)[:3],
    )


def dev_assets_images():
    """The `images` directory of the `typst-dev-assets` cargo checkout."""
    base = os.path.join(os.path.expanduser("~"), ".cargo", "git", "checkouts")
    for d in sorted(os.listdir(base)):
        if d.startswith("typst-dev-assets-"):
            for rev in sorted(os.listdir(os.path.join(base, d))):
                return os.path.join(base, d, rev, "files", "images")
    raise SystemExit("typst-dev-assets checkout not found")


def main():
    cases = []
    basic = GIFS["basic-19x12-4bit-runs"]
    head, rest = gif_split(basic)
    icc = app_ext(b"ICCRGBG1012", [b"profile-", b"data"])
    cases.append(("gif/icc", head + icc + rest))
    cases.append(("gif/icc-empty", head + app_ext(b"ICCRGBG1012", []) + rest))
    cases.append(
        (
            "gif/icc-twice",
            head + icc + app_ext(b"ICCRGBG1012", [b"second"]) + rest,
        )
    )
    cases.append(
        ("gif/icc-after-frame", head + rest[:-1] + icc + rest[-1:])
    )
    cases.append(("gif/netscape-and-icc", head + app_ext(b"NETSCAPE2.0", [b"\x01\x00\x00"]) + icc + rest))
    # Frames placed differently on the logical screen.
    cases.append(("gif/taller-screen", gif_with_screen(basic, 19, 20)))
    cases.append(("gif/taller-screen-top", gif_with_frame(gif_with_screen(basic, 19, 20), 0, 5)))
    cases.append(("gif/taller-screen-overflow", gif_with_frame(gif_with_screen(basic, 19, 20), 0, 10)))
    cases.append(("gif/wider-screen", gif_with_screen(basic, 30, 12)))
    cases.append(("gif/wider-screen-left", gif_with_frame(gif_with_screen(basic, 30, 14), 7, 1)))
    cases.append(("gif/smaller-screen", gif_with_screen(basic, 10, 5)))
    cases.append(("gif/empty-screen", gif_with_screen(basic, 0, 0)))
    cases.append(("gif/far-frame", gif_with_frame(basic, 300, 200)))
    # Files without a frame and the end of the stream at block starts.
    comment = b"\x21\xfe\x03abc\x00"
    cases.append(("gif/trailer-only", head + b"\x3b"))
    cases.append(("gif/trailer-extra-byte", head + b"\x3b\x00"))
    cases.append(("gif/comment-trailer", head + comment + b"\x3b"))
    cases.append(("gif/comment-eof", head + comment))
    cases.append(("gif/header-eof", head))
    cases.append(("gif/unknown-block-eof", head + b"\x99"))
    cases.append(("gif/unknown-block", head + b"\x99\x00"))

    lossless = webp_chunks(WEBPS["lossless-px2x2a-z0"])
    vp8l = [d for f, d in lossless if f == b"VP8L"][0]
    lossy = webp_chunks(WEBPS["lossy-grad37x23-q75"])
    vp8 = [d for f, d in lossy if f == b"VP8 "][0]
    profile = b"icc-profile-bytes"
    cases.append(
        (
            "webp/icc-lossless",
            riff([vp8x(0x30, 2, 2), chunk(b"ICCP", profile), chunk(b"VP8L", vp8l)]),
        )
    )
    cases.append(
        (
            "webp/icc-lossy",
            riff([vp8x(0x20, 37, 23), chunk(b"ICCP", profile), chunk(b"VP8 ", vp8)]),
        )
    )
    cases.append(
        (
            "webp/icc-empty",
            riff([vp8x(0x20, 37, 23), chunk(b"ICCP", b""), chunk(b"VP8 ", vp8)]),
        )
    )
    cases.append(
        (
            "webp/icc-unflagged",
            riff([vp8x(0x00, 37, 23), chunk(b"ICCP", profile), chunk(b"VP8 ", vp8)]),
        )
    )
    cases.append(("webp/riff-only", b"RIFF"))
    cases.append(("webp/bad-signature", b"RIFF\x04\x00\x00\x00WEBQ"))
    cases.append(("webp/no-chunk", riff([])))
    cases.append(("webp/bad-chunk", riff([chunk(b"ABCD", b"xx")])))
    cases.append(("webp/truncated-lossy", riff([chunk(b"VP8 ", vp8)])[:60]))

    # The GIF and WebP images of the test suite (`typst-dev-assets`).
    images = dev_assets_images()
    for name, fmt in [("small.gif", "gif"), ("small.webp", "webp")]:
        data = open(os.path.join(images, name), "rb").read()
        cases.append((f"{fmt}/dev-assets-{name.replace('.', '-')}", data))

    with open(OUT, "w") as f:
        for name, data in cases:
            f.write(f"=== {name}\n")
            b64 = base64.b64encode(data).decode()
            for i in range(0, len(b64), 76):
                f.write(b64[i : i + 76] + "\n")


if __name__ == "__main__":
    main()
