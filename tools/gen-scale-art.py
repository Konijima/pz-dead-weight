#!/usr/bin/env python3
"""Draws the Digital Scale's four faces into src/tiles/digital_scale_{S,E,N,W}.png.

Run by hand, NOT by sync.sh: the PNGs are the source art tools/gen-tiles.py
packs, and a hand refined PNG must not be overwritten on every sync. This
script is the reproducible first pass (a flat slab drawn in the game's own
isometric projection), so the art has no hidden dependency on extracted
vanilla sprites.

Projection, 2x tiles, frame 128x256, the tile's floor diamond is the bottom
64 rows (top corner (64,192), left (0,224), right (128,224), bottom (64,256)):
a point of the tile (u, v in 0..1, u grows right-down on screen, v grows
left-down) at height h pixels lands at
    x = 64 + (u - v) * 64,   y = 192 + (u + v) * 32 - h
The art sits at FLOOR level (no IsSurfaceOffset): on a counter the game lifts
the object by the counter's own surface height, see ISMoveableSpriteProps.

The LCD is drawn in the top plane's own coordinates, so it is a parallelogram
that follows the isometric plane, not a screen space rectangle. Its reader
stands on the edge the sprite faces (S: +v, E: +u, N: -v, W: -u) and its text
reads from there.

Usage: python3 tools/gen-scale-art.py
"""
import os
from PIL import Image, ImageDraw

SS = 4                      # supersampling, downscaled with a box filter
FRAME_W, FRAME_H = 128, 256
LO, HI = 0.20, 0.80         # footprint of the slab in the tile (0.6 tile square)
H = 8                       # slab thickness in 2x pixels (about 4/96 of a tile)
BEVEL = 0.025               # inset of the top face inside its rim, tile units

TOP = (216, 214, 206, 255)
RIM = (240, 238, 230, 255)
LEFT = (170, 168, 160, 255)     # the +v face, lit less
RIGHT = (128, 126, 120, 255)    # the +u face, darkest
EDGE = (70, 68, 64, 255)
LCD = (168, 184, 160, 255)
LCD_EDGE = (60, 72, 58, 255)
DIGIT = (34, 48, 32, 255)
GLINT = (236, 236, 230, 255)

# up (away from the reader) and right (reader's right hand) in (u, v), per facing
FACING = {
    "S": {"reader": (0, 1), "up": (0, -1), "right": (1, 0)},
    "E": {"reader": (1, 0), "up": (-1, 0), "right": (0, -1)},
    "N": {"reader": (0, -1), "up": (0, 1), "right": (-1, 0)},
    "W": {"reader": (-1, 0), "up": (1, 0), "right": (0, 1)},
}

# 3x5 pixel font, rows top to bottom
FONT = {
    "7": ["111", "001", "010", "010", "010"],
    "2": ["111", "001", "111", "100", "111"],
    "5": ["111", "100", "111", "001", "111"],
    ".": ["0", "0", "0", "0", "1"],
}
TEXT = "72.5"

LCD_W, LCD_D = 0.44, 0.17   # tile units, along the reader's right and up axes
LCD_MARGIN = 0.05           # from the reader's edge of the slab


def pt(u, v, h=0.0):
    return ((64 + (u - v) * 64) * SS, (192 + (u + v) * 32 - h) * SS)


def poly(d, pts, fill, outline=None):
    d.polygon([pt(*p) for p in pts], fill=fill)
    if outline:
        d.line([pt(*p) for p in pts + [pts[0]]], fill=outline, width=SS)


def lcd_point(face, a, b):
    """a in 0..1 to the reader's right, b in 0..1 from the far (up) edge to the reader."""
    f = FACING[face]
    cu = 0.5 + f["reader"][0] * (0.5 * (HI - LO) - LCD_MARGIN - LCD_D / 2)
    cv = 0.5 + f["reader"][1] * (0.5 * (HI - LO) - LCD_MARGIN - LCD_D / 2)
    ra, ub = (a - 0.5) * LCD_W, (0.5 - b) * LCD_D
    return (cu + f["right"][0] * ra + f["up"][0] * ub,
            cv + f["right"][1] * ra + f["up"][1] * ub, H)


def draw_face(face):
    img = Image.new("RGBA", (FRAME_W * SS, FRAME_H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # the two visible sides, then the top
    poly(d, [(LO, HI, H), (HI, HI, H), (HI, HI, 0), (LO, HI, 0)], LEFT, EDGE)
    poly(d, [(HI, LO, H), (HI, HI, H), (HI, HI, 0), (HI, LO, 0)], RIGHT, EDGE)
    poly(d, [(LO, LO, H), (HI, LO, H), (HI, HI, H), (LO, HI, H)], RIM, EDGE)
    b = BEVEL
    poly(d, [(LO + b, LO + b, H), (HI - b, LO + b, H), (HI - b, HI - b, H), (LO + b, HI - b, H)], TOP)
    # a soft glint band across the far corner of the top
    poly(d, [(LO + 0.06, LO + 0.06, H), (LO + 0.20, LO + 0.06, H), (LO + 0.06, LO + 0.20, H)], GLINT)
    # the LCD window and its digits, in the top plane
    def lp(a, b):
        return lcd_point(face, a, b)
    poly(d, [lp(0, 0), lp(1, 0), lp(1, 1), lp(0, 1)], LCD, LCD_EDGE)
    cols = sum(len(FONT[c][0]) for c in TEXT) + (len(TEXT) - 1)   # glyph gaps of 1
    rows = 5
    padx, pady = 1.5, 1.0
    gw, gh = cols + 2 * padx, rows + 2 * pady
    x = padx
    for ch in TEXT:
        glyph = FONT[ch]
        for r, row in enumerate(glyph):
            for c, bit in enumerate(row):
                if bit == "1":
                    a0, a1 = (x + c) / gw, (x + c + 1) / gw
                    b0, b1 = (pady + r) / gh, (pady + r + 1) / gh
                    poly(d, [lp(a0, b0), lp(a1, b0), lp(a1, b1), lp(a0, b1)], DIGIT)
        x += len(glyph[0]) + 1
    return img.resize((FRAME_W, FRAME_H), Image.BOX)


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "tiles")
    os.makedirs(out, exist_ok=True)
    for face in "SENW":
        draw_face(face).save(os.path.join(out, "digital_scale_%s.png" % face))
    print("wrote 4 faces to src/tiles")


if __name__ == "__main__":
    main()
