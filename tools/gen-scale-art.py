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
LO, HI = 0.33, 0.67         # footprint of the slab in the tile (0.34 tile square, a real bathroom scale is about 30 cm)
H = 5                       # slab thickness in 2x pixels (about 2.5/96 of a tile, 2.5 cm)
BEVEL = 0.018               # width of the silver rim line around the glass, tile units

# Look after the concept art Mathieu supplied (2026-09-21): black glass top,
# thin silver rim, brushed silver sides, two silver foot pads, an LCD at the
# far edge.
GLASS = (24, 27, 34, 255)
GLASS_LIT = (38, 43, 53, 255)   # soft reflection band across the glass
RIM = (206, 206, 200, 255)      # the thin silver frame line around the top
LEFT = (150, 150, 146, 255)     # the +v face, lit more
RIGHT = (98, 98, 96, 255)       # the +u face, in shade
EDGE = (52, 52, 52, 255)
PAD = (150, 148, 142, 255)
PAD_HI = (176, 174, 168, 255)
PAD_LINE = (84, 82, 78, 255)
LCD = (160, 174, 148, 255)
LCD_EDGE = (36, 44, 34, 255)
DIGIT = (26, 38, 24, 255)

# up (away from the reader) and right (reader's right hand) in (u, v), per facing
FACING = {
    "S": {"reader": (0, 1), "up": (0, -1), "right": (1, 0)},
    "E": {"reader": (1, 0), "up": (-1, 0), "right": (0, -1)},
    "N": {"reader": (0, -1), "up": (0, 1), "right": (-1, 0)},
    "W": {"reader": (-1, 0), "up": (1, 0), "right": (0, 1)},
}

# 3x5 pixel font, rows top to bottom
FONT = {
    "0": ["111", "101", "101", "101", "111"],
    "7": ["111", "001", "010", "010", "010"],
    "2": ["111", "001", "111", "100", "111"],
    "5": ["111", "100", "111", "001", "111"],
    ".": ["0", "0", "0", "0", "1"],
}
TEXT = "0.0"

LCD_W, LCD_D = 0.19, 0.08   # tile units, along the reader's right and up axes
LCD_MARGIN = 0.026          # from the far edge of the slab
PAD_X, PAD_W, PAD_LEN = 0.098, 0.05, 0.2   # pad centre offset, width, length


def pt(u, v, h=0.0):
    return ((64 + (u - v) * 64) * SS, (192 + (u + v) * 32 - h) * SS)


def poly(d, pts, fill, outline=None):
    d.polygon([pt(*p) for p in pts], fill=fill)
    if outline:
        d.line([pt(*p) for p in pts + [pts[0]]], fill=outline, width=SS)


def local(face, right, up, h=H):
    """A point of the top plane at `right` (reader's right) and `up` (away from the reader) of the centre."""
    f = FACING[face]
    return (0.5 + f["right"][0] * right + f["up"][0] * up,
            0.5 + f["right"][1] * right + f["up"][1] * up, h)


def rect(face, r0, r1, u0, u1):
    return [local(face, r0, u0), local(face, r1, u0), local(face, r1, u1), local(face, r0, u1)]


def draw_face(face):
    img = Image.new("RGBA", (FRAME_W * SS, FRAME_H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # the two visible sides, then the silver rim, then the glass
    poly(d, [(LO, HI, H), (HI, HI, H), (HI, HI, 0), (LO, HI, 0)], LEFT, EDGE)
    poly(d, [(HI, LO, H), (HI, HI, H), (HI, HI, 0), (HI, LO, 0)], RIGHT, EDGE)
    poly(d, [(LO, LO, H), (HI, LO, H), (HI, HI, H), (LO, HI, H)], RIM, EDGE)
    b = BEVEL
    poly(d, [(LO + b, LO + b, H), (HI - b, LO + b, H), (HI - b, HI - b, H), (LO + b, HI - b, H)], GLASS)
    # a soft reflection band across the glass, on the reader's diagonal
    half = 0.5 * (HI - LO) - b
    poly(d, [local(face, -half, half * 0.2), local(face, -half, half * 0.75),
             local(face, half * 0.35, -half), local(face, half * 0.8, -half)], GLASS_LIT)
    # two silver foot pads, a thin split across each
    for side in (-1, 1):
        x0, x1 = side * PAD_X - PAD_W / 2, side * PAD_X + PAD_W / 2
        y0, y1 = -PAD_LEN / 2 - 0.02, PAD_LEN / 2 - 0.02
        poly(d, rect(face, x0, x1, y0, y1), PAD, PAD_LINE)
        poly(d, rect(face, x0 + 0.006, x1 - 0.006, (y0 + y1) / 2 + 0.004, y1 - 0.006), PAD_HI)
        d.line([pt(*local(face, x0, (y0 + y1) / 2 - 0.004)), pt(*local(face, x1, (y0 + y1) / 2 - 0.004))],
               fill=PAD_LINE, width=SS)
    # the LCD window and its digits, in the top plane, at the far edge
    top = 0.5 * (HI - LO) - LCD_MARGIN
    ur0, ur1 = top - LCD_D, top

    def lp(a, b_):
        return local(face, (a - 0.5) * LCD_W, ur1 - b_ * LCD_D)

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
