#!/usr/bin/env python3
"""Writes workshop/art/320/deadweight-sprites.png: the clinic scale's two
sprites (cut from the game's own Tiles2x.pack) above the Digital Scale's four
faces (src/tiles), so the Workshop page shows what each one looks like.

Run by hand, not by sync (the output is committed). Needs Pillow and a Project
Zomboid install; pass the texturepacks folder if it is not the default Steam one.

Usage: python3 tools/gen-workshop-sprites.py [path/to/media/texturepacks]
"""
import io
import os
import struct
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PACKS = os.path.expanduser(
    "~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/media/texturepacks")
CLINIC = ["location_community_medical_01_8", "location_community_medical_01_9"]
W = 320
INK = (198, 212, 223, 255)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def clinic_sprites(packs):
    """Cut the CLINIC sprites out of Tiles2x.pack (PZPK: pages of named rects)."""
    f = open(os.path.join(packs, "Tiles2x.pack"), "rb")
    i32 = lambda: struct.unpack("<i", f.read(4))[0]

    def s():
        return f.read(i32()).decode()

    assert f.read(4) == b"PZPK"
    i32()
    found = {}
    for _ in range(i32()):
        s()
        n, _alpha = i32(), i32()
        ents = []
        for _ in range(n):
            name = s()
            ents.append((name,) + struct.unpack("<8i", f.read(32)))
        png = f.read(i32())
        for e in ents:
            if e[0] in CLINIC:
                page = Image.open(io.BytesIO(png)).convert("RGBA")
                found[e[0]] = page.crop((e[1], e[2], e[1] + e[3], e[2] + e[4]))
    return [found[n] for n in CLINIC]


def digital_faces():
    out = []
    for face in "SENW":
        im = Image.open(os.path.join(ROOT, "src", "tiles", "digital_scale_%s.png" % face)).convert("RGBA")
        out.append(im.crop(im.getbbox()))
    return out


def fit(im, factor):
    return im.resize((round(im.width * factor), round(im.height * factor)), Image.LANCZOS)


def row(canvas, sprites, y, gap):
    total = sum(s.width for s in sprites) + gap * (len(sprites) - 1)
    x = (W - total) // 2
    for s in sprites:
        canvas.alpha_composite(s, (x, y))
        x += s.width + gap


def main():
    packs = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PACKS
    clinic = [fit(s, 1.0) for s in clinic_sprites(packs)]
    digital = [fit(s, 1.6) for s in digital_faces()]
    font = ImageFont.truetype(FONT, 14)
    top, gap_label = 6, 24
    h = top + gap_label + max(s.height for s in clinic) + 22 + gap_label + max(s.height for s in digital) + 10
    canvas = Image.new("RGBA", (W, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    y = top
    d.text((W // 2, y), "Clinic scale", font=font, fill=INK, anchor="mt")
    y += gap_label
    row(canvas, clinic, y, 30)
    y += max(s.height for s in clinic) + 22
    d.text((W // 2, y), "Digital Scale (Build 42)", font=font, fill=INK, anchor="mt")
    y += gap_label
    row(canvas, digital, y, 8)
    out = os.path.join(ROOT, "workshop", "art", "320", "deadweight-sprites.png")
    canvas.save(out, optimize=True)
    print("%s: %dx%d" % (out, canvas.width, canvas.height))


if __name__ == "__main__":
    main()
