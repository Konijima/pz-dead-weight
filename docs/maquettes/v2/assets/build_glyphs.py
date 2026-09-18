#!/usr/bin/env python3
"""Bake a glyph atlas from Project Zomboid's own bitmap font pages.

Numerals  : media/fonts/EN/4x/zomboidLarge  (Noto Sans SemiBold, size=50)
Unit tag  : media/fonts/EN/2x/zomboidLarge  (Noto Sans SemiBold, size=40)

Both live in the zomboidLarge family (UIFont.Large), present in B41 and B42.
Glyphs are kept white with their alpha, so the draw side tints them the way
Lua's drawTexture(tex, x, y, w, h, r, g, b, a) would.
"""
import json, os
from PIL import Image

FONTS = os.path.expanduser(
    "~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/media/fonts")
HERE = os.path.dirname(os.path.abspath(__file__))
NUM_CHARS = "0123456789."
UNIT_CHARS = "kgl b"


def parse_fnt(path):
    common, pages, chars = {}, {}, {}
    for line in open(path, encoding="utf-8", errors="replace"):
        parts = line.split()
        if not parts:
            continue
        kv = {}
        for p in parts[1:]:
            if "=" in p:
                k, v = p.split("=", 1)
                kv[k] = v.strip('"')
        if parts[0] == "common":
            common = kv
        elif parts[0] == "page":
            pages[int(kv["id"])] = kv["file"]
        elif parts[0] == "char":
            chars[int(kv["id"])] = {k: int(v) for k, v in kv.items()}
    return common, pages, chars


def collect(rel, wanted):
    path = os.path.join(FONTS, rel)
    common, pages, chars = parse_fnt(path)
    base = os.path.dirname(path)
    imgs = {i: Image.open(os.path.join(base, f)).convert("RGBA")
            for i, f in pages.items()}
    out = []
    for ch in wanted:
        c = chars[ord(ch)]
        im = imgs[c["page"]].crop((c["x"], c["y"], c["x"] + c["width"],
                                   c["y"] + c["height"]))
        out.append(dict(ch=ch, img=im, w=c["width"], h=c["height"],
                        xo=c["xoffset"], yo=c["yoffset"], xa=c["xadvance"]))
    return common, out


def main():
    sets = {}
    packed, x, rowh, y, pad = [], 0, 0, 0, 2
    for name, rel, wanted in (("num", "EN/4x/zomboidLarge.fnt", NUM_CHARS),
                              ("unit", "EN/2x/zomboidLarge.fnt", UNIT_CHARS)):
        common, gl = collect(rel, wanted)
        sets[name] = dict(source=rel, lineHeight=int(common["lineHeight"]),
                          base=int(common["base"]), glyphs={})
        for g in gl:
            if x + g["w"] + pad > 512:
                x, y, rowh = 0, y + rowh + pad, 0
            packed.append((g, x, y))
            sets[name]["glyphs"][g["ch"]] = dict(
                sx=x, sy=y, w=g["w"], h=g["h"],
                xo=g["xo"], yo=g["yo"], xa=g["xa"])
            x += g["w"] + pad
            rowh = max(rowh, g["h"])
    atlas = Image.new("RGBA", (512, y + rowh + pad), (255, 255, 255, 0))
    for g, gx, gy in packed:
        atlas.paste(g["img"], (gx, gy), g["img"])
    atlas.save(os.path.join(HERE, "glyphs.png"))
    json.dump(sets, open(os.path.join(HERE, "glyphs.json"), "w"), indent=1)
    print("atlas", atlas.size, "num h(8) =", sets["num"]["glyphs"]["8"]["h"],
          " unit h(k) =", sets["unit"]["glyphs"]["k"]["h"])


if __name__ == "__main__":
    main()
